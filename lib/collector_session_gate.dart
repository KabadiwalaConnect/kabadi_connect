import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'collector_ui.dart';
import 'collector_home_screen.dart';
import 'quick_registration_screen.dart';
import 'quick_profile_service.dart';

/// Wrap the EXISTING main.dart home widget, preserving welcome artwork/timing.
/// No new Auth account, signout, deletion or role conversion occurs here.
class CollectorSessionGate extends StatefulWidget {
  const CollectorSessionGate({required this.onboarding, super.key});
  final Widget onboarding;
  @override
  State<CollectorSessionGate> createState() => _SessionState();
}

class _SessionState extends State<CollectorSessionGate> {
  int _retry = 0;
  bool _onboardPushed = false;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, a) {
      if (a.hasError) {
        return _problem(
          ct(
            'Session unavailable. Retry without clearing app data.',
            'सेशन उपलब्ध नहीं। ऐप डेटा मिटाए बिना फिर कोशिश करें।',
            'सेशन उपलब्ध नाही. अॅप डेटा न पुसता पुन्हा प्रयत्न करा.',
          ),
        );
      }
      final u = a.data;
      // No Firebase session: show the phone + PIN login screen. The
      // original guest onboarding stays reachable from its secondary
      // button, and login never deletes users, lots, requests or quotes.
      if (u == null) {
        // Open EXACTLY like the original app: the existing welcome ->
        // language -> registration flow is pushed on top of the gate, so
        // the gate stays root and logout can always come back here.
        if (!_onboardPushed) {
          _onboardPushed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && FirebaseAuth.instance.currentUser == null) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => widget.onboarding),
              );
            }
          });
        }
        return _splash();
      }
      _onboardPushed = false;
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('${u.uid}:$_retry'),
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .snapshots(includeMetadataChanges: true),
        builder: (context, s) {
          if (s.hasError) {
            return _problem(
              ct(
                'Profile access not confirmed. Check internet, account and published rules. Do not create another account to bypass this.',
                'प्रोफ़ाइल पहुँच पुष्ट नहीं। इंटरनेट, खाता और नियम जाँचें। इसे पार करने के लिए दूसरा खाता न बनाएँ।',
                'प्रोफाइल प्रवेश पुष्ट नाही. इंटरनेट, खाते व नियम तपासा. हे टाळण्यासाठी दुसरे खाते बनवू नका.',
              ),
            );
          }
          if (!s.hasData) {
            return _problem(
              ct(
                'Checking the saved account. Internet is needed if no profile is cached.',
                'सहेजा खाता जाँचा जा रहा है। प्रोफ़ाइल कैश नहीं है तो इंटरनेट चाहिए।',
                'जतन खाते तपासत आहोत. प्रोफाइल कॅश नसल्यास इंटरनेट आवश्यक.',
              ),
              waiting: true,
            );
          }
          final v = s.data!.data();
          if (v == null) {
            if (s.data!.metadata.isFromCache) {
              return _problem(
                ct(
                  'No cached profile. Connect to confirm its server state.',
                  'प्रोफ़ाइल कैश नहीं है। सर्वर स्थिति जाँचने के लिए कनेक्ट करें।',
                  'प्रोफाइल कॅश नाही. सर्व्हर स्थिती तपासण्यासाठी कनेक्ट करा.',
                ),
              );
            }
            return CollectorPage(
              title: () => ct(
                'Complete profile',
                'प्रोफ़ाइल पूरी करें',
                'प्रोफाइल पूर्ण करा',
              ),
              body: (c) => Column(
                children: [
                  note(
                    ct(
                      'Signed-in account exists but its profile is missing. Continue onboarding using the SAME account, or ask the developer to review missing records.',
                      'साइन-इन खाता है पर प्रोफ़ाइल नहीं। इसी खाते से पंजीकरण जारी करें या डेवलपर से गायब रिकॉर्ड जाँचें।',
                      'साइन इन खाते आहे पण प्रोफाइल नाही. याच खात्याने नोंदणी पुढे करा किंवा विकासकाकडून हरवलेल्या नोंदी तपासा.',
                    ),
                  ),
                  actionButton(
                    ct(
                      'Continue onboarding',
                      'पंजीकरण जारी रखें',
                      'नोंदणी पुढे करा',
                    ),
                    () => Navigator.of(c).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => widget.onboarding,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('gate_sign_out'),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: Text(
                      ct(
                        'Sign out and use phone + PIN login',
                        'साइन आउट करें और फोन + PIN लॉगिन इस्तेमाल करें',
                        'साइन आउट करा आणि फोन + PIN लॉगिन वापरा',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (v['name'] is! String ||
              !['collector', 'recycler'].contains(v['role'])) {
            return _problem(
              ct(
                'Existing profile needs review. Its data will not be overwritten.',
                'मौजूदा प्रोफ़ाइल की समीक्षा चाहिए। डेटा बदला नहीं जाएगा।',
                'सध्याच्या प्रोफाइलची तपासणी आवश्यक. डेटा बदलला जाणार नाही.',
              ),
            );
          }
          if (v['role'] == 'collector') {
            return CollectorHomeScreen(key: ValueKey(u.uid));
          }
          return QuickProfileReadyScreen(
            result: QuickProfileResult(
              uid: u.uid,
              profile: v,
              isAnonymous: u.isAnonymous,
              created: false,
            ),
          );
        },
      );
    },
  );
  Widget _splash() => Scaffold(
    backgroundColor: const Color(0xFFFFFAEF),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Image.asset(
              'assets/images/collector_welcome.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              semanticLabel: 'Kabadiwalla Connect',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              key: const ValueKey('gate_continue'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => widget.onboarding),
              ),
              child: Text(
                ct('Continue', 'आगे बढ़ें', 'पुढे जा'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _problem(String message, {bool waiting = false}) => CollectorPage(
    title: () => ct('Account check', 'खाता जाँच', 'खाते तपासणी'),
    body: (context) => Column(
      children: [
        if (waiting) const LinearProgressIndicator(),
        note(message),
        actionButton(
          ct('Retry', 'फिर कोशिश करें', 'पुन्हा प्रयत्न करा'),
          () => setState(() => _retry++),
        ),
        TextButton(
          key: const ValueKey('gate_problem_sign_out'),
          onPressed: () => FirebaseAuth.instance.signOut(),
          child: Text(
            ct(
              'Sign out and use phone + PIN login',
              'साइन आउट करें और फोन + PIN लॉगिन इस्तेमाल करें',
              'साइन आउट करा आणि फोन + PIN लॉगिन वापरा',
            ),
          ),
        ),
      ],
    ),
  );
}
