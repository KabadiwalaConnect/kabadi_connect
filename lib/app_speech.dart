import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

/// Shared, optional action speech and route guidance.
/// Never pass private names, emails, OTPs or payment details into speech.
/// No recording permission/API key. Offline support depends on installed voices.
class AppSpeech with WidgetsBindingObserver {
  AppSpeech._();
  static final AppSpeech instance = AppSpeech._();
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  final ValueNotifier<String?> unavailableLanguage = ValueNotifier<String?>(
    null,
  );
  Future<void>? _initialization;
  Future<void> _pending = Future<void>.value();
  int _generation = 0;
  bool _foreground = true;
  Object? _guideOwner;
  Object? _speakingOwner;
  String Function()? _guide;

  int get revision => _generation;
  bool get hasGuide => _guide != null;
  bool ownsGuide(Object owner) => identical(_guideOwner, owner);
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool('spoken_button_feedback') ?? true;
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      debugPrint('KC_SPEECH initialization unavailable');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      stop();
    }
    // Do not suddenly auto-read after a phone call; Replay remains available.
  }

  void stop() {
    _speakingOwner = null;
    ++_generation;
    _pending = _pending
        .then((_) async {
          try {
            await _tts.stop();
          } catch (_) {
            // Speech failure must not prevent using the app.
          }
        })
        .catchError((Object _) {});
  }

  void attachGuide(Object owner, String Function() instruction) {
    if (!identical(_guideOwner, owner) && _speakingOwner != null) {
      stop();
    }
    _guideOwner = owner;
    _guide = instruction;
  }

  void detachGuide(Object owner) {
    // Disposing an old route must not stop a newer route's speech.
    if (!identical(_guideOwner, owner)) {
      return;
    }
    _guideOwner = null;
    _guide = null;
    if (identical(_speakingOwner, owner)) {
      stop();
    }
  }

  void replayGuide() {
    final guide = _guide;
    if (guide != null) {
      say(guide(), owner: _guideOwner);
    }
  }

  void say(String label, {Object? owner}) {
    if (label.trim().isEmpty) {
      return;
    }
    _speakingOwner = owner;
    final generation = ++_generation;
    final code = appLanguage.code;
    _pending = _pending
        .then((_) async {
          await initialize();
          if (!enabled.value || !_foreground || generation != _generation) {
            return;
          }
          try {
            final locale = switch (code) {
              'hi' => 'hi-IN',
              'mr' => 'mr-IN',
              _ => 'en-IN',
            };
            await _tts.stop();
            final available = await _tts.isLanguageAvailable(locale);
            if (generation != _generation || !enabled.value || !_foreground) {
              return;
            }
            if (available != true && available != 1) {
              unavailableLanguage.value = code;
              return;
            }
            final setResult = await _tts.setLanguage(locale);
            if (generation != _generation || !enabled.value || !_foreground) {
              return;
            }
            if (setResult == 0) {
              unavailableLanguage.value = code;
              return;
            }
            unavailableLanguage.value = null;
            final result = await _tts.speak(label);
            if (result == 0 && generation == _generation) {
              unavailableLanguage.value = code;
            }
          } catch (_) {
            if (generation == _generation) {
              unavailableLanguage.value = code;
            }
            debugPrint('KC_SPEECH playback unavailable');
          }
        })
        .catchError((Object _) {
          debugPrint('KC_SPEECH request unavailable');
        });
  }

  Future<void> setEnabled(bool value) async {
    await initialize();
    enabled.value = value;
    stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('spoken_button_feedback', value);
    } catch (_) {
      // The session preference still applies.
    }
  }
}

String speechText(String en, String hi, String mr) => appLanguage.code == 'hi'
    ? hi
    : appLanguage.code == 'mr'
    ? mr
    : en;

VoidCallback spokenAction(String Function() label, VoidCallback action) => () {
  AppSpeech.instance.say(label());
  action();
};

/// One per guided route. Prompts once on entry/return, not every rebuild.
/// New actions cancel a scheduled entry prompt rather than being interrupted.
/// Route guidance is advisory; it never controls navigation or authentication.
class VoiceGuide extends StatefulWidget {
  const VoiceGuide({
    required this.instruction,
    this.stateKey,
    this.announceChanges = false,
    super.key,
  });
  final String Function() instruction;
  // Stable semantic state, not every backend timestamp or typed character.
  final Object? stateKey;
  final bool announceChanges;
  @override
  State<VoiceGuide> createState() => _VoiceGuideState();
}

class _VoiceGuideState extends State<VoiceGuide>
    with AutomaticKeepAliveClientMixin<VoiceGuide> {
  @override
  bool get wantKeepAlive => true;
  final Object _owner = Object();
  Timer? _entryTimer;
  bool _current = false;

  @override
  void initState() {
    super.initState();
    unawaited(AppSpeech.instance.initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends specifically on current-route status, including dialog overlays.
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (_current == current) {
      return;
    }
    _current = current;
    _entryTimer?.cancel();
    if (!current) {
      AppSpeech.instance.detachGuide(_owner);
      return;
    }
    final speech = AppSpeech.instance;
    speech.attachGuide(_owner, () => widget.instruction());
    _schedule(const Duration(milliseconds: 850));
  }

  void _schedule(Duration delay) {
    _entryTimer?.cancel();
    final speech = AppSpeech.instance;
    final revision = speech.revision;
    _entryTimer = Timer(delay, () {
      if (!mounted ||
          !_current ||
          !speech.ownsGuide(_owner) ||
          speech.revision != revision) {
        return;
      }
      speech.replayGuide();
    });
  }

  @override
  void didUpdateWidget(covariant VoiceGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_current) {
      AppSpeech.instance.attachGuide(_owner, () => widget.instruction());
      if (widget.announceChanges && widget.stateKey != oldWidget.stateKey) {
        _schedule(const Duration(milliseconds: 650));
      }
    }
  }

  @override
  void dispose() {
    _entryTimer?.cancel();
    AppSpeech.instance.detachGuide(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Keep route/step speech active without a visible instruction panel.
    return const SizedBox.shrink();
  }
}

/// Important dialog content remains visible even when guide panels are hidden.
class SpokenNotice extends StatelessWidget {
  const SpokenNotice({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(text),
      VoiceGuide(instruction: () => text),
    ],
  );
}

class SpeechFeedbackButton extends StatefulWidget {
  const SpeechFeedbackButton({super.key});
  @override
  State<SpeechFeedbackButton> createState() => _SpeechFeedbackButtonState();
}

class _SpeechFeedbackButtonState extends State<SpeechFeedbackButton> {
  bool _changing = false;
  @override
  void initState() {
    super.initState();
    unawaited(AppSpeech.instance.initialize());
  }

  void _replay(bool enabled) {
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            speechText(
              'Voice is off. Tap the speaker to enable it.',
              'आवाज बंद है। चालू करने के लिए स्पीकर दबाएँ।',
              'आवाज बंद आहे. सुरू करण्यासाठी स्पीकर दाबा.',
            ),
          ),
        ),
      );
      return;
    }
    if (AppSpeech.instance.hasGuide) {
      AppSpeech.instance.replayGuide();
    } else {
      AppSpeech.instance.say(
        speechText(
          'Page guidance is not available here yet.',
          'इस पेज की गाइड अभी उपलब्ध नहीं है।',
          'या पानासाठी मार्गदर्शन अद्याप उपलब्ध नाही.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AppSpeech.instance.enabled,
    builder: (context, enabled, _) => Semantics(
      label: enabled
          ? speechText(
              'Voice on. Tap to mute. Hold to hear guidance again.',
              'आवाज चालू है। बंद करने के लिए दबाएँ। निर्देश फिर सुनने के लिए दबाकर रखें।',
              'आवाज सुरू आहे. बंद करण्यासाठी दाबा. सूचना पुन्हा ऐकण्यासाठी दाबून ठेवा.',
            )
          : speechText(
              'Voice off. Tap to enable.',
              'आवाज बंद है। चालू करने के लिए दबाएँ।',
              'आवाज बंद आहे. सुरू करण्यासाठी दाबा.',
            ),
      child: GestureDetector(
        onLongPress: _changing ? null : () => _replay(enabled),
        child: IconButton(
          // No tooltip long-press recognizer: holding this control replays speech.
          icon: Icon(
            enabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          ),
          onPressed: _changing
              ? null
              : () async {
                  setState(() => _changing = true);
                  final next = !enabled;
                  await AppSpeech.instance.setEnabled(next);
                  if (!mounted || !context.mounted) {
                    return;
                  }
                  setState(() => _changing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        next
                            ? speechText(
                                'Voice on. Hold the speaker to hear guidance again.',
                                'आवाज चालू है। निर्देश फिर सुनने के लिए स्पीकर दबाकर रखें।',
                                'आवाज सुरू आहे. सूचना पुन्हा ऐकण्यासाठी स्पीकर दाबून ठेवा.',
                              )
                            : speechText(
                                'Voice off',
                                'आवाज बंद है',
                                'आवाज बंद आहे',
                              ),
                      ),
                    ),
                  );
                  if (next) {
                    AppSpeech.instance.say(
                      speechText(
                        'Voice guidance on. Hold the speaker to hear instructions again.',
                        'बोलकर सहायता चालू है। निर्देश फिर सुनने के लिए स्पीकर दबाकर रखें।',
                        'बोलून मदत सुरू आहे. सूचना पुन्हा ऐकण्यासाठी स्पीकर दाबून ठेवा.',
                      ),
                    );
                  }
                },
        ),
      ),
    ),
  );
}
