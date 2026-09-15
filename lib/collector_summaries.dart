import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'collector_ui.dart';
import 'material_photos.dart';

/// Sprint4 — Honest collection & earnings summaries.
///
/// Collection tab: totals per material from the collector's OWN lots
/// (collected = every synced lot; still in hand = draft; sold = handedOver
/// or archived). Numbers come from stored weights only — nothing is guessed.
///
/// Earnings tab:
/// - Estimated value = sum of quoteRate x confirmed handoverWeightKg over
///   completed offers (the mutually confirmed deal value).
/// - Recorded payments = sum of collector-recorded receipts (their own
///   statement, never bank-verified).
/// - Pending dues = completed offers without a recorded receipt.
/// All figures apply to the loaded window (100 newest records per source)
/// and say so on screen.
class SummariesScreen extends StatefulWidget {
  const SummariesScreen({super.key});

  @override
  State<SummariesScreen> createState() => _SummariesState();
}

class _SummariesState extends State<SummariesScreen> {
  static const _green = Color(0xFF286B3B);
  static const _ink = Color(0xFF1E2B22);
  static const _amber = Color(0xFFB26A00);

  int _tab = 0;

  Future<Map<String, dynamic>> _loadEarnings(String uid) async {
    final db = FirebaseFirestore.instance;
    final offSnap = await db
        .collectionGroup('offers')
        .where('collectorUid', isEqualTo: uid)
        .limit(100)
        .get();
    final paySnap = await db
        .collection('collectorPayments')
        .where('collectorUid', isEqualTo: uid)
        .limit(100)
        .get();

    final paidOfferIds = <String>{
      for (final p in paySnap.docs) '${p.data()['offerId'] ?? ''}',
    };
    num estimated = 0;
    final dues = <Map<String, dynamic>>[];
    int completed = 0;
    for (final o in offSnap.docs) {
      final v = o.data();
      if ('${v['status']}' != 'completed') continue;
      completed++;
      final rate = v['quoteRate'];
      final w = v['handoverWeightKg'];
      final value = (rate is num && w is num) ? rate * w : null;
      if (value != null) estimated += value;
      if (!paidOfferIds.contains(o.id)) {
        dues.add({
          'id': o.id,
          'material': '${v['material'] ?? ''}',
          'weightKg': w ?? 0,
          'value': value,
          'recyclerName': '${v['recyclerName'] ?? ''}',
        });
      }
    }
    num recorded = 0;
    for (final p in paySnap.docs) {
      final a = p.data()['amount'];
      if (a is num) recorded += a;
    }
    return {
      'estimated': estimated,
      'recorded': recorded,
      'dues': dues,
      'completed': completed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return CollectorPage(
      title: () => ct('Summaries', 'सारांश', 'सारांश'),
      guide: () => ct(
        'Collection and money summaries from your own records only. Recorded payments are your statements, not bank verification.',
        'केवल आपके अपने रिकॉर्ड से संग्रह और पैसों का सारांश। दर्ज भुगतान आपके बयान हैं, बैंक सत्यापन नहीं।',
        'फक्त तुमच्या स्वतःच्या नोंदींवरून संकलन व पैशांचा सारांश. नोंदवलेले देयक तुमचे निवेदन आहे, बँक पडताळणी नाही.',
      ),
      body: (context) {
        if (uid == null) {
          return note(
            ct('Sign in first.', 'पहले साइन इन करें।', 'आधी साइन इन करा.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: actionButton(
                    ct('Collection', 'संग्रह', 'संकलन'),
                    () => setState(() => _tab = 0),
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: actionButton(
                    ct('Earnings', 'कमाई', 'कमाई'),
                    () => setState(() => _tab = 1),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            if (_tab == 0) _collection(uid) else _earnings(uid),
          ],
        );
      },
    );
  }

  Widget _collection(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .snapshots(includeMetadataChanges: true),
      builder: (context, s) {
        if (s.hasError) {
          return note(
            ct(
              'Lots unavailable. Check connection and rules.',
              'लॉट उपलब्ध नहीं। कनेक्शन और नियम जाँचें।',
              'लॉट उपलब्ध नाहीत. कनेक्शन व नियम तपासा.',
            ),
          );
        }
        if (!s.hasData) return const LinearProgressIndicator();
        final byMaterial = <String, Map<String, num>>{};
        num totalAll = 0, inHandAll = 0, soldAll = 0;
        for (final d in s.data!.docs) {
          final v = d.data();
          final m = '${v['material'] ?? ''}';
          final w = v['weightKg'];
          if (m.isEmpty || w is! num) continue;
          final st = '${v['status']}';
          final e = byMaterial.putIfAbsent(
            m,
            () => {'total': 0, 'inHand': 0, 'sold': 0},
          );
          e['total'] = e['total']! + w;
          totalAll += w;
          if (st == 'draft') {
            e['inHand'] = e['inHand']! + w;
            inHandAll += w;
          }
          if (st == 'handedOver' || st == 'archived') {
            e['sold'] = e['sold']! + w;
            soldAll += w;
          }
        }
        final materials = byMaterial.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _totalsCard(totalAll, inHandAll, soldAll),
            if (materials.isEmpty)
              note(
                ct(
                  'No synced lots yet. Create and sync a lot to see summaries.',
                  'अभी कोई सिंक लॉट नहीं। सारांश देखने के लिए लॉट बनाकर सिंक करें।',
                  'अद्याप सिंक लॉट नाही. सारांश पाहण्यासाठी लॉट तयार करून सिंक करा.',
                ),
              ),
            ...materials.map((m) {
              final e = byMaterial[m]!;
              return Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      MaterialPhoto(material: m),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              materialLabel(m),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            Text(
                              '${ct('Collected', 'संग्रहित', 'संकलित')}: ${e['total']} kg',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${ct('Still in hand', 'अभी हाथ में', 'अद्याप हाती')}: ${e['inHand']} kg',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _amber,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${ct('Sold (handover done)', 'बिका (हैंडओवर पूर्ण)', 'विकले (हस्तांतरण पूर्ण)')}: ${e['sold']} kg',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            note(
              ct(
                'Weights are the ones you entered at lot creation; sold weight counts lots whose handover completed. Not scale-certified figures.',
                'वज़न वही हैं जो आपने लॉट बनाते समय भरे; बिका वज़न पूर्ण हैंडओवर वाले लॉट गिनता है। तराज़ू-प्रमाणित आँकड़े नहीं।',
                'वजन तेच आहे जे तुम्ही लॉट तयार करताना भरले; विक्री वजन पूर्ण हस्तांतरणाच्या लॉटचे. प्रमाणित आकडे नाहीत.',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _totalsCard(num total, num inHand, num sold) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _stat(
                ct('Collected', 'संग्रहित', 'संकलित'),
                '$total kg',
                _ink,
              ),
            ),
            Expanded(
              child: _stat(
                ct('In hand', 'हाथ में', 'हाती'),
                '$inHand kg',
                _amber,
              ),
            ),
            Expanded(
              child: _stat(ct('Sold', 'बिका', 'विकले'), '$sold kg', _green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _earnings(String uid) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadEarnings(uid),
      builder: (context, s) {
        if (s.hasError) {
          return note(
            ct(
              'Earnings unavailable. Check connection and rules.',
              'कमाई विवरण उपलब्ध नहीं। कनेक्शन और नियम जाँचें।',
              'कमाई तपशील उपलब्ध नाही. कनेक्शन व नियम तपासा.',
            ),
          );
        }
        if (!s.hasData) return const LinearProgressIndicator();
        final d = s.data!;
        final dues = d['dues'] as List;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _stat(
                            ct(
                              'Estimated value',
                              'अनुमानित मूल्य',
                              'अंदाजे मूल्य',
                            ),
                            '₹${(d['estimated'] as num).toStringAsFixed(2)}',
                            _ink,
                          ),
                        ),
                        Expanded(
                          child: _stat(
                            ct('Recorded', 'दर्ज', 'नोंदवलेले'),
                            '₹${(d['recorded'] as num).toStringAsFixed(2)}',
                            _green,
                          ),
                        ),
                        Expanded(
                          child: _stat(
                            ct('Completed', 'पूर्ण', 'पूर्ण'),
                            '${d['completed']}',
                            _ink,
                          ),
                        ),
                      ],
                    ),
                    note(
                      ct(
                        'Estimated value = agreed rate x confirmed handover weight of completed deals. Recorded = your own receipt entries, not bank verified. Loaded window: 100 newest records each.',
                        'अनुमानित मूल्य = तय भाव × पुष्टि हैंडओवर वज़न (पूर्ण सौदों का)। दर्ज = आपकी अपनी रसीदें, बैंक सत्यापित नहीं। लोड सूची: हर स्रोत की 100 नवीनतम प्रविष्टियाँ।',
                        'अंदाजे मूल्य = मान्य दर × निश्चित हस्तांतरण वजन (पूर्ण व्यवहारांचे). नोंद = तुमच्या स्वतःच्या पावत्या, बँक पडताळलेल्या नाहीत. लोड यादी: प्रत्येक स्रोताच्या 100 नवीन नोंदी.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            section(
              ct(
                'Pending dues (no receipt recorded)',
                'बकाया (रसीद दर्ज नहीं)',
                'थकबाकी (पावती नोंद नाही)',
              ),
            ),
            if (dues.isEmpty)
              note(
                ct(
                  'No pending dues in the loaded window. Record receipts for completed deals to keep this accurate.',
                  'लोड सूची में कोई बकाया नहीं। सटीक रखने के लिए पूर्ण सौदों की रसीद दर्ज करें।',
                  'लोड यादीत थकबाकी नाही. अचूकतेसाठी पूर्ण व्यवहारांच्या पावत्या नोंदवा.',
                ),
              )
            else
              ...dues.map(
                (x) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: MaterialPhoto(material: '${x['material']}'),
                    title: Text(
                      '${materialLabel('${x['material']}')} • ${x['weightKg']} kg',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${x['recyclerName']}\n${ct('Estimated', 'अनुमानित', 'अंदाजे')}: ${x['value'] == null ? '—' : '₹${(x['value'] as num).toStringAsFixed(2)}'}',
                    ),
                  ),
                ),
              ),
            note(
              ct(
                'A due means you completed the handover but did not record receiving money. Record it only when you actually received it.',
                'बकाया का अर्थ: हैंडओवर पूरा हुआ पर पैसा मिलना दर्ज नहीं किया। केवल वास्तव में मिलने पर ही दर्ज करें।',
                'थकबाकी म्हणजे हस्तांतरण पूर्ण परंतु पैसे मिळाल्याची नोंद नाही. प्रत्यक्ष मिळाल्यावरच नोंदवा.',
              ),
            ),
          ],
        );
      },
    );
  }
}
