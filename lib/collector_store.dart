import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local drafts/photos belong to a UID. Financial/offer transitions require a
/// server transaction. No cloud photo storage, OTP, payment gateway or AI calls.
class CollectorStore extends ChangeNotifier {
  CollectorStore._();
  static final instance = CollectorStore._();
  Future<Database>? _opening;
  bool syncing = false;
  String? lastError;
  final dbCloud = FirebaseFirestore.instance;
  String get uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('sign-in-required');
    return u.uid;
  }

  void checkUid(String expected) {
    if (uid != expected) throw StateError('account-changed');
  }

  Future<Database> get db => _opening ??= _open();
  Future<Database> _open() async => openDatabase(
    '${await getDatabasesPath()}/collector_v2.db',
    version: 1,
    onCreate: (d, _) async {
      await d.execute(
        'CREATE TABLE drafts(uid TEXT NOT NULL,id TEXT NOT NULL,data TEXT NOT NULL,base INTEGER NOT NULL,phase TEXT NOT NULL,error TEXT,PRIMARY KEY(uid,id))',
      );
      await d.execute(
        'CREATE TABLE actions(uid TEXT NOT NULL,id TEXT NOT NULL,data TEXT NOT NULL,PRIMARY KEY(uid,id))',
      );
    },
  );
  String newId() =>
      dbCloud.collection('users').doc(uid).collection('lots').doc().id;
  Future<List<Map<String, dynamic>>> drafts() async {
    final u = uid;
    final rows = await (await db).query(
      'drafts',
      where: 'uid=?',
      whereArgs: [u],
    );
    checkUid(u);
    return rows
        .map(
          (r) => <String, dynamic>{
            ...r,
            'value': jsonDecode(r['data'] as String),
          },
        )
        .toList();
  }

  Future<void> saveLocal(
    Map<String, dynamic> value, {
    int base = 0,
    bool queue = false,
    bool replaceBase = false,
  }) async {
    final u = uid;
    final d = await db;
    checkUid(u);
    await d.transaction((t) async {
      final old = await t.query(
        'drafts',
        where: 'uid=? AND id=?',
        whereArgs: [u, value['id']],
      );
      await t.insert('drafts', {
        'uid': u,
        'id': value['id'],
        'data': jsonEncode(value),
        'base': old.isEmpty || replaceBase ? base : old.first['base'],
        'phase': queue ? 'queued' : 'local',
        'error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    notifyListeners();
  }

  Future<void> removeLocal(String id) async {
    final u = uid;
    await (await db).delete(
      'drafts',
      where: 'uid=? AND id=?',
      whereArgs: [u, id],
    );
    // Do not delete a possibly referenced photo during an in-flight operation.
    // App-private media is retained until deliberate OS data removal.
    notifyListeners();
  }

  Future<String> retainPhoto(String source, String id) async {
    final u = uid;
    final root = await getApplicationDocumentsDirectory();
    checkUid(u);
    final dir = Directory('${root.path}/collector_photos/$u');
    await dir.create(recursive: true);
    final f = File(
      '${dir.path}/${id}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final bytes = await File(source).readAsBytes();
    if (bytes.length > 12000000) throw StateError('photo-too-large');
    await f.writeAsBytes(bytes, flush: true);
    checkUid(u);
    return f.path;
  }

  static bool validWeight(Object? w) =>
      w is num && w.isFinite && w > 0 && w <= 10000;
  Map<String, dynamic> lotPayload(
    Map<String, dynamic> v,
    int revision,
    Object created,
  ) => {
    'schemaVersion': 2,
    'material': v['material'],
    'weightKg': v['weightKg'],
    'city': v['city'],
    'status': 'draft',
    'createdAt': created,
    'updatedAt': FieldValue.serverTimestamp(),
    'revision': revision,
    'activeRequestId': '',
    'activeOfferId': '',
    'photoStorage': 'deviceOnly',
  };
  Future<void> sync({bool retryErrors = false}) async {
    if (syncing || FirebaseAuth.instance.currentUser == null) return;
    syncing = true;
    lastError = null;
    notifyListeners();
    final u = uid;
    try {
      final d = await db;
      final rows = await d.query(
        'drafts',
        where: retryErrors ? 'uid=? AND phase IN (?,?)' : 'uid=? AND phase=?',
        whereArgs: retryErrors ? [u, 'queued', 'error'] : [u, 'queued'],
      );
      for (final row in rows) {
        checkUid(u);
        final v = Map<String, dynamic>.from(
          jsonDecode(row['data'] as String) as Map,
        );
        final base = row['base'] as int;
        final id = row['id'] as String;
        try {
          if (!validWeight(v['weightKg']) ||
              v['material'] == null ||
              v['city'] == null) {
            throw StateError('invalid-draft');
          }
          final ref = dbCloud
              .collection('users')
              .doc(u)
              .collection('lots')
              .doc(id);
          await dbCloud
              .runTransaction((t) async {
                final s = await t.get(ref);
                final old = s.data();
                if (old != null) {
                  if (old['status'] != 'draft') throw StateError('lot-locked');
                  final rev = (old['revision'] as num?)?.toInt() ?? 0;
                  if (rev == base + 1 &&
                      old['material'] == v['material'] &&
                      old['weightKg'] == v['weightKg'] &&
                      old['city'] == v['city']) {
                    return;
                  }
                  if (rev != base) throw StateError('revision-conflict');
                } else if (base != 0) {
                  throw StateError('remote-lot-missing');
                }
                t.set(
                  ref,
                  lotPayload(
                    v,
                    base + 1,
                    old?['createdAt'] ?? FieldValue.serverTimestamp(),
                  ),
                );
              })
              .timeout(const Duration(seconds: 25));
          checkUid(u);
          await d.transaction((t) async {
            final now = await t.query(
              'drafts',
              where: 'uid=? AND id=?',
              whereArgs: [u, id],
            );
            if (now.isNotEmpty) {
              await t.update(
                'drafts',
                {
                  'base': base + 1,
                  'phase': now.first['data'] == row['data']
                      ? 'synced'
                      : 'queued',
                  'error': null,
                },
                where: 'uid=? AND id=?',
                whereArgs: [u, id],
              );
            }
          });
        } catch (e) {
          lastError = e is FirebaseException
              ? e.code
              : e is TimeoutException
              ? 'timeout'
              : 'conflict-or-invalid';
          await d.update(
            'drafts',
            {'phase': 'error', 'error': lastError},
            where: 'uid=? AND id=?',
            whereArgs: [u, id],
          );
          break; // Avoid repeated network failures over every local draft.
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  DocumentReference<Map<String, dynamic>> lot(String id) =>
      dbCloud.collection('users').doc(uid).collection('lots').doc(id);
  Future<void> archive(String id) async {
    final u = uid;
    final ref = lot(id);
    await dbCloud
        .runTransaction((t) async {
          final s = await t.get(ref);
          checkUid(u);
          if (s.data()?['status'] != 'draft') throw StateError('lot-locked');
          t.update(ref, {
            'status': 'archived',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 25));
  }

  Future<void> propose(String requestId, String lotId) async {
    final u = uid;
    final request = dbCloud.collection('recyclerRequests').doc(requestId);
    final l = lot(lotId);
    final offer = request.collection('offers').doc('${u}_$lotId');
    await dbCloud
        .runTransaction((t) async {
          final rs = await t.get(request),
              ls = await t.get(l),
              os = await t.get(offer);
          if (os.exists) throw StateError('offer-already-exists');
          final r = rs.data(), v = ls.data();
          if (r == null || v == null) throw StateError('missing-record');
          // Current authorization is checked by rules. Collector cannot read a buyer's private profile.
          if (r['status'] != 'active' ||
              r['authorizationStatus'] != 'verified' ||
              r['expiresAt'] is! Timestamp ||
              !(r['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now()) ||
              v['status'] != 'draft' ||
              r['material'] != v['material'] ||
              !validWeight(v['weightKg'])) {
            throw StateError('request-or-lot-unavailable');
          }
          checkUid(u);
          t.set(offer, {
            'schemaVersion': 2,
            'collectorUid': u,
            'lotId': lotId,
            'material': v['material'],
            'weightKg': v['weightKg'],
            'status': 'proposed',
            'createdAt': FieldValue.serverTimestamp(),
            'requestId': requestId,
            'recyclerUid': r['recyclerUid'],
            'recyclerName': r['recyclerName'],
            'city': r['city'],
          });
          t.update(l, {
            'status': 'offered',
            'activeRequestId': requestId,
            'activeOfferId': offer.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 25));
  }

  Future<void> transition(
    DocumentReference<Map<String, dynamic>> ref,
    String action, {
    double? weight,
  }) async {
    final u = uid;
    await dbCloud
        .runTransaction((t) async {
          final s = await t.get(ref);
          final v = s.data();
          if (v == null || v['collectorUid'] != u || v['schemaVersion'] != 2) {
            throw StateError('offer-unavailable');
          }
          final l = lot(v['lotId'] as String);
          final ls = await t.get(l);
          if (ls.data()?['activeOfferId'] != ref.id) {
            throw StateError('lot-not-reserved-for-offer');
          }
          checkUid(u);
          if (action == 'cancelled' &&
              ['proposed', 'quoted'].contains(v['status'])) {
            t.update(ref, {
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });
            t.update(l, {
              'status': 'draft',
              'activeRequestId': '',
              'activeOfferId': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else if (action == 'accepted' && v['status'] == 'quoted') {
            // Rules check current authorization without exposing buyer profile data.
            if (v['quoteExpiresAt'] is! Timestamp ||
                !(v['quoteExpiresAt'] as Timestamp).toDate().isAfter(
                  DateTime.now(),
                )) {
              throw StateError('quote-expired-or-buyer-unverified');
            }
            t.update(ref, {
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });
            t.update(l, {
              'status': 'reserved',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else if (action == 'handoverPending' &&
              v['status'] == 'accepted' &&
              validWeight(weight)) {
            t.update(ref, {
              'status': 'handoverPending',
              'handoverWeightKg': weight,
              'handoverRequestedAt': FieldValue.serverTimestamp(),
            });
          } else {
            throw StateError('invalid-transition');
          }
        })
        .timeout(const Duration(seconds: 25));
  }

  /// A single stable journal ID is reused after timeout/restart. This records
  /// the collector's statement of receipt, never performs a payment.
  Future<String> stagePayment(Map<String, dynamic> v) async {
    final u = uid;
    final encoded = jsonEncode(v);
    final id = await (await db).transaction<String>((t) async {
      final pending = await t.query('actions', where: 'uid=?', whereArgs: [u]);
      for (final row in pending) {
        final old = jsonDecode(row['data'] as String) as Map;
        if (old['requestId'] == v['requestId'] &&
            old['offerId'] == v['offerId']) {
          if (row['data'] == encoded) return row['id'] as String;
          throw StateError('review-existing-receipt-in-sync');
        }
      }
      final fresh = dbCloud.collection('collectorPayments').doc().id;
      await t.insert('actions', {'uid': u, 'id': fresh, 'data': encoded});
      return fresh;
    });
    notifyListeners();
    return id;
  }

  Future<List<Map<String, dynamic>>> paymentQueue() async =>
      (await db).query('actions', where: 'uid=?', whereArgs: [uid]);
  Future<void> postPayment(String id) async {
    final u = uid;
    final d = await db;
    final rows = await d.query(
      'actions',
      where: 'uid=? AND id=?',
      whereArgs: [u, id],
    );
    if (rows.isEmpty) return;
    final v = Map<String, dynamic>.from(
      jsonDecode(rows.first['data'] as String) as Map,
    );
    final p = dbCloud.collection('collectorPayments').doc(id);
    final o = dbCloud
        .collection('recyclerRequests')
        .doc(v['requestId'] as String)
        .collection('offers')
        .doc(v['offerId'] as String);
    await dbCloud
        .runTransaction((t) async {
          final old = await t.get(p);
          if (old.exists) return;
          final offer = await t.get(o);
          checkUid(u);
          if (offer.data()?['collectorUid'] != u ||
              offer.data()?['status'] != 'completed') {
            throw StateError('handover-not-confirmed');
          }
          t.set(p, {
            ...v,
            'collectorUid': u,
            'kind': 'collectorRecordedReceipt',
            'createdAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 25));
    checkUid(u);
    await d.delete('actions', where: 'uid=? AND id=?', whereArgs: [u, id]);
    notifyListeners();
  }
}
