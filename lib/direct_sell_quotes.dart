import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sprint1A helper for the REAL Direct Sell quote flow.
///
/// Path: collectorSellRequests/{sid}/quoteRounds/{publishedAtMillis}/directSellQuotes/{recyclerUid}
///
/// Guarantees (enforced by the matching published Rules, not just this file):
/// - Exactly ONE immutable quote per verified recycler per publication round.
/// - A quote binds the exact publishedAt Timestamp and lot revision of the
///   listing, so withdrawn/republished/edited/stale listings reject quotes.
/// - Rate is an integer number of PAISE per kg (1..1000000000 = 0.01..1,00,00,000
///   rupees per kg), currency INR only, validity max 24 hours.
/// - Quotes cannot be edited, deleted or withdrawn in this version.
///
/// This helper does NOT lock inventory, select a winner, prove payment or
/// confirm any pickup. Those are later sprint slices.
const int kQuoteSchemaVersion = 1;
const int kMinRatePaise = 1;
const int kMaxRatePaise = 1000000000;
const List<int> kQuoteExpiryHoursOptions = <int>[1, 6, 24];
const int kDefaultQuoteExpiryHours = 6;
const int kFeedPageSize = 50;
const int kFeedMaxSize = 200;
const Duration kQuoteSubmitTimeout = Duration(seconds: 25);

/// Outcome of a quote submission attempt. [unconfirmed] means the attempt may
/// still have been saved on the server (timeout/offline is NOT cancellation);
/// the user must check own quote history before retrying.
enum QuoteSubmitOutcome {
  submitted,
  alreadySubmitted,
  noSession,
  listingUnavailable,
  listingChanged,
  notVerified,
  invalidInput,
  unconfirmed,
  failed,
}

/// Parses a rupees-per-kg string like "42" or "42.5" or "42.50" into integer
/// paise. Returns null for anything invalid (letters, negative, >2 decimals,
/// out of the allowed 1..1000000000 paise range).
int? parseRupeesToPaise(String input) {
  final t = input.trim();
  if (t.isEmpty) {
    return null;
  }
  final m = RegExp(r'^([0-9]{1,8})(?:\.([0-9]{1,2}))?$').firstMatch(t);
  if (m == null) {
    return null;
  }
  final rupees = int.tryParse(m.group(1)!);
  if (rupees == null) {
    return null;
  }
  final frac = (m.group(2) ?? '').padRight(2, '0');
  final paise = rupees * 100 + int.parse(frac);
  if (paise < kMinRatePaise || paise > kMaxRatePaise) {
    return null;
  }
  return paise;
}

/// Formats integer paise as a rupee string, e.g. 4250 -> "Rs 42.50" style
/// with the rupee sign. Pure display helper.
String formatPaiseAsRupees(int paise) {
  final r = paise ~/ 100;
  final p = (paise.abs() % 100).toString().padLeft(2, '0');
  return '\u20B9$r.$p';
}

/// The round key is the publication's publishedAt in epoch milliseconds.
/// Same-millisecond republication cannot silently collide: a new round only
/// exists when the server assigned a new publishedAt, and quotes bind the
/// exact Timestamp, which Rules verify.
String quoteRoundKey(Timestamp publishedAt) =>
    publishedAt.millisecondsSinceEpoch.toString();

class DirectSellQuoteService {
  DirectSellQuoteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
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

  /// Open listings feed, newest publication first. Needs the composite index
  /// collectorSellRequests(status ASC, publishedAt DESC).
  Stream<QuerySnapshot<Map<String, dynamic>>> openListings({
    int limit = kFeedPageSize,
  }) => _db
      .collection('collectorSellRequests')
      .where('status', isEqualTo: 'open')
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true);

  /// Own quote history across all rounds/listings, newest first. Needs the
  /// collection-group composite index directSellQuotes(recyclerUid ASC,
  /// createdAt DESC). Snapshot fields are retained even if the listing is
  /// later withdrawn; the listing itself may then be unreadable, which is
  /// expected and handled by the UI.
  Stream<QuerySnapshot<Map<String, dynamic>>> myQuotes(
    String recyclerUid, {
    int limit = kFeedPageSize,
  }) => _db
      .collectionGroup('directSellQuotes')
      .where('recyclerUid', isEqualTo: recyclerUid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true);

  /// All quotes of ONE publication round, best rate first. Used by the
  /// collector-side comparison view. Bounded; no cross-listing scan.
  Stream<QuerySnapshot<Map<String, dynamic>>> quotesForRound(
    String saleId,
    String round, {
    int limit = 25,
  }) =>
      saleRef(saleId)
          .collection('quoteRounds')
          .doc(round)
          .collection('directSellQuotes')
          .orderBy('ratePaise', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: true);

  /// Submits one immutable quote. The transaction reads the exact stable
  /// quote reference FIRST (idempotent retry: an existing quote is preserved
  /// honestly, never overwritten), then the listing, then the own profile,
  /// and writes only when everything currently matches. [publishedAt] must be
  /// the listing snapshot's publishedAt the user is quoting against.
  ///
  /// The 25s timeout does NOT cancel the Firebase call; [unconfirmed] tells
  /// the UI to say "may still be saved - check My quotes" instead of retrying
  /// blindly. There is no offline quote queue and unsent typing is not saved.
  Future<QuoteSubmitOutcome> submitQuote({
    required String saleId,
    required Timestamp publishedAt,
    required int ratePaise,
    int expiryHours = kDefaultQuoteExpiryHours,
  }) async {
    if (ratePaise < kMinRatePaise || ratePaise > kMaxRatePaise) {
      return QuoteSubmitOutcome.invalidInput;
    }
    if (!kQuoteExpiryHoursOptions.contains(expiryHours)) {
      return QuoteSubmitOutcome.invalidInput;
    }
    final user = _auth.currentUser;
    if (user == null) {
      return QuoteSubmitOutcome.noSession;
    }
    final round = quoteRoundKey(publishedAt);
    try {
      return await _db
          .runTransaction<QuoteSubmitOutcome>((txn) async {
            final qRef = quoteRef(saleId, round, user.uid);
            final existing = await txn.get(qRef);
            if (existing.exists) {
              // Immutable: the first quote stands, even on retry.
              return QuoteSubmitOutcome.alreadySubmitted;
            }
            final saleSnap = await txn.get(saleRef(saleId));
            final sale = saleSnap.data();
            if (!saleSnap.exists || sale == null) {
              return QuoteSubmitOutcome.listingUnavailable;
            }
            if (sale['status'] != 'open') {
              return QuoteSubmitOutcome.listingUnavailable;
            }
            final pub = sale['publishedAt'];
            if (pub is! Timestamp ||
                pub.millisecondsSinceEpoch !=
                    publishedAt.millisecondsSinceEpoch) {
              // Republished since the user opened this listing: the old
              // round is not current anymore. Fail closed.
              return QuoteSubmitOutcome.listingChanged;
            }
            final exp = sale['expiresAt'];
            if (exp is Timestamp && !exp.toDate().isAfter(DateTime.now())) {
              // Device-clock convenience check; the server Rules with
              // request.time are the authoritative expiry gate.
              return QuoteSubmitOutcome.listingUnavailable;
            }
            final profileSnap = await txn.get(
              _db.collection('users').doc(user.uid),
            );
            final profile = profileSnap.data();
            if (profile == null ||
                profile['role'] != 'recycler' ||
                profile['authorizationStatus'] != 'verified') {
              return QuoteSubmitOutcome.notVerified;
            }
            final name = profile['name'];
            if (name is! String || name.trim().length < 2) {
              return QuoteSubmitOutcome.notVerified;
            }
            final collectorUid = sale['collectorUid'];
            final lotRevision = sale['lotRevision'];
            final material = sale['material'];
            final city = sale['city'];
            final weightKg = sale['weightKg'];
            if (collectorUid is! String ||
                lotRevision is! int ||
                material is! String ||
                city is! String ||
                weightKg is! num) {
              return QuoteSubmitOutcome.listingUnavailable;
            }
            txn.set(qRef, <String, Object?>{
              'schemaVersion': kQuoteSchemaVersion,
              'saleId': saleId,
              'collectorUid': collectorUid,
              'recyclerUid': user.uid,
              'recyclerName': name,
              'publishedAt': publishedAt,
              'lotRevision': lotRevision,
              'material': material,
              'city': city,
              'weightKg': weightKg,
              'ratePaise': ratePaise,
              'currency': 'INR',
              'expiresAt': Timestamp.fromDate(
                DateTime.now().add(Duration(hours: expiryHours)),
              ),
              'createdAt': FieldValue.serverTimestamp(),
            });
            return QuoteSubmitOutcome.submitted;
          })
          .timeout(kQuoteSubmitTimeout);
    } on TimeoutException {
      return QuoteSubmitOutcome.unconfirmed;
    } on FirebaseException catch (e) {
      debugPrint('KC_QUOTE error code: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return QuoteSubmitOutcome.unconfirmed;
      }
      return QuoteSubmitOutcome.failed;
    }
  }
}
