import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sprint1D: collector-recorded, immutable, idempotent payment record for a
/// completed direct sale. Lives at
/// collectorSellRequests/{sid}/receipts/current — NEVER in collectorPayments.
/// "recorded" != bank-verified; the UI must always say so.
enum ReceiptOutcome {
  recorded,
  alreadyRecorded,
  notOwner,
  notCompleted,
  invalidAmount,
  unconfirmed,
  failed,
}

class DirectSellReceiptService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> saleRef(String saleId) =>
      _db.collection('collectorSellRequests').doc(saleId);

  DocumentReference<Map<String, dynamic>> receiptRef(String saleId) =>
      saleRef(saleId).collection('receipts').doc('current');

  Future<ReceiptOutcome> recordReceipt({
    required String saleId,
    required int amountPaise,
    required String method,
    required String reference,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return ReceiptOutcome.failed;
    if (amountPaise <= 0 || amountPaise > 1000000000) {
      return ReceiptOutcome.invalidAmount;
    }
    try {
      return await _db
          .runTransaction((tx) async {
            final sale = await tx.get(saleRef(saleId));
            if (!sale.exists) return ReceiptOutcome.notCompleted;
            final d = sale.data()!;
            if (d['collectorUid'] != uid) return ReceiptOutcome.notOwner;
            if (d['status'] != 'completed') return ReceiptOutcome.notCompleted;
            final recyclerUid = d['selectedRecyclerUid'] is String
                ? d['selectedRecyclerUid'] as String
                : '';
            final ref = receiptRef(saleId);
            final existing = await tx.get(ref);
            if (existing.exists) return ReceiptOutcome.alreadyRecorded;
            tx.set(ref, {
              'schemaVersion': 1,
              'saleId': saleId,
              'collectorUid': uid,
              'recyclerUid': recyclerUid,
              'amountPaise': amountPaise,
              'currency': 'INR',
              'method': method,
              'reference': reference,
              'status': 'recorded',
              'recordedAt': FieldValue.serverTimestamp(),
            });
            return ReceiptOutcome.recorded;
          }, timeout: const Duration(seconds: 25))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => ReceiptOutcome.unconfirmed,
          );
    } catch (_) {
      return ReceiptOutcome.failed;
    }
  }
}
