import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_speech.dart';
import 'quick_registration_screen.dart';

enum UserRole { collector, recycler }

const _background = Color(0xFFFFFAEF);
const _green = Color(0xFF286B3B);
const _dark = Color(0xFF123D22);

String roleName(UserRole role) => appLanguage.text(
  role == UserRole.collector ? 'collectorRole' : 'recyclerRole',
);

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _choose(BuildContext context, UserRole role) {
    AppSpeech.instance.say(roleName(role));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuickRegistrationScreen(role: role.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _background,
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/images/language_footer.png',
                    height: 115,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22;
                    final collector = _RoleCard(
                      role: UserRole.collector,
                      onTap: () => _choose(context, UserRole.collector),
                    );
                    final recycler = _RoleCard(
                      role: UserRole.recycler,
                      onTap: () => _choose(context, UserRole.recycler),
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 115),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      children: [
                                        Image.asset(
                                          'assets/images/brand_logo.png',
                                          width: 165,
                                          height: 135,
                                          fit: BoxFit.contain,
                                          semanticLabel: 'Kabadiwalla Connect',
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          appLanguage.text('brandTagline'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF60705C),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: IconButton(
                                      key: const Key('role_back'),
                                      tooltip: MaterialLocalizations.of(context)
                                          .backButtonTooltip,
                                      onPressed: spokenAction(
                                        () =>
                                            speechText('Back', 'वापस', 'मागे'),
                                        () => Navigator.of(context).pop(),
                                      ),
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: _dark,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    right: 0,
                                    top: 0,
                                    child: SpeechFeedbackButton(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 26),
                              Text(
                                appLanguage.text('whoAreYou'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _dark,
                                  fontSize: 34,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  appLanguage.text('roleSubtitle'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF5D6057),
                                    fontSize: 18,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (stacked)
                                Column(
                                  children: [
                                    collector,
                                    const SizedBox(height: 16),
                                    recycler,
                                  ],
                                )
                              else
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: collector),
                                      const SizedBox(width: 12),
                                      Expanded(child: recycler),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2DD),
                                  borderRadius: BorderRadius.circular(35),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.eco_rounded,
                                      color: _green,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        appLanguage.text('togetherMessage'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: _dark,
                                          fontSize: 17,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap});
  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final collector = role == UserRole.collector;
    final description = appLanguage.text(
      collector ? 'collectorDescription' : 'recyclerDescription',
    );
    return Semantics(
      button: true,
      label: '${roleName(role)}. $description',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: collector ? const Color(0xFFEAF3DE) : const Color(0xFFFFF2CD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              width: 2,
              color: collector
                  ? const Color(0xFF57A568)
                  : const Color(0xFFE6C565),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('role_${role.name}'),
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(21),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.15,
                      child: Image.asset(
                        collector
                            ? 'assets/images/collector_role.png'
                            : 'assets/images/recycler_role.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                  child: Text(
                    roleName(role),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 23,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF545D4B),
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
