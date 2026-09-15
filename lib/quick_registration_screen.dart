import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_speech.dart';
import 'collector_home_screen.dart';
import 'quick_profile_service.dart';
import 'quick_registration_text.dart';
import 'collector_pages.dart' show RecoveryLoginScreen;
import 'collector_ui.dart' show confirmAction, ct;
import 'recycler_direct_sell.dart';

const _cream = Color(0xFFFFFAEF);
const _green = Color(0xFF286B3B);

class QuickRegistrationScreen extends StatefulWidget {
  const QuickRegistrationScreen({required this.role, this.service, super.key})
    : assert(role == 'collector' || role == 'recycler');
  final String role;
  final QuickProfileService? service;

  @override
  State<QuickRegistrationScreen> createState() =>
      _QuickRegistrationScreenState();
}

class _QuickRegistrationScreenState extends State<QuickRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  late String _role;
  bool _loginMode = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
  }

  bool _slow = false;
  bool _done = false;
  String? _error;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _name.dispose();
    _mobile.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  String _describe(Object error) {
    if (error is TimeoutException) {
      return quickText('network');
    }
    if (error is FirebaseException) {
      debugPrint('KC_QUICK error code: ${error.code}');
      final String key;
      switch (error.code) {
        case 'user-not-found':
        case 'user-disabled':
        case 'user-token-expired':
        case 'invalid-user-token':
          key = 'sessionInvalid';
          break;
        case 'operation-not-allowed':
        case 'admin-restricted-operation':
          key = 'disabled';
          break;
        case 'permission-denied':
          key = 'denied';
          break;
        case 'network-request-failed':
        case 'unavailable':
        case 'deadline-exceeded':
          key = 'network';
          break;
        case 'too-many-requests':
        case 'quota-exceeded':
          key = 'limited';
          break;
        default:
          key = 'failed';
      }
      return '${quickText(key)}\n(${error.code})';
    }
    debugPrint('KC_QUICK error type: ${error.runtimeType}');
    return quickText('failed');
  }

  /// Sprint1: registration with phone + 6-digit PIN + role. Creates the
  /// Firebase email/password account and writes the users/{uid} profile so
  /// the same phone + PIN logs back in later on any phone. The gate stays
  /// as root, so logout always returns to the login screen.
  Future<void> _start() async {
    if (_busy || _done) {
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      AppSpeech.instance.say(quickText('invalidForm'));
      return;
    }
    final email = _emailForPhone(_mobile.text);
    final pin = _pin.text.trim();
    final pin2 = _pin2.text.trim();
    if (email == null) {
      final m = quickText('invalidMobile');
      setState(() => _error = m);
      AppSpeech.instance.say(m);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      final m = ct(
        'PIN must be exactly 6 digits.',
        'PIN ठीक 6 अंकों का होना चाहिए।',
        'PIN नेमका 6 अंकी असावा.',
      );
      setState(() => _error = m);
      AppSpeech.instance.say(m);
      return;
    }
    if (pin != pin2) {
      final m = ct(
        'Confirm PIN does not match the PIN.',
        'पुष्टि PIN मूल PIN से मेल नहीं खाती।',
        'पुष्टी PIN मूळ PIN शी जुळत नाही.',
      );
      setState(() => _error = m);
      AppSpeech.instance.say(m);
      return;
    }
    AppSpeech.instance.say(
      speechText(
        'Please wait while your account is created.',
        'खाता बनाया जा रहा है। कृपया प्रतीक्षा करें।',
        'खाते तयार होत आहे. कृपया थांबा.',
      ),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _slow = false;
      _error = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _busy) {
        setState(() => _slow = true);
        if (ModalRoute.of(context)?.isCurrent == true) {
          AppSpeech.instance.say(quickText('slow'));
        }
      }
    });
    try {
      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pin,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Same phone registered earlier: login with its PIN instead.
          try {
            cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: pin,
            );
          } on FirebaseAuthException {
            if (mounted) {
              setState(
                () => _error = ct(
                  'This phone is already registered and the PIN is wrong. Use the correct PIN, or login from the first screen.',
                  'यह फोन पहले से पंजीकृत है और PIN गलत है। सही PIN इस्तेमाल करें, या पहली स्क्रीन से लॉगिन करें।',
                  'हा फोन आधीच नोंदणीकृत आहे व PIN चुकीचा आहे. योग्य PIN वापरा, किंवा पहिल्या स्क्रीनवरून लॉगिन करा.',
                ),
              );
              AppSpeech.instance.say(_error!);
            }
            return;
          }
        } else {
          rethrow;
        }
      }
      final uid = cred.user?.uid;
      if (uid == null) {
        throw StateError('Account created but no session.');
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          'name': _name.text.trim(),
          'role': _role,
          'mobile': email.split('@').first,
          'language': appLanguage.code,
          'authProvider': 'phone-pin',
          if (_role == 'recycler') 'authorizationStatus': 'pending',
        },
        SetOptions(merge: true),
      );
      if (!mounted || _done) {
        return;
      }
      _done = true;
      // Gate stays root: it routes to the right home and logout can return
      // to the login screen later.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _describe(error));
        if (ModalRoute.of(context)?.isCurrent == true) {
          AppSpeech.instance.say(_error!.split('\n').first);
        }
      }
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _slow = false;
        });
      }
    }
  }

  Future<void> _startGuest() async {
    if (_busy || _done) {
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      AppSpeech.instance.say(quickText('invalidForm'));
      return;
    }
    AppSpeech.instance.say(
      speechText(
        'Please wait while your profile is checked.',
        'प्रोफ़ाइल जाँची जा रही है। कृपया प्रतीक्षा करें।',
        'प्रोफाइल तपासले जात आहे. कृपया थांबा.',
      ),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _slow = false;
      _error = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _busy) {
        setState(() => _slow = true);
        if (ModalRoute.of(context)?.isCurrent == true) {
          AppSpeech.instance.say(quickText('slow'));
        }
      }
    });
    try {
      await (widget.service ?? QuickProfileService())
          .continueWithName(
            name: _name.text,
            mobileNumber: _mobile.text,
            role: widget.role,
            language: appLanguage.code,
          )
          .timeout(const Duration(seconds: 45));
      // This timeout does not cancel Firebase calls. A retry uses any
      // currently signed-in account rather than intentionally replacing it.
      if (!mounted || _done) {
        return;
      }
      _done = true;
      // Keep the CollectorSessionGate as root so logout can return to the
      // login screen; the gate routes by role itself.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _describe(error));
        if (ModalRoute.of(context)?.isCurrent == true) {
          AppSpeech.instance.say(_error!.split('\n').first);
        }
      }
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _slow = false;
        });
      }
    }
  }

  Widget _header() {
    // Registration header: illustration and slogan only.
    // Brand logo/name/tagline intentionally removed from this screen.
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _SkylinePainter())),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 45,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/images/quick_collector.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Expanded(
                flex: 55,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 20),
                  child: Text(
                    quickText('slogan'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      height: 1.35,
                      color: _green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _languageCard(String code, String label, Color badgeColor) {
    final selected = appLanguage.code == code;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFE1EED5) : const Color(0xFFFFFCF5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected ? _green : const Color(0xFFDDDCCD),
            width: selected ? 1.8 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('quick_language_$code'),
          onTap: _busy
              ? null
              : () async {
                  appLanguage.select(code);
                  AppSpeech.instance.say(
                    speechText(
                      'English selected. Enter your name and mobile contact number, then tap Continue. No OTP is sent.',
                      'हिंदी चुनी गई। नाम और मोबाइल संपर्क नंबर लिखें, फिर आगे बढ़ें दबाएँ। OTP नहीं भेजा जाएगा।',
                      'मराठी निवडली. नाव आणि मोबाइल संपर्क क्रमांक लिहा, मग पुढे जा दाबा. OTP पाठवला जाणार नाही.',
                    ),
                  );
                  setState(() => _error = null);
                  try {
                    await appLanguage.save();
                  } catch (_) {
                    if (mounted) {
                      setState(() => _error = appLanguage.text('saveError'));
                    }
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: badgeColor,
                    child: code == 'en'
                        ? const Icon(
                            Icons.language,
                            size: 21,
                            color: Colors.white,
                          )
                        : const Text(
                            'अ',
                            style: TextStyle(
                              fontSize: 21,
                              color: Color(0xFF153A21),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 17,
                  color: selected ? _green : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languages() {
    return Material(
      color: const Color(0xFFF0F5E4),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              quickText('languageTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              quickText('languageQuestion'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF626655)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wideText =
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final cards = [
                  _languageCard('en', 'Eng', _green),
                  _languageCard('hi', 'हिंदी', const Color(0xFFFFD574)),
                  _languageCard('mr', 'मराठी', const Color(0xFFB8D699)),
                ];
                if (constraints.maxWidth < 300 || wideText) {
                  return Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: card,
                        ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 7),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 7),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 10-digit phone -> internal login email (Firebase Email/Password).
  static const String _kEmailDomain = 'login.kabadiconnect.app';
  static String? _emailForPhone(String rawPhone) {
    final normalized = QuickProfileService.normalizeContactMobile(rawPhone);
    if (normalized == null) return null;
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return null;
    final ten = digits.substring(digits.length - 10);
    return '$ten@$_kEmailDomain';
  }

  Future<void> _login() async {
    if (_busy || _done) {
      return;
    }
    final email = _emailForPhone(_mobile.text);
    final pin = _pin.text.trim();
    if (email == null) {
      final m = quickText('invalidMobile');
      setState(() => _error = m);
      AppSpeech.instance.say(m);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      final m = ct(
        'PIN must be exactly 6 digits.',
        'PIN ठीक 6 अंकों का होना चाहिए।',
        'PIN नेमका 6 अंकी असावा.',
      );
      setState(() => _error = m);
      AppSpeech.instance.say(m);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pin,
      );
      if (!mounted || _done) {
        return;
      }
      _done = true;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              (e.code == 'invalid-credential' ||
                  e.code == 'user-not-found' ||
                  e.code == 'wrong-password')
              ? ct(
                  'No account for this phone, or wrong PIN. New here? Use New registration.',
                  'इस फोन का कोई खाता नहीं, या PIN गलत। नए हैं? नया पंजीकरण इस्तेमाल करें।',
                  'या फोनचे खाते नाही, किंवा PIN चुकीचा. नवीन आहात? नवीन नोंदणी वापरा.',
                )
              : (e.code == 'operation-not-allowed' ||
                    e.code == 'admin-restricted-operation')
              ? ct(
                  'Email/Password sign-in is disabled in Firebase. Enable it once in Firebase Console -> Authentication -> Sign-in method.',
                  'Firebase में Email/Password बंद है। Firebase Console -> Authentication -> Sign-in method में एक बार चालू करें।',
                  'Firebase मध्ये Email/Password बंद आहे. Firebase Console -> Authentication -> Sign-in method मध्ये एकदा सुरू करा.',
                )
              : _describe(e),
        );
        AppSpeech.instance.say(_error!.split('\n').first);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _describe(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _modeChip(bool login, String label) {
    final active = _loginMode == login;
    return Expanded(
      child: Material(
        color: active ? _green : const Color(0xFFEEF4EC),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: Key(login ? 'quick_mode_login' : 'quick_mode_register'),
          borderRadius: BorderRadius.circular(13),
          onTap: _busy
              ? null
              : () => setState(() {
                  _loginMode = login;
                  _error = null;
                }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF2F4636),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String role, IconData icon, String title) {
    final active = _role == role;
    final color = role == 'recycler' ? const Color(0xFF1565C0) : _green;
    return Expanded(
      child: Material(
        color: active ? color : const Color(0xFFEEF4EC),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: Key('quick_role_$role'),
          borderRadius: BorderRadius.circular(13),
          onTap: _busy ? null : () => setState(() => _role = role),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: active ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : const Color(0xFF2F4636),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameForm() {
    return Material(
      color: const Color(0xFFFFFDF7),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.eco_rounded, color: _green, size: 30),
              Text(
                quickText('title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _green,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                quickText('subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64685A), fontSize: 15),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _modeChip(
                    false,
                    ct('New registration', 'नया पंजीकरण', 'नवीन नोंदणी'),
                  ),
                  const SizedBox(width: 8),
                  _modeChip(true, ct('Login', 'लॉगिन', 'लॉगिन')),
                ],
              ),
              const SizedBox(height: 24),
              if (!_loginMode) ...[
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: _green,
                      child: Text('1', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        quickText('name'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('quick_name'),
                  controller: _name,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: quickText('hint'),
                    prefixIcon: const Icon(Icons.person_outline, color: _green),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: Color(0xFFDCDCCE)),
                    ),
                  ),
                  validator: (value) {
                    final n = (value ?? '').trim().length;
                    return n < 2 || n > 100 ? quickText('invalidName') : null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: _green,
                    child: Text('2', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quickText('mobile'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('quick_mobile'),
                controller: _mobile,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _start(),
                maxLength: 20,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: quickText('mobile'),
                  helperText: quickText('mobileHint'),
                  helperMaxLines: 2,
                  errorMaxLines: 3,
                  prefixIcon: const Icon(Icons.phone_outlined, color: _green),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFFDCDCCE)),
                  ),
                ),
                validator: (value) =>
                    QuickProfileService.normalizeContactMobile(value ?? '') ==
                        null
                    ? quickText('invalidMobile')
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: _green,
                    child: Text('3', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ct(
                        'Create 6-digit PIN',
                        '6-अंकों का PIN बनाएं',
                        '6-अंकी PIN तयार करा',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('quick_pin'),
                controller: _pin,
                enabled: !_busy,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: ct('6-digit PIN', '6-अंकों का PIN', '6-अंकी PIN'),
                  prefixIcon: const Icon(Icons.lock_outline, color: _green),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFFDCDCCE)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_loginMode) ...[
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: _green,
                      child: Text('4', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ct(
                          'Confirm 6-digit PIN',
                          'PIN की पुष्टि करें',
                          'PIN ची पुष्टी करा',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('quick_pin2'),
                  controller: _pin2,
                  enabled: !_busy,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: ct(
                      'Confirm PIN',
                      'PIN की पुष्टि',
                      'PIN ची पुष्टी',
                    ),
                    prefixIcon: const Icon(Icons.lock_outline, color: _green),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: Color(0xFFDCDCCE)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!_loginMode) ...[
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: _green,
                      child: Text('5', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ct('Role', 'रोल', 'भूमिका'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _roleChip(
                      'collector',
                      Icons.recycling,
                      ct('Collector', 'संग्राहक', 'संकलक'),
                    ),
                    const SizedBox(width: 10),
                    _roleChip(
                      'recycler',
                      Icons.factory_outlined,
                      ct('Recycler', 'रीसाइक्लर', 'रिसायकलर'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text(
                quickText('mobileNotice'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                quickText('consent'),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF626655),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('quick_continue'),
                onPressed: _busy ? null : (_loginMode ? _login : _start),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _busy
                              ? quickText('working')
                              : _loginMode
                              ? ct('Login', 'लॉगिन', 'लॉगिन')
                              : quickText('start'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.arrow_forward_rounded, size: 28),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                key: const Key('quick_guest'),
                onPressed: _busy ? null : _startGuest,
                child: Text(
                  ct(
                    'Continue as guest without PIN (old flow)',
                    'PIN के बिना अतिथि जारी रखें (पुराना तरीका)',
                    'PIN शिवाय पाहुणे सुरू ठेवा (जुनी पद्धत)',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_slow)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(quickText('slow'), textAlign: TextAlign.center),
                ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF9C2929)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                quickText('online'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF626655)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0CB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  quickText('guestWarning'),
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : spokenAction(
                        () => speechText(
                          'Email recovery',
                          'ईमेल रिकवरी',
                          'ईमेल रिकव्हरी',
                        ),
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RecoveryLoginScreen(),
                          ),
                        ),
                      ),
                icon: const Icon(Icons.lock_reset),
                label: Text(
                  speechText(
                    'Recover linked email account',
                    'जुड़ा ईमेल खाता खोलें',
                    'जोडलेले ईमेल खाते उघडा',
                  ),
                ),
              ),
              Text(
                quickText('existingNote'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF626655)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _cream,
          appBar: AppBar(
            backgroundColor: _cream,
            leading: BackButton(
              onPressed: spokenAction(
                () => speechText('Back', 'वापस', 'मागे'),
                () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: const [SpeechFeedbackButton()],
            title: Text(quickText(widget.role)),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _header(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: VoiceGuide(
                          instruction: () => speechText(
                            'Enter your name and mobile contact number, then tap Continue. No OTP is sent. This number cannot recover your account. An existing signed-in account will be kept.',
                            'नाम और मोबाइल संपर्क नंबर लिखें। फिर आगे बढ़ें दबाएँ। OTP नहीं भेजा जाएगा। इस नंबर से खाता रिकवर नहीं होगा। पहले से साइन इन हैं तो मौजूदा खाता रखा जाएगा।',
                            'नाव आणि मोबाइल संपर्क क्रमांक लिहा. मग पुढे जा दाबा. OTP पाठवला जाणार नाही. या क्रमांकाने खाते रिकव्हर होणार नाही. आधीच साइन इन असल्यास सध्याचे खाते कायम राहील.',
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _languages(),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _nameForm(),
                      ),
                      const SizedBox(height: 12),
                      ExcludeSemantics(
                        child: Image.asset(
                          'assets/images/language_footer.png',
                          width: double.infinity,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class QuickProfileReadyScreen extends StatelessWidget {
  const QuickProfileReadyScreen({required this.result, super.key});
  final QuickProfileResult result;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        final role = result.profile['role'] as String;
        // Sprint1A: real recycler accounts open the Direct Sell dashboard.
        // Fresh registration and the unchanged CollectorSessionGate restore
        // route both arrive here, so both reach the same screen. Collectors
        // never reach this screen; non-recycler roles keep this placeholder.
        if (role == 'recycler') {
          return RecyclerDirectSellScreen(result: result);
        }
        return Scaffold(
          backgroundColor: _cream,
          appBar: AppBar(
            backgroundColor: _cream,
            leading: BackButton(
              onPressed: spokenAction(
                () => speechText('Back', 'वापस', 'मागे'),
                () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: [_logoutAction(context), const SpeechFeedbackButton()],
            title: Text(quickText(result.created ? 'ready' : 'restored')),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VoiceGuide(
                    instruction: () => speechText(
                      'Your profile is available. Recycler approval and account-recovery information are shown below. This screen does not confirm authorization or payment.',
                      'आपकी प्रोफ़ाइल उपलब्ध है। रीसायकलकर्ता की अनुमति और खाते की रिकवरी की जानकारी नीचे है। यह स्क्रीन अनुमति या भुगतान की पुष्टि नहीं करती।',
                      'तुमचे प्रोफाइल उपलब्ध आहे. रीसायकलकर्त्याची परवानगी आणि खाते रिकवरीची माहिती खाली आहे. ही स्क्रीन परवानगी किंवा पेमेंटची पुष्टी करत नाही.',
                    ),
                  ),
                  const Icon(Icons.check_circle, size: 74, color: _green),
                  const SizedBox(height: 18),
                  Text(
                    '${result.profile['name']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${quickText('role')}: ${quickText(role)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(quickText(result.isAnonymous ? 'guest' : 'linked')),
                  if (!result.created)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        quickText('preserved'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (role == 'recycler' &&
                      result.profile['authorizationStatus'] == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        quickText('pending'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (result.isAnonymous) ...[
                    const SizedBox(height: 20),
                    Text(
                      quickText('guestWarning'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quickText('recoveryLater'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    quickText('dashboardPending'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE5EDCF);
    for (var i = 0; i < 13; i++) {
      final x = size.width * i / 13;
      final h = 18.0 + (i % 4) * 12;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, size.width / 15, h),
        paint,
      );
    }
    paint.color = const Color(0xFFD1E2B4);
    for (var i = 0; i < 19; i++) {
      canvas.drawCircle(
        Offset(size.width * i / 18, size.height + 5),
        18,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) => false;
}

/// Sprint1 UI-fix: logout for the non-recycler "ready" placeholder.
/// Signs out ONLY the current Firebase user; no data is deleted.
/// Recyclers get the same control on the Direct Sell dashboard itself.
Widget _logoutAction(BuildContext context) => PopupMenuButton<String>(
  key: const ValueKey('ready_sign_out'),
  tooltip: ct('Account', 'खाता', 'खाते'),
  icon: const Icon(Icons.logout_outlined, color: _green),
  onSelected: (value) async {
    if (value != 'logout') return;
    final ok = await confirmAction(
      context,
      ct(
        'Sign out now? Only the current session ends. Data is never deleted.',
        'अभी साइन आउट करें? केवल मौजूदा सेशन समाप्त होता है। डेटा कभी नहीं मिटता।',
        'आता साइन आउट करायचे? फक्त सध्याचे सेशन संपते. डेटा कधीही पुसला जात नाही.',
      ),
    );
    if (!ok || !context.mounted) return;
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  },
  itemBuilder: (context) => [
    PopupMenuItem<String>(
      value: 'logout',
      child: Text(ct('Sign out', 'साइन आउट', 'साइन आउट')),
    ),
  ],
);
