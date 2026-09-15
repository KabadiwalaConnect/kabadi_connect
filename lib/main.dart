import 'collector_session_gate.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_language.dart';
import 'firebase_options.dart';
import 'language_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await appLanguage.load();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('KabadiConnect: Firebase initialized successfully.');

    runApp(const KabadiConnectApp());
  } catch (error) {
    debugPrint('KabadiConnect: Firebase initialization failed: $error');

    runApp(const FirebaseSetupErrorApp());
  }
}

class KabadiConnectApp extends StatelessWidget {
  const KabadiConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        return MaterialApp(
          title: 'Kabadiwalla Connect',
          debugShowCheckedModeBanner: false,
          locale: appLanguage.locale,
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFFFAEF),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E703D),
            ),
          ),
          home: CollectorSessionGate(onboarding: const WelcomeScreen()),
        );
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LanguageScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAEF),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/collector_welcome.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          semanticLabel: 'Kabadiwalla Connect',
        ),
      ),
    );
  }
}

// Setup diagnostic only; not a successful registration screen.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key});

  String get message {
    switch (appLanguage.code) {
      case 'hi':
        return 'Firebase शुरू नहीं हो पाया।\n'
            'कृपया टर्मिनल का error देखें और setup ठीक करें।';
      case 'mr':
        return 'Firebase सुरू करता आले नाही.\n'
            'टर्मिनलमधील error तपासा आणि setup दुरुस्त करा.';
      default:
        return 'Firebase could not initialize.\n'
            'Please check the terminal error and correct the setup.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFAEF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFF286B3B),
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
