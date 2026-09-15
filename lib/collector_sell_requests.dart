import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collector_ui.dart';
import 'collector_pages.dart';
import 'material_photos.dart';
import 'request_tracking.dart';
import 'app_speech.dart';

/// No notification, quote, reservation or payment is implied by publication.
/// One stable document per UID/lot prevents duplicate publication on retry.
class CollectorSellService {
  CollectorSellService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : firestore = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  void check(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('account-changed');
  }

  static double? parseRate(String value) {
    if (value.trim().isEmpty) return 0;
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value.trim())) return null;
    final n = double.tryParse(value.trim());
    return n != null && n > 0 && n <= 10000000 ? n : null;
  }

  static bool eligible(Map<String, dynamic> v) =>
      v['schemaVersion'] == 2 &&
      v['status'] == 'draft' &&
      v['activeOfferId'] == '' &&
      v['activeRequestId'] == '' &&
      v['revision'] is int &&
      collectorMaterials.contains(v['material']) &&
      collectorCities.contains(v['city']) &&
      v['weightKg'] is num &&
      (v['weightKg'] as num).isFinite &&
      (v['weightKg'] as num) > 0 &&
      (v['weightKg'] as num) <= 10000;
  static DateTime expiry(DateTime now, bool today) => today
      ? DateTime(now.year, now.month, now.day + 1)
      : now.add(const Duration(days: 6));
  Future<bool> publish({
    required String uid,
    required String lotId,
    required String fulfilment,
    required double askingRate,
    required bool today,
    required int expectedRevision,
  }) async {
    check(uid);
    if (!['pickup', 'delivery', 'either'].contains(fulfilment) ||
        !askingRate.isFinite ||
        askingRate < 0 ||
        askingRate > 10000000)
      throw ArgumentError('invalid-details');
    final deadline = Timestamp.fromDate(expiry(DateTime.now(), today));
    final ref = firestore
        .collection('collectorSellRequests')
        .doc('${uid}_$lotId');
    final lotRef = firestore
        .collection('users')
        .doc(uid)
        .collection('lots')
        .doc(lotId);
    final result = await firestore
        .runTransaction<bool>((t) async {
          check(uid);
          final existing = await t.get(ref);
          // An uncertain previous request may already have committed. Never silently overwrite it.
          if (existing.exists && existing.data()?['status'] == 'open')
            return false;
          final lot = await t.get(lotRef);
          final v = lot.data();
          if (v == null || !eligible(v) || v['revision'] != expectedRevision)
            throw StateError('lot-changed-refresh');
          check(uid);
          t.set(ref, {
            'schemaVersion': 1,
            'collectorUid': uid,
            'lotId': lotId,
            'lotRevision': v['revision'],
            'material': v['material'],
            'weightKg': v['weightKg'],
            'city': v['city'],
            'status': 'open',
            'fulfilment': fulfilment,
            'askingRate': askingRate,
            'currency': 'INR',
            'availability': today ? 'today' : 'flexible',
            'expiresAt': deadline,
            'createdAt':
                existing.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
            'publishedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        })
        .timeout(const Duration(seconds: 25));
    check(uid);
    return result;
  }

  Future<void> withdraw(String uid, String id) async {
    check(uid);
    final ref = firestore.collection('collectorSellRequests').doc(id);
    await firestore
        .runTransaction((t) async {
          final snap = await t.get(ref);
          check(uid);
          if (snap.data()?['collectorUid'] != uid)
            throw StateError('not-owner');
          if (snap.data()?['status'] == 'withdrawn') return;
          t.update(ref, {
            'status': 'withdrawn',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 25));
    check(uid);
  }
}

/// Pure UI: fixtures never reach Firebase or real action callbacks.
class RequestDemoPanel extends StatelessWidget {
  const RequestDemoPanel({this.selling = false, super.key});
  final bool selling;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE8B3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          ct(
            'DEMO ONLY \u2014 fictional data. No requests are sent.',
            '\u0915\u0947\u0935\u0932 \u0921\u0947\u092e\u094b \u2014 \u0915\u093e\u0932\u094d\u092a\u0928\u093f\u0915 \u0921\u0947\u091f\u093e\u0964 \u0915\u094b\u0908 \u092e\u093e\u0901\u0917 \u0928\u0939\u0940\u0902 \u092d\u0947\u091c\u0940 \u091c\u093e\u0924\u0940\u0964',
            '\u092b\u0915\u094d\u0924 \u0921\u0947\u092e\u094b \u2014 \u0915\u093e\u0932\u094d\u092a\u0928\u093f\u0915 \u092e\u093e\u0939\u093f\u0924\u0940. \u0915\u094b\u0923\u0924\u0940\u0939\u0940 \u092e\u093e\u0917\u0923\u0940 \u092a\u093e\u0920\u0935\u0932\u0940 \u091c\u093e\u0924 \u0928\u093e\u0939\u0940.',
          ),
        ),
      ),
      if (selling) ...[
        const SizedBox(height: 12),
        _demoCard(context, 'PCB', 'Demo collector lot', 'Ludhiana', 15),
        note(
          ct(
            'Example: collected today, pickup preferred, quote required. In Real mode select your own synced lot and publish.',
            '\u0909\u0926\u093e\u0939\u0930\u0923: \u0906\u091c \u0915\u093e \u0938\u0902\u0917\u094d\u0930\u0939, \u092a\u093f\u0915\u0905\u092a \u091a\u093e\u0939\u093f\u090f, \u092d\u093e\u0935 \u091a\u093e\u0939\u093f\u090f\u0964 \u0930\u093f\u092f\u0932 \u092e\u094b\u0921 \u092e\u0947\u0902 \u0905\u092a\u0928\u093e \u0938\u093f\u0902\u0915 \u0939\u0941\u0906 \u0932\u0949\u091f \u091a\u0941\u0928\u0915\u0930 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0947\u0902\u0964',
            '\u0909\u0926\u093e\u0939\u0930\u0923: \u0906\u091c\u091a\u0947 \u0938\u0902\u0915\u0932\u0928, \u092a\u093f\u0915\u0905\u092a \u0939\u0935\u093e, \u0926\u0930 \u0939\u0935\u093e. \u0930\u093f\u0905\u0932 \u092e\u094b\u0921\u092e\u0927\u094d\u092f\u0947 \u0938\u094d\u0935\u0924\u0903\u091a\u093e \u0938\u093f\u0902\u0915 \u091d\u093e\u0932\u0947\u0932\u093e \u0932\u0949\u091f \u0928\u093f\u0935\u0921\u0942\u0928 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u093e.',
          ),
        ),
      ] else ...[
        _demoCard(context, 'PCB', 'Demo Recycler A', 'Ludhiana', 100),
        _demoCard(context, 'Cable', 'Demo Recycler B', 'Jalandhar', 80),
        _demoCard(context, 'Motor', 'Demo Recycler C', 'Amritsar', 150),
        _demoCard(context, 'LCD', 'Demo Recycler D', 'Ludhiana', 40),
        _demoCard(context, 'Aluminium', 'Demo Recycler E', 'Jalandhar', 120),
      ],
    ],
  );
  Widget _demoCard(
    BuildContext context,
    String material,
    String name,
    String city,
    int kg,
  ) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MaterialPhoto(material: material),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materialLabel(material),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(name),
                    Text('$city \u2022 $kg kg'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ct(
              'Quote required \u2022 DEMO',
              '\u092d\u093e\u0935 \u091a\u093e\u0939\u093f\u090f \u2022 \u0921\u0947\u092e\u094b',
              '\u0926\u0930 \u0939\u0935\u093e \u2022 \u0921\u0947\u092e\u094b',
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: spokenAction(
              () => ct(
                'View demo details',
                '\u0921\u0947\u092e\u094b \u0935\u093f\u0935\u0930\u0923 \u0926\u0947\u0916\u0947\u0902',
                '\u0921\u0947\u092e\u094b \u0924\u092a\u0936\u0940\u0932 \u092a\u0939\u093e',
              ),
              () => openCollector(
                context,
                DemoRequestDetailsScreen(
                  material: material,
                  city: city,
                  weightKg: kg,
                  sale: selling,
                ),
              ),
            ),
            child: Text(
              ct(
                'View demo details',
                '\u0921\u0947\u092e\u094b \u0935\u093f\u0935\u0930\u0923 \u0926\u0947\u0916\u0947\u0902',
                '\u0921\u0947\u092e\u094b \u0924\u092a\u0936\u0940\u0932 \u092a\u0939\u093e',
              ),
            ),
          ),
          FilledButton(
            onPressed: null,
            child: Text(
              ct(
                'Demo \u2014 sending disabled',
                '\u0921\u0947\u092e\u094b \u2014 \u092d\u0947\u091c\u0928\u093e \u092c\u0902\u0926 \u0939\u0948',
                '\u0921\u0947\u092e\u094b \u2014 \u092a\u093e\u0920\u0935\u0923\u0947 \u092c\u0902\u0926 \u0906\u0939\u0947',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class RequestModeBar extends StatelessWidget {
  const RequestModeBar({
    required this.selling,
    required this.demo,
    required this.onSelling,
    required this.onDemo,
    super.key,
  });
  final bool selling, demo;
  final ValueChanged<bool> onSelling, onDemo;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              ct(
                'Buyer requests',
                '\u0916\u0930\u0940\u0926\u093e\u0930 \u0915\u0940 \u092e\u093e\u0901\u0917',
                '\u0916\u0930\u0947\u0926\u0940\u0926\u093e\u0930\u093e\u0902\u091a\u0940 \u092e\u093e\u0917\u0923\u0940',
              ),
              !selling,
              () => onSelling(false),
            ),
            const SizedBox(width: 10),
            _chip(
              ct(
                'Sell my collection',
                '\u0905\u092a\u0928\u093e \u0938\u0902\u0917\u094d\u0930\u0939 \u092c\u0947\u091a\u0947\u0902',
                '\u092e\u093e\u091d\u0947 \u0938\u0902\u0915\u0932\u0928 \u0935\u093f\u0915\u093e',
              ),
              selling,
              () => onSelling(true),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text(
              ct(
                'Real data',
                '\u0935\u093e\u0938\u094d\u0924\u0935\u093f\u0915 \u0921\u0947\u091f\u093e',
                '\u092a\u094d\u0930\u0924\u094d\u092f\u0915\u094d\u0937 \u092e\u093e\u0939\u093f\u0924\u0940',
              ),
            ),
            selected: !demo,
            onSelected: (_) => onDemo(false),
          ),
          ChoiceChip(
            label: Text(
              ct(
                'Demo preview',
                '\u0921\u0947\u092e\u094b \u092a\u094d\u0930\u0940\u0935\u094d\u092f\u0942',
                '\u0921\u0947\u092e\u094b \u092a\u0942\u0930\u094d\u0935\u093e\u0935\u0932\u094b\u0915\u0928',
              ),
            ),
            selected: demo,
            onSelected: (_) => onDemo(true),
          ),
        ],
      ),
      const SizedBox(height: 10),
    ],
  );
  Widget _chip(String text, bool active, VoidCallback callback) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: active ? collectorGreen : const Color(0xFFE1EED5),
      foregroundColor: active ? Colors.white : collectorGreen,
      minimumSize: const Size(0, 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: () {
      AppSpeech.instance.say(text);
      callback();
    },
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class SellCollectionPanel extends StatefulWidget {
  const SellCollectionPanel({super.key});
  @override
  State<SellCollectionPanel> createState() => _SellCollectionState();
}

class _SellCollectionState extends State<SellCollectionPanel> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _service = CollectorSellService();
  final _rate = TextEditingController();
  String? _lotId, _message;
  String _fulfilment = 'pickup';
  bool _today = true, _busy = false, _consent = false, _loadingDraft = true;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _lots = _uid == null
      ? null
      : _service.firestore
            .collection('users')
            .doc(_uid)
            .collection('lots')
            .limit(100)
            .snapshots(includeMetadataChanges: true);
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _listings =
      _uid == null
      ? null
      : _service.firestore
            .collection('collectorSellRequests')
            .where('collectorUid', isEqualTo: _uid)
            .limit(100)
            .snapshots(includeMetadataChanges: true);
  String get _draftKey => 'collector_sell_draft_$_uid';
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      if (_uid == null) return;
      final value = (await SharedPreferences.getInstance()).getString(
        _draftKey,
      );
      if (value != null && mounted) {
        final d = jsonDecode(value) as Map;
        if (d['lotId'] is String) _lotId = d['lotId'];
        if (['pickup', 'delivery', 'either'].contains(d['fulfilment']))
          _fulfilment = d['fulfilment'];
        if (d['rate'] is String) _rate.text = d['rate'];
        if (d['today'] is bool) _today = d['today'];
      }
    } catch (_) {
      _message = ct(
        'Saved form could not load. You can fill it again.',
        '\u0938\u0939\u0947\u091c\u093e \u092b\u0949\u0930\u094d\u092e \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u093e\u0964 \u092b\u093f\u0930 \u092d\u0930 \u0938\u0915\u0924\u0947 \u0939\u0948\u0902\u0964',
        '\u091c\u0924\u0928 \u092b\u0949\u0930\u094d\u092e \u0909\u0918\u0921\u0932\u093e \u0928\u093e\u0939\u0940. \u092a\u0941\u0928\u094d\u0939\u093e \u092d\u0930\u0942 \u0936\u0915\u0924\u093e.',
      );
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_uid == null) return;
    await _run(() async {
      _service.check(_uid);
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        _draftKey,
        jsonEncode({
          'lotId': _lotId,
          'fulfilment': _fulfilment,
          'rate': _rate.text,
          'today': _today,
        }),
      );
      if (!saved) throw StateError('local-save-failed');
      _service.check(_uid);
      return ct(
        'Form saved on this device only. Not published.',
        '\u092b\u0949\u0930\u094d\u092e \u0915\u0947\u0935\u0932 \u0907\u0938 \u0921\u093f\u0935\u093e\u0907\u0938 \u092a\u0930 \u0938\u0939\u0947\u091c\u093e \u0917\u092f\u093e\u0964 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0928\u0939\u0940\u0902 \u0939\u0941\u0906\u0964',
        '\u092b\u0949\u0930\u094d\u092e \u092b\u0915\u094d\u0924 \u092f\u093e \u0921\u093f\u0935\u094d\u0939\u093e\u0907\u0938\u0935\u0930 \u091c\u0924\u0928 \u091d\u093e\u0932\u093e. \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0928\u093e\u0939\u0940.',
      );
    });
  }

  Future<void> _run(Future<String> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final text = await fn();
      if (mounted) {
        setState(() => _message = text);
        AppSpeech.instance.say(
          ct(
            'Action result updated',
            '\u0915\u093e\u0930\u094d\u0930\u0935\u093e\u0908 \u0915\u093e \u092a\u0930\u093f\u0923\u093e\u092e \u0905\u092a\u0921\u0947\u091f \u0939\u0941\u0906',
            '\u0915\u0943\u0924\u0940\u091a\u093e \u092a\u0930\u093f\u0923\u093e\u092e \u092c\u0926\u0932\u0932\u093e',
          ),
        );
      }
    } on TimeoutException {
      if (mounted)
        setState(
          () => _message = ct(
            'Confirmation timed out; the action may still finish. Check My sell requests before retrying. The same lot uses the same request ID.',
            '\u092a\u0941\u0937\u094d\u091f\u093f \u092e\u0947\u0902 \u0938\u092e\u092f \u0932\u0917\u093e; \u0915\u093e\u0930\u094d\u0930\u0935\u093e\u0908 \u092a\u0942\u0930\u0940 \u0939\u094b \u0938\u0915\u0924\u0940 \u0939\u0948\u0964 \u092b\u093f\u0930 \u0915\u094b\u0936\u093f\u0936 \u0938\u0947 \u092a\u0939\u0932\u0947 \u092e\u0947\u0930\u0940 \u092c\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0901\u0917 \u0926\u0947\u0916\u0947\u0902\u0964 \u0909\u0938\u0940 \u0932\u0949\u091f \u0915\u093e \u0935\u0939\u0940 \u0905\u0928\u0941\u0930\u094b\u0927 ID \u0930\u0939\u0947\u0917\u093e\u0964',
            '\u092a\u0941\u0937\u094d\u091f\u0940\u0932\u093e \u0935\u0947\u0933 \u0932\u093e\u0917\u0932\u093e; \u0915\u0943\u0924\u0940 \u092a\u0942\u0930\u094d\u0923 \u0939\u094b\u090a \u0936\u0915\u0924\u0947. \u092a\u0941\u0928\u094d\u0939\u093e \u092a\u094d\u0930\u092f\u0924\u094d\u0928\u093e\u0906\u0927\u0940 \u092e\u093e\u091d\u094d\u092f\u093e \u0935\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0917\u0923\u094d\u092f\u093e \u092a\u0939\u093e. \u0924\u094d\u092f\u093e \u0932\u0949\u091f\u091a\u093e \u0924\u094b\u091a \u0935\u093f\u0928\u0902\u0924\u0940 ID \u0930\u093e\u0939\u0940\u0932.',
          ),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Not confirmed. Check connection, published rules, and whether the lot changed. Refresh the page before retrying; your saved form remains on this device.',
            '\u092a\u0941\u0937\u094d\u091f\u093f \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964 \u0928\u0947\u091f\u0935\u0930\u094d\u0915, \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0928\u093f\u092f\u092e \u0914\u0930 \u0932\u0949\u091f \u092e\u0947\u0902 \u092c\u0926\u0932\u093e\u0935 \u091c\u093e\u0901\u091a\u0947\u0902\u0964 \u092b\u093f\u0930 \u0915\u094b\u0936\u093f\u0936 \u0938\u0947 \u092a\u0939\u0932\u0947 \u092a\u0947\u091c \u0926\u094b\u092c\u093e\u0930\u093e \u0916\u094b\u0932\u0947\u0902; \u0938\u0939\u0947\u091c\u093e \u092b\u0949\u0930\u094d\u092e \u0907\u0938\u0940 \u0921\u093f\u0935\u093e\u0907\u0938 \u092a\u0930 \u0930\u0939\u0947\u0917\u093e\u0964',
            '\u092a\u0941\u0937\u094d\u091f\u0940 \u0928\u093e\u0939\u0940. \u0928\u0947\u091f\u0935\u0930\u094d\u0915, \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0928\u093f\u092f\u092e \u0935 \u0932\u0949\u091f\u092e\u0927\u0940\u0932 \u092c\u0926\u0932 \u0924\u092a\u093e\u0938\u093e. \u092a\u0941\u0928\u094d\u0939\u093e \u092a\u094d\u0930\u092f\u0924\u094d\u0928\u093e\u0906\u0927\u0940 \u092a\u0947\u091c \u0909\u0918\u0921\u093e; \u091c\u0924\u0928 \u092b\u0949\u0930\u094d\u092e \u092f\u093e \u0921\u093f\u0935\u094d\u0939\u093e\u0907\u0938\u0935\u0930 \u0930\u093e\u0939\u0940\u0932.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(Map<String, dynamic> lot) async {
    final uid = _uid,
        id = _lotId,
        rate = CollectorSellService.parseRate(_rate.text);
    if (uid == null || id == null || rate == null || !_consent) {
      setState(
        () => _message = ct(
          'Select a lot, enter a valid optional rate and confirm publication consent.',
          '\u0932\u0949\u091f \u091a\u0941\u0928\u0947\u0902, \u0935\u0948\u0927 \u0935\u0948\u0915\u0932\u094d\u092a\u093f\u0915 \u092d\u093e\u0935 \u092d\u0930\u0947\u0902 \u0914\u0930 \u092a\u094d\u0930\u0915\u093e\u0936\u0928 \u0915\u0940 \u0938\u0939\u092e\u0924\u093f \u0926\u0947\u0902\u0964',
          '\u0932\u0949\u091f \u0928\u093f\u0935\u0921\u093e, \u092f\u094b\u0917\u094d\u092f \u0910\u091a\u094d\u091b\u093f\u0915 \u0926\u0930 \u092d\u0930\u093e \u0935 \u092a\u094d\u0930\u0915\u093e\u0936\u0928\u093e\u0932\u093e \u0938\u0902\u092e\u0924\u0940 \u0926\u094d\u092f\u093e.',
        ),
      );
      return;
    }
    await _run(() async {
      final created = await _service.publish(
        uid: uid,
        lotId: id,
        fulfilment: _fulfilment,
        askingRate: rate,
        today: _today,
        expectedRevision: lot['revision'] as int,
      );
      if (mounted)
        openCollector(
          context,
          SellRequestDetailsScreen(
            ref: _service.firestore
                .collection('collectorSellRequests')
                .doc('${uid}_$id'),
          ),
        );
      return created
          ? ct(
              'Published to the server. No recycler notification, quote or pickup is confirmed.',
              '\u0938\u0930\u094d\u0935\u0930 \u092a\u0930 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924\u0964 \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u093e \u0915\u094b \u0938\u0942\u091a\u0928\u093e, \u092d\u093e\u0935 \u092f\u093e \u092a\u093f\u0915\u0905\u092a \u0915\u0940 \u092a\u0941\u0937\u094d\u091f\u093f \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
              '\u0938\u0930\u094d\u0935\u094d\u0939\u0930\u0935\u0930 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924. \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u094d\u092f\u093e\u0932\u093e \u0938\u0942\u091a\u0928\u093e, \u0926\u0930 \u0915\u093f\u0902\u0935\u093e \u092a\u093f\u0915\u0905\u092a\u091a\u0940 \u092a\u0941\u0937\u094d\u091f\u0940 \u0928\u093e\u0939\u0940.',
            )
          : ct(
              'This lot already has an open request. Its existing details were kept. Withdraw it first to change or republish.',
              '\u0907\u0938 \u0932\u0949\u091f \u0915\u0940 \u0916\u0941\u0932\u0940 \u092e\u093e\u0901\u0917 \u092a\u0939\u0932\u0947 \u0938\u0947 \u0939\u0948\u0964 \u092a\u0941\u0930\u093e\u0928\u0947 \u0935\u093f\u0935\u0930\u0923 \u0930\u0916\u0947 \u0917\u090f\u0964 \u092c\u0926\u0932\u0928\u0947 \u092f\u093e \u092b\u093f\u0930 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0928\u0947 \u0938\u0947 \u092a\u0939\u0932\u0947 \u0935\u093e\u092a\u0938 \u0932\u0947\u0902\u0964',
              '\u092f\u093e \u0932\u0949\u091f\u091a\u0940 \u0916\u0941\u0932\u0940 \u092e\u093e\u0917\u0923\u0940 \u0906\u0927\u0940\u091a \u0906\u0939\u0947. \u091c\u0941\u0928\u0947 \u0924\u092a\u0936\u0940\u0932 \u0920\u0947\u0935\u0932\u0947. \u092c\u0926\u0932\u0923\u094d\u092f\u093e\u091a\u094d\u092f\u093e \u0915\u093f\u0902\u0935\u093e \u092a\u0941\u0928\u094d\u0939\u093e \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0923\u094d\u092f\u093e\u091a\u094d\u092f\u093e \u0906\u0927\u0940 \u092e\u093e\u0917\u0947 \u0918\u094d\u092f\u093e.',
            );
    });
  }

  String _mode(String v) => v == 'pickup'
      ? ct(
          'Pickup needed',
          '\u092a\u093f\u0915\u0905\u092a \u091a\u093e\u0939\u093f\u090f',
          '\u092a\u093f\u0915\u0905\u092a \u0939\u0935\u093e',
        )
      : v == 'delivery'
      ? ct(
          'I can deliver',
          '\u092e\u0948\u0902 \u092a\u0939\u0941\u0901\u091a\u093e \u0938\u0915\u0924\u093e \u0939\u0942\u0901',
          '\u092e\u0940 \u092a\u094b\u0939\u094b\u091a\u0935\u0942 \u0936\u0915\u0924\u094b',
        )
      : ct(
          'Either option',
          '\u0926\u094b\u0928\u094b\u0902 \u0935\u093f\u0915\u0932\u094d\u092a',
          '\u0926\u094b\u0928\u094d\u0939\u0940 \u092a\u0930\u094d\u092f\u093e\u092f',
        );
  String _date(Object? v) => v is Timestamp
      ? '${v.toDate().toLocal()}'.substring(0, 16)
      : ct(
          'Awaiting confirmation',
          '\u092a\u0941\u0937\u094d\u091f\u093f \u092c\u093e\u0915\u0940',
          '\u092a\u0941\u0937\u094d\u091f\u0940 \u092c\u093e\u0915\u0940',
        );
  @override
  Widget build(BuildContext context) {
    if (_uid == null || FirebaseAuth.instance.currentUser?.uid != _uid)
      return note(
        ct(
          'Sign in to publish your collection.',
          '\u0938\u0902\u0917\u094d\u0930\u0939 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0928\u0947 \u0915\u0947 \u0932\u093f\u090f \u0938\u093e\u0907\u0928 \u0907\u0928 \u0915\u0930\u0947\u0902\u0964',
          '\u0938\u0902\u0915\u0932\u0928 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0923\u094d\u092f\u093e\u0938\u093e\u0920\u0940 \u0938\u093e\u0907\u0928 \u0907\u0928 \u0915\u0930\u093e.',
        ),
      );
    if (_loadingDraft) return const LinearProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ct(
            'Sell today\u2019s collection',
            '\u0906\u091c \u0915\u093e \u0938\u0902\u0917\u094d\u0930\u0939 \u092c\u0947\u091a\u0947\u0902',
            '\u0906\u091c\u091a\u0947 \u0938\u0902\u0915\u0932\u0928 \u0935\u093f\u0915\u093e',
          ),
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        note(
          ct(
            'Publish a whole synced, available lot. No phone number, exact address or device photo is published. This is a listing, not a reservation.',
            '\u092a\u0942\u0930\u093e \u0938\u093f\u0902\u0915 \u0939\u0941\u0906 \u0909\u092a\u0932\u092c\u094d\u0927 \u0932\u0949\u091f \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0947\u0902\u0964 \u092b\u094b\u0928 \u0928\u0902\u092c\u0930, \u0938\u091f\u0940\u0915 \u092a\u0924\u093e \u092f\u093e \u0921\u093f\u0935\u093e\u0907\u0938 \u092b\u094b\u091f\u094b \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0928\u0939\u0940\u0902 \u0939\u094b\u0917\u093e\u0964 \u092f\u0939 \u0938\u0942\u091a\u0940 \u0939\u0948, \u0906\u0930\u0915\u094d\u0937\u0923 \u0928\u0939\u0940\u0902\u0964',
            '\u092a\u0942\u0930\u094d\u0923 \u0938\u093f\u0902\u0915 \u091d\u093e\u0932\u0947\u0932\u093e \u0909\u092a\u0932\u092c\u094d\u0927 \u0932\u0949\u091f \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u093e. \u092b\u094b\u0928 \u0928\u0902\u092c\u0930, \u0905\u091a\u0942\u0915 \u092a\u0924\u094d\u0924\u093e \u0915\u093f\u0902\u0935\u093e \u0921\u093f\u0935\u094d\u0939\u093e\u0907\u0938 \u092b\u094b\u091f\u094b \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0939\u094b\u0923\u093e\u0930 \u0928\u093e\u0939\u0940. \u0939\u0940 \u091c\u093e\u0939\u093f\u0930\u093e\u0924 \u0906\u0939\u0947, \u0906\u0930\u0915\u094d\u0937\u0923 \u0928\u093e\u0939\u0940.',
          ),
        ),
        note(
          ct(
            'Approved recyclers now see this listing in their Direct sell feed and can send quotes, which appear in Details & tracking. Choosing a buyer, handover and receipt are not connected yet; publishing sends no SMS/push notification and does not guarantee same-day pickup.',
            '\u0938\u0924\u094d\u092f\u093e\u092a\u093f\u0924 \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u093e \u0905\u092c \u092f\u0939 \u0938\u0942\u091a\u0940 \u0905\u092a\u0928\u0940 Direct sell \u092b\u093c\u0940\u0921 \u092e\u0947\u0902 \u0926\u0947\u0916\u0924\u0947 \u0939\u0948\u0902 \u0914\u0930 \u092d\u093e\u0935 \u092d\u0947\u091c \u0938\u0915\u0924\u0947 \u0939\u0948\u0902, \u091c\u094b \u0935\u093f\u0935\u0930\u0923 \u0914\u0930 \u091f\u094d\u0930\u0948\u0915\u093f\u0902\u0917 \u092e\u0947\u0902 \u0905\u092a\u0928\u0947 \u0906\u092a \u0926\u093f\u0916\u0924\u0947 \u0939\u0948\u0902\u0964 \u0916\u0930\u0940\u0926\u093e\u0930 \u091a\u0941\u0928\u0928\u093e, \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0914\u0930 \u0930\u0938\u0940\u0926 \u0905\u092d\u0940 \u0928\u0939\u0940\u0902 \u091c\u0941\u0921\u093c\u0947; \u092a\u094d\u0930\u0915\u093e\u0936\u0928 \u0938\u0947 SMS/\u092a\u0941\u0936 \u0938\u0942\u091a\u0928\u093e \u0928\u0939\u0940\u0902 \u091c\u093e\u0924\u0940 \u0914\u0930 \u0906\u091c \u092a\u093f\u0915\u0905\u092a \u0915\u0940 \u0917\u093e\u0930\u0902\u091f\u0940 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
            '\u0938\u0924\u094d\u092f\u093e\u092a\u093f\u0924 \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u093e \u0906\u0924\u093e \u0939\u0940 \u091c\u093e\u0939\u093f\u0930\u093e\u0924 \u0924\u094d\u092f\u093e\u0902\u091a\u094d\u092f\u093e Direct sell \u092b\u0940\u0921\u092e\u0927\u094d\u092f\u0947 \u092a\u093e\u0939\u0924\u093e\u0924 \u0935 \u0926\u0930 \u092a\u093e\u0920\u0935\u0942 \u0936\u0915\u0924\u093e\u0924, \u091c\u0947 \u0924\u092a\u0936\u0940\u0932 \u0935 \u091f\u094d\u0930\u0945\u0915\u093f\u0902\u0917\u092e\u0927\u094d\u092f\u0947 \u0906\u092a\u094b\u0906\u092a \u0926\u093f\u0938\u0924\u093e\u0924. \u0916\u0930\u0947\u0926\u0940\u0926\u093e\u0930 \u0928\u093f\u0935\u0921, \u0939\u0938\u094d\u0924\u093e\u0902\u0924\u0930\u0923 \u0935 \u092a\u093e\u0935\u0924\u0940 \u0905\u0926\u094d\u092f\u093e\u092a \u091c\u094b\u0921\u0932\u0947\u0932\u0940 \u0928\u093e\u0939\u0940\u0924; \u092a\u094d\u0930\u0915\u093e\u0936\u0928\u093e\u0928\u0947 SMS/\u092a\u0941\u0936 \u0938\u0942\u091a\u0928\u093e \u091c\u093e\u0924 \u0928\u093e\u0939\u0940 \u0935 \u0906\u091c \u092a\u093f\u0915\u0905\u092a\u091a\u0940 \u0939\u092e\u0940 \u0928\u093e\u0939\u0940.',
          ),
        ),
        actionButton(
          ct(
            'Create / sync my lots',
            '\u092e\u0947\u0930\u0947 \u0932\u0949\u091f \u092c\u0928\u093e\u090f\u0901 / \u0938\u093f\u0902\u0915 \u0915\u0930\u0947\u0902',
            '\u092e\u093e\u091d\u0947 \u0932\u0949\u091f \u0924\u092f\u093e\u0930 / \u0938\u093f\u0902\u0915 \u0915\u0930\u093e',
          ),
          _busy ? null : () => openCollector(context, const LotsScreen()),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _lots,
          builder: (context, s) {
            if (s.hasError)
              return note(
                ct(
                  'Lots unavailable. Check sign-in, rules and connection.',
                  '\u0932\u0949\u091f \u0909\u092a\u0932\u092c\u094d\u0927 \u0928\u0939\u0940\u0902\u0964 \u0938\u093e\u0907\u0928-\u0907\u0928, \u0928\u093f\u092f\u092e \u0914\u0930 \u0928\u0947\u091f\u0935\u0930\u094d\u0915 \u091c\u093e\u0901\u091a\u0947\u0902\u0964',
                  '\u0932\u0949\u091f \u0909\u092a\u0932\u092c\u094d\u0927 \u0928\u093e\u0939\u0940\u0924. \u0938\u093e\u0907\u0928 \u0907\u0928, \u0928\u093f\u092f\u092e \u0935 \u0928\u0947\u091f\u0935\u0930\u094d\u0915 \u0924\u092a\u093e\u0938\u093e.',
                ),
              );
            if (!s.hasData) return const LinearProgressIndicator();
            final docs = s.data!.docs
                .where((d) => CollectorSellService.eligible(d.data()))
                .toList();
            final matches = docs.where((d) => d.id == _lotId);
            final selected = matches.isEmpty ? null : matches.first;
            final offline =
                s.data!.metadata.isFromCache ||
                s.data!.metadata.hasPendingWrites;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (docs.isEmpty)
                  note(
                    ct(
                      'No available synced lot in the loaded 100 lots. Create/save/sync a lot first.',
                      '\u0932\u094b\u0921 \u0939\u0941\u090f 100 \u0932\u0949\u091f \u092e\u0947\u0902 \u0909\u092a\u0932\u092c\u094d\u0927 \u0938\u093f\u0902\u0915 \u0932\u0949\u091f \u0928\u0939\u0940\u0902\u0964 \u092a\u0939\u0932\u0947 \u0932\u0949\u091f \u092c\u0928\u093e\u090f\u0901, \u0938\u0939\u0947\u091c\u0947\u0902 \u0914\u0930 \u0938\u093f\u0902\u0915 \u0915\u0930\u0947\u0902\u0964',
                      '\u0932\u094b\u0921 \u091d\u093e\u0932\u0947\u0932\u094d\u092f\u093e 100 \u0932\u0949\u091f\u092e\u0927\u094d\u092f\u0947 \u0909\u092a\u0932\u092c\u094d\u0927 \u0938\u093f\u0902\u0915 \u0932\u0949\u091f \u0928\u093e\u0939\u0940. \u0906\u0927\u0940 \u0932\u0949\u091f \u0924\u092f\u093e\u0930, \u091c\u0924\u0928 \u0935 \u0938\u093f\u0902\u0915 \u0915\u0930\u093e.',
                    ),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey('sell_lot_${selected?.id}'),
                  initialValue: selected?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: ct(
                      'Choose saved lot',
                      '\u0938\u0939\u0947\u091c\u093e \u0932\u0949\u091f \u091a\u0941\u0928\u0947\u0902',
                      '\u091c\u0924\u0928 \u0932\u0949\u091f \u0928\u093f\u0935\u0921\u093e',
                    ),
                  ),
                  items: docs
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            '${materialLabel('${d.data()['material']}')} \u2022 ${d.data()['weightKg']} kg \u2022 ${d.data()['city']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _lotId = v);
                          AppSpeech.instance.say(
                            ct(
                              'Lot selected',
                              '\u0932\u0949\u091f \u091a\u0941\u0928\u093e',
                              '\u0932\u0949\u091f \u0928\u093f\u0935\u0921\u0932\u093e',
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('sell_mode_$_fulfilment'),
                  initialValue: _fulfilment,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: ct(
                      'Handover preference',
                      '\u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0915\u0940 \u092a\u0938\u0902\u0926',
                      '\u0939\u0938\u094d\u0924\u093e\u0902\u0924\u0930\u0923\u093e\u091a\u0940 \u092a\u0938\u0902\u0924\u0940',
                    ),
                  ),
                  items: ['pickup', 'delivery', 'either']
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text(_mode(v))),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() => _fulfilment = v);
                            AppSpeech.instance.say(_mode(v));
                          }
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _today,
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _today = v);
                          AppSpeech.instance.say(
                            ct(
                              'Availability changed',
                              '\u0909\u092a\u0932\u092c\u094d\u0927\u0924\u093e \u092c\u0926\u0932\u0940',
                              '\u0909\u092a\u0932\u092c\u094d\u0927\u0924\u093e \u092c\u0926\u0932\u0932\u0940',
                            ),
                          );
                        },
                  title: Text(
                    ct(
                      'Available today',
                      '\u0906\u091c \u0909\u092a\u0932\u092c\u094d\u0927',
                      '\u0906\u091c \u0909\u092a\u0932\u092c\u094d\u0927',
                    ),
                  ),
                  subtitle: Text(
                    ct(
                      'On: expires at local midnight. Off: available for six days.',
                      '\u091a\u093e\u0932\u0942: \u0938\u094d\u0925\u093e\u0928\u0940\u092f \u092e\u0927\u094d\u092f\u0930\u093e\u0924\u094d\u0930\u093f \u092a\u0930 \u0938\u092e\u093e\u092a\u094d\u0924\u0964 \u092c\u0902\u0926: \u091b\u0939 \u0926\u093f\u0928 \u0909\u092a\u0932\u092c\u094d\u0927\u0964',
                      '\u091a\u093e\u0932\u0942: \u0938\u094d\u0925\u093e\u0928\u093f\u0915 \u092e\u0927\u094d\u092f\u0930\u093e\u0924\u094d\u0930\u0940 \u0938\u0902\u092a\u0924\u0947. \u092c\u0902\u0926: \u0938\u0939\u093e \u0926\u093f\u0935\u0938 \u0909\u092a\u0932\u092c\u094d\u0927.',
                    ),
                  ),
                ),
                TextField(
                  controller: _rate,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: ct(
                      'Asking \u20b9/kg (optional)',
                      '\u092e\u093e\u0901\u0917\u093e \u092d\u093e\u0935 \u20b9/\u0915\u093f\u0932\u094b (\u0935\u0948\u0915\u0932\u094d\u092a\u093f\u0915)',
                      '\u0905\u092a\u0947\u0915\u094d\u0937\u093f\u0924 \u20b9/\u0915\u093f\u0932\u094b (\u0910\u091a\u094d\u091b\u093f\u0915)',
                    ),
                    helperText: ct(
                      'Blank = ask recycler for quote',
                      '\u0916\u093e\u0932\u0940 = \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u093e \u0938\u0947 \u092d\u093e\u0935 \u092e\u093e\u0901\u0917\u0947\u0902',
                      '\u0930\u093f\u0915\u093e\u092e\u0947 = \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u094d\u092f\u093e\u0915\u0921\u0942\u0928 \u0926\u0930 \u092e\u093e\u0917\u093e',
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _consent = v ?? false);
                          AppSpeech.instance.say(
                            ct(
                              'Publication consent changed',
                              '\u092a\u094d\u0930\u0915\u093e\u0936\u0928 \u0915\u0940 \u0938\u0939\u092e\u0924\u093f \u092c\u0926\u0932\u0940',
                              '\u092a\u094d\u0930\u0915\u093e\u0936\u0928\u093e\u091a\u0940 \u0938\u0902\u092e\u0924\u0940 \u092c\u0926\u0932\u0932\u0940',
                            ),
                          );
                        },
                  title: Text(
                    ct(
                      'I agree to share this lot\u2019s material, weight, city and sale preferences with verified recyclers.',
                      '\u092e\u0948\u0902 \u0938\u0924\u094d\u092f\u093e\u092a\u093f\u0924 \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u093e\u0913\u0902 \u0938\u0947 \u0907\u0938 \u0932\u0949\u091f \u0915\u0940 \u0938\u093e\u092e\u0917\u094d\u0930\u0940, \u0935\u091c\u0928, \u0936\u0939\u0930 \u0914\u0930 \u092c\u093f\u0915\u094d\u0930\u0940 \u0915\u0940 \u092a\u0938\u0902\u0926 \u0938\u093e\u091d\u093e \u0915\u0930\u0928\u0947 \u0915\u094b \u0938\u0939\u092e\u0924 \u0939\u0942\u0901\u0964',
                      '\u092e\u0940 \u0938\u0924\u094d\u092f\u093e\u092a\u093f\u0924 \u0930\u0940\u0938\u093e\u092f\u0915\u0932\u0915\u0930\u094d\u0924\u094d\u092f\u093e\u0902\u0938\u094b\u092c\u0924 \u092f\u093e \u0932\u0949\u091f\u091a\u0947 \u0938\u093e\u0939\u093f\u0924\u094d\u092f, \u0935\u091c\u0928, \u0936\u0939\u0930 \u0935 \u0935\u093f\u0915\u094d\u0930\u0940\u091a\u0940 \u092a\u0938\u0902\u0924\u0940 \u0936\u0947\u092f\u0930 \u0915\u0930\u0923\u094d\u092f\u093e\u0938 \u0938\u0939\u092e\u0924 \u0906\u0939\u0947.',
                    ),
                  ),
                ),
                if (offline)
                  note(
                    ct(
                      'Cached lots: publishing needs an online server check.',
                      '\u0915\u0948\u0936 \u0932\u0949\u091f: \u092a\u094d\u0930\u0915\u093e\u0936\u0928 \u0915\u0947 \u0932\u093f\u090f \u0911\u0928\u0932\u093e\u0907\u0928 \u0938\u0930\u094d\u0935\u0930 \u091c\u093e\u0901\u091a \u091a\u093e\u0939\u093f\u090f\u0964',
                      '\u0915\u0945\u0936 \u0932\u0949\u091f: \u092a\u094d\u0930\u0915\u093e\u0936\u0928\u093e\u0938\u093e\u0920\u0940 \u0911\u0928\u0932\u093e\u0907\u0928 \u0938\u0930\u094d\u0935\u094d\u0939\u0930 \u0924\u092a\u093e\u0938\u0923\u0940 \u0906\u0935\u0936\u094d\u092f\u0915.',
                    ),
                  ),
                actionButton(
                  ct(
                    'Save form on device',
                    '\u092b\u0949\u0930\u094d\u092e \u0921\u093f\u0935\u093e\u0907\u0938 \u092a\u0930 \u0938\u0939\u0947\u091c\u0947\u0902',
                    '\u092b\u0949\u0930\u094d\u092e \u0921\u093f\u0935\u094d\u0939\u093e\u0907\u0938\u0935\u0930 \u091c\u0924\u0928 \u0915\u0930\u093e',
                  ),
                  _busy ? null : _saveDraft,
                ),
                actionButton(
                  ct(
                    'Publish sell request',
                    '\u092c\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0901\u0917 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u0947\u0902',
                    '\u0935\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0917\u0923\u0940 \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0915\u0930\u093e',
                  ),
                  _busy || offline || selected == null || !_consent
                      ? null
                      : () => _publish(selected.data()),
                ),
              ],
            );
          },
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) note(_message!),
        const SizedBox(height: 20),
        Text(
          ct(
            'My sell requests',
            '\u092e\u0947\u0930\u0940 \u092c\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0901\u0917',
            '\u092e\u093e\u091d\u094d\u092f\u093e \u0935\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0917\u0923\u094d\u092f\u093e',
          ),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _listings,
          builder: (context, s) {
            if (s.hasError)
              return note(
                ct(
                  'Sell requests unavailable. Check the new rules are published and your connection.',
                  '\u092c\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0901\u0917 \u0909\u092a\u0932\u092c\u094d\u0927 \u0928\u0939\u0940\u0902\u0964 \u0928\u090f \u0928\u093f\u092f\u092e \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0939\u0948\u0902 \u0914\u0930 \u0928\u0947\u091f\u0935\u0930\u094d\u0915 \u0938\u0939\u0940 \u0939\u0948, \u091c\u093e\u0901\u091a\u0947\u0902\u0964',
                  '\u0935\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0917\u0923\u094d\u092f\u093e \u0909\u092a\u0932\u092c\u094d\u0927 \u0928\u093e\u0939\u0940\u0924. \u0928\u0935\u0940\u0928 \u0928\u093f\u092f\u092e \u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0906\u0939\u0947\u0924 \u0935 \u0928\u0947\u091f\u0935\u0930\u094d\u0915 \u092f\u094b\u0917\u094d\u092f \u0906\u0939\u0947 \u0924\u0947 \u0924\u092a\u093e\u0938\u093e.',
                ),
              );
            if (!s.hasData) return const LinearProgressIndicator();
            final docs = s.data!.docs.toList()
              ..sort(
                (a, b) =>
                    ((b.data()['publishedAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                          (a.data()['publishedAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0,
                        ),
              );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.data!.metadata.isFromCache)
                  note(
                    ct(
                      'Cached requests \u2014 not a fresh server confirmation.',
                      '\u0915\u0948\u0936 \u092e\u093e\u0901\u0917 \u2014 \u0928\u0908 \u0938\u0930\u094d\u0935\u0930 \u092a\u0941\u0937\u094d\u091f\u093f \u0928\u0939\u0940\u0902\u0964',
                      '\u0915\u0945\u0936 \u092e\u093e\u0917\u0923\u094d\u092f\u093e \u2014 \u0928\u0935\u0940\u0928 \u0938\u0930\u094d\u0935\u094d\u0939\u0930 \u092a\u0941\u0937\u094d\u091f\u0940 \u0928\u093e\u0939\u0940.',
                    ),
                  ),
                if (docs.isEmpty)
                  note(
                    ct(
                      'No sell requests in this view yet.',
                      '\u0907\u0938 \u0938\u0942\u091a\u0940 \u092e\u0947\u0902 \u0905\u092d\u0940 \u092c\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0901\u0917 \u0928\u0939\u0940\u0902\u0964',
                      '\u092f\u093e \u092f\u093e\u0926\u0940\u0924 \u0905\u091c\u0942\u0928 \u0935\u093f\u0915\u094d\u0930\u0940 \u092e\u093e\u0917\u0923\u0940 \u0928\u093e\u0939\u0940.',
                    ),
                  ),
                ...docs.map((d) {
                  final v = d.data();
                  final open = v['status'] == 'open';
                  final expired =
                      v['expiresAt'] is Timestamp &&
                      !(v['expiresAt'] as Timestamp).toDate().isAfter(
                        DateTime.now(),
                      );
                  return Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              MaterialPhoto(material: '${v['material']}'),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${materialLabel('${v['material']}')} \u2022 ${v['weightKg']} kg\n${v['city']}',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            !open
                                ? ct(
                                    'Withdrawn',
                                    '\u0935\u093e\u092a\u0938 \u0932\u0940 \u0917\u0908',
                                    '\u092e\u093e\u0917\u0947 \u0918\u0947\u0924\u0932\u0940',
                                  )
                                : expired
                                ? ct(
                                    'Expired \u2014 withdraw before republishing',
                                    '\u0938\u092e\u093e\u092a\u094d\u0924 \u2014 \u092b\u093f\u0930 \u092a\u094d\u0930\u0915\u093e\u0936\u0928 \u0938\u0947 \u092a\u0939\u0932\u0947 \u0935\u093e\u092a\u0938 \u0932\u0947\u0902',
                                    '\u092e\u0941\u0926\u0924 \u0938\u0902\u092a\u0932\u0940 \u2014 \u092a\u0941\u0928\u094d\u0939\u093e \u092a\u094d\u0930\u0915\u093e\u0936\u0928\u093e\u0906\u0927\u0940 \u092e\u093e\u0917\u0947 \u0918\u094d\u092f\u093e',
                                  )
                                : ct(
                                    'Published listing \u2014 availability must be reconfirmed',
                                    '\u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u0938\u0942\u091a\u0940 \u2014 \u0909\u092a\u0932\u092c\u094d\u0927\u0924\u093e \u092b\u093f\u0930 \u091c\u093e\u0901\u091a\u0928\u0940 \u0939\u094b\u0917\u0940',
                                    '\u092a\u094d\u0930\u0915\u093e\u0936\u093f\u0924 \u091c\u093e\u0939\u093f\u0930\u093e\u0924 \u2014 \u0909\u092a\u0932\u092c\u094d\u0927\u0924\u093e \u092a\u0941\u0928\u094d\u0939\u093e \u0924\u092a\u093e\u0938\u093e\u0935\u0940 \u0932\u093e\u0917\u0947\u0932',
                                  ),
                          ),
                          Text(
                            '${_mode('${v['fulfilment']}')} \u2022 ${v['askingRate'] == 0 ? ct('Quote required', '\u092d\u093e\u0935 \u091a\u093e\u0939\u093f\u090f', '\u0926\u0930 \u0939\u0935\u093e') : '\u20b9${v['askingRate']}/kg'}',
                          ),
                          Text(
                            '${ct('Expires', '\u0938\u092e\u093e\u092a\u094d\u0924\u093f', '\u092e\u0941\u0926\u0924')}: ${_date(v['expiresAt'])}',
                          ),
                          actionButton(
                            ct(
                              'Details & tracking',
                              '\u0935\u093f\u0935\u0930\u0923 \u0914\u0930 \u091f\u094d\u0930\u0948\u0915\u093f\u0902\u0917',
                              '\u0924\u092a\u0936\u0940\u0932 \u0935 \u091f\u094d\u0930\u0945\u0915\u093f\u0902\u0917',
                            ),
                            () => openCollector(
                              context,
                              SellRequestDetailsScreen(ref: d.reference),
                            ),
                          ),
                          if (open)
                            actionButton(
                              ct(
                                'Withdraw request',
                                '\u092e\u093e\u0901\u0917 \u0935\u093e\u092a\u0938 \u0932\u0947\u0902',
                                '\u092e\u093e\u0917\u0923\u0940 \u092e\u093e\u0917\u0947 \u0918\u094d\u092f\u093e',
                              ),
                              _busy || s.data!.metadata.isFromCache
                                  ? null
                                  : () => _run(() async {
                                      await _service.withdraw(_uid, d.id);
                                      return ct(
                                        'Withdrawal confirmed. This does not cancel any separate buyer offer.',
                                        '\u092e\u093e\u0901\u0917 \u0935\u093e\u092a\u0938 \u0932\u0947\u0928\u0947 \u0915\u0940 \u092a\u0941\u0937\u094d\u091f\u093f\u0964 \u0907\u0938\u0938\u0947 \u0905\u0932\u0917 \u0916\u0930\u0940\u0926\u093e\u0930 \u0911\u092b\u0930 \u0930\u0926\u094d\u0926 \u0928\u0939\u0940\u0902 \u0939\u094b\u0924\u093e\u0964',
                                        '\u092e\u093e\u0917\u0923\u0940 \u092e\u093e\u0917\u0947 \u0918\u0947\u0924\u0932\u094d\u092f\u093e\u091a\u0940 \u092a\u0941\u0937\u094d\u091f\u0940. \u092f\u093e\u0928\u0947 \u0935\u0947\u0917\u0933\u093e \u0916\u0930\u0947\u0926\u0940\u0926\u093e\u0930 \u0911\u092b\u0930 \u0930\u0926\u094d\u0926 \u0939\u094b\u0924 \u0928\u093e\u0939\u0940.',
                                      );
                                    }),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                note(
                  ct(
                    'Up to 100 own requests. Photos stay on this device. Withdraw a listing when its lot changes or is sold elsewhere.',
                    '\u0905\u0927\u093f\u0915\u0924\u092e 100 \u0905\u092a\u0928\u0940 \u092e\u093e\u0901\u0917\u0964 \u092b\u094b\u091f\u094b \u0907\u0938\u0940 \u0921\u093f\u0935\u093e\u0907\u0938 \u092a\u0930 \u0930\u0939\u0924\u0940 \u0939\u0948\u0902\u0964 \u0932\u0949\u091f \u092c\u0926\u0932\u0928\u0947 \u092f\u093e \u0915\u0939\u0940\u0902 \u0914\u0930 \u092c\u093f\u0915\u0928\u0947 \u092a\u0930 \u0938\u0942\u091a\u0940 \u0935\u093e\u092a\u0938 \u0932\u0947\u0902\u0964',
                    '\u0915\u092e\u093e\u0932 100 \u0938\u094d\u0935\u0924\u0903\u091a\u094d\u092f\u093e \u092e\u093e\u0917\u0923\u094d\u092f\u093e. \u092b\u094b\u091f\u094b \u092f\u093e \u0921\u093f\u0935\u094d\u0939\u093e\u0907\u0938\u0935\u0930 \u0930\u093e\u0939\u0924\u093e\u0924. \u0932\u0949\u091f \u092c\u0926\u0932\u0932\u094d\u092f\u093e\u0935\u0930 \u0915\u093f\u0902\u0935\u093e \u0907\u0924\u0930\u0924\u094d\u0930 \u0935\u093f\u0915\u0932\u094d\u092f\u093e\u0935\u0930 \u091c\u093e\u0939\u093f\u0930\u093e\u0924 \u092e\u093e\u0917\u0947 \u0918\u094d\u092f\u093e.',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
