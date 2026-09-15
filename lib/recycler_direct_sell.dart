import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_speech.dart';
import 'direct_sell_quotes.dart';
import 'direct_sell_selection.dart';
import 'direct_sell_handover.dart';
import 'direct_sell_receipts.dart';
import 'recycler_demand.dart';
import 'recycler_authorization.dart';
import 'quick_profile_service.dart';

const _cream = Color(0xFFFFFAEF);
const _green = Color(0xFF286B3B);

const List<String> kDirectSellMaterials = <String>[
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

const List<String> kDirectSellCities = <String>[
  'Amritsar',
  'Jalandhar',
  'Ludhiana',
  'Mumbai',
  'Pune',
];

/// Sprint1A recycler dashboard: REAL open collector listings, real immutable
/// quotes, own quote history. Requires an actual recycler profile with
/// server-confirmed authorizationStatus == 'verified'. Pending/rejected
/// states are shown honestly; this app can never self-approve.
///
/// Not included in this slice (later sprints): winner selection, lot
/// reservation, handover, receipts, direct-sale chat, notifications.
class RecyclerDirectSellScreen extends StatefulWidget {
  const RecyclerDirectSellScreen({required this.result, super.key});
  final QuickProfileResult result;

  @override
  State<RecyclerDirectSellScreen> createState() =>
      _RecyclerDirectSellScreenState();
}

class _RecyclerDirectSellScreenState extends State<RecyclerDirectSellScreen> {
  final DirectSellQuoteService _service = DirectSellQuoteService();
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  int _feedLimit = kFeedPageSize;
  int _quoteLimit = kFeedPageSize;
  String? _material;
  String? _city;
  String _query = '';
  bool _hideExpired = false;
  bool _showAll = false;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _cream,
          body: SafeArea(
            top: true,
            child: uid == null
                ? _message(
                    _t(
                      'Session unavailable. Restart the app without clearing data.',
                      'सेशन उपलब्ध नहीं। डेटा मिटाए बिना ऐप फिर खोलें।',
                      'सत्र उपलब्ध नाही. डेटा न पुसता अॅप पुन्हा उघडा.',
                    ),
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .snapshots(includeMetadataChanges: true),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _message(
                          _t(
                            'Profile check failed. Check internet and published rules, then retry.',
                            'प्रोफ़ाइल जाँच विफल। इंटरनेट और नियम जाँचकर फिर कोशिश करें।',
                            'प्रोफाइल तपासणी अयशस्वी. इंटरनेट व नियम तपासून पुन्हा प्रयत्न करा.',
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final profile = snap.data!.data();
                      if (profile == null) {
                        return _message(
                          _t(
                            'Profile not found on the server for this account.',
                            'इस खाते की प्रोफ़ाइल सर्वर पर नहीं मिली।',
                            'या खात्याचे प्रोफाइल सर्व्हरवर सापडले नाही.',
                          ),
                        );
                      }
                      if (profile['role'] != 'recycler') {
                        return _message(
                          _t(
                            'This dashboard is for recycler accounts only.',
                            'यह डैशबोर्ड केवल रीसायकलकर्ता खातों के लिए है।',
                            'हे डॅशबोर्ड फक्त रीसायकलर खात्यांसाठी आहे.',
                          ),
                        );
                      }
                      final status = profile['authorizationStatus'];
                      final name = profile['name'] is String
                          ? profile['name'] as String
                          : '';
                      if (status != 'verified') {
                        return _statusScreen(status == 'rejected', name);
                      }
                      return _dashboard(uid, name);
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _message(String text) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 54, color: _green),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );

  /// Honest pending/rejected screen. Approval is a real admin decision in
  /// Firebase; the app shows the state and cannot change it.
  Widget _statusScreen(bool rejected, String name) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Icon(
            rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
            size: 64,
            color: rejected ? const Color(0xFF9C2929) : _green,
          ),
          const SizedBox(height: 14),
          if (name.isNotEmpty)
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          const SizedBox(height: 10),
          Text(
            rejected
                ? _t(
                    'Your recycler account was NOT approved. You cannot see listings or send quotes. Contact the project administrator.',
                    'आपका रीसायकलकर्ता खाता स्वीकृत नहीं हुआ। आप लिस्टिंग नहीं देख सकते और quote नहीं भेज सकते। प्रोजेक्ट एडमिन से संपर्क करें।',
                    'तुमचे रीसायकलर खाते मंजूर झाले नाही. तुम्ही यादी पाहू शकत नाही किंवा कोट पाठवू शकत नाही. प्रकल्प प्रशासकाशी संपर्क करा.',
                  )
                : _t(
                    'Your recycler account is waiting for approval. Approval is done by the project administrator, not by this app. Once approved, open listings and quoting start here automatically.',
                    'आपका रीसायकलकर्ता खाता स्वीकृति की प्रतीक्षा में है। स्वीकृति प्रोजेक्ट एडमिन देता है, यह ऐप नहीं। स्वीकृति मिलते ही लिस्टिंग और quote यहाँ अपने आप शुरू हो जाएँगे।',
                    'तुमच्या रीसायकलर खात्याची मंजुरी प्रतीक्षेत आहे. मंजुरी प्रकल्प प्रशासक देतो, हे अॅप नाही. मंजुरी मिळताच यादी आणि कोट येथे आपोआप सुरू होतील.',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0CB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _t(
                'This screen never approves accounts by itself. Registration does not equal authorization.',
                'यह स्क्रीन स्वयं खाते स्वीकृत नहीं करती। पंजीकरण का मतलब स्वीकृति नहीं है।',
                'ही स्क्रीन स्वतः खाती मंजूर करत नाही. नोंदणी म्हणजे मंजुरी नव्हे.',
              ),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ── cp121 redesign: brand dashboard shell (real data only) ─────────
  Widget _dashboard(String uid, String name) {
    return Scaffold(
      backgroundColor: _cream,
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _brandBar(uid, name),
            Expanded(
              child: _tab == 0
                  ? _home(uid, name)
                  : _tab == 1
                  ? _listings()
                  : _tab == 2
                  ? _myQuotes(uid)
                  : const RecyclerDemandScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x20286B3B),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, _t('Home', 'होम', 'होम')),
              _navItem(
                1,
                Icons.storefront_outlined,
                _t('Listings', 'लिस्टिंग', 'लिस्टिंग'),
              ),
              _navItem(
                2,
                Icons.receipt_long_outlined,
                _t('My quotes', 'मेरे भाव', 'माझे भाव'),
              ),
              _navItem(
                3,
                Icons.shopping_bag_outlined,
                _t('Demand', 'माँग', 'मागणी'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final sel = _tab == index;
    final grey = const Color(0xFF8A9188);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: spokenAction(() => label, () => setState(() => _tab = index)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: sel ? _green : grey, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: sel ? _green : grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandBar(String uid, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 2),
      child: Row(
        children: [
          _assetImg(
            'assets/images/recycler_logo.png',
            42,
            42,
            Icons.eco_outlined,
            radius: 10,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Kabadi Connect', 'कबड़ी कनेक्ट', 'कबडी कनेक्ट'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2B22),
                  ),
                ),
                Text(
                  _t(
                    'Behtar Kal, Saaf Kal',
                    'बेहतर कल, साफ़ कल',
                    'चांगले उद्या, स्वच्छ उद्या',
                  ),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const SpeechFeedbackButton(),
          _bell(uid),
          InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecyclerAccountScreen()),
            ),
            child: _assetImg(
              'assets/images/recycler_avatar.png',
              38,
              38,
              Icons.person,
              radius: 19,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2B22),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _t('Recycler', 'रीसायकलकर्ता', 'रीसायकलर'),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7C8B80),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF1E2B22),
            ),
            itemBuilder: (c) => [
              PopupMenuItem(
                value: 'back',
                child: Text(_t('Back', 'वापस', 'मागे')),
              ),
              PopupMenuItem(
                value: 'out',
                child: Text(_t('Sign out', 'साइन आउट', 'साइन आउट')),
              ),
            ],
            onSelected: (v) {
              if (v == 'back') {
                Navigator.of(context).maybePop();
              } else {
                _confirmSignOut(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _bell(String uid) {
    return FutureBuilder<int>(
      future: _pendingConfirmCount(uid),
      builder: (context, s) {
        final n = s.data ?? 0;
        return Stack(
          children: [
            IconButton(
              tooltip: _t(
                'Needs your confirmation',
                'आपकी पुष्टि का इंतज़ार',
                'तुमच्या पुष्टीची वाट',
              ),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF1E2B22),
                size: 24,
              ),
              onPressed: spokenAction(
                () => _t('Incoming materials', 'आने वाला माल', 'येणारा माल'),
                () => setState(() => _tab = 0),
              ),
            ),
            if (n > 0)
              Positioned(
                right: 8,
                top: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD33A2C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<int> _pendingConfirmCount(String uid) async {
    try {
      final s = await FirebaseFirestore.instance
          .collection('collectorSellRequests')
          .where('selectedRecyclerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'handoverPending')
          .limit(50)
          .get();
      return s.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Widget _home(String uid, String name) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadHomeData(uid),
      builder: (context, s) {
        if (s.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hero(name),
              const SizedBox(height: 14),
              _errorBox('${s.error}'),
            ],
          );
        }
        if (!s.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hero(name),
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final d = s.data!;
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _hero(name),
            const SizedBox(height: 14),
            _stats(d),
            const SizedBox(height: 18),
            _incoming(d),
          ],
        );
      },
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return _t('Good Morning', 'सुप्रभात', 'शुभ सकाळ');
    if (h < 17) return _t('Good Afternoon', 'नमस्ते', 'शुभ दुपार');
    return _t('Good Evening', 'शुभ संध्या', 'शुभ संध्याकाळ');
  }

  Widget _hero(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9F6EC), Color(0xFFCFE9D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 10, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _greeting() + ',',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF274231),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.isEmpty
                        ? _t('Recycler', 'रीसायकलकर्ता', 'रीसायकलर')
                        : name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      "Turn today's scrap into a better tomorrow.",
                      'आज का कबाड़, बेहतर कल।',
                      'आजची रद्दी, चांगले उद्या.',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF33513E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: _green,
                    borderRadius: BorderRadius.circular(26),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: spokenAction(
                        () => _t(
                          'Incoming materials',
                          'आने वाला माल',
                          'येणारा माल',
                        ),
                        () {
                          if (_scroll.hasClients) {
                            _scroll.animateTo(
                              _scroll.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _t(
                                'View Incoming Waste',
                                'आने वाला माल देखें',
                                'येणारा माल पहा',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 48,
            child: Image.asset(
              'assets/images/recycler_hero.png',
              fit: BoxFit.cover,
              height: 230,
              errorBuilder: (c, e, st) => const SizedBox(width: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(Map<String, dynamic> d) {
    final pending = d['pending'] is int ? d['pending'] as int : 0;
    final todayKg = d['todayKg'] is num ? d['todayKg'] as num : 0;
    final doneToday = d['doneToday'] is int ? d['doneToday'] as int : 0;
    final totalKg = d['totalKg'] is num ? d['totalKg'] as num : 0;
    return Row(
      children: [
        _statTile(
          Icons.inventory_2_outlined,
          '$pending',
          _t('Pending Materials', 'पेंडिंग माल', 'प्रलंबित माल'),
          _t('Awaiting handover', 'हैंडओवर का इंतज़ार', 'हस्तांतरणाची वाट'),
        ),
        _statTile(
          Icons.recycling_rounded,
          _kgLabel(todayKg) + ' kg',
          _t('Processed Today', 'आज प्रोसेस', 'आज प्रक्रिया'),
          '+$doneToday ' + _t('deals', 'सौदे', 'सौदे'),
        ),
        _statTile(
          Icons.currency_rupee_rounded,
          '₹ —',
          _t('Revenue This Month', 'इस माह की आय', 'या महिन्याचे उत्पन्न'),
          _t(
            'After receipts (Sprint 1D)',
            'रसीदों के बाद (Sprint 1D)',
            'पावतीनंतर (Sprint 1D)',
          ),
        ),
        _statTile(
          Icons.eco_outlined,
          _kgLabel(totalKg) + ' kg',
          _t('Total Received', 'कुल प्राप्त', 'एकूण प्राप्त'),
          _t('All time confirmed', 'अब तक पुष्ट', 'आत्तापर्यंत पुष्टी'),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, String sub) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF7EF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2B22),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF41544A),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 9, color: Color(0xFF7C8B80)),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incoming(Map<String, dynamic> d) {
    final rows = List<Map<String, dynamic>>.from(d['rows'] as List);
    final all = List<Map<String, dynamic>>.from(d['all'] as List);
    final shown = _showAll ? all : rows.take(4).toList();
    return Column(
      children: [
        Row(
          children: [
            Text(
              _t('Incoming Materials', 'आने वाला माल', 'येणारा माल'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E2B22),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: spokenAction(
                () => _t('See all', 'सभी देखें', 'सर्व पहा'),
                () => setState(() => _showAll = !_showAll),
              ),
              child: Row(
                children: [
                  Text(
                    _showAll
                        ? _t('Show less', 'कम देखें', 'कमी पहा')
                        : _t('See All', 'सभी देखें', 'सर्व पहा'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: _green,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (shown.isEmpty)
          _emptyBox(
            _t(
              'No selected deals yet. Quote on open listings to get selected.',
              'अभी कोई चुना हुआ सौदा नहीं। खुली लिस्टिंग पर भाव दें।',
              'अद्याप निवडलेला सौदा नाही. खुल्या लिस्टिंगवर भाव द्या.',
            ),
          ),
        ...shown.map(_dealRow),
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7C8B80)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Color(0xFF66756B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dealRow(Map<String, dynamic> m) {
    final status = '${m['status']}';
    final material = '${m['material'] ?? ''}';
    final city = '${m['city'] ?? ''}';
    final listedKg = m['weightKg'] is num ? m['weightKg'] as num : 0;
    final finalKg = m['finalKg'] is num ? m['finalKg'] as num : null;
    final kg = (status == 'reserved' || finalKg == null) ? listedKg : finalKg;
    final rate = m['selectedRatePaise'] is num
        ? m['selectedRatePaise'] as num
        : 0;
    final paiseTotal = (kg * rate).round();
    final ts = m['selectedAt'] is Timestamp
        ? m['selectedAt'] as Timestamp
        : (m['publishedAt'] is Timestamp
              ? m['publishedAt'] as Timestamp
              : null);
    final pending = status == 'handoverPending';
    final done = status == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 1.5,
        shadowColor: const Color(0x30286B3B),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: spokenAction(() => material, () => _openDeal('${m['id']}')),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _assetImg(
                  'assets/images/${material.toLowerCase()}.png',
                  62,
                  62,
                  Icons.category_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              material,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF1E2B22),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4F3E6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '~ ${_kgLabel(kg)} kg',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _meta(Icons.place_outlined, city),
                      _meta(
                        Icons.person_outline,
                        _t('Collector deal', 'कलेक्टर सौदा', 'कलेक्टर सौदा'),
                      ),
                      if (ts != null)
                        _meta(Icons.schedule_outlined, dateLabel(ts)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _t('Est. Value', 'अनु. मूल्य', 'अंदाजे मूल्य'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7C8B80),
                      ),
                    ),
                    Text(
                      '₹ ${formatPaiseAsRupees(paiseTotal)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2B22),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: done ? const Color(0xFFD9EDDB) : _green,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: spokenAction(
                          () => material,
                          () => _openDeal('${m['id']}'),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                done
                                    ? _t('Accepted', 'स्वीकृत', 'स्वीकृत')
                                    : pending
                                    ? _t('Verify', 'पुष्टि करें', 'पुष्टी करा')
                                    : _t('View', 'देखें', 'पहा'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: done ? _green : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: done ? _green : Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDeal(String saleId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DealDetailPage(saleId: saleId)));
  }

  Future<Map<String, dynamic>> _loadHomeData(String uid) async {
    final db = FirebaseFirestore.instance;
    final active = await db
        .collection('collectorSellRequests')
        .where('selectedRecyclerUid', isEqualTo: uid)
        .where('status', whereIn: ['reserved', 'handoverPending'])
        .limit(100)
        .get();
    final done = await db
        .collection('collectorSellRequests')
        .where('selectedRecyclerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .limit(100)
        .get();
    int pending = 0;
    num todayKg = 0;
    num totalKg = 0;
    int doneToday = 0;
    final now = DateTime.now();
    final rows = <Map<String, dynamic>>[];
    final all = <Map<String, dynamic>>[];
    for (final doc in active.docs) {
      final m = Map<String, dynamic>.from(doc.data());
      m['id'] = doc.id;
      if (m['status'] == 'handoverPending') pending++;
      rows.add(m);
      all.add(m);
    }
    rows.sort(
      (a, b) => (a['status'] == 'handoverPending' ? 0 : 1).compareTo(
        b['status'] == 'handoverPending' ? 0 : 1,
      ),
    );
    for (final doc in done.docs) {
      final m = Map<String, dynamic>.from(doc.data());
      m['id'] = doc.id;
      num kg = 0;
      try {
        final h = await db
            .collection('collectorSellRequests')
            .doc(doc.id)
            .collection('handover')
            .doc('current')
            .get();
        final hd = h.data();
        if (hd != null) {
          if (hd['finalWeightKg'] is num) kg = hd['finalWeightKg'] as num;
          final ca = hd['confirmedAt'];
          if (ca is Timestamp) {
            final dt = ca.toDate();
            if (dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day) {
              todayKg += kg;
              doneToday++;
            }
          }
        }
      } catch (_) {
        kg = 0;
      }
      m['finalKg'] = kg;
      totalKg += kg;
      all.add(m);
    }
    return {
      'pending': pending,
      'todayKg': todayKg,
      'doneToday': doneToday,
      'totalKg': totalKg,
      'rows': rows,
      'all': all,
    };
  }

  Widget _listings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filterBar(),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.openListings(limit: _feedLimit),
          builder: (context, snap) {
            if (snap.hasError) {
              return _errorBox(snap.error.toString());
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(26),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snap.data!;
            final docs = _applyFilters(data.docs);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.metadata.isFromCache)
                  _cacheNote(
                    _t(
                      'Showing cached listings. Reconnect for the latest.',
                      'कैश की लिस्टिंग दिख रही है। नवीनतम के लिए कनेक्ट करें।',
                      'कॅशमधील याद्या दिसत आहेत. अलीकडीलसाठी कनेक्ट करा.',
                    ),
                  ),
                Text(
                  _t(
                    'Open listings: ${docs.length}',
                    'खुली लिस्टिंग: ${docs.length}',
                    'खुल्या याद्या: ${docs.length}',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 8),
                if (docs.isEmpty)
                  _emptyBox(
                    _t(
                      'No open listings match right now. Listings appear here when collectors publish them. Nothing is pre-filled or fake.',
                      'अभी कोई खुली लिस्टिंग मेल नहीं खाती। कलेक्टर लिस्टिंग प्रकाशित करेंगे तो यहाँ दिखेगी। कुछ भी नकली नहीं भरा जाता।',
                      'सध्या कोणतीही खुली यादी जुळत नाही. कलेक्टर यादी प्रकाशित करताच येथे दिसेल. काहीही बनावट भरले जात नाही.',
                    ),
                  ),
                for (final doc in docs) ...[
                  _ListingCard(
                    data: doc.data(),
                    onQuote: () => _openQuoteForm(doc.id, doc.data()),
                  ),
                  const SizedBox(height: 10),
                ],
                if (data.docs.length >= _feedLimit && _feedLimit < kFeedMaxSize)
                  OutlinedButton(
                    onPressed: spokenAction(
                      () => _t(
                        'Load more listings',
                        'और लिस्टिंग लोड करें',
                        'अधिक याद्या लोड करा',
                      ),
                      () => setState(
                        () => _feedLimit = (_feedLimit + 50).clamp(
                          kFeedPageSize,
                          kFeedMaxSize,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: _green, width: 1.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _t(
                        'Load more (up to $kFeedMaxSize)',
                        'और लोड करें (अधिकतम $kFeedMaxSize)',
                        'अधिक लोड करा (जास्तीत जास्त $kFeedMaxSize)',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _green,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Material/city/search controls. Filters apply ONLY to the already loaded
  /// window (bounded query), never a new unbounded server scan.
  Widget _filterBar() {
    return Material(
      color: const Color(0xFFF0F5E4),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(
                    _t('All materials', 'सभी सामग्री', 'सर्व साहित्य'),
                    _material == null,
                    () => setState(() => _material = null),
                  ),
                  for (final m in kDirectSellMaterials)
                    _chip(
                      m,
                      _material == m,
                      () => setState(() => _material = m),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(
                    _t('All cities', 'सभी शहर', 'सर्व शहरे'),
                    _city == null,
                    () => setState(() => _city = null),
                  ),
                  for (final c in kDirectSellCities)
                    _chip(c, _city == c, () => setState(() => _city = c)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: _t(
                  'Search material or city in loaded list',
                  'लोड हुई सूची में सामग्री या शहर खोजें',
                  'लोड झालेल्या यादीत साहित्य किंवा शहर शोधा',
                ),
                prefixIcon: const Icon(Icons.search, color: _green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _hideExpired,
                  onChanged: (v) => setState(() => _hideExpired = v ?? false),
                ),
                Expanded(
                  child: Text(
                    _t(
                      'Hide expired listings (device time; server decides)',
                      'समय समाप्त लिस्टिंग छिपाएँ (फ़ोन समय; निर्णय सर्वर का)',
                      'मुदत संपलेल्या याद्या लपवा (फोन वेळ; निर्णय सर्व्हरचा)',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _green,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? Colors.white : const Color(0xFF33402C),
      ),
    ),
  );

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((d) {
      final v = d.data();
      final m = v['material'];
      final c = v['city'];
      if (_material != null && m != _material) {
        return false;
      }
      if (_city != null && c != _city) {
        return false;
      }
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty) {
        final hay = '${m ?? ''} ${c ?? ''}'.toLowerCase();
        if (!hay.contains(q)) {
          return false;
        }
      }
      if (_hideExpired) {
        final exp = v['expiresAt'];
        if (exp is Timestamp && !exp.toDate().isAfter(DateTime.now())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openQuoteForm(String saleId, Map<String, dynamic> sale) {
    final publishedAt = sale['publishedAt'];
    if (publishedAt is! Timestamp) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuoteFormPage(
          service: _service,
          saleId: saleId,
          publishedAt: publishedAt,
          material: sale['material'] is String
              ? sale['material'] as String
              : '',
          city: sale['city'] is String ? sale['city'] as String : '',
          weightKg: sale['weightKg'] is num ? sale['weightKg'] as num : 0,
          askingRate: sale['askingRate'] is num ? sale['askingRate'] as num : 0,
          expiresAt: sale['expiresAt'] is Timestamp
              ? sale['expiresAt'] as Timestamp
              : null,
        ),
      ),
    );
  }

  // ---------------- Own quote history ----------------

  Widget _myQuotes(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.myQuotes(uid, limit: _quoteLimit),
      builder: (context, snap) {
        if (snap.hasError) {
          return _errorBox(snap.error.toString());
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(26),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.metadata.isFromCache)
              _cacheNote(
                _t(
                  'Showing cached history. Reconnect for the latest.',
                  'कैश इतिहास दिख रहा है। नवीनतम के लिए कनेक्ट करें।',
                  'कॅश इतिहास दिसत आहे. अलीकडीलसाठी कनेक्ट करा.',
                ),
              ),
            if (data.docs.isEmpty)
              _emptyBox(
                _t(
                  'No quotes sent yet. Open a listing and send your first quote.',
                  'अभी कोई quote नहीं भेजा। लिस्टिंग खोलकर पहला quote भेजें।',
                  'अद्याप कोट पाठवला नाही. यादी उघडून पहिला कोट पाठवा.',
                ),
              ),
            for (final doc in data.docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MyQuoteCard(data: doc.data()),
              ),
            if (data.docs.length >= _quoteLimit && _quoteLimit < kFeedMaxSize)
              OutlinedButton(
                onPressed: spokenAction(
                  () => _t(
                    'Load more history',
                    'और इतिहास लोड करें',
                    'अधिक इतिहास लोड करा',
                  ),
                  () => setState(
                    () => _quoteLimit = (_quoteLimit + 50).clamp(
                      kFeedPageSize,
                      kFeedMaxSize,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: _green, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _t('Load more', 'और लोड करें', 'अधिक लोड करा'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              _t(
                'Quotes are final in this version: no edit, no withdraw. Snapshots stay here even if the collector withdraws the listing.',
                'इस संस्करण में quote अंतिम हैं: न बदलाव, न वापसी। कलेक्टर लिस्टिंग हटाए तो भी स्नैपशॉट यहाँ रहते हैं।',
                'या आवृत्तीत कोट अंतिम आहेत: बदल नाही, माघार नाही. कलेक्टरने यादी मागे घेतली तरी स्नॅपशॉट येथे राहतात.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF626655),
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cacheNote(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Color(0xFF8A6D1A)),
    ),
  );

  Widget _emptyBox(String text) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCDCCE)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, height: 1.5),
    ),
  );

  Widget _errorBox(String raw) {
    final needsIndex = raw.toLowerCase().contains('failed-precondition');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        needsIndex
            ? _t(
                'A required Firebase index is missing. Create the composite index from the setup guide (or open the index link printed in the run console), wait until it is Enabled, then reopen this page.',
                'एक ज़रूरी Firebase index नहीं बना। सेटअप गाइड वाला composite index बनाएँ (या कंसोल में छपा index लिंक खोलें), Enabled होने का इंतज़ार करें, फिर यह पेज दोबारा खोलें।',
                'एक आवश्यक Firebase index नाही. सेटअप गाइडमधील composite index तयार करा (किंवा कन्सोलमधील index लिंक उघडा), Enabled होण्याची वाट पहा, नंतर हे पान पुन्हा उघडा.',
              )
            : _t(
                'Could not load data. Check internet and published rules, then retry.',
                'डेटा लोड नहीं हुआ। इंटरनेट और नियम जाँचकर फिर कोशिश करें।',
                'डेटा लोड झाला नाही. इंटरनेट व नियम तपासून पुन्हा प्रयत्न करा.',
              ),
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.data, required this.onQuote});
  final Map<String, dynamic> data;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    final material = data['material'] is String
        ? data['material'] as String
        : '';
    final city = data['city'] is String ? data['city'] as String : '';
    final weightKg = data['weightKg'] is num ? data['weightKg'] as num : 0;
    final askingRate = data['askingRate'] is num
        ? data['askingRate'] as num
        : 0;
    final fulfilment = data['fulfilment'] is String
        ? data['fulfilment'] as String
        : '';
    final availability = data['availability'] is String
        ? data['availability'] as String
        : '';
    final expiresAt = data['expiresAt'] is Timestamp
        ? data['expiresAt'] as Timestamp
        : null;
    final expired =
        expiresAt != null && !expiresAt.toDate().isAfter(DateTime.now());
    final askingPaise = (askingRate * 100).round();
    return Material(
      color: const Color(0xFFFFFCF5),
      elevation: 2.5,
      shadowColor: const Color(0x40286B3B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4E2D2), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: expired ? null : onQuote,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1EED5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/${material.toLowerCase()}.png',
                      width: 66,
                      height: 66,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Center(
                        child: Icon(Icons.category_outlined, color: _green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$city · ${_numLabel(weightKg)} kg',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF51584A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E5230), Color(0xFF3C8A52)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          askingRate > 0
                              ? formatPaiseAsRupees(askingPaise)
                              : speechText('Open', 'खुला', 'खुले'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          askingRate > 0
                              ? speechText('per kg', 'प्रति किलो', 'प्रति किलो')
                              : speechText(
                                  'to quotes',
                                  'quote के लिए',
                                  'कोटसाठी',
                                ),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE1EED5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _pill(_fulfilmentLabel(fulfilment)),
                  _pill(_availabilityLabel(availability)),
                  if (expiresAt != null) _pill(expiryLabel(expiresAt)),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: expired ? null : onQuote,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: const Color(0xFFB9C4AE),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  expired
                      ? speechText('Expired', 'समय समाप्त', 'मुदत संपली')
                      : speechText(
                          'Give my quote',
                          'अपना quote दें',
                          'माझा कोट द्या',
                        ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE1EED5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF33402C),
      ),
    ),
  );
}

class _MyQuoteCard extends StatelessWidget {
  const _MyQuoteCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final material = data['material'] is String
        ? data['material'] as String
        : '';
    final city = data['city'] is String ? data['city'] as String : '';
    final weightKg = data['weightKg'] is num ? data['weightKg'] as num : 0;
    final ratePaise = data['ratePaise'] is int ? data['ratePaise'] as int : 0;
    final createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;
    final expiresAt = data['expiresAt'] is Timestamp
        ? data['expiresAt'] as Timestamp
        : null;
    final estimatedPaise = (ratePaise * weightKg).round();
    final saleId = data['saleId'] is String ? data['saleId'] as String : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saleId != null) _SelectionBanner(saleId: saleId),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: const Color(0xFFFFFCF5),
            elevation: 2,
            shadowColor: const Color(0x33286B3B),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_green, Color(0xFF7FBF6A)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _quoteCardBody(
                      material,
                      city,
                      weightKg,
                      ratePaise,
                      estimatedPaise,
                      createdAt,
                      expiresAt,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quoteCardBody(
    String material,
    String city,
    num weightKg,
    int ratePaise,
    int estimatedPaise,
    Timestamp? createdAt,
    Timestamp? expiresAt,
  ) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$material · $city',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              formatPaiseAsRupees(ratePaise),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            speechText('per kg', 'प्रति किलो', 'प्रति किलो'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF626655)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          speechText(
            'Listed weight ${_numLabel(weightKg)} kg · estimated total ${formatPaiseAsRupees(estimatedPaise)}',
            'लिखित वज़न ${_numLabel(weightKg)} कि.ग्रा. · अनुमानित कुल ${formatPaiseAsRupees(estimatedPaise)}',
            'नोंदवलेले वजन ${_numLabel(weightKg)} किलो · अंदाजे एकूण ${formatPaiseAsRupees(estimatedPaise)}',
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          speechText(
            'Estimate uses the listed weight only. The real total depends on the actual handover weight, agreed later.',
            'यह अनुमान केवल लिखित वज़न से है। असल कुल हाथ-में-लेने के वास्तविक वज़न पर तय होगा, बाद में।',
            'हा अंदाज फक्त नोंदवलेल्या वजनावरून आहे. खरे एकूण प्रत्यक्ष हस्तांतरण वजनावर नंतर ठरेल.',
          ),
          style: const TextStyle(fontSize: 11, color: Color(0xFF626655)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (createdAt != null)
              _stamp(
                '${speechText('Sent', 'भेजा', 'पाठवला')} ${dateLabel(createdAt)}',
              ),
            if (expiresAt != null) _stamp(expiryLabel(expiresAt)),
          ],
        ),
      ],
    ),
  );

  static Widget _stamp(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE1EED5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF33402C),
      ),
    ),
  );
}

String _numLabel(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _fulfilmentLabel(String v) => switch (v) {
  'pickup' => speechText('Collector pickup', 'कलेक्टर पिकअप', 'कलेक्टर पिकअप'),
  'delivery' => speechText(
    'Collector delivers',
    'कलेक्टर पहुँचाएगा',
    'कलेक्टर पोहोचवेल',
  ),
  _ => speechText(
    'Pickup or delivery',
    'पिकअप या डिलीवरी',
    'पिकअप किंवा डिलिव्हरी',
  ),
};

String _availabilityLabel(String v) => v == 'today'
    ? speechText('Available today', 'आज उपलब्ध', 'आज उपलब्ध')
    : speechText('Flexible days', 'लचीले दिन', 'लवचिक दिवस');

/// Expiry labels are computed on render from the DEVICE clock and are not an
/// authoritative decision; the published server Rules decide what is valid.
String expiryLabel(Timestamp exp) {
  final diff = exp.toDate().difference(DateTime.now());
  if (diff.isNegative) {
    return speechText('Expired', 'समय समाप्त', 'मुदत संपली');
  }
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  if (h >= 24) {
    final d = diff.inDays;
    return speechText('Closes in $d d', '$d दिन में बंद', '$d दिवसांत बंद');
  }
  return speechText(
    'Closes in ${h}h ${m}m',
    '$h घं. $m मि. में बंद',
    '$h ता. $m मि. मध्ये बंद',
  );
}

String dateLabel(Timestamp ts) {
  final d = ts.toDate();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Quote form: rate per kg + validity. One immutable quote per listing round.
class QuoteFormPage extends StatefulWidget {
  const QuoteFormPage({
    required this.service,
    required this.saleId,
    required this.publishedAt,
    required this.material,
    required this.city,
    required this.weightKg,
    required this.askingRate,
    required this.expiresAt,
    super.key,
  });
  final DirectSellQuoteService service;
  final String saleId;
  final Timestamp publishedAt;
  final String material;
  final String city;
  final num weightKg;
  final num askingRate;
  final Timestamp? expiresAt;

  @override
  State<QuoteFormPage> createState() => _QuoteFormPageState();
}

class _QuoteFormPageState extends State<QuoteFormPage> {
  final _rate = TextEditingController();
  int _expiryHours = kDefaultQuoteExpiryHours;
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  String outcomeMessage(QuoteSubmitOutcome o) => switch (o) {
    QuoteSubmitOutcome.submitted => _t(
      'Quote sent and saved under this listing. See it in My quotes.',
      'Quote भेज दिया और इस लिस्टिंग में सहेज गया। मेरे quote में देखें।',
      'कोट पाठवला आणि या यादीत जतन झाला. माझे कोट मध्ये पहा.',
    ),
    QuoteSubmitOutcome.alreadySubmitted => _t(
      'You already quoted on this listing. Your first quote stands; quotes cannot be changed in this version.',
      'आप इस लिस्टिंग पर पहले ही quote दे चुके हैं। पहला quote ही मान्य है; इस संस्करण में quote बदले नहीं जा सकते।',
      'तुम्ही या यादीवर आधीच कोट दिला आहे. पहिला कोटच ग्राह्य; या आवृत्तीत कोट बदलता येत नाहीत.',
    ),
    QuoteSubmitOutcome.listingUnavailable => _t(
      'This listing is no longer open (withdrawn, expired or closed). Refresh the list.',
      'यह लिस्टिंग अब खुली नहीं (वापस, समाप्त या बंद)। सूची ताज़ा करें।',
      'ही यादी आता खुली नाही (मागे घेतली, मुदत संपली किंवा बंद). यादी ताजी करा.',
    ),
    QuoteSubmitOutcome.listingChanged => _t(
      'The collector republished this listing, so that quote round ended. Refresh and quote on the new listing if you want.',
      'कलेक्टर ने लिस्टिंग दोबारा प्रकाशित की, इसलिए वह quote दौर समाप्त। ताज़ा करें और नई लिस्टिंग पर quote दें।',
      'कलेक्टरने यादी पुन्हा प्रकाशित केली, त्यामुळे तो कोट टप्पा संपला. ताजे करा आणि नवीन यादीवर कोट द्या.',
    ),
    QuoteSubmitOutcome.notVerified => _t(
      'Only approved recycler accounts can quote. Approval comes from the project administrator, not this app.',
      'केवल स्वीकृत रीसायकलकर्ता quote दे सकते हैं। स्वीकृति प्रोजेक्ट एडमिन देता है, यह ऐप नहीं।',
      'फक्त मंजूर रीसायकलर कोट देऊ शकतात. मंजुरी प्रकल्प प्रशासक देतो, हे अॅप नाही.',
    ),
    QuoteSubmitOutcome.invalidInput => _t(
      'Enter a valid rate per kg (up to 2 decimals).',
      'प्रति किलो वैध भाव लिखें (2 दशमलव तक)।',
      'प्रति किलो वैध भाव लिहा (2 दशांशांपर्यंत).',
    ),
    QuoteSubmitOutcome.unconfirmed => _t(
      'Could not confirm sending (timeout or offline). Your quote may still have been saved. Open My quotes and check before trying again.',
      'भेजना पुष्ट नहीं हुआ (timeout या ऑफ़लाइन)। quote फिर भी सहेजा जा सकता है। फिर कोशिश से पहले मेरे quote जाँचें।',
      'पाठवणे निश्चित झाले नाही (टाइमआउट किंवा ऑफलाइन). कोट तरीही जतन झाला असेल. पुन्हा प्रयत्नापूर्वी माझे कोट तपासा.',
    ),
    _ => _t(
      'The server rejected this quote. Check approval, listing state and connection, then try again.',
      'सर्वर ने यह quote अस्वीकार किया। स्वीकृति, लिस्टिंग स्थिति और कनेक्शन जाँचकर फिर कोशिश करें।',
      'सर्व्हरने हा कोट नाकारला. मंजुरी, यादी स्थिती व कनेक्शन तपासून पुन्हा प्रयत्न करा.',
    ),
  };

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final paise = parseRupeesToPaise(_rate.text);
    if (paise == null) {
      AppSpeech.instance.say(outcomeMessage(QuoteSubmitOutcome.invalidInput));
      return;
    }
    setState(() => _busy = true);
    final outcome = await widget.service.submitQuote(
      saleId: widget.saleId,
      publishedAt: widget.publishedAt,
      ratePaise: paise,
      expiryHours: _expiryHours,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    AppSpeech.instance.say(outcomeMessage(outcome));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCF5),
        title: Text(
          outcome == QuoteSubmitOutcome.submitted
              ? _t('Quote sent', 'Quote भेजा गया', 'कोट पाठवला')
              : _t('Not sent', 'नहीं भेजा गया', 'पाठवला नाही'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          outcomeMessage(outcome),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('OK', 'ठीक है', 'ठीक आहे')),
          ),
        ],
      ),
    );
    if (mounted && outcome == QuoteSubmitOutcome.submitted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratePaise = parseRupeesToPaise(_rate.text);
    final estimated = ratePaise == null
        ? null
        : (ratePaise * widget.weightKg).round();
    return AnimatedBuilder(
      animation: appLanguage,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _cream,
          appBar: AppBar(
            backgroundColor: _cream,
            leading: BackButton(
              onPressed: _busy
                  ? null
                  : spokenAction(
                      () => _t('Back', 'वापस', 'मागे'),
                      () => Navigator.of(context).maybePop(),
                    ),
            ),
            actions: [_signOutButton(context), const SpeechFeedbackButton()],
            title: Text(_t('My quote', 'मेरा quote', 'माझा कोट')),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VoiceGuide(
                          instruction: () => _t(
                            'Enter your honest rate per kilogram, choose how long the quote stays valid, then send. One final quote per listing; it cannot be edited or withdrawn in this version.',
                            'ईमानदार भाव प्रति किलो लिखें, quote की अवधि चुनें, फिर भेजें। प्रति लिस्टिंग एक अंतिम quote; इस संस्करण में बदलाव या वापसी नहीं।',
                            'प्रति किलो प्रामाणिक भाव लिहा, कोटची मुदत निवडा, नंतर पाठवा. प्रत्येक यादीवर एक अंतिम कोट; या आवृत्तीत बदल किंवा माघार नाही.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF0F5E4), Color(0xFFE1EED5)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFCBDCB4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/images/${widget.material.toLowerCase()}.png',
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      const Center(
                                        child: Icon(
                                          Icons.category_outlined,
                                          color: _green,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.material} · ${widget.city}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_numLabel(widget.weightKg)} kg · ${widget.askingRate > 0 ? _t('asking ${_numLabel(widget.askingRate)} per kg', 'माँग ${_numLabel(widget.askingRate)} प्रति किलो', 'मागणी ${_numLabel(widget.askingRate)} प्रति किलो') : _t('no asking rate', 'कोई माँग भाव नहीं', 'मागणी भाव नाही')}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (widget.expiresAt != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        _t(
                                          'Listing ${expiryLabel(widget.expiresAt!)} by your device clock; the server decides.',
                                          'लिस्टिंग ${expiryLabel(widget.expiresAt!)} आपके फ़ोन समय से; निर्णय सर्वर लेता है।',
                                          'यादी ${expiryLabel(widget.expiresAt!)} तुमच्या फोन वेळेनुसार; निर्णय सर्व्हर घेतो.',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF626655),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _rate,
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            labelText: _t(
                              'Your rate (rupees per kg)',
                              'आपका भाव (रुपये प्रति किलो)',
                              'तुमचा भाव (रुपये प्रति किलो)',
                            ),
                            helperText: _t(
                              'Example: 42.50 means 42 rupees 50 paise per kg.',
                              'उदाहरण: 42.50 का मतलब 42 रुपये 50 पैसे प्रति किलो।',
                              'उदाहरण: 42.50 म्हणजे 42 रुपये 50 पैसे प्रति किलो.',
                            ),
                            prefixText: '\u20B9 ',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        if (estimated != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1EED5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFCBDCB4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calculate_rounded,
                                  color: _green,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _t(
                                      'Estimated total: ${formatPaiseAsRupees(estimated)} for ${_numLabel(widget.weightKg)} kg (listed weight; actual total depends on handover weight)',
                                      'अनुमानित कुल: ${_numLabel(widget.weightKg)} कि.ग्रा. के लिए ${formatPaiseAsRupees(estimated)} (लिखित वज़न; असल कुल हाथ-में-लेने के वज़न पर)',
                                      'अंदाजे एकूण: ${_numLabel(widget.weightKg)} किलोसाठी ${formatPaiseAsRupees(estimated)} (नोंदवलेले वजन; खरे एकूण हस्तांतरण वजनावर)',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E5230),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          _t(
                            'Quote valid for',
                            'Quote कितनी देर मान्य',
                            'कोट किती वेळ वैध',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final h in kQuoteExpiryHoursOptions)
                              ChoiceChip(
                                label: Text(
                                  h == 1
                                      ? _t('1 hour', '1 घंटा', '1 तास')
                                      : h == 6
                                      ? _t(
                                          '6 hours (default)',
                                          '6 घंटे (डिफ़ॉल्ट)',
                                          '6 तास (डीफॉल्ट)',
                                        )
                                      : _t(
                                          '24 hours (maximum)',
                                          '24 घंटे (अधिकतम)',
                                          '24 तास (जास्तीत जास्त)',
                                        ),
                                ),
                                selected: _expiryHours == h,
                                onSelected: _busy
                                    ? null
                                    : (_) => setState(() => _expiryHours = h),
                                selectedColor: _green,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _expiryHours == h
                                      ? Colors.white
                                      : const Color(0xFF33402C),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0CB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _t(
                              'Your quote is FINAL for this listing: exactly one quote per listing, no edit and no withdraw in this version. Send only your true rate. A quote never locks the material or promises payment.',
                              'इस लिस्टिंग के लिए आपका quote अंतिम है: एक लिस्टिंग पर केवल एक quote, इस संस्करण में न बदलाव न वापसी। केवल सच्चा भाव भेजें। quote से माल लॉक नहीं होता और भुगतान का वादा नहीं है।',
                              'या यादीसाठी तुमचा कोट अंतिम आहे: प्रत्येक यादीवर फक्त एक कोट, या आवृत्तीत बदल किंवा माघार नाही. फक्त खरा भाव पाठवा. कोटमुळे माल लॉक होत नाही किंवा पेमेंटचे वचन नाही.',
                            ),
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: _busy ? 0.7 : 1,
                          child: Container(
                            height: 62,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF1E5230),
                                  _green,
                                  Color(0xFF3C8A52),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40286B3B),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _busy
                                    ? null
                                    : spokenAction(
                                        () => _t(
                                          'Send quote',
                                          'Quote भेजें',
                                          'कोट पाठवा',
                                        ),
                                        _submit,
                                      ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 9),
                                      Text(
                                        _busy
                                            ? _t(
                                                'Sending...',
                                                'भेज रहे हैं...',
                                                'पाठवत आहोत...',
                                              )
                                            : _t(
                                                'Send quote',
                                                'Quote भेजें',
                                                'कोट पाठवा',
                                              ),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (_busy)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Soft translucent skyline behind the green gradient header, matching the
/// registration screen's artwork treatment.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 13; i++) {
      final x = size.width * i / 13;
      final h = 18.0 + (i % 4) * 12;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, size.width / 15, h),
        paint,
      );
    }
    paint.color = Colors.white.withValues(alpha: 0.07);
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

/// Sprint1 UI-fix: real logout for recycler sessions. Signs out ONLY the
/// current Firebase user (quotes, lots and requests are never deleted),
/// then returns to the login screen: CollectorSessionGate rebuilds on
/// authStateChanges and popUntil clears pushed routes like the quote form.
Widget _signOutButton(BuildContext context) => PopupMenuButton<String>(
  key: const ValueKey('direct_sell_sign_out'),
  tooltip: speechText('Account', 'खाता', 'खाते'),
  icon: const Icon(Icons.more_vert, color: _green),
  onSelected: (value) {
    if (value == 'logout') _confirmSignOut(context);
  },
  itemBuilder: (context) => [
    PopupMenuItem<String>(
      value: 'logout',
      child: Row(
        children: [
          const Icon(Icons.logout, color: _green),
          const SizedBox(width: 10),
          Text(speechText('Sign out', 'साइन आउट', 'साइन आउट')),
        ],
      ),
    ),
  ],
);

Future<void> _confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        speechText('Sign out?', 'साइन आउट करें?', 'साइन आउट करायचे?'),
      ),
      content: Text(
        speechText(
          'Only the current Firebase account is signed out. Your quotes, lots and requests are never deleted. You can log in again with the same phone number and PIN.',
          'केवल मौजूदा Firebase खाता साइन आउट होता है। आपके कोट, लॉट और अनुरोध कभी नहीं मिटते। उसी फोन नंबर और PIN से फिर लॉगिन करें।',
          'फक्त सध्याचे Firebase खाते साइन आउट होते. तुमचे कोट, लॉट व विनंत्या कधीही पुसल्या जात नाहीत. त्याच फोन नंबर व PIN ने पुन्हा लॉगिन करा.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(speechText('Cancel', 'रद्द करें', 'रद्द करा')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(speechText('Sign out', 'साइन आउट', 'साइन आउट')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Sprint1B+1C: honest outcome panel for the SELECTED recycler. It appears
/// on the matching quote card only while the server says this account is the
/// selected buyer (rules grant exactly that read): RESERVED (declinable),
/// HANDOVER PENDING (confirm physical receipt) or COMPLETED (history).
/// Every action runs the real transaction; the server decides, never this UI.
class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({required this.saleId});
  final String saleId;

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  Future<void> _decline(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCF5),
        title: Text(
          _t(
            'Decline this selection?',
            'यह चयन अस्वीकार करें?',
            'ही निवड नाकारायची?',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          _t(
            'The deal ends for you and the listing opens again so the collector can choose another buyer. Your quote stays as history. This cannot be undone.',
            'आपके लिए सौदा खत्म होगा और लिस्टिंग फिर खुल जाएगी ताकि कलेक्टर दूसरा खरीदार चुन सके। आपका quote इतिहास में रहेगा। यह वापस नहीं होगा।',
            'तुमच्यासाठी सौदा संपेल आणि यादी पुन्हा खुली होईल जेणेकरून कलेक्टर दुसरा खरेदीदार निवडू शकेल. तुमचा कोट इतिहासात राहील. हे मागे घेता येणार नाही.',
          ),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Keep it', 'रहने दें', 'राहू दे')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _t('Decline', 'अस्वीकार करें', 'नाकारा'),
              style: const TextStyle(color: Color(0xFF9C2929)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await DirectSellSelectionService().declineSelection(saleId);
    if (!context.mounted) return;
    final msg = _declineMessage(result);
    AppSpeech.instance.say(msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirm(BuildContext context, int revision) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCF5),
        title: Text(
          _t(
            'Confirm physical receipt?',
            'माल भौतिक रूप से मिलने की पुष्टि करें?',
            'प्रत्यक्ष माल मिळाल्याची पुष्टी करायची?',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          _t(
            'Confirm ONLY if you have physically received the material at the proposed weight. This completes the deal and archives the collector lot. It cannot be undone from the app.',
            'केवल तभी पुष्टि करें जब आपको प्रस्तावित वज़न का माल भौतिक रूप से मिल चुका हो। इससे सौदा पूरा होगा और कलेक्टर का लॉट आर्काइव हो जाएगा। ऐप से यह वापस नहीं होगा।',
            'प्रस्तावित वजनाचा माल तुम्हाला प्रत्यक्ष मिळाला असेल तरच पुष्टी करा. यामुळे सौदा पूर्ण होईल आणि कलेक्टरचा लॉट संग्रहित होईल. अॅपमधून हे मागे घेता येणार नाही.',
          ),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Not yet', 'अभी नहीं', 'अजून नाही')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('Yes, received', 'हाँ, मिल गया', 'होय, मिळाले')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await DirectSellHandoverService().confirmHandover(
      saleId: saleId,
      revision: revision,
    );
    if (!context.mounted) return;
    final msg = _handoverMessage(result);
    AppSpeech.instance.say(msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _declineMessage(SelectionOutcome o) => switch (o) {
    SelectionOutcome.declined => _t(
      'Declined. The listing is open again for the collector.',
      'अस्वीकार किया। लिस्टिंग कलेक्टर के लिए फिर खुल गई।',
      'नाकारले. यादी कलेक्टरसाठी पुन्हा खुली झाली.',
    ),
    SelectionOutcome.alreadyCancelled => _t(
      'The listing is already open again.',
      'लिस्टिंग पहले से ही फिर खुली है।',
      'यादी आधीच पुन्हा खुली आहे.',
    ),
    SelectionOutcome.notSelectedParty => _t(
      'You are not the selected buyer for this listing right now.',
      'इस लिस्टिंग के चुने हुए खरीदार अभी आप नहीं हैं।',
      'या यादीसाठी निवडलेला खरेदीदार आता तुम्ही नाही.',
    ),
    SelectionOutcome.listingUnavailable => _t(
      'This listing is no longer active.',
      'यह लिस्टिंग अब सक्रिय नहीं है।',
      'ही यादी आता सक्रिय नाही.',
    ),
    SelectionOutcome.unconfirmed => _t(
      'Could not confirm (timeout or offline). The decline may still complete. Check before trying again.',
      'पुष्टि नहीं हुई (timeout या ऑफ़लाइन)। अस्वीकृति फिर भी पूरी हो सकती है। फिर कोशिश से पहले जाँचें।',
      'निश्चिती झाली नाही (टाइमआउट किंवा ऑफलाइन). नकार तरीही पूर्ण होऊ शकतो. पुन्हा प्रयत्नापूर्वी तपासा.',
    ),
    _ => _t(
      'The server rejected the decline. Refresh and try again.',
      'सर्वर ने अस्वीकृति अस्वीकार कर दी। ताज़ा करें और फिर कोशिश करें।',
      'सर्व्हरने नकार अस्वीकारला. ताजे करा आणि पुन्हा प्रयत्न करा.',
    ),
  };

  String _handoverMessage(HandoverOutcome o) => switch (o) {
    HandoverOutcome.confirmed => _t(
      'Handover confirmed. The deal is complete.',
      'हैंडओवर पुष्ट। सौदा पूरा हुआ।',
      'हस्तांतरण पुष्ट. सौदा पूर्ण.',
    ),
    HandoverOutcome.alreadyCompleted => _t(
      'This deal is already complete.',
      'यह सौदा पहले ही पूरा है।',
      'हा सौदा आधीच पूर्ण आहे.',
    ),
    HandoverOutcome.revisionChanged => _t(
      'The handover details changed meanwhile (weight corrected?). Refresh and check before confirming.',
      'इस दौरान हैंडओवर विवरण बदल गया (वज़न सुधारा?)। पुष्टि से पहले ताज़ा करके देखें।',
      'यादरम्यान हस्तांतरण तपशील बदलला (वजन दुरुस्त?). पुष्टीपूर्वी ताजे करून पहा.',
    ),
    HandoverOutcome.notSelectedParty => _t(
      'You are not the selected buyer for this listing right now.',
      'इस लिस्टिंग के चुने हुए खरीदार अभी आप नहीं हैं।',
      'या यादीसाठी निवडलेला खरेदीदार आता तुम्ही नाही.',
    ),
    HandoverOutcome.unconfirmed => _t(
      'Could not confirm (timeout or offline). The confirmation may still complete. Check before trying again.',
      'पुष्टि नहीं हुई (timeout या ऑफ़लाइन)। पुष्टि फिर भी पूरी हो सकती है। फिर कोशिश से पहले जाँचें।',
      'निश्चिती झाली नाही (टाइमआउट किंवा ऑफलाइन). पुष्टी तरीही पूर्ण होऊ शकते. पुन्हा प्रयत्नापूर्वी तपासा.',
    ),
    _ => _t(
      'The server rejected the confirmation. Refresh and try again.',
      'सर्वर ने पुष्टि अस्वीकार की। ताज़ा करें और फिर कोशिश करें।',
      'सर्व्हरने पुष्टी नाकारली. ताजे करा आणि पुन्हा प्रयत्न करा.',
    ),
  };

  Widget _shell({
    required List<Color> colors,
    required List<Widget> children,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  List<Widget> _reservedContent(BuildContext context) {
    return [
      Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                'SELECTED — reserved for you',
                'चुने गए — आपके लिए आरक्षित',
                'निवडले गेले — तुमच्यासाठी राखीव',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        _t(
          'The collector chose your quote; the lot is reserved for you. Handover starts when the collector enters the final weight — then you confirm physical receipt. You may decline until then; the listing reopens for other buyers.',
          'कलेक्टर ने आपका quote चुना; लॉट आपके लिए आरक्षित है। कलेक्टर के अंतिम वज़न भरते ही हैंडओवर शुरू होगा — तब आप माल मिलने की पुष्टि करेंगे। तब तक आप मना कर सकते हैं; लिस्टिंग दूसरों के लिए फिर खुल जाएगी।',
          'कलेक्टरने तुमचा कोट निवडला; लॉट तुमच्यासाठी राखीव आहे. कलेक्टरने अंतिम वजन भरताच हस्तांतरण सुरू होईल — तेव्हा तुम्ही माल मिळाल्याची पुष्टी कराल. तोपर्यंत तुम्ही नकार देऊ शकता; यादी इतरांसाठी पुन्हा खुली होईल.',
        ),
        style: const TextStyle(
          color: Color(0xFFE1EED5),
          fontSize: 13,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => _decline(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white, width: 1.6),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        label: Text(
          _t(
            'Decline this selection',
            'यह चयन अस्वीकार करें',
            'ही निवड नाकारा',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('collectorSellRequests')
          .doc(saleId)
          .snapshots(),
      builder: (context, snap) {
        final sale = snap.data?.data();
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final status = sale == null ? null : sale['status'];
        final selected =
            sale != null &&
            uid != null &&
            sale['selectedRecyclerUid'] == uid &&
            (status == 'reserved' ||
                status == 'handoverPending' ||
                status == 'completed');
        if (!selected) {
          return const SizedBox.shrink();
        }
        if (status == 'reserved') {
          return _shell(
            colors: const [Color(0xFF1E5230), _green, Color(0xFF3C8A52)],
            children: _reservedContent(context),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('collectorSellRequests')
              .doc(saleId)
              .collection('handover')
              .doc('current')
              .snapshots(),
          builder: (context, hs) {
            final ho = hs.data?.data();
            final w = ho == null ? null : ho['finalWeightKg'];
            final hp = ho == null ? null : ho['ratePaise'];
            final rev = ho == null ? null : ho['revision'];
            final confirmedAt = ho != null && ho['confirmedAt'] is Timestamp
                ? ho['confirmedAt'] as Timestamp
                : null;
            if (status == 'handoverPending') {
              final ready =
                  ho != null && ho['status'] == 'proposed' && rev is int;
              return _shell(
                colors: const [
                  Color(0xFF7A5A00),
                  Color(0xFFB8860B),
                  Color(0xFFD4A72C),
                ],
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t(
                            'HANDOVER PROPOSED — confirm receipt',
                            'हैंडओवर प्रस्तावित — प्राप्ति पुष्ट करें',
                            'हस्तांतरण प्रस्तावित — मिळाल्याची पुष्टी करा',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (w is num)
                    Text(
                      hp is int
                          ? '${_t('Proposed final weight', 'प्रस्तावित अंतिम वज़न', 'प्रस्तावित अंतिम वजन')}: ${w} kg • ${formatPaiseAsRupees((hp * w).round())}'
                          : '${_t('Proposed final weight', 'प्रस्तावित अंतिम वज़न', 'प्रस्तावित अंतिम वजन')}: ${w} kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _t(
                      'The collector started the handover. Confirm ONLY if you physically received the material at this weight. The collector may still correct the weight before you confirm.',
                      'कलेक्टर ने हैंडओवर शुरू किया। केवल तभी पुष्टि करें जब यह वज़न का माल आपको भौतिक रूप से मिल चुका हो। पुष्टि से पहले कलेक्टर वज़न सुधार सकता है।',
                      'कलेक्टरने हस्तांतरण सुरू केले. हे वजनाचे माल तुम्हाला प्रत्यक्ष मिळाले असेल तरच पुष्टी करा. पुष्टीपूर्वी कलेक्टर वजन दुरुस्त करू शकतो.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFF3D6),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ready)
                    FilledButton.icon(
                      onPressed: () => _confirm(context, rev),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7A5A00),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        _t(
                          'Confirm: material received',
                          'पुष्टि: माल मिल गया',
                          'पुष्टी: माल मिळाला',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    Text(
                      _t(
                        'Loading handover details…',
                        'हैंडओवर विवरण लोड हो रहा है…',
                        'हस्तांतरण तपशील लोड होत आहे…',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              );
            }
            // completed
            return _shell(
              colors: const [Color(0xFF1E5230), _green, Color(0xFF3C8A52)],
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t(
                          'DEAL COMPLETE — you confirmed handover',
                          'सौदा पूरा — आपने हैंडओवर पुष्ट किया',
                          'सौदा पूर्ण — तुम्ही हस्तांतरण पुष्ट केले',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (w is num)
                      '${w} kg' +
                          (hp is int
                              ? ' • ${formatPaiseAsRupees((hp * w).round())}'
                              : ''),
                    if (confirmedAt != null) dateLabel(confirmedAt),
                  ].join(' • '),
                  style: const TextStyle(
                    color: Color(0xFFE1EED5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'The lot is archived. Receipt recording for this deal comes in the next update; nothing here is a bank-verified payment.',
                    'लॉट आर्काइव हो गया। इस सौदे की रसीद अगले अपडेट में दर्ज होगी; यहाँ कुछ भी बैंक-सत्यापित भुगतान नहीं है।',
                    'लॉट संग्रहित झाला. या सौद्याची पावती पुढील अपडेटमध्ये नोंदवली जाईल; येथे काहीही बँक-पडताळलेले पेमेंट नाही.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFE1EED5),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class DealDetailPage extends StatelessWidget {
  const DealDetailPage({required this.saleId, super.key});
  final String saleId;

  String _t(String en, String hi, String mr) => speechText(en, hi, mr);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: Text(_t('Deal details', 'सौदा विवरण', 'सौदा तपशील')),
        actions: const [SpeechFeedbackButton()],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('collectorSellRequests')
            .doc(saleId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                _t(
                  'Could not load this deal.',
                  'सौदा लोड नहीं हुआ।',
                  'सौदा लोड झाला नाही.',
                ),
              ),
            );
          }
          final sale = snap.data?.data();
          if (sale == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final material = '${sale['material'] ?? ''}';
          final city = '${sale['city'] ?? ''}';
          final listedKg = sale['weightKg'] is num
              ? sale['weightKg'] as num
              : 0;
          final asking = sale['askingRate'] is num
              ? sale['askingRate'] as num
              : 0;
          final rate = sale['selectedRatePaise'] is num
              ? sale['selectedRatePaise'] as num
              : 0;
          final status = '${sale['status'] ?? ''}';
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _SelectionBanner(saleId: saleId),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                elevation: 1.5,
                shadowColor: const Color(0x30286B3B),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _assetImg(
                            'assets/images/${material.toLowerCase()}.png',
                            64,
                            64,
                            Icons.category_outlined,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                city,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF66756B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _t('Status', 'स्थिति', 'स्थिती') + ': ' + status,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                      Text(
                        _t('Listed weight', 'सूचीबद्ध वज़न', 'सूचीबद्ध वजन') +
                            ': ${_kgLabel(listedKg)} kg',
                      ),
                      Text(
                        _t('Asking rate', 'मांगा गया दर', 'मागलेला दर') +
                            ': ₹${formatPaiseAsRupees((asking * 100).round())} / kg',
                      ),
                      Text(
                        _t('Selected rate', 'चुना गया दर', 'निवडलेला दर') +
                            ': ₹${formatPaiseAsRupees(rate.round())} / kg',
                      ),
                      const SizedBox(height: 10),
                      _receiptSection(status),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _receiptSection(String status) {
    if (status != 'completed') return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DirectSellReceiptService().receiptRef(saleId).snapshots(),
      builder: (context, s) {
        final r = s.data?.data();
        if (r == null) {
          return Text(
            _t(
              'Collector has not recorded the payment yet.',
              'कलेक्टर ने अब तक भुगतान दर्ज नहीं किया।',
              'कलेक्टरने अद्याप पेमेंट नोंदवले नाही.',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF66756B)),
          );
        }
        final amount = r['amountPaise'] is num
            ? (r['amountPaise'] as num).round()
            : 0;
        final method = '${r['method'] ?? ''}';
        return Text(
          _t(
            'Payment recorded by collector: Rs ${formatPaiseAsRupees(amount)} via ${method.toUpperCase()}. Not bank-verified.',
            'कलेक्टर ने भुगतान दर्ज किया: Rs ${formatPaiseAsRupees(amount)} ${method.toUpperCase()} से। बैंक-सत्यापित नहीं।',
            'कलेक्टरने पेमेंट नोंदवले: Rs ${formatPaiseAsRupees(amount)} ${method.toUpperCase()}. बँक-पडताळलेले नाही.',
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _green,
          ),
        );
      },
    );
  }
}

Widget _assetImg(
  String path,
  double w,
  double h,
  IconData fallback, {
  double radius = 14,
}) {
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE1EED5),
      borderRadius: BorderRadius.circular(radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      path,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (c, e, st) => Center(
        child: Icon(fallback, color: _green, size: h * 0.55),
      ),
    ),
  );
}

String _kgLabel(num kg) {
  if (kg == kg.roundToDouble()) return '${kg.toInt()}';
  return kg.toStringAsFixed(1);
}
