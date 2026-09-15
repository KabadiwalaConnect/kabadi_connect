import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_speech.dart';
import 'collector_messages.dart';
import 'collector_ui.dart';
import 'material_photos.dart';
import 'recycler_direct_sell.dart' show kDirectSellMaterials, kDirectSellCities;
import 'request_tracking.dart' show PickupPlanPanel;

/// Sprint2 recycler side of the EXISTING buyer-request flow:
/// draft buying requests (admin publishes), own offers inbox,
/// quote/reject, pickup-plan confirm, handover confirm, offer chat.
/// No self-approval, no invented data; every state is server-recorded.
enum DemandOutcome { done, wrongState, notMine, invalid, unconfirmed, failed }

class DirectDemandService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> offerRef(
    String requestId,
    String offerId,
  ) => _db
      .collection('recyclerRequests')
      .doc(requestId)
      .collection('offers')
      .doc(offerId);

  Future<DemandOutcome> createDraft({
    required String material,
    required String city,
    num? pricePerKg,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return DemandOutcome.failed;
    if (!kDirectSellMaterials.contains(material) ||
        !kDirectSellCities.contains(city)) {
      return DemandOutcome.invalid;
    }
    if (pricePerKg != null && (pricePerKg <= 0 || pricePerKg > 10000000)) {
      return DemandOutcome.invalid;
    }
    try {
      final data = <String, dynamic>{
        'schemaVersion': 1,
        'recyclerUid': uid,
        'recyclerName': '',
        'city': city,
        'material': material,
        'status': 'draft',
        'authorizationStatus': 'pendingPublish',
        'currency': 'INR',
        'createdAt': FieldValue.serverTimestamp(),
      };
      // recyclerName is enforced by rules from the live profile; the client
      // pre-fills it so the draft is readable in the UI.
      final me = await _db.collection('users').doc(uid).get();
      final name = me.data()?['name'];
      data['recyclerName'] = name is String ? name : '';
      if (pricePerKg != null) data['pricePerKg'] = pricePerKg;
      await _db
          .collection('recyclerRequests')
          .add(data)
          .timeout(const Duration(seconds: 25));
      return DemandOutcome.done;
    } on TimeoutException {
      return DemandOutcome.unconfirmed;
    } catch (_) {
      return DemandOutcome.failed;
    }
  }

  Future<DemandOutcome> quoteOffer({
    required String requestId,
    required String offerId,
    required num ratePerKg,
    required int expiryHours,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return DemandOutcome.failed;
    if (ratePerKg <= 0 || ratePerKg > 10000000) return DemandOutcome.invalid;
    if (![1, 6, 24].contains(expiryHours)) return DemandOutcome.invalid;
    try {
      return await _db
          .runTransaction((tx) async {
            final ref = offerRef(requestId, offerId);
            final snap = await tx.get(ref);
            if (!snap.exists) return DemandOutcome.wrongState;
            final v = snap.data()!;
            if (v['recyclerUid'] != uid) return DemandOutcome.notMine;
            if (v['status'] != 'proposed') return DemandOutcome.wrongState;
            tx.update(ref, {
              'status': 'quoted',
              'quoteRate': ratePerKg,
              'quoteCurrency': 'INR',
              'quoteExpiresAt': Timestamp.fromMillisecondsSinceEpoch(
                DateTime.now().millisecondsSinceEpoch +
                    expiryHours * 3600 * 1000,
              ),
              'quotedAt': FieldValue.serverTimestamp(),
            });
            return DemandOutcome.done;
          }, timeout: const Duration(seconds: 25))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => DemandOutcome.unconfirmed,
          );
    } catch (_) {
      return DemandOutcome.failed;
    }
  }

  /// Reject = offer->rejected AND collector lot released back to draft.
  /// Rules require BOTH writes in one transaction (getAfter pairing).
  Future<DemandOutcome> rejectOffer({
    required String requestId,
    required String offerId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return DemandOutcome.failed;
    try {
      return await _db
          .runTransaction((tx) async {
            final ref = offerRef(requestId, offerId);
            final snap = await tx.get(ref);
            if (!snap.exists) return DemandOutcome.wrongState;
            final v = snap.data()!;
            if (v['recyclerUid'] != uid) return DemandOutcome.notMine;
            final st = v['status'];
            if (st != 'proposed' && st != 'quoted') {
              return DemandOutcome.wrongState;
            }
            final collectorUid = '${v['collectorUid']}';
            final lotId = '${v['lotId']}';
            final lot = _db
                .collection('users')
                .doc(collectorUid)
                .collection('lots')
                .doc(lotId);
            tx.update(ref, {
              'status': 'rejected',
              'rejectedAt': FieldValue.serverTimestamp(),
            });
            tx.update(lot, {
              'status': 'draft',
              'activeRequestId': '',
              'activeOfferId': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return DemandOutcome.done;
          }, timeout: const Duration(seconds: 25))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => DemandOutcome.unconfirmed,
          );
    } catch (_) {
      return DemandOutcome.failed;
    }
  }

  /// Confirm handover = offer->completed AND lot->handedOver, paired.
  Future<DemandOutcome> confirmHandover({
    required String requestId,
    required String offerId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return DemandOutcome.failed;
    try {
      return await _db
          .runTransaction((tx) async {
            final ref = offerRef(requestId, offerId);
            final snap = await tx.get(ref);
            if (!snap.exists) return DemandOutcome.wrongState;
            final v = snap.data()!;
            if (v['recyclerUid'] != uid) return DemandOutcome.notMine;
            if (v['status'] != 'handoverPending') {
              return DemandOutcome.wrongState;
            }
            final collectorUid = '${v['collectorUid']}';
            final lotId = '${v['lotId']}';
            final lot = _db
                .collection('users')
                .doc(collectorUid)
                .collection('lots')
                .doc(lotId);
            tx.update(ref, {
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
            });
            tx.update(lot, {
              'status': 'handedOver',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return DemandOutcome.done;
          }, timeout: const Duration(seconds: 25))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => DemandOutcome.unconfirmed,
          );
    } catch (_) {
      return DemandOutcome.failed;
    }
  }
}

String demandStatus(String s, String Function(String, String, String) t) =>
    switch (s) {
      'draft' => t(
        'Draft - awaiting admin publication',
        'ड्राफ़्ट - एडमिन प्रकाशन बाकी',
        'ड्राफ्ट - प्रकाशन बाकी',
      ),
      'active' => t('Live', 'सक्रिय', 'सक्रिय'),
      'proposed' => t('Proposal received', 'प्रस्ताव मिला', 'प्रस्ताव मिळाला'),
      'quoted' => t('You quoted', 'आपने भाव दिया', 'तुम्ही दर दिला'),
      'accepted' => t(
        'Collector accepted',
        'कलेक्टर ने स्वीकारा',
        'संकलकाने स्वीकारले',
      ),
      'handoverPending' => t(
        'Awaiting your confirmation',
        'आपकी पुष्टि बाकी',
        'तुमची पुष्टी बाकी',
      ),
      'completed' => t('Completed', 'पूर्ण', 'पूर्ण'),
      'rejected' => t('Rejected', 'अस्वीकृत', 'नाकारले'),
      'cancelled' => t(
        'Withdrawn by collector',
        'कलेक्टर ने वापस लिया',
        'संकलकाने मागे घेतले',
      ),
      _ => s,
    };

class RecyclerDemandScreen extends StatefulWidget {
  const RecyclerDemandScreen({super.key});
  @override
  State<RecyclerDemandScreen> createState() => _DemandState();
}

class _DemandState extends State<RecyclerDemandScreen> {
  final DirectDemandService _service = DirectDemandService();
  int _tab = 0;
  bool _busy = false;
  String? _message;

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  void _say(String text) => AppSpeech.instance.say(text);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAEF),
        title: Text(
          _t('My demand & offers', 'मेरी माँग और ऑफ़र', 'माझी माग व ऑफर'),
        ),
        actions: const [SpeechFeedbackButton()],
      ),
      body: SafeArea(
        child: uid == null
            ? Center(
                child: Text(
                  _t(
                    'Session unavailable.',
                    'सेशन उपलब्ध नहीं।',
                    'सत्र उपलब्ध नाही.',
                  ),
                ),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      _seg(
                        0,
                        _t('My requests', 'मेरी माँगे', 'माझ्या मागण्या'),
                      ),
                      _seg(
                        1,
                        _t('Offers inbox', 'ऑफ़र इनबॉक्स', 'ऑफर इनबॉक्स'),
                      ),
                    ],
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: note(_message!),
                    ),
                  Expanded(child: _tab == 0 ? _requests(uid) : _offers(uid)),
                ],
              ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF286B3B),
              onPressed: _busy ? null : () => _newRequest(uid!),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                _t('New buying request', 'नई खरीद माँग', 'नवीन खरेदी माग'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }

  Widget _seg(int index, String label) {
    final sel = _tab == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: Material(
          color: sel ? const Color(0xFF286B3B) : const Color(0xFFE4F3E6),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              _say(label);
              setState(() => _tab = index);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : const Color(0xFF286B3B),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _requests(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('recyclerRequests')
          .where('recyclerUid', isEqualTo: uid)
          .limit(50)
          .snapshots(includeMetadataChanges: true),
      builder: (context, s) {
        if (s.hasError) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              note(
                _t(
                  'Requests could not load. Check connection and published rules.',
                  'माँगे लोड नहीं हुईं। कनेक्शन और प्रकाशित नियम जाँचें।',
                  'मागण्या लोड झाल्या नाहीत. कनेक्शन व नियम तपासा.',
                ),
              ),
            ],
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        docs.sort(
          (a, b) =>
              ((b.data()['createdAt'] is Timestamp
                      ? (b.data()['createdAt'] as Timestamp)
                            .millisecondsSinceEpoch
                      : 0))
                  .compareTo(
                    (a.data()['createdAt'] is Timestamp
                        ? (a.data()['createdAt'] as Timestamp)
                              .millisecondsSinceEpoch
                        : 0),
                  ),
        );
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            note(
              _t(
                'Drafts are visible only to you. A trusted admin publishes them live; you cannot self-publish.',
                'ड्राफ़्ट सिर्फ़ आपको दिखते हैं। भरोसेमंद एडमिन इन्हें लाइव करते हैं; आप खुद प्रकाशित नहीं कर सकते।',
                'ड्राफ्ट फक्त तुम्हाला दिसतात. विश्वासू प्रकाशक ते लाइव करतो; तुम्ही स्वतः प्रकाशित करू शकत नाही.',
              ),
            ),
            if (docs.isEmpty)
              note(
                _t(
                  'No buying requests yet. Create one with the + button.',
                  'अभी कोई खरीद माँग नहीं। + बटन से बनाएं।',
                  'अद्याप खरेदी माग नाही. + बटणाने तयार करा.',
                ),
              ),
            ...docs.map((d) {
              final v = d.data();
              final status = '${v['status']}';
              final expired =
                  v['expiresAt'] is Timestamp &&
                  !(v['expiresAt'] as Timestamp).toDate().isAfter(
                    DateTime.now(),
                  );
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MaterialPhoto(material: '${v['material'] ?? ''}'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  materialLabel('${v['material'] ?? ''}'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${v['city'] ?? ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'active' && !expired
                                  ? const Color(0xFFD9EDDB)
                                  : const Color(0xFFFFEEC9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status == 'active' && expired
                                  ? _t('Expired', 'समाप्त', 'मुदत संपली')
                                  : demandStatus(status, _t),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (v['pricePerKg'] is num)
                        note(
                          '${_t('Indicative rate', 'संकेतक भाव', 'सूचक दर')}: ₹${v['pricePerKg']}/kg',
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _newRequest(String uid) async {
    String material = kDirectSellMaterials.first;
    String city = kDirectSellCities.first;
    final rate = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          backgroundColor: const Color(0xFFFFFAEF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            _t('New buying request', 'नई खरीद माँग', 'नवीन खरेदी माग'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: material,
                items: [
                  for (final m in kDirectSellMaterials)
                    DropdownMenuItem(value: m, child: Text(materialLabel(m))),
                ],
                onChanged: (v) => setS(() => material = v!),
                decoration: InputDecoration(
                  labelText: _t('Material', 'सामग्री', 'साहित्य'),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: city,
                items: [
                  for (final cc in kDirectSellCities)
                    DropdownMenuItem(value: cc, child: Text(cc)),
                ],
                onChanged: (v) => setS(() => city = v!),
                decoration: InputDecoration(
                  labelText: _t('City', 'शहर', 'शहर'),
                ),
              ),
              TextField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t(
                    'Indicative rate ₹/kg (optional)',
                    'संकेतक भाव ₹/kg (वैकल्पिक)',
                    'सूचक दर ₹/kg (ऐच्छिक)',
                  ),
                ),
              ),
              Text(
                _t(
                  'Saved as draft. A trusted admin must publish it before collectors can see it.',
                  'ड्राफ़्ट के रूप में सहेजा जाएगा। कलेक्टरों को दिखने से पहले एडमिन प्रकाशित करेंगे।',
                  'ड्राफ्ट म्हणून जतन होईल. संकलकांना दिसण्याआधी प्रकाशक लाइव करतील.',
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF66756B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: Text(_t('Cancel', 'रद्द करें', 'रद्द करा')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF286B3B),
              ),
              onPressed: () => Navigator.of(c).pop(true),
              child: Text(
                _t('Save draft', 'ड्राफ़्ट सहेजें', 'ड्राफ्ट जतन करा'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final rv = double.tryParse(rate.text.trim());
    setState(() {
      _busy = true;
      _message = null;
    });
    final out = await _service.createDraft(
      material: material,
      city: city,
      pricePerKg: rv,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (out) {
        DemandOutcome.done => _t(
          'Draft saved. Waiting for admin publication.',
          'ड्राफ़्ट सहेजा। एडमिन प्रकाशन बाकी।',
          'ड्राफ्ट जतन. प्रकाशनाची वाट.',
        ),
        DemandOutcome.invalid => _t(
          'Enter valid details.',
          'सही विवरण भरें।',
          'योग्य तपशील भरा.',
        ),
        DemandOutcome.unconfirmed => _t(
          'Not confirmed yet - refresh before retrying.',
          'पुष्टि बाकी - रिफ़्रेश करके जाँचें।',
          'पुष्टी बाकी - रिफ्रेश करून पहा.',
        ),
        _ => _t(
          'Could not save. Try again.',
          'सहेजा नहीं गया। दोबारा कोशिश करें।',
          'जतन झाले नाही. पुन्हा प्रयत्न करा.',
        ),
      };
    });
    _say(_message!);
  }

  Widget _offers(String uid) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadOffers(uid),
      builder: (context, s) {
        if (s.hasError) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              note(
                _t(
                  'Offers could not load. Check connection and rules.',
                  'ऑफ़र लोड नहीं हुए। कनेक्शन और नियम जाँचें।',
                  'ऑफर लोड झाले नाहीत. कनेक्शन व नियम तपासा.',
                ),
              ),
            ],
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final rows = s.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              note(
                _t(
                  'Proposals from collectors on your live requests. Open one to quote, reject, confirm pickup or handover, and chat.',
                  'आपकी लाइव माँगों पर कलेक्टरों के प्रस्ताव। खोलकर भाव दें, अस्वीकार करें, पिकअप/हैंडओवर पुष्टि करें और चैट करें।',
                  'तुमच्या लाइव मागण्यांवर संकलकांचे प्रस्ताव. उघडून दर द्या, नाकारा, पिकअप/हस्तांतरण पुष्टी करा व चॅट करा.',
                ),
              ),
              if (rows.isEmpty)
                note(
                  _t(
                    'No offers right now.',
                    'अभी कोई ऑफ़र नहीं।',
                    'सध्या ऑफर नाहीत.',
                  ),
                ),
              ...rows.map((m) {
                final status = '${m['status']}';
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecyclerOfferDetailScreen(
                          requestId: '${m['requestId']}',
                          offerId: '${m['id']}',
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          MaterialPhoto(material: '${m['material'] ?? ''}'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${materialLabel('${m['material'] ?? ''}')} • ${m['weightKg'] ?? ''} kg',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  demandStatus(status, _t),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF286B3B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF286B3B),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadOffers(String uid) async {
    final db = FirebaseFirestore.instance;
    final reqs = await db
        .collection('recyclerRequests')
        .where('recyclerUid', isEqualTo: uid)
        .limit(20)
        .get();
    final rows = <Map<String, dynamic>>[];
    for (final r in reqs.docs) {
      final off = await r.reference.collection('offers').limit(50).get();
      for (final o in off.docs) {
        final m = Map<String, dynamic>.from(o.data());
        m['id'] = o.id;
        m['requestId'] = r.id;
        rows.add(m);
      }
    }
    rows.sort(
      (a, b) =>
          ((b['createdAt'] is Timestamp
                  ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
                  : 0))
              .compareTo(
                (a['createdAt'] is Timestamp
                    ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
                    : 0),
              ),
    );
    return rows;
  }
}

class RecyclerOfferDetailScreen extends StatefulWidget {
  const RecyclerOfferDetailScreen({
    required this.requestId,
    required this.offerId,
    super.key,
  });
  final String requestId, offerId;
  @override
  State<RecyclerOfferDetailScreen> createState() => _OfferDetailState();
}

class _OfferDetailState extends State<RecyclerOfferDetailScreen> {
  final DirectDemandService _service = DirectDemandService();
  final _rate = TextEditingController();
  int _expiry = 6;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  Future<void> _act(
    Future<DemandOutcome> Function() work,
    String okText,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final out = await work();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (out) {
        DemandOutcome.done => okText,
        DemandOutcome.wrongState => _t(
          'The offer changed meanwhile. Refresh and check.',
          'ऑफ़र बदल चुका है। रिफ़्रेश करके देखें।',
          'ऑफर बदलला आहे. रिफ्रेश करून पहा.',
        ),
        DemandOutcome.notMine => _t(
          'Only the linked recycler can act on this offer.',
          'सिर्फ़ जुड़ा हुआ रीसायकलकर्ता इस ऑफ़र पर कार्रवाई कर सकता है।',
          'फक्त जोडलेला रीसायकलर या ऑफरवर कृती करू शकतो.',
        ),
        DemandOutcome.invalid => _t(
          'Enter a valid rate.',
          'सही भाव भरें।',
          'योग्य दर भरा.',
        ),
        DemandOutcome.unconfirmed => _t(
          'Not confirmed yet - reopen before retrying.',
          'पुष्टि बाकी - दोबारा खोलकर जाँचें।',
          'पुष्टी बाकी - पुन्हा उघडून पहा.',
        ),
        _ => _t(
          'Action did not complete. Try again.',
          'कार्रवाई पूरी नहीं हुई। दोबारा कोशिश करें।',
          'कृती पूर्ण झाली नाही. पुन्हा प्रयत्न करा.',
        ),
      };
    });
    AppSpeech.instance.say(_message!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAEF),
        title: Text(_t('Offer details', 'ऑफ़र विवरण', 'ऑफर तपशील')),
        actions: const [SpeechFeedbackButton()],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service
            .offerRef(widget.requestId, widget.offerId)
            .snapshots(includeMetadataChanges: true),
        builder: (context, s) {
          if (s.hasError) {
            return Center(
              child: Text(
                _t(
                  'Offer unavailable. Check access and connection.',
                  'ऑफ़र उपलब्ध नहीं। पहुँच और कनेक्शन जाँचें।',
                  'ऑफर उपलब्ध नाही. प्रवेश व कनेक्शन तपासा.',
                ),
              ),
            );
          }
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          final v = s.data!.data();
          if (v == null) {
            return Center(
              child: Text(
                _t('Offer not found', 'ऑफ़र नहीं मिला', 'ऑफर सापडला नाही'),
              ),
            );
          }
          final status = '${v['status']}';
          final material = '${v['material'] ?? ''}';
          final ref = _service.offerRef(widget.requestId, widget.offerId);
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MaterialPhoto(material: material),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  materialLabel(material),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '${v['weightKg'] ?? ''} kg • ${v['city'] ?? ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  demandStatus(status, _t),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF286B3B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              note(
                _t(
                  'Collector identity stays private; meet only through agreed pickup details. Chat never changes quote or payment records.',
                  'कलेक्टर की पहचान निजी रहती है; पिकअप विवरण से ही मिलें। चैट से भाव या भुगतान रिकॉर्ड नहीं बदलते।',
                  'संकलकाची ओळख खाजगी राहते; फक्त पिकअप तपशिलांमधून भेटा. चॅटने दर व पेमेंट नोंदी बदलत नाहीत.',
                ),
              ),
              if (status == 'proposed' || status == 'quoted') ...[
                TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _t(
                      'Your rate ₹/kg',
                      'आपका भाव ₹/kg',
                      'तुमचा दर ₹/kg',
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final h in [1, 6, 24])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selectedColor: const Color(0xFF286B3B),
                          labelStyle: TextStyle(
                            color: _expiry == h
                                ? Colors.white
                                : const Color(0xFF286B3B),
                            fontWeight: FontWeight.w700,
                          ),
                          label: Text('${h}h'),
                          selected: _expiry == h,
                          onSelected: (sel) {
                            if (sel) setState(() => _expiry = h);
                          },
                        ),
                      ),
                  ],
                ),
                if (v['quoteRate'] is num)
                  note(
                    '${_t('Current quote', 'वर्तमान भाव', 'सध्याचा दर')}: ₹${v['quoteRate']}/kg',
                  ),
                actionButton(
                  ct(
                    'Give / update quote',
                    'भाव दें / अपडेट करें',
                    'दर द्या / अद्यतन करा',
                  ),
                  _busy
                      ? null
                      : () {
                          final r = double.tryParse(_rate.text.trim());
                          if (r == null) {
                            setState(
                              () => _message = _t(
                                'Enter a valid rate.',
                                'सही भाव भरें।',
                                'योग्य दर भरा.',
                              ),
                            );
                            return;
                          }
                          _act(
                            () => _service.quoteOffer(
                              requestId: widget.requestId,
                              offerId: widget.offerId,
                              ratePerKg: r,
                              expiryHours: _expiry,
                            ),
                            _t(
                              'Quote recorded. Collector can now accept it.',
                              'भाव दर्ज। कलेक्टर अब स्वीकार सकता है।',
                              'दर नोंदवला. संकलक आता स्वीकारू शकतो.',
                            ),
                          );
                        },
                  icon: Icons.price_change_outlined,
                ),
                actionButton(
                  ct(
                    'Reject proposal',
                    'प्रस्ताव अस्वीकारें',
                    'प्रस्ताव नाकारा',
                  ),
                  _busy
                      ? null
                      : () async {
                          final ok = await confirmAction(
                            context,
                            _t(
                              'Reject this proposal? The collector lot is released immediately.',
                              'इस प्रस्ताव को अस्वीकार करें? कलेक्टर का लॉट तुरंत मुक्त होगा।',
                              'हा प्रस्ताव नाकारायचा? संकलकाचा लॉट लगेच मोकळा होईल.',
                            ),
                          );
                          if (ok != true) return;
                          _act(
                            () => _service.rejectOffer(
                              requestId: widget.requestId,
                              offerId: widget.offerId,
                            ),
                            _t(
                              'Rejected. The lot is released.',
                              'अस्वीकृत। लॉट मुक्त हुआ।',
                              'नाकारले. लॉट मोकळा झाला.',
                            ),
                          );
                        },
                  icon: Icons.thumb_down_outlined,
                ),
              ],
              if (status == 'accepted') ...[
                note(
                  _t(
                    'Collector accepted your quote. Review and confirm the pickup plan below.',
                    'कलेक्टर ने आपका भाव स्वीकारा। नीचे पिकअप योजना देखकर पुष्टि करें।',
                    'संकलकाने तुमचा दर स्वीकारला. खाली पिकअप योजना तपासून पुष्टी करा.',
                  ),
                ),
                PickupPlanPanel(source: ref, sourceData: v),
              ],
              if (status == 'handoverPending')
                actionButton(
                  ct(
                    'Confirm handover (material received)',
                    'हैंडओवर पुष्टि करें (माल मिला)',
                    'हस्तांतरण पुष्टी करा (माल मिळाला)',
                  ),
                  _busy
                      ? null
                      : () async {
                          final ok = await confirmAction(
                            context,
                            _t(
                              'Confirm only if the material is physically with you. This completes the deal and marks the lot handed over.',
                              'तभी पुष्टि करें जब माल वास्तव में आपके पास है। इससे सौदा पूरा होगा और लॉट सौंपा हुआ चिन्हित होगा।',
                              'फक्त माल प्रत्यक्ष तुमच्याकडे असल्यासच पुष्टी करा. याने सौदा पूर्ण होईल व लॉट हस्तांतरित चिन्हित होईल.',
                            ),
                          );
                          if (ok != true) return;
                          _act(
                            () => _service.confirmHandover(
                              requestId: widget.requestId,
                              offerId: widget.offerId,
                            ),
                            _t(
                              'Handover confirmed. Deal complete.',
                              'हैंडओवर पुष्ट। सौदा पूरा।',
                              'हस्तांतरण पुष्ट. सौदा पूर्ण.',
                            ),
                          );
                        },
                  icon: Icons.fact_check_outlined,
                ),
              if (v['schemaVersion'] == 2)
                actionButton(
                  ct('Open conversation', 'बातचीत खोलें', 'चर्चा उघडा'),
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OfferChatScreen(offer: ref),
                    ),
                  ),
                  icon: Icons.chat_bubble_outline,
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_message != null) note(_message!),
            ],
          );
        },
      ),
    );
  }
}
