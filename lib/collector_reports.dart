import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_speech.dart';
import 'collector_ui.dart';

/// Sprint3 — Collector report about the recycler linked to one offer.
///
/// Rules contract (chatReports/{rptid}):
/// - doc id MUST be '<collectorUid>_<offerId>' (one report per offer);
/// - targetUid must equal the linked offer's recyclerUid (proved via get());
/// - immutable after creation — only the trusted admin reviews and resolves
///   ('resolved'/'dismissed') from the Console. The client can never edit or
///   delete a report, and reporting never auto-blocks anyone.
class ReportRecyclerScreen extends StatefulWidget {
  const ReportRecyclerScreen({required this.offerRef, super.key});

  final DocumentReference<Map<String, dynamic>> offerRef;

  @override
  State<ReportRecyclerScreen> createState() => _ReportRecyclerState();
}

class _ReportRecyclerState extends State<ReportRecyclerScreen> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _reportRef(String uid) =>
      FirebaseFirestore.instance
          .collection('chatReports')
          .doc('${uid}_${widget.offerRef.id}');

  Future<void> _submit(String uid, Map<String, dynamic> offer) async {
    if (_busy) return;
    final reason = _reason.text.trim();
    if (reason.length < 5 || reason.length > 500) {
      setState(
        () => _message = ct(
          'Write the problem in at least 5 characters (up to 500).',
          'समस्या कम से कम 5 अक्षरों में लिखें (500 तक)।',
          'समस्या किमान 5 अक्षरांत लिहा (500 पर्यंत).',
        ),
      );
      return;
    }
    if (!await confirmAction(
          context,
          ct(
            'Send this report to the admin? It cannot be edited or deleted later. Reporting does not block the recycler by itself.',
            'यह शिकायत एडमिन को भेजें? बाद में बदली या मिटाई नहीं जा सकती। रिपोर्ट भेजने से रीसाइकलर अपने आप ब्लॉक नहीं होता।',
            'ही तक्रार प्रशासकाला पाठवावी? नंतर बदलता वा खोडता येत नाही. तक्रारीमुळे रिसायकलर आपोआप ब्लॉक होत नाही.',
          ),
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await FirebaseFirestore.instance
          .runTransaction((t) async {
            final offerSnap = await t.get(widget.offerRef);
            final ov = offerSnap.data();
            if (ov == null) throw StateError('offer-missing');
            final existing = await t.get(_reportRef(uid));
            if (existing.exists) throw StateError('already-reported');
            t.set(_reportRef(uid), {
              'schemaVersion': 1,
              'reporterUid': uid,
              'targetUid': '${ov['recyclerUid'] ?? offer['recyclerUid'] ?? ''}',
              'requestId': '${ov['requestId'] ?? offer['requestId'] ?? ''}',
              'offerId': widget.offerRef.id,
              'reason': reason,
              'status': 'open',
              'createdAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _message = ct(
          'Report sent to admin. Status will show here after review.',
          'शिकायत एडमिन को भेज दी गई। समीक्षा के बाद स्थिति यहाँ दिखेगी।',
          'तक्रार प्रशासकाला पाठवली. तपासणीनंतर स्थिती इथे दिसेल.',
        );
        _reason.clear();
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(
        () => _message = e.message == 'already-reported'
            ? ct(
                'A report for this offer already exists. One report per offer.',
                'इस ऑफ़र की शिकायत पहले से मौजूद है। एक ऑफ़र पर एक ही शिकायत।',
                'या ऑफरची तक्रार आधीच आहे. एका ऑफरवर एकच तक्रार.',
              )
            : ct(
                'Offer changed or unavailable. Reopen and try again.',
                'ऑफ़र बदल गई या उपलब्ध नहीं। दोबारा खोलकर कोशिश करें।',
                'ऑफर बदलली वा उपलब्ध नाही. पुन्हा उघडून प्रयत्न करा.',
              ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () => _message = ct(
          'Timed out. Check whether the report appears below before retrying — do not send duplicates.',
          'समय समाप्त। दोबारा भेजने से पहले जाँचें कि शिकायत नीचे दिख रही है या नहीं — डुप्लिकेट न भेजें।',
          'वेळ संपली. पुन्हा पाठवण्यापूर्वी तक्रार खाली दिसतेय का ते पहा — डुप्लिकेट पाठवू नका.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = ct(
          'Not sent. Check connection and updated rules, then retry.',
          'नहीं भेजी गई। कनेक्शन और नए नियम जाँचकर फिर कोशिश करें।',
          'पाठवता आले नाही. कनेक्शन व नवीन नियम तपासून पुन्हा प्रयत्न करा.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return CollectorPage(
      title: () =>
          ct('Report to admin', 'एडमिन को शिकायत', 'प्रशासकाला तक्रार'),
      guide: () => ct(
        'Report fake behaviour, refusal after quote, wrong weights or threats. Only the trusted admin reviews reports and decides action.',
        'झूठा व्यवहार, भाव देकर मुकरना, गलत वज़न या धमकी की शिकायत करें। शिकायतें केवल विश्वसनीय एडमिन देखता है और निर्णय लेता है।',
        'खोटे वर्तन, दर देऊन नकार, चुकीचे वजन वा धमकीची तक्रार करा. तक्रारी फक्त विश्वासू प्रशासक तपासतो व निर्णय घेतो.',
      ),
      body: (context) {
        if (uid == null) {
          return note(
            ct('Sign in first.', 'पहले साइन इन करें।', 'आधी साइन इन करा.'),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.offerRef.snapshots(includeMetadataChanges: true),
          builder: (context, s) {
            if (s.hasError) {
              return note(
                ct(
                  'Offer unavailable. Check access and connection.',
                  'ऑफ़र उपलब्ध नहीं। पहुँच और कनेक्शन जाँचें।',
                  'ऑफर उपलब्ध नाही. प्रवेश व कनेक्शन तपासा.',
                ),
              );
            }
            if (!s.hasData) return const LinearProgressIndicator();
            final v = s.data!.data();
            if (v == null) {
              return note(
                ct('Offer not found.', 'ऑफ़र नहीं मिला।', 'ऑफर सापडला नाही.'),
              );
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _reportRef(uid).snapshots(includeMetadataChanges: true),
              builder: (context, rs) {
                final existing = rs.hasData ? rs.data!.data() : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          '${ct('Linked recycler', 'जुड़ा रीसाइकलर', 'जोडलेला रिसायकलर')}: ${v['recyclerName'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (existing != null)
                      _statusCard('${existing['status'] ?? ''}')
                    else ...[
                      TextField(
                        controller: _reason,
                        enabled: !_busy,
                        maxLength: 500,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: ct(
                            'What happened? (5-500 characters)',
                            'क्या हुआ? (5-500 अक्षर)',
                            'काय झाले? (5-500 अक्षरे)',
                          ),
                        ),
                      ),
                      actionButton(
                        _busy
                            ? ct('Sending…', 'भेज रहे हैं…', 'पाठवत आहे…')
                            : ct(
                                'Send report to admin',
                                'एडमिन को शिकायत भेजें',
                                'प्रशासकाला तक्रार पाठवा',
                              ),
                        _busy ? null : () => _submit(uid, v),
                        icon: Icons.flag_outlined,
                      ),
                    ],
                    if (_message != null) SpokenNotice(text: _message!),
                    note(
                      ct(
                        'Reports are stored as-is and cannot be edited or deleted by you. Admin resolves them honestly; this app never fabricates review outcomes.',
                        'शिकायतें जैसी हैं वैसी संग्रहित होती हैं और आप इन्हें बदल या मिटा नहीं सकते। एडमिन ईमानदारी से निपटारा करता है; यह ऐप समीक्षा परिणाम कभी गढ़ता नहीं।',
                        'तक्रारी जशाच्या तशा साठवल्या जातात व तुम्ही त्या बदलू वा खोडू शकत नाही. प्रशासक प्रामाणिकपणे निर्णय देतो; हे अ‍ॅप निकाल कधीही घडवत नाही.',
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statusCard(String status) {
    late final Color color;
    late final String title;
    switch (status) {
      case 'open':
        color = const Color(0xFFB26A00);
        title = ct(
          'Report with admin — review pending',
          'शिकायत एडमिन के पास — समीक्षा बाकी',
          'तक्रार प्रशासकाकडे — तपासणी बाकी',
        );
      case 'resolved':
        color = const Color(0xFF286B3B);
        title = ct(
          'Admin resolved this report',
          'एडमिन ने इस शिकायत का निपटारा किया',
          'प्रशासकाने ही तक्रार निकाली काढली',
        );
      case 'dismissed':
        color = const Color(0xFF8A9188);
        title = ct(
          'Admin dismissed this report',
          'एडमिन ने यह शिकायत खारिज की',
          'प्रशासकाने ही तक्रार फेटाळली',
        );
      default:
        color = const Color(0xFFB26A00);
        title = ct(
          'Report status: $status',
          'शिकायत स्थिति: $status',
          'तक्रार स्थिती: $status',
        );
    }
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.flag_circle_outlined, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
