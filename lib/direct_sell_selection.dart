import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sprint1B: collector selects ONE quote -> atomic whole-lot reservation that
/// SHARES the existing demand-offer lock invariant (a lot is never locked by
/// both flows). All real guarantees live in the published Rules; this file
/// only performs the same-batch writes the Rules permit.
///
/// Writes (single transaction, all or nothing):
///   sale  : open -> reserved (+ selected* fields, selectedAt)
///   lot   : activeDirectSaleId = saleId (shared whole-lot lock)
/// Cancel  : reserved -> withdrawn, selected fields removed, lot unlocked.
/// Decline : reserved -> open (same round stays selectable), lock cleared.
///
/// Quotes are never mutated. Timeout is NOT cancellation (25 s pattern).
enum SelectionOutcome {
  selected,
  alreadySelected,
  cancelled,
  alreadyCancelled,
  declined,
  noSession,
  notOwner,
  notSelectedParty,
  listingUnavailable,
  listingChanged,
  quoteMissing,
  quoteExpired,
  lotChanged,
  unconfirmed,
  failed,
}

const Duration kSelectionTimeout = Duration(seconds: 25);

class DirectSellSelectionService {
  DirectSellSelectionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> saleRef(String saleId) =>
      _db.collection('collectorSellRequests').doc(saleId);

  DocumentReference<Map<String, dynamic>> quoteRef(
    String saleId,
    String round,
    String recyclerUid,
  ) =>
      saleRef(saleId)
          .collection('quoteRounds')
          .doc(round)
          .collection('directSellQuotes')
          .doc(recyclerUid);

  /// Collector selects one quote of the CURRENT round. Idempotent retry:
  /// reserved with the SAME selection reports [alreadySelected], never a
  /// duplicate write. Any concurrent different mutation fails closed.
  Future<SelectionOutcome> selectQuote({
    required String saleId,
    required String round,
    required String recyclerUid,
    required String recyclerName,
    required int ratePaise,
    required Timestamp publishedAt,
    required int lotRevision,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return SelectionOutcome.noSession;
    try {
      return await _db
          .runTransaction<SelectionOutcome>((txn) async {
            final sRef = saleRef(saleId);
            final saleSnap = await txn.get(sRef);
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return SelectionOutcome.listingUnavailable;
            }
            if (sale['collectorUid'] != user.uid) {
              return SelectionOutcome.notOwner;
            }
            if (sale['status'] == 'reserved') {
              final same =
                  sale['selectedRecyclerUid'] == recyclerUid &&
                  (sale['selectedPublishedAt'] is Timestamp) &&
                  (sale['selectedPublishedAt'] as Timestamp)
                          .millisecondsSinceEpoch ==
                      publishedAt.millisecondsSinceEpoch;
              return same
                  ? SelectionOutcome.alreadySelected
                  : SelectionOutcome.listingChanged;
            }
            if (sale['status'] != 'open') {
              return SelectionOutcome.listingUnavailable;
            }
            final pub = sale['publishedAt'];
            if (pub is! Timestamp ||
                pub.millisecondsSinceEpoch !=
                    publishedAt.millisecondsSinceEpoch) {
              return SelectionOutcome.listingChanged;
            }
            final qSnap = await txn.get(quoteRef(saleId, round, recyclerUid));
            final q = qSnap.data();
            if (!qSnap.exists || q == null) {
              return SelectionOutcome.quoteMissing;
            }
            if (q['ratePaise'] != ratePaise ||
                q['publishedAt'] is! Timestamp ||
                (q['publishedAt'] as Timestamp).millisecondsSinceEpoch !=
                    publishedAt.millisecondsSinceEpoch) {
              return SelectionOutcome.listingChanged;
            }
            final qExp = q['expiresAt'];
            if (qExp is! Timestamp || !qExp.toDate().isAfter(DateTime.now())) {
              return SelectionOutcome.quoteExpired;
            }
            final lotId = sale['lotId'];
            if (lotId is! String) return SelectionOutcome.listingUnavailable;
            final lRef = _db
                .collection('users')
                .doc(user.uid)
                .collection('lots')
                .doc(lotId);
            final lSnap = await txn.get(lRef);
            final lot = lSnap.data();
            if (!lSnap.exists || lot == null) {
              return SelectionOutcome.lotChanged;
            }
            // Same stale-lot predicate as the 114 quote-create rules.
            if (lot['status'] != 'draft' ||
                lot['revision'] != lotRevision ||
                lot['activeRequestId'] != '' ||
                lot['activeOfferId'] != '' ||
                (lot['activeDirectSaleId'] ?? '') != '' ||
                lot['material'] != sale['material'] ||
                lot['weightKg'] != sale['weightKg'] ||
                lot['city'] != sale['city']) {
              return SelectionOutcome.lotChanged;
            }
            txn.update(sRef, <String, Object?>{
              'status': 'reserved',
              'selectedRecyclerUid': recyclerUid,
              'selectedRecyclerName': recyclerName,
              'selectedRatePaise': ratePaise,
              'selectedPublishedAt': publishedAt,
              'selectedLotRevision': lotRevision,
              'selectedRound': round,
              'selectedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            txn.update(lRef, <String, Object?>{
              'activeDirectSaleId': saleId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return SelectionOutcome.selected;
          })
          .timeout(kSelectionTimeout);
    } on TimeoutException {
      return SelectionOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_SELECT error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return SelectionOutcome.unconfirmed;
      }
      if (e.code == 'permission-denied') {
        return SelectionOutcome.listingChanged;
      }
      return SelectionOutcome.failed;
    }
  }

  /// Collector cancels pre-handover: reserved -> withdrawn, selected fields
  /// removed, lot lock cleared. Republish later starts a NEW round.
  Future<SelectionOutcome> cancelReservation(String saleId) async {
    final user = _auth.currentUser;
    if (user == null) return SelectionOutcome.noSession;
    try {
      return await _db
          .runTransaction<SelectionOutcome>((txn) async {
            final sRef = saleRef(saleId);
            final saleSnap = await txn.get(sRef);
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return SelectionOutcome.listingUnavailable;
            }
            if (sale['collectorUid'] != user.uid) {
              return SelectionOutcome.notOwner;
            }
            if (sale['status'] == 'withdrawn') {
              return SelectionOutcome.alreadyCancelled;
            }
            if (sale['status'] != 'reserved') {
              return SelectionOutcome.listingUnavailable;
            }
            final lotId = sale['lotId'];
            if (lotId is String) {
              final lRef = _db
                  .collection('users')
                  .doc(user.uid)
                  .collection('lots')
                  .doc(lotId);
              final lot = (await txn.get(lRef)).data();
              if (lot != null && lot['activeDirectSaleId'] == saleId) {
                txn.update(lRef, <String, Object?>{
                  'activeDirectSaleId': '',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
            txn.update(sRef, <String, Object?>{
              'status': 'withdrawn',
              'updatedAt': FieldValue.serverTimestamp(),
              'selectedRecyclerUid': FieldValue.delete(),
              'selectedRecyclerName': FieldValue.delete(),
              'selectedRatePaise': FieldValue.delete(),
              'selectedPublishedAt': FieldValue.delete(),
              'selectedLotRevision': FieldValue.delete(),
              'selectedRound': FieldValue.delete(),
              'selectedAt': FieldValue.delete(),
            });
            return SelectionOutcome.cancelled;
          })
          .timeout(kSelectionTimeout);
    } on TimeoutException {
      return SelectionOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_CANCEL error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return SelectionOutcome.unconfirmed;
      }
      if (e.code == 'permission-denied') {
        return SelectionOutcome.listingChanged;
      }
      return SelectionOutcome.failed;
    }
  }

  /// Selected recycler declines pre-handover: reserved -> open, same round
  /// stays selectable by the collector, lock cleared.
  Future<SelectionOutcome> declineSelection(String saleId) async {
    final user = _auth.currentUser;
    if (user == null) return SelectionOutcome.noSession;
    try {
      return await _db
          .runTransaction<SelectionOutcome>((txn) async {
            final sRef = saleRef(saleId);
            final saleSnap = await txn.get(sRef);
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return SelectionOutcome.listingUnavailable;
            }
            if (sale['status'] == 'open') {
              return SelectionOutcome.alreadyCancelled;
            }
            if (sale['status'] != 'reserved' ||
                sale['selectedRecyclerUid'] != user.uid) {
              return SelectionOutcome.notSelectedParty;
            }
            final collectorUid = sale['collectorUid'];
            final lotId = sale['lotId'];
            if (collectorUid is String && lotId is String) {
              final lRef = _db
                  .collection('users')
                  .doc(collectorUid)
                  .collection('lots')
                  .doc(lotId);
              final lot = (await txn.get(lRef)).data();
              if (lot != null && lot['activeDirectSaleId'] == saleId) {
                txn.update(lRef, <String, Object?>{
                  'activeDirectSaleId': '',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
            txn.update(sRef, <String, Object?>{
              'status': 'open',
              'updatedAt': FieldValue.serverTimestamp(),
              'selectedRecyclerUid': FieldValue.delete(),
              'selectedRecyclerName': FieldValue.delete(),
              'selectedRatePaise': FieldValue.delete(),
              'selectedPublishedAt': FieldValue.delete(),
              'selectedLotRevision': FieldValue.delete(),
              'selectedRound': FieldValue.delete(),
              'selectedAt': FieldValue.delete(),
            });
            return SelectionOutcome.declined;
          })
          .timeout(kSelectionTimeout);
    } on TimeoutException {
      return SelectionOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_DECLINE error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return SelectionOutcome.unconfirmed;
      }
      if (e.code == 'permission-denied') {
        return SelectionOutcome.listingChanged;
      }
      return SelectionOutcome.failed;
    }
  }
}
