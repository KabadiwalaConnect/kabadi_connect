import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collector_ui.dart';
import 'collector_store.dart';
import 'collector_pages.dart';
import 'collector_market.dart';
import 'collector_price_board.dart';
import 'collector_summaries.dart';
import 'material_photos.dart';
import 'app_language.dart';
import 'app_speech.dart';

DateTime collectorWeekStart(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day.subtract(Duration(days: now.weekday - DateTime.monday));
}

String homeMoney(num value) => '\u20B9${value.toStringAsFixed(2)}';
String homeGreeting(int hour) => hour < 12
    ? ct(
        'Good morning,',
        '\u0938\u0941\u092A\u094D\u0930\u092D\u093E\u0924,',
        '\u0938\u0941\u092A\u094D\u0930\u092D\u093E\u0924,',
      )
    : hour < 17
    ? ct(
        'Good afternoon,',
        '\u0928\u092E\u0938\u094D\u0915\u093E\u0930,',
        '\u0928\u092E\u0938\u094D\u0915\u093E\u0930,',
      )
    : ct(
        'Good evening,',
        '\u0936\u0941\u092D \u0938\u0902\u0927\u094D\u092F\u093E,',
        '\u0936\u0941\u092D \u0938\u0902\u0927\u094D\u092F\u093E\u0915\u093E\u0933,',
      );

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});
  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeState();
}

class _CollectorHomeState extends State<CollectorHomeScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _pricesKey = GlobalKey();
  final _entryUid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<User?> _authStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _receiptsStream;
  late Future<Map<String, dynamic>> _prices;
  late DateTime _weekStart;
  int _hour = DateTime.now().hour;
  String _city = 'Ludhiana';
  String? _selected, _message;

  Future<Map<String, dynamic>> _loadPrices() async => Map<String, dynamic>.from(
    jsonDecode(
      await rootBundle.loadString(
        'assets/data/price_dataset.json',
        cache: false,
      ),
    ) as Map,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authStream = FirebaseAuth.instance.authStateChanges();
    _prices = _loadPrices();
    _weekStart = collectorWeekStart(DateTime.now());
    if (_entryUid != null) {
      _profileStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_entryUid)
          .snapshots(includeMetadataChanges: true);
      _setReceiptStream();
      unawaited(_loadCity());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _trySync();
    });
  }

  void _setReceiptStream() {
    if (_entryUid == null) return;
    _receiptsStream = FirebaseFirestore.instance
        .collection('collectorPayments')
        .where('collectorUid', isEqualTo: _entryUid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_weekStart),
        )
        .orderBy('createdAt', descending: true)
        .limit(101)
        .snapshots(includeMetadataChanges: true);
  }

  Future<void> _loadCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('collector_home_city_$_entryUid');
      if (mounted && collectorCities.contains(saved))
        setState(() => _city = saved!);
    } catch (_) {
      /* City selector remains usable if preferences are unavailable. */
    }
  }

  Future<void> _chooseCity(String value) async {
    setState(() => _city = value);
    AppSpeech.instance.say(value);
    if (_entryUid == null) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
        'collector_home_city_$_entryUid',
        value,
      );
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'City changed for this session; preference could not be saved.',
            '\u0907\u0938 \u0938\u0947\u0936\u0928 \u0915\u093E \u0936\u0939\u0930 \u092C\u0926\u0932\u093E; \u092A\u0938\u0902\u0926 \u0938\u0939\u0947\u091C\u0940 \u0928\u0939\u0940\u0902 \u0917\u0908\u0964',
            '\u092F\u093E \u0938\u0947\u0936\u0928\u091A\u0947 \u0936\u0939\u0930 \u092C\u0926\u0932\u0932\u0947; \u092A\u0938\u0902\u0924\u0940 \u091C\u0924\u0928 \u091D\u093E\u0932\u0940 \u0928\u093E\u0939\u0940.',
          ),
        );
    }
  }

  void _trySync() {
    if (FirebaseAuth.instance.currentUser?.uid != _entryUid ||
        _entryUid == null)
      return;
    unawaited(
      CollectorStore.instance.sync().catchError((Object error) {
        if (mounted)
          setState(
            () => _message = ct(
              'Sync needs attention. Open Offline & sync.',
              '\u0938\u093F\u0902\u0915 \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u0911\u092B\u0932\u093E\u0907\u0928 \u0914\u0930 \u0938\u093F\u0902\u0915 \u0916\u094B\u0932\u0947\u0902\u0964',
              '\u0938\u093F\u0902\u0915 \u0924\u092A\u093E\u0938\u093E. \u0911\u092B\u0932\u093E\u0907\u0928 \u0935 \u0938\u093F\u0902\u0915 \u0909\u0918\u0921\u093E.',
            ),
          );
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now(), week = collectorWeekStart(DateTime.now());
    setState(() {
      _hour = now.hour;
      if (week != _weekStart) {
        _weekStart = week;
        _setReceiptStream();
      }
    });
    _trySync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  bool _accountReady() =>
      _entryUid != null && FirebaseAuth.instance.currentUser?.uid == _entryUid;
  void _open(String id, {String? material}) {
    if (id == 'prices') {
      setState(() => _selected = id);
      AppSpeech.instance.say(
        ct(
          'Material prices',
          '\u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u0915\u0947 \u092D\u093E\u0935',
          '\u0938\u093E\u0939\u093F\u0924\u094D\u092F\u093E\u091A\u0947 \u0926\u0930',
        ),
      );
      final c = _pricesKey.currentContext;
      if (c != null)
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 300),
        );
      return;
    }
    if (!_accountReady() && id != 'safety') {
      final text = ct(
        'Sign in to use account features. Restart the app to check your session; do not clear data.',
        '\u0916\u093E\u0924\u0947 \u0915\u0947 \u0915\u093E\u092E \u0915\u0947 \u0932\u093F\u090F \u0938\u093E\u0907\u0928-\u0907\u0928 \u0915\u0930\u0947\u0902\u0964 \u0938\u0947\u0936\u0928 \u091C\u093E\u0901\u091A\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0910\u092A \u0926\u094B\u092C\u093E\u0930\u093E \u0916\u094B\u0932\u0947\u0902; \u0921\u0947\u091F\u093E \u0928 \u092E\u093F\u091F\u093E\u090F\u0901\u0964',
        '\u0916\u093E\u0924\u094D\u092F\u093E\u091A\u094D\u092F\u093E \u0915\u0943\u0924\u0940\u0902\u0938\u093E\u0920\u0940 \u0938\u093E\u0907\u0928 \u0907\u0928 \u0915\u0930\u093E. \u0938\u0947\u0936\u0928 \u0924\u092A\u093E\u0938\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0905\u0945\u092A \u092A\u0941\u0928\u094D\u0939\u093E \u0909\u0918\u0921\u093E; \u0921\u0947\u091F\u093E \u092A\u0941\u0938\u0942 \u0928\u0915\u093E.',
      );
      setState(() => _message = text);
      AppSpeech.instance.say(text);
      return;
    }
    final Widget page = switch (id) {
      'sell' => const DirectSellPage(),
      'requests' => const RecyclerRequestsScreen(),
      'ledger' => const LedgerScreen(),
      'board' => const PriceBoardScreen(),
      'summaries' => const SummariesScreen(),
      'lots' => const LotsScreen(),
      'directory' => const RecyclerDirectoryScreen(),
      'offers' => const MyOffersScreen(),
      'sync' => const SyncScreen(),
      'profile' => const ProfileScreen(),
      'safety' => const SafetyScreen(),
      'camera' => LotEditor(value: {'city': _city, 'material': material}),
      _ => const LotsScreen(),
    };
    setState(() {
      _selected = id;
      _message = null;
    });
    AppSpeech.instance.say(
      ct(
        'Opening selected page',
        '\u091A\u0941\u0928\u093E \u092A\u0947\u091C \u0916\u094B\u0932 \u0930\u0939\u0947 \u0939\u0948\u0902',
        '\u0928\u093F\u0935\u0921\u0932\u0947\u0932\u0947 \u092A\u0947\u091C \u0909\u0918\u0921\u0924 \u0906\u0939\u0947',
      ),
    );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _signOut() async {
    if (!await confirmAction(
      context,
      ct(
        'Sign out of this account? Your saved lots and requests stay safe on the server and come back when you log in again with the same phone number and PIN.',
        '\u0907\u0938 \u0916\u093E\u0924\u0947 \u0938\u0947 \u0938\u093E\u0907\u0928 \u0906\u0909\u091F \u0915\u0930\u0947\u0902? \u0906\u092A\u0915\u0947 \u0938\u0939\u0947\u091C\u0947 \u0932\u0949\u091F \u0914\u0930 \u0905\u0928\u0941\u0930\u094B\u0927 \u0938\u0930\u094D\u0935\u0930 \u092A\u0930 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0930\u0939\u0924\u0947 \u0939\u0948\u0902 \u0914\u0930 \u0909\u0938\u0940 \u092B\u093C\u094B\u0928 \u0928\u0902\u092C\u0930 + PIN \u0938\u0947 \u092B\u093F\u0930 \u0932\u0949\u0917\u093F\u0928 \u0915\u0930\u0928\u0947 \u092A\u0930 \u0935\u093E\u092A\u0938 \u0906 \u091C\u093E\u0924\u0947 \u0939\u0948\u0902\u0964',
        '\u092F\u093E \u0916\u093E\u0924\u094D\u092F\u093E\u0924\u0942\u0928 \u0938\u093E\u0907\u0928 \u0906\u0909\u091F \u0915\u0930\u093E\u092F\u091A\u0947? \u0924\u0941\u092E\u091A\u0947 \u091C\u0924\u0928 \u0915\u0947\u0932\u0947\u0932\u0947 \u0932\u0949\u091F \u0935 \u0935\u093F\u0928\u0902\u0924\u094D\u092F\u093E \u0938\u0930\u094D\u0935\u0939\u0930\u0935\u0930 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0930\u093E\u0939\u0924\u093E\u0924 \u0935 \u0924\u094D\u092F\u093E\u091A \u092B\u094B\u0928 \u0928\u0902\u092C\u0930 + PIN \u0928\u0947 \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0917\u093F\u0928 \u0915\u0947\u0932\u094D\u092F\u093E\u0938 \u092A\u0930\u0924 \u092F\u0947\u0924\u093E\u0924.',
      ),
    ))
      return;
    await FirebaseAuth.instance.signOut();
  }

  void _home() {
    setState(() => _selected = null);
    AppSpeech.instance.say(
      ct('Home', '\u0939\u094B\u092E', '\u0939\u094B\u092E'),
    );
    if (_scroll.hasClients)
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appLanguage,
    builder: (context, _) => StreamBuilder<User?>(
      stream: _authStream,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, auth) {
        final valid = _entryUid != null && auth.data?.uid == _entryUid;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: valid ? _profileStream : null,
          builder: (context, p) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: valid ? _receiptsStream : null,
                builder: (context, r) => FutureBuilder<Map<String, dynamic>>(
                  future: _prices,
                  builder: (context, prices) {
                    final rawName = valid ? ((p.data?.data())?['name']) : null;
                    double? received;
                    final overflow = valid && (r.data?.docs.length ?? 0) > 100;
                    if (valid &&
                        r.hasData &&
                        r.connectionState == ConnectionState.active &&
                        !r.hasError &&
                        !r.data!.metadata.isFromCache &&
                        !r.data!.metadata.hasPendingWrites &&
                        !overflow) {
                      var sum = 0.0, good = true;
                      for (final d in r.data!.docs) {
                        final amount = d.data()['amount'];
                        if (amount is! num ||
                            !amount.isFinite ||
                            amount <= 0 ||
                            d.data()['currency'] != 'INR') {
                          good = false;
                          break;
                        }
                        sum += amount.toDouble();
                      }
                      if (good) received = sum;
                    }
                    final profileMessage = !valid
                        ? ct(
                            'No active collector session. Account actions need sign-in.',
                            '\u0938\u0915\u094D\u0930\u093F\u092F \u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0938\u0947\u0936\u0928 \u0928\u0939\u0940\u0902\u0964 \u0916\u093E\u0924\u0947 \u0915\u0947 \u0915\u093E\u092E \u0915\u0947 \u0932\u093F\u090F \u0938\u093E\u0907\u0928-\u0907\u0928 \u091A\u093E\u0939\u093F\u090F\u0964',
                            '\u0938\u0915\u094D\u0930\u093F\u092F \u0938\u0902\u0915\u0932\u0915 \u0938\u0947\u0936\u0928 \u0928\u093E\u0939\u0940. \u0916\u093E\u0924\u094D\u092F\u093E\u091A\u094D\u092F\u093E \u0915\u0943\u0924\u0940\u0902\u0938\u093E\u0920\u0940 \u0938\u093E\u0907\u0928 \u0907\u0928 \u0906\u0935\u0936\u094D\u092F\u0915.',
                          )
                        : p.hasError
                        ? ct(
                            'Profile could not load; menu and local price references remain available.',
                            '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0932\u094B\u0921 \u0928\u0939\u0940\u0902 \u0939\u0941\u0908; \u092E\u0947\u0928\u0942 \u0914\u0930 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0938\u0902\u0926\u0930\u094D\u092D \u092D\u093E\u0935 \u0909\u092A\u0932\u092C\u094D\u0927 \u0939\u0948\u0902\u0964',
                            '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u0932\u094B\u0921 \u091D\u093E\u0932\u0947 \u0928\u093E\u0939\u0940; \u092E\u0947\u0928\u0942 \u0935 \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0938\u0902\u0926\u0930\u094D\u092D \u0926\u0930 \u0909\u092A\u0932\u092C\u094D\u0927 \u0906\u0939\u0947\u0924.',
                          )
                        : null;
                    return CollectorDashboardView(
                      name: rawName is String && rawName.trim().isNotEmpty
                          ? rawName
                          : null,
                      hour: _hour,
                      city: _city,
                      selectedId: _selected,
                      prices: prices.data,
                      priceLoading:
                          prices.connectionState != ConnectionState.done,
                      priceError: prices.hasError,
                      recordedThisWeek: received,
                      receiptOverflow: overflow,
                      message: _message ?? profileMessage,
                      scrollController: _scroll,
                      pricesKey: _pricesKey,
                      onAction: (id) => _open(id),
                      onCreateLot: (m) => _open('camera', material: m),
                      onCityChanged: _chooseCity,
                      onHome: _home,
                      onCamera: () => _open('camera'),
                      onMessages: () => _open('offers'),
                      onRetryPrices: () =>
                          setState(() => _prices = _loadPrices()),
                      onSignOut: _signOut,
                      voiceControl: const SpeechFeedbackButton(),
                      guide: VoiceGuide(
                        instruction: () => ct(
                          'Your home has shortcuts in a horizontal row. Swipe that row for more features. Scroll below for dated rupee-per-kilogram material prices. These are reference rates, not buyer offers.',
                          '\u0939\u094B\u092E \u0915\u0947 \u0935\u093F\u0915\u0932\u094D\u092A \u090F\u0915 \u0906\u0921\u093C\u0940 \u092A\u0902\u0915\u094D\u0924\u093F \u092E\u0947\u0902 \u0939\u0948\u0902\u0964 \u0914\u0930 \u0935\u093F\u0915\u0932\u094D\u092A \u0915\u0947 \u0932\u093F\u090F \u092A\u0902\u0915\u094D\u0924\u093F \u0915\u094B \u0916\u093F\u0938\u0915\u093E\u090F\u0901\u0964 \u0928\u0940\u091A\u0947 \u0924\u093E\u0930\u0940\u0916 \u0935\u093E\u0932\u0947 \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u0915\u0947 \u092D\u093E\u0935 \u0926\u0947\u0916\u0947\u0902\u0964 \u092F\u0947 \u0938\u0902\u0926\u0930\u094D\u092D \u092D\u093E\u0935 \u0939\u0948\u0902, \u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u0947 \u0911\u092B\u0930 \u0928\u0939\u0940\u0902\u0964',
                          '\u0939\u094B\u092E\u091A\u0947 \u092A\u0930\u094D\u092F\u093E\u092F \u0906\u0921\u0935\u094D\u092F\u093E \u0930\u093E\u0902\u0917\u0947\u0924 \u0906\u0939\u0947\u0924. \u0906\u0923\u0916\u0940 \u092A\u0930\u094D\u092F\u093E\u092F\u093E\u0902\u0938\u093E\u0920\u0940 \u0930\u093E\u0902\u0917 \u0938\u0930\u0915\u0935\u093E. \u0916\u093E\u0932\u0940 \u0924\u093E\u0930\u0940\u0916 \u0905\u0938\u0932\u0947\u0932\u0947 \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B\u091A\u0947 \u0926\u0930 \u092A\u0939\u093E. \u0939\u0947 \u0938\u0902\u0926\u0930\u094D\u092D \u0926\u0930 \u0906\u0939\u0947\u0924, \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930\u093E\u0902\u091A\u0947 \u0911\u092B\u0930 \u0928\u093E\u0939\u0940\u0924.',
                        ),
                      ),
                    );
                  },
                ),
              ),
        );
      },
    ),
  );
}

/// Reference-inspired Home only. Other screens keep their current shared frame.
/// No fabricated pickups, distances, ratings, unread dots or impact metrics.
class CollectorDashboardView extends StatelessWidget {
  const CollectorDashboardView({
    required this.city,
    required this.onAction,
    required this.onCreateLot,
    required this.onCityChanged,
    required this.onHome,
    required this.onCamera,
    required this.onMessages,
    required this.onRetryPrices,
    required this.onSignOut,
    this.name,
    this.hour = 9,
    this.selectedId,
    this.prices,
    this.priceLoading = false,
    this.priceError = false,
    this.recordedThisWeek,
    this.receiptOverflow = false,
    this.message,
    this.scrollController,
    this.pricesKey,
    this.voiceControl,
    this.guide,
    super.key,
  });
  final String city;
  final String? name, selectedId, message;
  final int hour;
  final Map<String, dynamic>? prices;
  final bool priceLoading, priceError, receiptOverflow;
  final double? recordedThisWeek;
  final ValueChanged<String> onAction, onCreateLot, onCityChanged;
  final VoidCallback onHome, onCamera, onMessages, onRetryPrices, onSignOut;
  final ScrollController? scrollController;
  final GlobalKey? pricesKey;
  final Widget? voiceControl, guide;
  String get _name =>
      name ??
      ct(
        'Collector',
        '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915',
        '\u0938\u0902\u0915\u0932\u0915',
      );

  Widget _homeActions() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            ct('Home', '\u0939\u094B\u092E', '\u0939\u094B\u092E'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: collectorGreen,
            ),
          ),
        ),
        if (voiceControl != null) voiceControl!,
        IconButton(
          key: const ValueKey('dashboard_bell'),
          tooltip: ct(
            'Offers & messages',
            '\u0911\u092B\u0930 \u0914\u0930 \u0938\u0902\u0926\u0947\u0936',
            '\u0911\u092B\u0930 \u0935 \u0938\u0902\u0926\u0947\u0936',
          ),
          onPressed: onMessages,
          icon: const Icon(Icons.notifications_none, color: collectorGreen),
        ),
        IconButton(
          key: const ValueKey('dashboard_profile'),
          tooltip: ct(
            'Profile',
            '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932',
            '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932',
          ),
          onPressed: () => onAction('profile'),
          icon: const Icon(Icons.person_outline, color: collectorGreen),
        ),
        IconButton(
          key: const ValueKey('dashboard_sign_out'),
          tooltip: ct(
            'Sign out',
            '\u0938\u093E\u0907\u0928 \u0906\u0909\u091F',
            '\u0938\u093E\u0907\u0928 \u0906\u0909\u091F',
          ),
          onPressed: onSignOut,
          icon: const Icon(Icons.logout, color: collectorGreen),
        ),
      ],
    ),
  );

  // The registration illustration replaces the dashboard hero artwork.
  // Keep the real profile greeting without adding another oversized image.
  Widget _greeting() => Text(
    '${homeGreeting(hour)} $_name!',
    key: const ValueKey('dashboard_greeting'),
    style: const TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w800,
      height: 1.3,
      color: collectorGreen,
    ),
  );

  Widget _shortcut(String id, IconData icon, String title, String subtitle) {
    final selected = selectedId == id;
    return SizedBox(
      width: 142,
      child: Semantics(
        selected: selected,
        button: true,
        child: Card(
          key: ValueKey('dashboard_feature_$id'),
          margin: const EdgeInsets.only(right: 10),
          elevation: 0,
          color: selected ? collectorGreen : const Color(0xFFEEF8F1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onAction(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: selected ? Colors.white : collectorGreen,
                    child: Icon(
                      icon,
                      color: selected ? collectorGreen : Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF112A1B),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: selected ? Colors.white : const Color(0xFF65746C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _features() => SingleChildScrollView(
    key: const ValueKey('dashboard_features'),
    scrollDirection: Axis.horizontal,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _shortcut(
            'requests',
            Icons.assignment_outlined,
            ct(
              'New requests',
              '\u0928\u0908 \u092E\u093E\u0901\u0917',
              '\u0928\u0935\u0940\u0928 \u092E\u093E\u0917\u0923\u094D\u092F\u093E',
            ),
            ct(
              'Real recycler demand',
              '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0940 \u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u092E\u093E\u0901\u0917',
              '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0902\u091A\u0940 \u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u092E\u093E\u0917\u0923\u0940',
            ),
          ),
          _shortcut(
            'ledger',
            Icons.currency_rupee,
            recordedThisWeek == null
                ? ct(
                    'Receipts',
                    '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F\u092F\u093E\u0901',
                    '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940',
                  )
                : homeMoney(recordedThisWeek!),
            recordedThisWeek == null
                ? ct(
                    'View payment records',
                    '\u092D\u0941\u0917\u0924\u093E\u0928 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0926\u0947\u0916\u0947\u0902',
                    '\u092A\u0947\u092E\u0947\u0902\u091F \u0928\u094B\u0902\u0926\u0940 \u092A\u0939\u093E',
                  )
                : ct(
                    'Recorded this week',
                    '\u0907\u0938 \u0938\u092A\u094D\u0924\u093E\u0939 \u0926\u0930\u094D\u091C \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F',
                    '\u092F\u093E \u0906\u0920\u0935\u0921\u094D\u092F\u093E\u0924 \u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u0940 \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940',
                  ),
          ),
          _shortcut(
            'board',
            Icons.attach_money,
            ct(
              'Live price board',
              '\u0932\u093E\u0907\u0935 \u092D\u093E\u0935 \u092C\u094B\u0930\u094D\u0921',
              '\u0932\u093E\u0907\u0935\u094D\u0939 \u092D\u093E\u0935 \u092B\u0932\u0915',
            ),
            ct(
              'Admin-published city rates & estimate',
              '\u090F\u0921\u092E\u093F\u0928 \u0926\u094D\u0935\u093E\u0930\u093E \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0936\u0939\u0930 \u092D\u093E\u0935 \u0914\u0930 \u0905\u0928\u0941\u092E\u093E\u0928',
              '\u092A\u094D\u0930\u0936\u093E\u0938\u0915\u093E\u0928\u0947 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0915\u0947\u0932\u0947\u0932\u0947 \u0936\u0939\u0930 \u0926\u0930 \u0935 \u0905\u0902\u0926\u093E\u091C',
            ),
          ),
          _shortcut(
            'summaries',
            Icons.receipt_long_outlined,
            ct(
              'Summaries',
              '\u0938\u093E\u0930\u093E\u0902\u0936',
              '\u0938\u093E\u0930\u093E\u0902\u0936',
            ),
            ct(
              'Collection & earnings totals, dues',
              '\u0938\u0902\u0917\u094D\u0930\u0939 \u0914\u0930 \u0915\u092E\u093E\u0908 \u0915\u0947 \u091C\u094B\u0921\u093C, \u092C\u0915\u093E\u092F\u093E',
              '\u0938\u0902\u0915\u0932\u0928 \u0935 \u0915\u092E\u093E\u0908\u091A\u0940 \u092C\u0947\u0930\u0940\u091C, \u0925\u0915\u092C\u093E\u0915\u0940',
            ),
          ),
          _shortcut(
            'lots',
            Icons.inventory_2_outlined,
            ct(
              'My lots',
              '\u092E\u0947\u0930\u0947 \u0932\u0949\u091F',
              '\u092E\u093E\u091D\u0947 \u0932\u0949\u091F',
            ),
            ct(
              'Saved material & photos',
              '\u0938\u0939\u0947\u091C\u0940 \u0938\u093E\u092E\u093E\u0917\u094D\u0930\u0940 \u0914\u0930 \u092B\u094B\u091F\u094B',
              '\u091C\u0924\u0928 \u0938\u093E\u0939\u093F\u0924\u094D\u092F \u0935 \u092B\u094B\u091F\u094B',
            ),
          ),
          _shortcut(
            'sell',
            Icons.point_of_sale,
            ct(
              'Sell collection',
              '\u092E\u093E\u0932 \u092C\u0947\u091A\u0947\u0902',
              '\u092E\u093E\u0932 \u0935\u093F\u0915\u093E',
            ),
            ct(
              'Direct sell: quotes from verified recyclers',
              '\u0938\u0940\u0927\u0940 \u092C\u093F\u0915\u094D\u0930\u0940: \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E\u0913\u0902 \u0938\u0947 \u092D\u093E\u0935',
              '\u0925\u0947\u091F \u0935\u093F\u0915\u094D\u0930\u0940: \u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0902\u0915\u0921\u0942\u0928 \u0926\u0930',
            ),
          ),
          _shortcut(
            'directory',
            Icons.factory_outlined,
            ct(
              'Recyclers',
              '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E',
              '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u0947',
            ),
            ct(
              'Directory contacts',
              '\u0938\u0942\u091A\u0940 \u0915\u0947 \u0938\u0902\u092A\u0930\u094D\u0915',
              '\u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u093E \u0938\u0902\u092A\u0930\u094D\u0915',
            ),
          ),
          _shortcut(
            'offers',
            Icons.handshake_outlined,
            ct(
              'My offers',
              '\u092E\u0947\u0930\u0947 \u0911\u092B\u0930',
              '\u092E\u093E\u091D\u0947 \u0911\u092B\u0930',
            ),
            ct(
              'Quotes & handover',
              '\u092D\u093E\u0935 \u0914\u0930 \u0939\u0948\u0902\u0921\u0913\u0935\u0930',
              '\u0926\u0930 \u0935 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923',
            ),
          ),
          _shortcut(
            'sync',
            Icons.sync,
            ct(
              'Offline & sync',
              '\u0911\u092B\u0932\u093E\u0907\u0928 \u0914\u0930 \u0938\u093F\u0902\u0915',
              '\u0911\u092B\u0932\u093E\u0907\u0928 \u0935 \u0938\u093F\u0902\u0915',
            ),
            ct(
              'Pending records',
              '\u0932\u0902\u092C\u093F\u0924 \u0930\u093F\u0915\u0949\u0930\u094D\u0921',
              '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0928\u094B\u0902\u0926\u0940',
            ),
          ),
          _shortcut(
            'profile',
            Icons.person_outline,
            ct(
              'Profile',
              '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932',
              '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932',
            ),
            ct(
              'Language & recovery',
              '\u092D\u093E\u0937\u093E \u0914\u0930 \u0930\u093F\u0915\u0935\u0930\u0940',
              '\u092D\u093E\u0937\u093E \u0935 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940',
            ),
          ),
          _shortcut(
            'safety',
            Icons.health_and_safety_outlined,
            ct(
              'Safety',
              '\u0938\u0941\u0930\u0915\u094D\u0937\u093E',
              '\u0938\u0941\u0930\u0915\u094D\u0937\u093E',
            ),
            ct(
              'Safe handling tips',
              '\u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0938\u0901\u092D\u093E\u0932 \u0915\u0940 \u091C\u093E\u0928\u0915\u093E\u0930\u0940',
              '\u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u093E\u0924\u093E\u0933\u0923\u0940\u091A\u0940 \u092E\u093E\u0939\u093F\u0924\u0940',
            ),
          ),
          _shortcut(
            'prices',
            Icons.price_change_outlined,
            ct('Prices', '\u092D\u093E\u0935', '\u0926\u0930'),
            ct(
              'Rates on this page',
              '\u092D\u093E\u0935 \u0907\u0938\u0940 \u092A\u0947\u091C \u092A\u0930',
              '\u0926\u0930 \u092F\u093E\u091A \u092A\u0947\u091C\u0935\u0930',
            ),
          ),
        ],
      ),
    ),
  );

  Map? _rate(String material) {
    final latest = prices?['latest_prices'];
    final byCity = latest is Map ? latest[material] : null;
    final entry = byCity is Map ? byCity[city] : null;
    return entry is Map ? entry : null;
  }

  Widget _priceCard(String material, double scale) {
    final entry = _rate(material);
    final value = entry?['price'];
    final valid = value is num && value.isFinite && value > 0;
    final date = entry?['date'];
    final amount = valid
        ? homeMoney(value)
        : ct(
            'Rate unavailable',
            '\u092D\u093E\u0935 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902',
            '\u0926\u0930 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940',
          );
    Widget money() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          amount,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF11261A),
          ),
        ),
        if (valid)
          Text(
            ct(
              'per kg',
              '\u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B',
              '\u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7770)),
          ),
      ],
    );
    Widget button() => FilledButton(
      key: ValueKey('dashboard_create_$material'),
      onPressed: () => onCreateLot(material),
      style: FilledButton.styleFrom(
        backgroundColor: collectorGreen,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(
        ct(
          'Create lot',
          '\u0932\u0949\u091F \u092C\u0928\u093E\u090F\u0901',
          '\u0932\u0949\u091F \u0924\u092F\u093E\u0930 \u0915\u0930\u093E',
        ),
      ),
    );
    Widget details() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          materialLabel(material),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: Color(0xFF6F7C87),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                city,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6F7C87)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${ct('Rate date', '\u092D\u093E\u0935 \u0915\u0940 \u0924\u093E\u0930\u0940\u0916', '\u0926\u0930\u093E\u091A\u0940 \u0924\u093E\u0930\u0940\u0916')}: ${date is String ? date : ct('Not supplied', '\u0928\u0939\u0940\u0902 \u0926\u0940 \u0917\u0908', '\u0926\u093F\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940')}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6F7C87)),
        ),
      ],
    );
    return Container(
      key: ValueKey('dashboard_rate_$material'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D164B2A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 300 || scale > 1.3)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      MaterialPhoto(material: material, width: 64, height: 68),
                      const SizedBox(width: 10),
                      Expanded(child: details()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [money(), button()],
                  ),
                ],
              );
            return Row(
              children: [
                MaterialPhoto(material: material, width: 66, height: 72),
                const SizedBox(width: 10),
                Expanded(child: details()),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [money(), const SizedBox(height: 7), button()],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: collectorGreen),
      textTheme: Theme.of(context).textTheme.merge(
        const TextTheme(
          bodyMedium: TextStyle(fontWeight: FontWeight.w600),
          labelLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: collectorCream,
      bottomNavigationBar: CollectorHomeNavigation(
        onHome: onHome,
        onCamera: onCamera,
        onMessages: onMessages,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _homeActions(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => ListView(
                  key: const ValueKey('dashboard_scroll'),
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: bounds.maxWidth > 760 ? 760 : bounds.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CollectorArtwork(
                              key: const ValueKey(
                                'dashboard_registration_header',
                              ),
                              greeting: '${homeGreeting(hour)} $_name!',
                            ),
                            if (guide != null) guide!,
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: _features(),
                            ),
                            if (recordedThisWeek != null || receiptOverflow)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  0,
                                ),
                                child: Text(
                                  receiptOverflow
                                      ? ct(
                                          'More than 100 weekly records: open the ledger. Weekly total is not shown.',
                                          '\u0938\u092A\u094D\u0924\u093E\u0939 \u092E\u0947\u0902 100 \u0938\u0947 \u0905\u0927\u093F\u0915 \u0930\u093F\u0915\u0949\u0930\u094D\u0921: \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0916\u093E\u0924\u093E \u0916\u094B\u0932\u0947\u0902\u0964 \u0938\u093E\u092A\u094D\u0924\u093E\u0939\u093F\u0915 \u0915\u0941\u0932 \u0928\u0939\u0940\u0902 \u0926\u093F\u0916\u093E\u092F\u093E \u0917\u092F\u093E \u0939\u0948\u0964',
                                          '\u0906\u0920\u0935\u0921\u094D\u092F\u093E\u0924 100 \u092A\u0947\u0915\u094D\u0937\u093E \u091C\u093E\u0938\u094D\u0924 \u0928\u094B\u0902\u0926\u0940: \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0916\u093E\u0924\u0947 \u0909\u0918\u0921\u093E. \u0938\u093E\u092A\u094D\u0924\u093E\u0939\u093F\u0915 \u092C\u0947\u0930\u0940\u091C \u0926\u093E\u0916\u0935\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940.',
                                        )
                                      : ct(
                                          'Receipt amounts are collector-recorded, not bank verified.',
                                          '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0930\u093E\u0936\u093F \u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0915\u0940 \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F \u0939\u0948, \u092C\u0948\u0902\u0915 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902\u0964',
                                          '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0930\u0915\u094D\u0915\u092E \u0938\u0902\u0915\u0932\u0915\u093E\u091A\u0940 \u0928\u094B\u0902\u0926 \u0906\u0939\u0947, \u092C\u0901\u0915 \u092A\u094D\u0930\u092E\u093E\u0923\u0940 \u0928\u093E\u0939\u0940.',
                                        ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6F7C87),
                                  ),
                                ),
                              ),
                            if (message != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  0,
                                ),
                                child: Text(
                                  message!,
                                  style: const TextStyle(
                                    color: Color(0xFF875121),
                                  ),
                                ),
                              ),
                            Padding(
                              key: pricesKey,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                22,
                                16,
                                10,
                              ),
                              child: Text(
                                ct(
                                  'Material prices',
                                  '\u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u0915\u0947 \u092D\u093E\u0935',
                                  '\u0938\u093E\u0939\u093F\u0924\u094D\u092F\u093E\u091A\u0947 \u0926\u0930',
                                ),
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('dashboard_city_$city'),
                                initialValue: city,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: ct(
                                    'Price location',
                                    '\u092D\u093E\u0935 \u0915\u093E \u0936\u0939\u0930',
                                    '\u0926\u0930\u093E\u091A\u0947 \u0936\u0939\u0930',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.location_on_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                items: collectorCities
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) onCityChanged(v);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                10,
                                18,
                                12,
                              ),
                              child: Text(
                                ct(
                                  'Reference rates in INR/kg from your dataset. Check the date: these are not live buyer offers or guaranteed sale prices. Images illustrate categories.',
                                  '\u0906\u092A\u0915\u0947 \u0921\u0947\u091F\u093E\u0938\u0947\u091F \u0915\u0947 \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u0938\u0902\u0926\u0930\u094D\u092D \u092D\u093E\u0935\u0964 \u0924\u093E\u0930\u0940\u0916 \u091C\u093E\u0901\u091A\u0947\u0902: \u092F\u0947 \u0932\u093E\u0907\u0935 \u0916\u0930\u0940\u0926\u093E\u0930 \u0911\u092B\u0930 \u092F\u093E \u092C\u093F\u0915\u094D\u0930\u0940 \u0915\u0940 \u0917\u093E\u0930\u0902\u091F\u0940 \u0928\u0939\u0940\u0902 \u0939\u0948\u0902\u0964 \u092B\u094B\u091F\u094B \u0936\u094D\u0930\u0947\u0923\u0940 \u0915\u0947 \u0909\u0926\u093E\u0939\u0930\u0923 \u0939\u0948\u0902\u0964',
                                  '\u0924\u0941\u092E\u091A\u094D\u092F\u093E \u0921\u0947\u091F\u093E\u0938\u0947\u091F\u091A\u094D\u092F\u093E \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u0938\u0902\u0926\u0930\u094D\u092D \u0926\u0930. \u0924\u093E\u0930\u0940\u0916 \u0924\u092A\u093E\u0938\u093E: \u0939\u0947 \u0932\u093E\u0907\u0935\u094D\u0939 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0911\u092B\u0930 \u0915\u093F\u0902\u0935\u093E \u0935\u093F\u0915\u094D\u0930\u0940\u091A\u0940 \u0939\u092E\u0940 \u0928\u093E\u0939\u0940\u0924. \u092B\u094B\u091F\u094B \u0936\u094D\u0930\u0947\u0923\u0940\u091A\u094D\u092F\u093E \u0909\u0926\u093E\u0939\u0930\u0923\u0947 \u0906\u0939\u0947\u0924.',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF6F7C87),
                                ),
                              ),
                            ),
                            if (priceLoading)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: LinearProgressIndicator(),
                              ),
                            if (priceError)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      ct(
                                        'Price file could not load. Check assets/data/price_dataset.json.',
                                        '\u092D\u093E\u0935 \u0915\u0940 \u092B\u093C\u093E\u0907\u0932 \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u0940\u0964 assets/data/price_dataset.json \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                                        '\u0926\u0930 \u092B\u093E\u0907\u0932 \u0909\u0918\u0921\u0932\u0940 \u0928\u093E\u0939\u0940. assets/data/price_dataset.json \u0924\u092A\u093E\u0938\u093E.',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: onRetryPrices,
                                      child: Text(
                                        ct(
                                          'Retry prices',
                                          '\u092D\u093E\u0935 \u092B\u093F\u0930 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902',
                                          '\u0926\u0930 \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0921 \u0915\u0930\u093E',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ...collectorMaterials.map(
                              (m) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _priceCard(
                                  m,
                                  MediaQuery.textScalerOf(context).scale(14) /
                                      14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const CollectorFooter(
                              key: ValueKey('dashboard_registration_footer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pure menu: all nine cards exist independently of any Firestore result.
class CollectorHomeMenu extends StatelessWidget {
  const CollectorHomeMenu({
    required this.onOpen,
    this.selectedId,
    this.profile = const SizedBox.shrink(),
    super.key,
  });
  final void Function(String id, Widget page) onOpen;
  final String? selectedId;
  final Widget profile;
  Widget _tile(
    String id,
    String label,
    String detail,
    IconData icon,
    Widget page,
  ) {
    final selected = selectedId == id;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        key: ValueKey('home_card_$id'),
        color: selected ? collectorGreen : const Color(0xFFEDF7EF),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(id, page),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: selected ? Colors.white : collectorGreen,
                  child: Icon(
                    icon,
                    color: selected ? collectorGreen : Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : collectorGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: selected ? Colors.white : collectorGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      profile,
      _tile(
        'lots',
        ct(
          'My lots',
          '\u092E\u0947\u0930\u0947 \u0932\u0949\u091F',
          '\u092E\u093E\u091D\u0947 \u0932\u0949\u091F',
        ),
        ct(
          'Drafts, photos and synced lot status',
          '\u0921\u094D\u0930\u093E\u092B\u094D\u091F, \u092B\u094B\u091F\u094B \u0914\u0930 \u0938\u093F\u0902\u0915 \u0938\u094D\u0925\u093F\u0924\u093F',
          '\u0921\u094D\u0930\u093E\u092B\u094D\u091F, \u092B\u094B\u091F\u094B \u0935 \u0938\u093F\u0902\u0915 \u0938\u094D\u0925\u093F\u0924\u0940',
        ),
        Icons.inventory_2_outlined,
        const LotsScreen(),
      ),
      _tile(
        'prices',
        ct(
          'Reference prices',
          '\u0938\u0902\u0926\u0930\u094D\u092D \u092D\u093E\u0935',
          '\u0938\u0902\u0926\u0930\u094D\u092D \u0926\u0930',
        ),
        ct(
          'Dated dataset, not live offers',
          '\u0924\u093E\u0930\u0940\u0916 \u0935\u093E\u0932\u0947 \u0906\u0901\u0915\u0921\u093C\u0947, \u0932\u093E\u0907\u0935 \u0911\u092B\u0930 \u0928\u0939\u0940\u0902',
          '\u0924\u093E\u0930\u0940\u0916 \u0905\u0938\u0932\u0947\u0932\u0947 \u0906\u0915\u0921\u0947, \u0932\u093E\u0907\u0935\u094D\u0939 \u0911\u092B\u0930 \u0928\u093E\u0939\u0940\u0924',
        ),
        Icons.price_change_outlined,
        const PricesScreen(),
      ),
      _tile(
        'requests',
        ct(
          'Buyer requests',
          '\u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u0940 \u092E\u093E\u0901\u0917',
          '\u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930\u093E\u0902\u091A\u094D\u092F\u093E \u092E\u093E\u0917\u0923\u094D\u092F\u093E',
        ),
        ct(
          'Send a selected lot to real demand',
          '\u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u092E\u093E\u0901\u0917 \u092E\u0947\u0902 \u091A\u0941\u0928\u093E \u0932\u0949\u091F \u092D\u0947\u091C\u0947\u0902',
          '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u092E\u093E\u0917\u0923\u0940\u0932\u093E \u0928\u093F\u0935\u0921\u0932\u0947\u0932\u093E \u0932\u0949\u091F \u092A\u093E\u0920\u0935\u093E',
        ),
        Icons.campaign_outlined,
        const RecyclerRequestsScreen(),
      ),
      _tile(
        'offers',
        ct(
          'My offers & handover',
          '\u092E\u0947\u0930\u0947 \u0911\u092B\u0930 \u0914\u0930 \u0939\u0948\u0902\u0921\u0913\u0935\u0930',
          '\u092E\u093E\u091D\u0947 \u0911\u092B\u0930 \u0935 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923',
        ),
        ct(
          'Quotes, acceptance, QR and confirmation',
          '\u092D\u093E\u0935, \u0938\u094D\u0935\u0940\u0915\u0943\u0924\u093F, QR \u0914\u0930 \u092A\u0941\u0937\u094D\u091F\u093F',
          '\u0926\u0930, \u0938\u094D\u0935\u0940\u0915\u093E\u0930, QR \u0935 \u092A\u0941\u0937\u094D\u091F\u0940',
        ),
        Icons.handshake_outlined,
        const MyOffersScreen(),
      ),
      _tile(
        'directory',
        ct(
          'Recycler directory',
          '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0938\u0942\u091A\u0940',
          '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u093E',
        ),
        ct(
          'Supplied business contacts; review required',
          '\u0926\u093F\u090F \u0935\u094D\u092F\u093E\u092A\u093E\u0930\u093F\u0915 \u0938\u0902\u092A\u0930\u094D\u0915; \u091C\u093E\u0901\u091A \u091C\u093C\u0930\u0942\u0930\u0940',
          '\u0926\u093F\u0932\u0947\u0932\u0947 \u0935\u094D\u092F\u093E\u0935\u0938\u093E\u092F\u093F\u0915 \u0938\u0902\u092A\u0930\u094D\u0915; \u0924\u092A\u093E\u0938\u0923\u0940 \u0906\u0935\u0936\u094D\u092F\u0915',
        ),
        Icons.factory_outlined,
        const RecyclerDirectoryScreen(),
      ),
      _tile(
        'ledger',
        ct(
          'Receipts & earnings records',
          '\u0930\u0938\u0940\u0926\u0947\u0902 \u0914\u0930 \u0906\u092F \u0930\u093F\u0915\u0949\u0930\u094D\u0921',
          '\u092A\u093E\u0935\u0924\u094D\u092F\u093E \u0935 \u0915\u092E\u093E\u0908 \u0928\u094B\u0902\u0926\u0940',
        ),
        ct(
          'Collector statements, not bank verification',
          '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0915\u0940 \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F\u092F\u093E\u0901, \u092C\u0948\u0902\u0915 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902',
          '\u0938\u0902\u0915\u0932\u0915\u093E\u091A\u094D\u092F\u093E \u0928\u094B\u0902\u0926\u0940, \u092C\u0901\u0915 \u092A\u094D\u0930\u092E\u093E\u0923\u0940 \u0928\u093E\u0939\u0940',
        ),
        Icons.receipt_long_outlined,
        const LedgerScreen(),
      ),
      _tile(
        'sync',
        ct(
          'Offline & sync',
          '\u0911\u092B\u0932\u093E\u0907\u0928 \u0914\u0930 \u0938\u093F\u0902\u0915',
          '\u0911\u092B\u0932\u093E\u0907\u0928 \u0935 \u0938\u093F\u0902\u0915',
        ),
        ct(
          'Review and retry queued records',
          '\u0915\u0924\u093E\u0930 \u0926\u0947\u0916\u0947\u0902 \u0914\u0930 \u092B\u093F\u0930 \u092D\u0947\u091C\u0947\u0902',
          '\u0930\u093E\u0902\u0917 \u0924\u092A\u093E\u0938\u093E \u0935 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093E',
        ),
        Icons.sync,
        const SyncScreen(),
      ),
      _tile(
        'profile',
        ct(
          'Profile & recovery',
          '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0914\u0930 \u0930\u093F\u0915\u0935\u0930\u0940',
          '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u0935 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940',
        ),
        ct(
          'Same account, language and optional email linking',
          '\u0935\u0939\u0940 \u0916\u093E\u0924\u093E, \u092D\u093E\u0937\u093E \u0914\u0930 \u0935\u0948\u0915\u0932\u094D\u092A\u093F\u0915 \u0908\u092E\u0947\u0932 \u0932\u093F\u0902\u0915',
          '\u0924\u0947\u091A \u0916\u093E\u0924\u0947, \u092D\u093E\u0937\u093E \u0935 \u092A\u0930\u094D\u092F\u093E\u092F\u0940 \u0908\u092E\u0947\u0932 \u0932\u093F\u0902\u0915',
        ),
        Icons.person_outline,
        const ProfileScreen(),
      ),
      _tile(
        'safety',
        ct(
          'Safety & help',
          '\u0938\u0941\u0930\u0915\u094D\u0937\u093E \u0914\u0930 \u0938\u0939\u093E\u092F\u0924\u093E',
          '\u0938\u0941\u0930\u0915\u094D\u0937\u093E \u0935 \u092E\u0926\u0924',
        ),
        ct(
          'Safe handling and fraud prevention',
          '\u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0938\u0901\u092D\u093E\u0932 \u0914\u0930 \u0927\u094B\u0916\u093E\u0927\u0921\u093C\u0940 \u0938\u0947 \u092C\u091A\u093E\u0935',
          '\u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u093E\u0924\u093E\u0933\u0923\u0940 \u0935 \u092B\u0938\u0935\u0923\u0942\u0915 \u092A\u094D\u0930\u0924\u093F\u092C\u0902\u0927',
        ),
        Icons.health_and_safety_outlined,
        const SafetyScreen(),
      ),
    ],
  );
}

class CollectorHomeNavigation extends StatelessWidget {
  const CollectorHomeNavigation({
    required this.onHome,
    required this.onCamera,
    required this.onMessages,
    super.key,
  });
  final VoidCallback onHome, onCamera, onMessages;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: collectorCream,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: const ValueKey('home_nav_home'),
              onPressed: onHome,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home, size: 30),
                  Text(
                    ct('Home', '\u0939\u094B\u092E', '\u0939\u094B\u092E'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              heightFactor: 1,
              child: Semantics(
                label: ct(
                  'Create lot with camera',
                  '\u0915\u0948\u092E\u0930\u0947 \u0938\u0947 \u0932\u0949\u091F \u092C\u0928\u093E\u090F\u0901',
                  '\u0915\u0945\u092E\u0947\u0931\u094D\u092F\u093E\u0928\u0947 \u0932\u0949\u091F \u0924\u092F\u093E\u0930 \u0915\u0930\u093E',
                ),
                button: true,
                child: IconButton.filled(
                  key: const ValueKey('home_nav_camera'),
                  style: IconButton.styleFrom(
                    backgroundColor: collectorGreen,
                    minimumSize: const Size(66, 66),
                    shape: const CircleBorder(),
                  ),
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt, size: 32),
                ),
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              key: const ValueKey('home_nav_messages'),
              onPressed: onMessages,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 30),
                  Text(
                    ct(
                      'Messages',
                      '\u0938\u0902\u0926\u0947\u0936',
                      '\u0938\u0902\u0926\u0947\u0936',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Receipt ledger',
      '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0916\u093E\u0924\u093E',
      '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0916\u093E\u0924\u0947',
    ),
    guide: () => ct(
      'These are your recorded receipt statements, not bank verified earnings.',
      '\u092F\u0947 \u0906\u092A\u0915\u0947 \u0926\u0930\u094D\u091C \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u092C\u092F\u093E\u0928 \u0939\u0948\u0902, \u092C\u0948\u0902\u0915 \u0938\u0947 \u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0906\u092F \u0928\u0939\u0940\u0902\u0964',
      '\u092F\u093E \u0924\u0941\u092E\u091A\u094D\u092F\u093E \u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u094D\u092F\u093E \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0906\u0939\u0947\u0924, \u092C\u0901\u0915 \u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0915\u092E\u093E\u0908 \u0928\u093E\u0939\u0940.',
    ),
    body: (_) => const ReceiptList(),
  );
}

class SellCameraScreen extends StatelessWidget {
  const SellCameraScreen({required this.city, this.initialMaterial, super.key});
  final String city;
  final String? initialMaterial;
  @override
  Widget build(BuildContext context) =>
      LotEditor(value: {'city': city, 'material': initialMaterial});
}
