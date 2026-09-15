import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sprint1C: handover of a RESERVED direct sale. The collector proposes the
/// REAL final weight (revisioned while pending); the selected verified
/// recycler confirms PHYSICAL receipt, which completes the sale and archives
/// the lot in one transaction. Once handover starts there is no free
/// cancellation. Money is never recorded here (that is Sprint1D); server
/// Rules enforce every transition, fail-closed.
enum HandoverOutcome {
  proposed,
  alreadyPending,
  weightRevised,
  confirmed,
  alreadyCompleted,
  noSession,
  notOwner,
  notSelectedParty,
  listingUnavailable,
  revisionChanged,
  invalidWeight,
  unconfirmed,
  failed,
}

const Duration kHandoverTimeout = Duration(seconds: 25);
const double kMaxHandoverWeightKg = 10000;

class DirectSellHandoverService {
  DirectSellHandoverService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> saleRef(String saleId) =>
      _db.collection('collectorSellRequests').doc(saleId);

  DocumentReference<Map<String, dynamic>> handoverRef(String saleId) =>
      saleRef(saleId).collection('handover').doc('current');

  /// Collector starts handover: sale reserved -> handoverPending and the
  /// handover doc (proposed weight, revision 1) are written in ONE
  /// transaction. Retry-safe: an already-pending sale reports
  /// [alreadyPending] instead of writing again.
  Future<HandoverOutcome> proposeHandover({
    required String saleId,
    required double finalWeightKg,
  }) async {
    if (finalWeightKg <= 0 || finalWeightKg > kMaxHandoverWeightKg) {
      return HandoverOutcome.invalidWeight;
    }
    final user = _auth.currentUser;
    if (user == null) return HandoverOutcome.noSession;
    try {
      return await _db
          .runTransaction<HandoverOutcome>((txn) async {
            final sRef = saleRef(saleId);
            final saleSnap = await txn.get(sRef);
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return HandoverOutcome.listingUnavailable;
            }
            if (sale['collectorUid'] != user.uid) {
              return HandoverOutcome.notOwner;
            }
            if (sale['status'] == 'handoverPending') {
              return HandoverOutcome.alreadyPending;
            }
            if (sale['status'] == 'completed') {
              return HandoverOutcome.alreadyCompleted;
            }
            if (sale['status'] != 'reserved') {
              return HandoverOutcome.listingUnavailable;
            }
            final ratePaise = sale['selectedRatePaise'];
            if (ratePaise is! int) return HandoverOutcome.listingUnavailable;
            final hRef = handoverRef(saleId);
            txn.set(hRef, <String, Object?>{
              'schemaVersion': 1,
              'saleId': saleId,
              'collectorUid': user.uid,
              'status': 'proposed',
              'finalWeightKg': finalWeightKg,
              'ratePaise': ratePaise,
              'revision': 1,
              'proposedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            txn.update(sRef, <String, Object?>{
              'status': 'handoverPending',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return HandoverOutcome.proposed;
          })
          .timeout(kHandoverTimeout);
    } on TimeoutException {
      return HandoverOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_HANDOVER error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return HandoverOutcome.unconfirmed;
      }
      if (e.code == 'permission-denied') {
        return HandoverOutcome.listingUnavailable;
      }
      return HandoverOutcome.failed;
    }
  }

  /// Collector corrects the proposed weight while confirmation is pending.
  /// [revision] must match the current handover doc (concurrency guard).
  Future<HandoverOutcome> reviseHandoverWeight({
    required String saleId,
    required double finalWeightKg,
    required int revision,
  }) async {
    if (finalWeightKg <= 0 || finalWeightKg > kMaxHandoverWeightKg) {
      return HandoverOutcome.invalidWeight;
    }
    final user = _auth.currentUser;
    if (user == null) return HandoverOutcome.noSession;
    try {
      return await _db
          .runTransaction<HandoverOutcome>((txn) async {
            final sRef = saleRef(saleId);
            final saleSnap = await txn.get(sRef);
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return HandoverOutcome.listingUnavailable;
            }
            if (sale['collectorUid'] != user.uid) {
              return HandoverOutcome.notOwner;
            }
            if (sale['status'] == 'completed') {
              return HandoverOutcome.alreadyCompleted;
            }
            if (sale['status'] != 'handoverPending') {
              return HandoverOutcome.listingUnavailable;
            }
            final hRef = handoverRef(saleId);
            final hoSnap = await txn.get(hRef);
            final ho = hoSnap.data();
            if (!hoSnap.exists || ho == null || ho['status'] != 'proposed') {
              return HandoverOutcome.revisionChanged;
            }
            if (ho['revision'] != revision) {
              return HandoverOutcome.revisionChanged;
            }
            txn.update(hRef, <String, Object?>{
              'finalWeightKg': finalWeightKg,
              'revision': revision + 1,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return HandoverOutcome.weightRevised;
          })
          .timeout(kHandoverTimeout);
    } on TimeoutException {
      return HandoverOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_HANDOVER_REV error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return HandoverOutcome.unconfirmed;
      }
      if (e.code == 'permission-denied') {
        return HandoverOutcome.revisionChanged;
      }
      return HandoverOutcome.failed;
    }
  }

  /// Selected recycler confirms PHYSICAL receipt. One transaction writes:
  /// handover confirmed + sale completed + lot archived with the lock
  /// cleared. [revision] guards against confirming a stale weight.
  Future<HandoverOutcome> confirmHandover({
    required String saleId,
    required int revision,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return HandoverOutcome.noSession;
    try {
      return await _db
          .runTransaction<HandoverOutcome>((txn) async {
            final sRef = saleRef(saleId);
            final saleSnap = await txn.get(sRef);
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return HandoverOutcome.listingUnavailable;
            }
            if (sale['status'] == 'completed') {
              return HandoverOutcome.alreadyCompleted;
            }
            if (sale['status'] != 'handoverPending' ||
                sale['selectedRecyclerUid'] != user.uid) {
              return HandoverOutcome.notSelectedParty;
            }
            final hRef = handoverRef(saleId);
            final hoSnap = await txn.get(hRef);
            final ho = hoSnap.data();
            if (!hoSnap.exists || ho == null || ho['status'] != 'proposed') {
              return HandoverOutcome.revisionChanged;
            }
            if (ho['revision'] != revision) {
              return HandoverOutcome.revisionChanged;
            }
            final collectorUid = sale['collectorUid'];
            final lotId = sale['lotId'];
            if (collectorUid is! String || lotId is! String) {
              return HandoverOutcome.listingUnavailable;
            }
            final lRef = _db
                .collection('users')
                .doc(collectorUid)
                .collection('lots')
                .doc(lotId);
            final lot = (await txn.get(lRef)).data();
            if (lot == null || lot['activeDirectSaleId'] != saleId) {
              return HandoverOutcome.listingUnavailable;
            }
            txn.update(hRef, <String, Object?>{
              'status': 'confirmed',
              'confirmedBy': user.uid,
              'confirmedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            txn.update(sRef, <String, Object?>{
              'status': 'completed',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            txn.update(lRef, <String, Object?>{
              'status': 'archived',
              'activeDirectSaleId': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return HandoverOutcome.confirmed;
          })
          .timeout(kHandoverTimeout);
    } on TimeoutException {
      return HandoverOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_HANDOVER_CONFIRM error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return HandoverOutcome.unconfirmed;
      }
      if (e.code == 'permission-denied') {
        return HandoverOutcome.revisionChanged;
      }
      return HandoverOutcome.failed;
    }
  }
}
