import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_speech.dart';
import 'role_selection_screen.dart';

const _cream = Color(0xFFFFFAEF);
const _green = Color(0xFF2E703D);
const _darkGreen = Color(0xFF123D22);

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _saving = false;

  void _selectLanguage(String code) {
    if (_saving) {
      return;
    }
    // Change the language first, then speak in the newly selected language.
    appLanguage.select(code);
    AppSpeech.instance.say(
      speechText('English selected', 'हिंदी चुनी गई', 'मराठी निवडली'),
    );
  }

  Future<void> _continue() async {
    if (_saving) {
      return;
    }
    AppSpeech.instance.say(appLanguage.text('continue'));
    setState(() => _saving = true);

    try {
      await appLanguage.save();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final message = appLanguage.text('saveError');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      AppSpeech.instance.say(message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _cream,
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/images/language_footer.png',
                    height: 125,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: SpeechFeedbackButton(),
                          ),
                          Image.asset(
                            'assets/images/brand_logo.png',
                            width: 150,
                            height: 126,
                            fit: BoxFit.contain,
                            semanticLabel: 'Kabadiwalla Connect',
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7EFD6),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              appLanguage.text('chooseLanguage'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _darkGreen,
                                fontSize: 34,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            appLanguage.text('languageSubtitle'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF515348),
                              fontSize: 19,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _languageCard(
                            code: 'en',
                            label: 'English',
                            badgeColor: _green,
                            globe: true,
                          ),
                          const SizedBox(height: 12),
                          _languageCard(
                            code: 'hi',
                            label: 'हिंदी',
                            badgeColor: const Color(0xFFFFD574),
                          ),
                          const SizedBox(height: 12),
                          _languageCard(
                            code: 'mr',
                            label: 'मराठी',
                            badgeColor: const Color(0xFFB8D699),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('continue_button'),
                              onPressed: _saving ? null : _continue,
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 66),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      appLanguage.text(
                                        _saving ? 'saving' : 'continue',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  if (_saving)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 32,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _languageCard({
    required String code,
    required String label,
    required Color badgeColor,
    bool globe = false,
  }) {
    final selected = appLanguage.code == code;

    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFE0EED3) : const Color(0xFFFFFBF2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected ? _green : const Color(0xFFE5E0D0),
            width: selected ? 2.2 : 1.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('language_$code'),
          onTap: _saving ? null : () => _selectLanguage(code),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 94),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: globe
                          ? const Icon(
                              Icons.language,
                              color: Colors.white,
                              size: 43,
                            )
                          : const Text(
                              'अ',
                              style: TextStyle(
                                fontSize: 43,
                                height: 1.1,
                                color: _darkGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        color: Color(0xFF152C1B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 36,
                    color: selected ? _green : const Color(0xFFBABBB1),
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
