import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_speech.dart';
import 'collector_ui.dart';

/// Sprint3 — Recycler account + honest authorization status.
///
/// Trust model:
/// - Approval / rejection / revocation is a TRUSTED-ADMIN action (Firebase
///   Console for now; in-app admin workflow comes later). No client can ever
///   write 'verified'.
/// - The only client write allowed from this screen is honest re-application:
///   own recycler doc 'rejected'/'revoked' -> 'pending'. The Rules permit
///   exactly that one transition (plus normal profile edits) and nothing else.
/// - This screen never claims approval that did not happen and shows the raw
///   stored status if it is something unexpected.
class RecyclerAccountScreen extends StatefulWidget {
  const RecyclerAccountScreen({super.key});

  @override
  State<RecyclerAccountScreen> createState() => _RecyclerAccountState();
}

class _RecyclerAccountState extends State<RecyclerAccountScreen> {
  static const _green = Color(0xFF286B3B);
  static const _cream = Color(0xFFFFFAEF);
  static const _ink = Color(0xFF1E2B22);
  static const _amber = Color(0xFFB26A00);
  static const _red = Color(0xFFB3261E);

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  bool _busy = false;
  String? _message;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> _resubmit(String uid) async {
    if (_busy) return;
    final ok = await confirmAction(
      context,
      _t(
        'Send your recycler application to admin review again? This does not approve it by itself.',
        'अपना रीसाइकलर आवेदन दोबारा एडमिन समीक्षा के लिए भेजें? इससे अपने आप स्वीकृति नहीं मिलती।',
        'तुमचा रिसायकलर अर्ज पुन्हा प्रशासक तपासणीसाठी पाठवावा? यामुळे आपोआप मंजुरी मिळत नाही.',
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String out;
    try {
      await FirebaseFirestore.instance
          .runTransaction((t) async {
            final s = await t.get(_userRef(uid));
            final st = '${s.data()?['authorizationStatus'] ?? ''}';
            if (st != 'rejected' && st != 'revoked') {
              throw StateError('state-changed');
            }
            t.update(_userRef(uid), {
              'authorizationStatus': 'pending',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 25));
      out = _t(
        'Application sent for review again. You will see the honest status here.',
        'आवेदन दोबारा समीक्षा के लिए भेज दिया। स्थिति यहाँ साफ़ दिखेगी।',
        'अर्ज पुन्हा तपासणीसाठी पाठवला. स्थिती इथे स्पष्ट दिसेल.',
      );
    } on StateError {
      out = _t(
        'Status changed meanwhile. Close and reopen to see the latest status.',
        'इस बीच स्थिति बदल गई। बंद करके दोबारा खोलें और नई स्थिति देखें।',
        'दरम्यान स्थिती बदलली. बंद करून पुन्हा उघडा आणि नवीन स्थिती पहा.',
      );
    } on TimeoutException {
      out = _t(
        'Timed out. Nothing was changed. Check your connection and try again.',
        'समय समाप्त। कुछ नहीं बदला। कनेक्शन जाँचकर दोबारा कोशिश करें।',
        'वेळ संपली. काहीही बदलले नाही. कनेक्शन तपासून पुन्हा प्रयत्न करा.',
      );
    } catch (_) {
      out = _t(
        'Could not resubmit. Check connection and updated rules.',
        'दोबारा नहीं भेज सके। कनेक्शन और नए नियम जाँचें।',
        'पुन्हा पाठवता आले नाही. कनेक्शन व नवीन नियम तपासा.',
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = out;
    });
    AppSpeech.instance.say(out);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: Text(_t('My account', 'मेरा खाता', 'माझे खाते')),
        actions: const [SpeechFeedbackButton()],
      ),
      body: uid == null
          ? Center(
              child: Text(
                _t(
                  'Please sign in first.',
                  'पहले साइन इन करें।',
                  'आधी साइन इन करा.',
                ),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userRef(uid).snapshots(includeMetadataChanges: true),
              builder: (context, s) {
                if (s.hasError) {
                  return note(
                    _t(
                      'Account details unavailable. Check connection and rules.',
                      'खाता विवरण उपलब्ध नहीं। कनेक्शन और नियम जाँचें।',
                      'खाते तपशील उपलब्ध नाही. कनेक्शन व नियम तपासा.',
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = s.data!.data();
                if (d == null) {
                  return note(
                    _t(
                      'Profile not found for this account.',
                      'इस खाते की प्रोफ़ाइल नहीं मिली।',
                      'या खात्याची प्रोफाइल सापडली नाही.',
                    ),
                  );
                }
                final status = '${d['authorizationStatus'] ?? ''}';
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _profileCard(d),
                    const SizedBox(height: 14),
                    _authCard(status),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      note(_message!),
                    ],
                    const SizedBox(height: 14),
                    note(
                      _t(
                        'Approval is done only by a trusted admin after checking your details. This app never auto-approves recyclers.',
                        'स्वीकृति केवल विश्वसनीय एडमिन विवरण जाँचकर देता है। यह ऐप रीसाइकलर को कभी स्वतः स्वीकृत नहीं करता।',
                        'मंजुरी फक्त विश्वासू प्रशासक तपशील तपासून देतो. हे अ‍ॅप रिसायकलरना कधीही आपोआप मंजूर करत नाही.',
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _profileCard(Map<String, dynamic> d) {
    final role = '${d['role'] ?? ''}';
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Profile', 'प्रोफ़ाइल', 'प्रोफाइल'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${d['name'] ?? ''}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            if ('${d['mobile'] ?? ''}'.isNotEmpty)
              Text(
                '${d['mobile'] ?? ''}',
                style: const TextStyle(fontSize: 13, color: _ink),
              ),
            Text(
              role == 'recycler'
                  ? _t('Recycler account', 'रीसाइकलर खाता', 'रिसायकलर खाते')
                  : _t('Collector account', 'कलेक्टर खाता', 'संकलक खाते'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authCard(String status) {
    late final Color color;
    late final String title;
    late final String body;
    switch (status) {
      case 'verified':
        color = _green;
        title = _t('Approved recycler', 'स्वीकृत रीसाइकलर', 'मंजूर रिसायकलर');
        body = _t(
          'Admin has approved your account. You can create buying demands, quote collector offers and confirm pickups.',
          'एडमिन ने आपका खाता स्वीकृत कर दिया है। आप खरीद माँग बना सकते हैं, कलेक्टर ऑफ़र पर भाव दे सकते हैं और पिकअप पक्का कर सकते हैं।',
          'प्रशासकाने तुमचे खाते मंजूर केले आहे. तुम्ही खरेदी मागणी करू शकता, संकलक ऑफरना दर देऊ शकता व पिकअप निश्चित करू शकता.',
        );
      case 'pending':
        color = _amber;
        title = _t(
          'Waiting for admin review',
          'एडमिन समीक्षा बाकी',
          'प्रशासक तपासणी बाकी',
        );
        body = _t(
          'Your details are with the admin. Demands and quoting unlock as soon as the account is approved.',
          'आपका विवरण एडमिन के पास है। खाता स्वीकृत होते ही माँग और भाव खुल जाएँगे।',
          'तुमचा तपशील प्रशासकाकडे आहे. खाते मंजूर होताच मागणी व दर सुरू होतील.',
        );
      case 'rejected':
        color = _red;
        title = _t('Not approved', 'स्वीकृत नहीं', 'मंजूर नाही');
        body = _t(
          'Admin has not approved this account. You can submit your application again for review.',
          'एडमिन ने यह खाता स्वीकृत नहीं किया। आप समीक्षा के लिए दोबारा आवेदन भेज सकते हैं।',
          'प्रशासकाने हे खाते मंजूर केले नाही. तुम्ही पुन्हा तपासणीसाठी अर्ज पाठवू शकता.',
        );
      case 'revoked':
        color = _red;
        title = _t(
          'Approval withdrawn',
          'स्वीकृति वापस ली गई',
          'मंजुरी मागे घेतली',
        );
        body = _t(
          'Admin has withdrawn the earlier approval. You can submit your application again for review.',
          'एडमिन ने पिछली स्वीकृति वापस ले ली है। आप दोबारा आवेदन भेज सकते हैं।',
          'प्रशासकाने आधीची मंजुरी मागे घेतली आहे. तुम्ही पुन्हा अर्ज पाठवू शकता.',
        );
      default:
        color = _amber;
        title = _t('Unknown status', 'अज्ञात स्थिति', 'अज्ञात स्थिती');
        body = _t(
          'Stored status: $status. Please check with the admin.',
          'संग्रहित स्थिति: $status. कृपया एडमिन से जाँच करें।',
          'साठवलेली स्थिती: $status. कृपया प्रशासकाकडे तपासा.',
        );
    }
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: color, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 14, color: _ink)),
            if (status == 'rejected' || status == 'revoked') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy
                    ? null
                    : () {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) _resubmit(uid);
                      },
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _t(
                    'Apply again for review',
                    'समीक्षा के लिए दोबारा आवेदन करें',
                    'तपासणीसाठी पुन्हा अर्ज करा',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
