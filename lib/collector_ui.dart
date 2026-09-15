import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_language.dart';
import 'app_speech.dart';

const collectorGreen = Color(0xFF21643D);
const collectorCream = Color(0xFFFFFAEF);
String ct(String en, String hi, String mr) => speechText(en, hi, mr);
const collectorMaterials = [
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
const collectorCities = ['Amritsar', 'Jalandhar', 'Ludhiana', 'Mumbai', 'Pune'];
String materialLabel(String key) {
  const labels = {
    'Copper': [
      '\u0924\u093E\u0902\u092C\u093E',
      '\u0924\u093E\u0902\u092C\u0947',
    ],
    'Aluminium': [
      '\u090F\u0932\u094D\u092F\u0941\u092E\u093F\u0928\u093F\u092F\u092E',
      '\u0905\u0945\u0932\u094D\u092F\u0941\u092E\u093F\u0928\u093F\u092F\u092E',
    ],
    'Iron': ['\u0932\u094B\u0939\u093E', '\u0932\u094B\u0916\u0902\u0921'],
    'PCB': [
      '\u0938\u0930\u094D\u0915\u093F\u091F \u092C\u094B\u0930\u094D\u0921',
      '\u0938\u0930\u094D\u0915\u093F\u091F \u092C\u094B\u0930\u094D\u0921',
    ],
    'Battery': [
      '\u092C\u0948\u091F\u0930\u0940',
      '\u092C\u0945\u091F\u0930\u0940',
    ],
    'CRT': [
      '\u0938\u0940\u0906\u0930\u091F\u0940',
      '\u0938\u0940\u0906\u0930\u091F\u0940',
    ],
    'LCD': [
      '\u090F\u0932\u0938\u0940\u0921\u0940',
      '\u090F\u0932\u0938\u0940\u0921\u0940',
    ],
    'Cable': ['\u0915\u0947\u092C\u0932', '\u0915\u0947\u092C\u0932'],
    'Motor': ['\u092E\u094B\u091F\u0930', '\u092E\u094B\u091F\u0930'],
  };
  return ct(key, labels[key]?[0] ?? key, labels[key]?[1] ?? key);
}

String statusLabel(String s) {
  const labels = {
    'draft': [
      'Draft',
      '\u0921\u094D\u0930\u093E\u092B\u094D\u091F',
      '\u0921\u094D\u0930\u093E\u092B\u094D\u091F',
    ],
    'offered': [
      'Offered',
      '\u0911\u092B\u0930 \u092D\u0947\u091C\u093E',
      '\u0911\u092B\u0930 \u092A\u093E\u0920\u0935\u0932\u093E',
    ],
    'reserved': [
      'Reserved',
      '\u0906\u0930\u0915\u094D\u0937\u093F\u0924',
      '\u0930\u093E\u0916\u0940\u0935',
    ],
    'handedOver': [
      'Handed over',
      '\u0938\u094C\u0902\u092A\u093E \u0917\u092F\u093E',
      '\u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u093F\u0924',
    ],
    'archived': [
      'Archived',
      '\u0938\u0902\u0917\u094D\u0930\u0939\u0940\u0924',
      '\u0938\u0902\u0917\u094D\u0930\u0939\u093F\u0924',
    ],
    'proposed': [
      'Sent',
      '\u092D\u0947\u091C\u093E \u0917\u092F\u093E',
      '\u092A\u093E\u0920\u0935\u0932\u0947',
    ],
    'quoted': [
      'Quote received',
      '\u092D\u093E\u0935 \u092E\u093F\u0932\u093E',
      '\u0926\u0930 \u092E\u093F\u0933\u093E\u0932\u093E',
    ],
    'accepted': [
      'Accepted',
      '\u0938\u094D\u0935\u0940\u0915\u0943\u0924',
      '\u0938\u094D\u0935\u0940\u0915\u093E\u0930\u0932\u0947',
    ],
    'rejected': [
      'Rejected',
      '\u0905\u0938\u094D\u0935\u0940\u0915\u0943\u0924',
      '\u0928\u093E\u0915\u093E\u0930\u0932\u0947',
    ],
    'cancelled': [
      'Cancelled',
      '\u0930\u0926\u094D\u0926',
      '\u0930\u0926\u094D\u0926',
    ],
    'handoverPending': [
      'Awaiting recycler handover confirmation',
      '\u0938\u094C\u0902\u092A\u0928\u0947 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u092C\u093E\u0915\u0940',
      '\u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092A\u0941\u0937\u094D\u091F\u0940 \u092C\u093E\u0915\u0940',
    ],
    'completed': [
      'Handover confirmed',
      '\u0938\u094C\u0902\u092A\u0928\u0947 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0939\u0941\u0908',
      '\u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092A\u0941\u0937\u094D\u091F\u0940 \u091D\u093E\u0932\u0940',
    ],
    'local': [
      'Local draft',
      '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F',
      '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F',
    ],
    'queued': [
      'Sync pending',
      '\u0938\u093F\u0902\u0915 \u092C\u093E\u0915\u0940',
      '\u0938\u093F\u0902\u0915 \u092C\u093E\u0915\u0940',
    ],
    'synced': [
      'Synced',
      '\u0938\u093F\u0902\u0915 \u0939\u0941\u0906',
      '\u0938\u093F\u0902\u0915 \u091D\u093E\u0932\u0947',
    ],
    'error': [
      'Sync needs attention',
      '\u0938\u093F\u0902\u0915 \u091C\u093E\u0901\u091A\u0947\u0902',
      '\u0938\u093F\u0902\u0915 \u0924\u092A\u093E\u0938\u093E',
    ],
  };
  final l = labels[s];
  return l == null
      ? ct(
          'Unknown state',
          '\u0905\u091C\u094D\u091E\u093E\u0924 \u0938\u094D\u0925\u093F\u0924\u093F',
          '\u0905\u091C\u094D\u091E\u093E\u0924 \u0938\u094D\u0925\u093F\u0924\u0940',
        )
      : ct(l[0], l[1], l[2]);
}

String friendlyError(Object e) => ct(
  'Not confirmed. Check internet, account and setup; retry safely.',
  '\u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964 \u0907\u0902\u091F\u0930\u0928\u0947\u091F, \u0916\u093E\u0924\u093E \u0914\u0930 \u0938\u0947\u091F\u0905\u092A \u091C\u093E\u0901\u091A\u0915\u0930 \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0915\u0930\u0947\u0902\u0964',
  '\u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940. \u0907\u0902\u091F\u0930\u0928\u0947\u091F, \u0916\u093E\u0924\u0947 \u0935 \u0938\u0947\u091F\u0905\u092A \u0924\u092A\u093E\u0938\u0942\u0928 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928 \u0915\u0930\u093E.',
);

/// Shared page wrapper. Backend/account checks never own the page layout.
class CollectorPage extends StatefulWidget {
  const CollectorPage({
    required this.title,
    required this.body,
    this.guide,
    this.bottom,
    this.scrollController,
    super.key,
  });
  final String Function() title;
  final Widget Function(BuildContext) body;
  final String Function()? guide;
  final Widget Function()? bottom;
  final ScrollController? scrollController;
  @override
  State<CollectorPage> createState() => _CollectorPageState();
}

class _CollectorPageState extends State<CollectorPage> {
  final _entryUid = FirebaseAuth.instance.currentUser?.uid;
  late final _authChanges = FirebaseAuth.instance.authStateChanges();
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appLanguage,
    builder: (context, _) => StreamBuilder<User?>(
      stream: _authChanges,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, auth) {
        final changed = _entryUid != null && auth.data?.uid != _entryUid;
        return CollectorPageLayout(
          title: widget.title(),
          scrollController: widget.scrollController,
          actions: const [SpeechFeedbackButton()],
          bottom: changed ? null : widget.bottom?.call(),
          guide: changed
              ? null
              : VoiceGuide(
                  instruction:
                      widget.guide ??
                      () =>
                          '${widget.title()}. ${ct('Review the details and choose an action.', '\u091C\u093E\u0928\u0915\u093E\u0930\u0940 \u091C\u093E\u0901\u091A\u0915\u0930 \u0915\u093E\u0930\u094D\u0930\u0935\u093E\u0908 \u091A\u0941\u0928\u0947\u0902\u0964', '\u0924\u092A\u0936\u0940\u0932 \u0924\u092A\u093E\u0938\u0942\u0928 \u0915\u0943\u0924\u0940 \u0928\u093F\u0935\u0921\u093E.')}',
                ),
          // Build content as its own child rather than evaluating it while
          // constructing the entire viewport/header/footer.
          body: changed
              ? note(
                  ct(
                    'Account changed. Close this page and restart the app. No account data has been merged.',
                    '\u0916\u093E\u0924\u093E \u092C\u0926\u0932 \u0917\u092F\u093E\u0964 \u092A\u0947\u091C \u092C\u0902\u0926 \u0915\u0930\u0915\u0947 \u0910\u092A \u0926\u094B\u092C\u093E\u0930\u093E \u0916\u094B\u0932\u0947\u0902\u0964 \u0916\u093E\u0924\u0947 \u0915\u093E \u0921\u0947\u091F\u093E \u092E\u093F\u0932\u093E\u092F\u093E \u0928\u0939\u0940\u0902 \u0917\u092F\u093E \u0939\u0948\u0964',
                    '\u0916\u093E\u0924\u0947 \u092C\u0926\u0932\u0932\u0947. \u092A\u0947\u091C \u092C\u0902\u0926 \u0915\u0930\u0942\u0928 \u0905\u0945\u092A \u092A\u0941\u0928\u094D\u0939\u093E \u0909\u0918\u0921\u093E. \u0916\u093E\u0924\u094D\u092F\u093E\u0902\u091A\u093E \u0921\u0947\u091F\u093E \u090F\u0915\u0924\u094D\u0930 \u0915\u0947\u0932\u0947\u0932\u093E \u0928\u093E\u0939\u0940.',
                  ),
                )
              : Builder(builder: widget.body),
        );
      },
    ),
  );
}

/// Pure, bounded layout, also exercised without Firebase in widget tests.
/// One vertical scroll view owns the header, page content and footer.
class CollectorPageLayout extends StatelessWidget {
  const CollectorPageLayout({
    required this.title,
    required this.body,
    this.guide,
    this.bottom,
    this.scrollController,
    this.actions = const [],
    super.key,
  });
  final String title;
  final Widget body;
  final Widget? guide, bottom;
  final ScrollController? scrollController;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: collectorGreen),
      textTheme: Theme.of(context).textTheme.merge(
        const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontWeight: FontWeight.w700),
          bodySmall: TextStyle(fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          titleSmall: TextStyle(fontWeight: FontWeight.w700),
          labelLarge: TextStyle(fontWeight: FontWeight.w700),
          labelMedium: TextStyle(fontWeight: FontWeight.w700),
          labelSmall: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: collectorCream,
      appBar: AppBar(
        backgroundColor: collectorCream,
        title: Text(title),
        leading: Navigator.of(context).canPop()
            ? BackButton(
                onPressed: spokenAction(
                  () => ct(
                    'Back',
                    '\u0935\u093E\u092A\u0938',
                    '\u092E\u093E\u0917\u0947',
                  ),
                  () => Navigator.maybePop(context),
                ),
              )
            : null,
        actions: actions,
      ),
      bottomNavigationBar: bottom,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth > 600 ? 600.0 : bounds.maxWidth;
            Widget bounded(Widget child) => Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: child),
            );
            return ListView(
              key: const ValueKey('collector_page_scroll'),
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                bounded(
                  const CollectorArtwork(key: ValueKey('collector_header')),
                ),
                if (guide != null) bounded(guide!),
                bounded(
                  Padding(padding: const EdgeInsets.all(16), child: body),
                ),
                bounded(
                  const CollectorFooter(key: ValueKey('collector_footer')),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class CollectorFooter extends StatelessWidget {
  const CollectorFooter({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 110,
    child: Image.asset(
      'assets/images/language_footer.png',
      width: double.infinity,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) => Center(
        child: Text(
          ct(
            'Footer image missing: language_footer.png',
            '\u092B\u0941\u091F\u0930 \u0915\u0940 \u092B\u094B\u091F\u094B \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u0940: language_footer.png',
            '\u092B\u0941\u091F\u0930\u091A\u093E \u092B\u094B\u091F\u094B \u0928\u093E\u0939\u0940: language_footer.png',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class CollectorArtwork extends StatelessWidget {
  const CollectorArtwork({this.greeting, super.key});

  final String? greeting;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: CustomPaint(painter: CollectorSkyline())),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              flex: 45,
              child: ExcludeSemantics(
                child: Image.asset(
                  'assets/images/quick_collector.png',
                  height: 185,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => SizedBox(
                    height: 185,
                    child: Center(
                      child: Text(
                        ct(
                          'Header image missing: quick_collector.png',
                          'हेडर की फोटो नहीं मिली: quick_collector.png',
                          'हेडरचा फोटो नाही: quick_collector.png',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (greeting != null) ...[
                      Text(
                        greeting!,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          color: collectorGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      ct(
                        'Not waste.\nA better tomorrow.',
                        'कचरा नहीं,\nबेहतर कल की शुरुआत',
                        'कचरा नाही,\nउत्तम कलाची सुरुवात',
                      ),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        color: Color(0xFF286B3B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class CollectorSkyline extends CustomPainter {
  const CollectorSkyline();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFE5EDCF);
    for (var i = 0; i < 13; i++) {
      final h = 18.0 + (i % 4) * 12;
      canvas.drawRect(
        Rect.fromLTWH(size.width * i / 13, size.height - h, size.width / 15, h),
        p,
      );
    }
    p.color = const Color(0xFFD1E2B4);
    for (var i = 0; i < 19; i++) {
      canvas.drawCircle(Offset(size.width * i / 18, size.height + 5), 18, p);
    }
  }

  @override
  bool shouldRepaint(covariant CollectorSkyline oldDelegate) => false;
}

Widget section(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      color: collectorGreen,
    ),
  ),
);
Widget note(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(text, style: const TextStyle(height: 1.5)),
);
Widget actionButton(
  String text,
  VoidCallback? onTap, {
  IconData icon = Icons.arrow_forward,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: FilledButton.icon(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: collectorGreen,
    ),
    onPressed: onTap == null ? null : spokenAction(() => text, onTap),
    icon: Icon(icon),
    label: Text(text),
  ),
);
Future<bool> confirmAction(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: SingleChildScrollView(child: SpokenNotice(text: text)),
        actions: [
          TextButton(
            onPressed: spokenAction(
              () => ct(
                'Cancel',
                '\u0930\u0926\u094D\u0926',
                '\u0930\u0926\u094D\u0926',
              ),
              () => Navigator.pop(c, false),
            ),
            child: Text(
              ct(
                'Cancel',
                '\u0930\u0926\u094D\u0926',
                '\u0930\u0926\u094D\u0926',
              ),
            ),
          ),
          FilledButton(
            onPressed: spokenAction(
              () => ct(
                'Confirm',
                '\u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0947\u0902',
                '\u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0930\u093E',
              ),
              () => Navigator.pop(c, true),
            ),
            child: Text(
              ct(
                'Confirm',
                '\u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0947\u0902',
                '\u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0930\u093E',
              ),
            ),
          ),
        ],
      ),
    ) ??
    false;
void openCollector(BuildContext context, Widget page) {
  AppSpeech.instance.say(
    ct(
      'Opening page',
      '\u092A\u0947\u091C \u0916\u094B\u0932 \u0930\u0939\u0947 \u0939\u0948\u0902',
      '\u092A\u0947\u091C \u0909\u0918\u0921\u0924 \u0906\u0939\u0947',
    ),
  );
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}
