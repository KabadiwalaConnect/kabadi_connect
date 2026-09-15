import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_language.dart';
import 'collector_home_screen.dart';
import 'quick_profile_service.dart';
import 'quick_registration_text.dart';

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
  bool _busy = false;
  bool _slow = false;
  bool _done = false;
  String? _error;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _name.dispose();
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

  Future<void> _start() async {
    if (_busy || _done || !(_form.currentState?.validate() ?? false)) {
      return;
    }
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
      }
    });
    try {
      final result = await (widget.service ?? QuickProfileService())
          .continueWithName(
            name: _name.text,
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => result.profile['role'] == 'collector'
              ? const CollectorHomeScreen()
              : QuickProfileReadyScreen(result: result),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _describe(error));
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
                  _languageCard('en', 'ENG', _green),
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
              const SizedBox(height: 24),
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
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _start(),
                maxLength: 100,
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
              const SizedBox(height: 6),
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
                onPressed: _busy ? null : _start,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize: const Size(0, 60),
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
                          quickText(_busy ? 'working' : 'start'),
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
        return Scaffold(
          backgroundColor: _cream,
          appBar: AppBar(
            backgroundColor: _cream,
            title: Text(quickText(result.created ? 'ready' : 'restored')),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
