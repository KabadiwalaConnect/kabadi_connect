import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_speech.dart';
import 'collector_ui.dart';
import 'material_photos.dart';

/// Sprint4 — Admin-published indicative price board + honest estimate helper.
///
/// - Prices live in priceBoard/{material}_{city} and are written ONLY by the
///   trusted admin from the Firebase Console (Rules: client write = false).
/// - The estimate helper multiplies the admin rate by the entered weight and
///   is clearly labelled as an estimate — final price is always decided in
///   the quote/handover flow, never assumed.
/// - If no rate is published for a material/city, this screen says so
///   honestly instead of inventing a number.
class PriceBoardScreen extends StatefulWidget {
  const PriceBoardScreen({super.key});

  @override
  State<PriceBoardScreen> createState() => _PriceBoardState();
}

class _PriceBoardState extends State<PriceBoardScreen> {
  static const _green = Color(0xFF286B3B);
  static const _ink = Color(0xFF1E2B22);

  // Same lists the Firestore rules enforce (material()/city()).
  static const _materials = [
    'Copper',
    'Aluminium',
    'Iron',
    'PCB',
    'Battery',
    'CRT',
    'LCD',
    'Cable',
    'Motor',
  ];
  static const _cities = [
    'Amritsar',
    'Jalandhar',
    'Ludhiana',
    'Mumbai',
    'Pune',
  ];

  String? _material = 'Copper';
  String? _city = 'Ludhiana';
  final _weight = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Map<String, num> _rateLookup(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final m = <String, num>{};
    for (final d in docs) {
      final v = d.data();
      final mat = '${v['material'] ?? ''}';
      final city = '${v['city'] ?? ''}';
      final rate = v['ratePerKg'];
      if (mat.isNotEmpty && city.isNotEmpty && rate is num) {
        m['$mat|$city'] = rate;
      }
    }
    return m;
  }

  void _speakEstimate(num rate, num kg, num total) {
    AppSpeech.instance.say(
      ct(
        'Estimate for $kg kilograms: $total rupees. Rate $rate rupees per kilogram. Final price is decided by the recycler at quote.',
        '$kg किलो का अनुमान: $total रुपये। भाव $rate रुपये प्रति किलो। अंतिम भाव रीसाइकलर तय करेगा।',
        '$kg किलोचा अंदाज: $total रुपये. दर $rate रुपये प्रती किलो. अंतिम दर रिसायकलर ठरवेल.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CollectorPage(
      title: () => ct('Price board', 'भाव बोर्ड', 'भाव फलक'),
      guide: () => ct(
        'Indicative rates published by the admin. These help you judge an offer; the final price is always the recycler quote you accept.',
        'एडमिन द्वारा प्रकाशित सांकेतिक भाव। इनसे ऑफ़र परखने में मदद मिलती है; अंतिम भाव वही है जो रीसाइकलर दे और आप स्वीकार करें।',
        'प्रशासकाने प्रकाशित केलेले सूचक दर. यामुळे ऑफरचा अंदाज येतो; अंतिम दर रिसायकलरचा मान्य केलेला कोटच असतो.',
      ),
      body: (context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('priceBoard')
            .limit(100)
            .snapshots(includeMetadataChanges: true),
        builder: (context, s) {
          if (s.hasError) {
            return note(
              ct(
                'Price board unavailable. Check connection and rules.',
                'भाव बोर्ड उपलब्ध नहीं। कनेक्शन और नियम जाँचें।',
                'भाव फलक उपलब्ध नाही. कनेक्शन व नियम तपासा.',
              ),
            );
          }
          if (!s.hasData) return const LinearProgressIndicator();
          final docs = s.data!.docs;
          final rates = _rateLookup(docs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (docs.isEmpty)
                note(
                  ct(
                    'Admin has not published any rates yet. Rates appear here as soon as they are published.',
                    'एडमिन ने अभी कोई भाव प्रकाशित नहीं किया। प्रकाशित होते ही यहाँ दिखेंगे।',
                    'प्रशासकाने अद्याप दर प्रकाशित केलेले नाहीत. प्रकाशित होताच इथे दिसतील.',
                  ),
                )
              else ...[
                section(ct('Published rates', 'प्रकाशित भाव', 'प्रकाशित दर')),
                ..._materials
                    .where(
                      (m) => _cities.any((c) => rates.containsKey('$m|$c')),
                    )
                    .map((m) {
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
                                    ..._cities
                                        .where(
                                          (c) => rates.containsKey('$m|$c'),
                                        )
                                        .map(
                                          (c) => Text(
                                            '$c: ₹${rates['$m|$c']}/kg',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _green,
                                            ),
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
              ],
              const SizedBox(height: 14),
              section(ct('Estimate helper', 'अनुमान सहायक', 'अंदाज सहाय्यक')),
              DropdownButtonFormField<String>(
                value: _material,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: ct('Material', 'सामग्री', 'साहित्य'),
                ),
                items: _materials
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(materialLabel(m)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _material = v),
              ),
              DropdownButtonFormField<String>(
                value: _city,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: ct('City', 'शहर', 'शहर'),
                ),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _city = v),
              ),
              TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: ct(
                    'Approximate weight (kg)',
                    'अनुमानित वज़न (किग्रा)',
                    'अंदाजे वजन (किलो)',
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final rate = rates['$_material|$_city'];
                  final kg = num.tryParse(_weight.text.trim());
                  if (rate == null) {
                    return note(
                      ct(
                        'No published rate for this material in this city yet. Ask admin to publish it, or rely on recycler quotes.',
                        'इस शहर में इस सामग्री का भाव अभी प्रकाशित नहीं। एडमिन से प्रकाशित करने को कहें, या रीसाइकलर के भाव पर भरोसा करें।',
                        'या शहरात या साहित्याचा दर अद्याप प्रकाशित नाही. प्रशासकाला प्रकाशित करण्यास सांगा, किंवा रिसायकलरच्या कोटवर अवलंबून राहा.',
                      ),
                    );
                  }
                  if (kg == null || kg <= 0 || kg > 100000) {
                    return note(
                      ct(
                        'Enter an approximate weight to see the estimate.',
                        'अनुमान देखने के लिए वज़न भरें।',
                        'अंदाज पाहण्यासाठी वजन भरा.',
                      ),
                    );
                  }
                  final total = rate * kg;
                  return Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${ct('Estimate', 'अनुमान', 'अंदाज')}: ₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _green,
                            ),
                          ),
                          Text(
                            '${ct('Rate', 'भाव', 'दर')}: ₹$rate/kg × $kg kg',
                            style: const TextStyle(fontSize: 13, color: _ink),
                          ),
                          note(
                            ct(
                              'Indicative estimate only — not an offer or payment promise. Final value uses the recycler quote and confirmed handover weight.',
                              'केवल सांकेतिक अनुमान — न ऑफ़र, न भुगतान का वादा। अंतिम मूल्य रीसाइकलर भाव और पुष्टि हैंडओवर वज़न से तय होता है।',
                              'फक्त सूचक अंदाज — ऑफर किंवा देय वचन नाही. अंतिम मूल्य रिसायकलर कोट व निश्चित हस्तांतरण वजनावर ठरते.',
                            ),
                          ),
                          actionButton(
                            ct(
                              'Speak this estimate',
                              'यह अनुमान बोलकर सुनाएँ',
                              'हा अंदाज बोलून दाखवा',
                            ),
                            () => _speakEstimate(
                              rate,
                              kg,
                              num.parse(total.toStringAsFixed(2)),
                            ),
                            icon: Icons.volume_up_outlined,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
