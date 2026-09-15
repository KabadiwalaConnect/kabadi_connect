import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collector_ui.dart';
import 'collector_market.dart' show OfferDetailScreen;
import 'collector_home_screen.dart'
    show CollectorHomeNavigation, SellCameraScreen;
import 'material_photos.dart';
import 'request_tracking.dart' show trackingDate;
import 'app_speech.dart';
import 'collector_chat_tools.dart';

bool validChatText(String text) =>
    text.trim().isNotEmpty && text.trim().length <= 2000;
const chatWritableStatuses = [
  'proposed',
  'quoted',
  'accepted',
  'handoverPending',
  'completed',
];
String chatStorageKey(String uid, String path) =>
    'offer_chat_outbox_${base64Url.encode(utf8.encode(jsonEncode([uid, path])))}';

/// One durable, explicitly submitted pending message per UID and offer.
/// No automatic retry, deletion of server messages, or delivered/read claims.
class OfferChatService {
  OfferChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : firestore = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  static final Map<String, Future<void>> _locks = {};
  static Future<T> _locked<T>(String key, Future<T> Function() work) async {
    final previous = _locks[key] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[key] = done.future;
    await previous;
    try {
      return await work();
    } finally {
      done.complete();
      if (identical(_locks[key], done.future)) _locks.remove(key);
    }
  }

  void check(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('account-changed');
  }

  Future<Map<String, String>?> pending(String uid, String path) async {
    check(uid);
    final raw = (await SharedPreferences.getInstance()).getString(
      chatStorageKey(uid, path),
    );
    check(uid);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['id'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(data['id']) ||
        data['text'] is! String ||
        (!validChatText(data['text']) ||
            (data['text'] as String).length > 2000))
      throw StateError('invalid-local-message');
    return {'id': data['id'], 'text': data['text']};
  }

  Future<Map<String, String>> prepare(
    String uid,
    DocumentReference<Map<String, dynamic>> offer,
    String text,
  ) async {
    if (!validChatText(text)) throw ArgumentError('invalid-message');
    final key = chatStorageKey(uid, offer.path);
    return _locked(key, () async {
      check(uid);
      final old = await pending(uid, offer.path);
      if (old != null) {
        if (old['text'] != text.trim())
          throw StateError('another-message-pending');
        return old;
      }
      final item = {
        'id': offer.collection('messages').doc().id,
        'text': text.trim(),
      };
      final ok = await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode(item),
      );
      if (!ok) throw StateError('local-save-failed');
      check(uid);
      return item;
    });
  }

  Future<void> send(
    String uid,
    DocumentReference<Map<String, dynamic>> offer,
    Map<String, String> item,
  ) async {
    check(uid);
    if (!validChatText(item['text'] ?? ''))
      throw ArgumentError('invalid-message');
    final id = item['id'];
    if (id == null ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
        item['text']!.length > 2000)
      throw ArgumentError('invalid-message-id');
    final message = offer.collection('messages').doc(id);
    await firestore
        .runTransaction((t) async {
          final old = await t.get(message);
          check(uid);
          if (old.exists) {
            if (old.data()?['senderUid'] != uid ||
                old.data()?['text'] != item['text'])
              throw StateError('message-id-conflict');
            return;
          }
          final parent = await t.get(offer);
          final p = parent.data();
          check(uid);
          if (p == null ||
              p['schemaVersion'] != 2 ||
              !chatWritableStatuses.contains(p['status']) ||
              (p['collectorUid'] != uid && p['recyclerUid'] != uid))
            throw StateError('thread-read-only');
          // Rules also check current buyer verification and the exact linked request.
          t.set(message, {
            'schemaVersion': 1,
            'senderUid': uid,
            'text': item['text'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 25));
    check(uid);
  }

  Future<void> clearLocal(String uid, String path, String id) async {
    final key = chatStorageKey(uid, path);
    await _locked(key, () async {
      check(uid);
      final current = await pending(uid, path);
      if (current == null || current['id'] != id) return;
      if (!await (await SharedPreferences.getInstance()).remove(key))
        throw StateError('local-cleanup-failed');
      check(uid);
    });
  }
}

int offerActivityMillis(Map<String, dynamic> v) {
  var latest = 0;
  for (final key in [
    'createdAt',
    'quotedAt',
    'acceptedAt',
    'handoverRequestedAt',
    'completedAt',
    'cancelledAt',
    'rejectedAt',
  ]) {
    final value = v[key];
    if (value is Timestamp && value.millisecondsSinceEpoch > latest)
      latest = value.millisecondsSinceEpoch;
  }
  return latest;
}

List<Map<String, dynamic>> filterMessageThreads(
  List<Map<String, dynamic>> records, {
  String query = '',
  String group = 'all',
}) {
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final statuses = switch (group) {
    'waiting' => ['proposed'],
    'quotes' => ['quoted'],
    'active' => ['accepted', 'handoverPending'],
    'closed' => ['completed', 'cancelled', 'rejected'],
    _ => null,
  };
  return records.where((v) {
      final text =
          '${v['recyclerName'] ?? ''} ${v['material'] ?? ''} ${v['city'] ?? ''}'
              .toLowerCase();
      return (statuses == null || statuses.contains(v['status'])) &&
          words.every(text.contains);
    }).toList()
    ..sort((a, b) => offerActivityMillis(b).compareTo(offerActivityMillis(a)));
}

String inboxFilterLabel(String id) => switch (id) {
  'waiting' => ct(
    'Waiting',
    '\u092A\u094D\u0930\u0924\u0940\u0915\u094D\u0937\u093E',
    '\u092A\u094D\u0930\u0924\u0940\u0915\u094D\u0937\u093E',
  ),
  'quotes' => ct('Quotes', '\u092D\u093E\u0935', '\u0926\u0930'),
  'active' => ct(
    'In progress',
    '\u091C\u093E\u0930\u0940',
    '\u0938\u0941\u0930\u0942',
  ),
  'closed' => ct('Closed', '\u092C\u0902\u0926', '\u092C\u0902\u0926'),
  _ => ct('All', '\u0938\u092D\u0940', '\u0938\u0930\u094D\u0935'),
};

class CollectorMessagesScreen extends StatefulWidget {
  const CollectorMessagesScreen({super.key});
  @override
  State<CollectorMessagesScreen> createState() => _CollectorMessagesState();
}

class _CollectorMessagesState extends State<CollectorMessagesScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _filter = 'all';
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _stream = _uid == null
      ? null
      : FirebaseFirestore.instance
            .collectionGroup('offers')
            .where('collectorUid', isEqualTo: _uid)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(includeMetadataChanges: true);
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Messages & offers',
      '\u0938\u0902\u0926\u0947\u0936 \u0914\u0930 \u0911\u092B\u0930',
      '\u0938\u0902\u0926\u0947\u0936 \u0935 \u0911\u092B\u0930',
    ),
    scrollController: _scroll,
    guide: () => ct(
      'Open an offer conversation to message its linked recycler or review its status. Messages are text only. No read receipts or push notifications are claimed.',
      '\u091C\u0941\u0921\u093C\u0947 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u094B \u0938\u0902\u0926\u0947\u0936 \u092D\u0947\u091C\u0928\u0947 \u092F\u093E \u0938\u094D\u0925\u093F\u0924\u093F \u0926\u0947\u0916\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0911\u092B\u0930 \u0915\u0940 \u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0947\u0902\u0964 \u0915\u0947\u0935\u0932 \u091F\u0947\u0915\u094D\u0938\u094D\u091F \u0938\u0902\u0926\u0947\u0936 \u0939\u0948\u0902\u0964 \u092A\u0922\u093C\u0947 \u091C\u093E\u0928\u0947 \u092F\u093E \u092A\u0941\u0936 \u0938\u0942\u091A\u0928\u093E \u0915\u093E \u0926\u093E\u0935\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
      '\u091C\u094B\u0921\u0932\u0947\u0932\u094D\u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0932\u093E \u0938\u0902\u0926\u0947\u0936 \u092A\u093E\u0920\u0935\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0915\u093F\u0902\u0935\u093E \u0938\u094D\u0925\u093F\u0924\u0940 \u092A\u093E\u0939\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0911\u092B\u0930\u091A\u0940 \u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u093E. \u092B\u0915\u094D\u0924 \u092E\u091C\u0915\u0942\u0930 \u0938\u0902\u0926\u0947\u0936 \u0906\u0939\u0947\u0924. \u0935\u093E\u091A\u0932\u094D\u092F\u093E\u091A\u0940 \u0915\u093F\u0902\u0935\u093E \u092A\u0941\u0936 \u0938\u0942\u091A\u0928\u0947\u091A\u0940 \u0939\u092E\u0940 \u0928\u093E\u0939\u0940.',
    ),
    bottom: () => CollectorHomeNavigation(
      onHome: () {
        AppSpeech.instance.say(
          ct('Home', '\u0939\u094B\u092E', '\u0939\u094B\u092E'),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      onCamera: () =>
          openCollector(context, const SellCameraScreen(city: 'Ludhiana')),
      onMessages: () {
        AppSpeech.instance.say(
          ct(
            'Messages',
            '\u0938\u0902\u0926\u0947\u0936',
            '\u0938\u0902\u0926\u0947\u0936',
          ),
        );
        if (_scroll.hasClients)
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
      },
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => openCollector(context, const PendingChatScreen()),
          icon: const Icon(Icons.outbox_outlined),
          label: Text(
            ct(
              'Pending chat messages',
              '\u0932\u0902\u092C\u093F\u0924 \u091A\u0948\u091F \u0938\u0902\u0926\u0947\u0936',
              '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u091A\u0945\u091F \u0938\u0902\u0926\u0947\u0936',
            ),
          ),
        ),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: ct(
              'Search recycler or material',
              '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u092F\u093E \u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u0916\u094B\u091C\u0947\u0902',
              '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u093F\u0902\u0935\u093E \u0938\u093E\u0939\u093F\u0924\u094D\u092F \u0936\u094B\u0927\u093E',
            ),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: ct(
                      'Clear search',
                      '\u0916\u094B\u091C \u0939\u091F\u093E\u090F\u0901',
                      '\u0936\u094B\u0927 \u092A\u0941\u0938\u093E',
                    ),
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                      AppSpeech.instance.say(
                        ct(
                          'Search cleared',
                          '\u0916\u094B\u091C \u0939\u091F\u093E\u0908',
                          '\u0936\u094B\u0927 \u092A\u0941\u0938\u0932\u093E',
                        ),
                      );
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final id in ['all', 'waiting', 'quotes', 'active', 'closed'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _filter == id,
                    selectedColor: collectorGreen,
                    labelStyle: TextStyle(
                      color: _filter == id ? Colors.white : collectorGreen,
                      fontWeight: FontWeight.w700,
                    ),
                    label: Text(inboxFilterLabel(id)),
                    onSelected: (_) {
                      setState(() => _filter = id);
                      AppSpeech.instance.say(inboxFilterLabel(id));
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            ct(
              'One conversation per offer. Rows preview offer status, not the latest chat or an unread count.',
              '\u0939\u0930 \u0911\u092B\u0930 \u0915\u0940 \u0905\u0932\u0917 \u092C\u093E\u0924\u091A\u0940\u0924\u0964 \u092A\u0902\u0915\u094D\u0924\u093F\u092F\u093E\u0901 \u0911\u092B\u0930 \u0915\u0940 \u0938\u094D\u0925\u093F\u0924\u093F \u0926\u093F\u0916\u093E\u0924\u0940 \u0939\u0948\u0902, \u0906\u0916\u093F\u0930\u0940 \u091A\u0948\u091F \u092F\u093E \u0905\u092A\u0920\u093F\u0924 \u0938\u0902\u0916\u094D\u092F\u093E \u0928\u0939\u0940\u0902\u0964',
              '\u092A\u094D\u0930\u0924\u094D\u092F\u0947\u0915 \u0911\u092B\u0930\u091A\u0940 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u091A\u0930\u094D\u091A\u093E. \u0930\u093E\u0902\u0917\u093E \u0911\u092B\u0930\u091A\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u0926\u093E\u0916\u0935\u0924\u093E\u0924, \u0936\u0947\u0935\u091F\u091A\u093E \u091A\u0945\u091F \u0915\u093F\u0902\u0935\u093E \u0928 \u0935\u093E\u091A\u0932\u0947\u0932\u0940 \u0938\u0902\u0916\u094D\u092F\u093E \u0928\u093E\u0939\u0940.',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6C786E)),
          ),
        ),
        if (_uid == null)
          note(
            ct(
              'Sign in to open your conversations.',
              '\u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0938\u093E\u0907\u0928 \u0907\u0928 \u0915\u0930\u0947\u0902\u0964',
              '\u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0938\u093E\u0907\u0928 \u0907\u0928 \u0915\u0930\u093E.',
            ),
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, s) {
              if (s.hasError)
                return note(
                  ct(
                    'Inbox unavailable. Check connection, account access and the existing offers collection-group index.',
                    '\u0907\u0928\u092C\u0949\u0915\u094D\u0938 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0928\u0947\u091F\u0935\u0930\u094D\u0915, \u0916\u093E\u0924\u093E \u0905\u0928\u0941\u092E\u0924\u093F \u0914\u0930 offers collection-group index \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                    '\u0907\u0928\u092C\u0949\u0915\u094D\u0938 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940. \u0928\u0947\u091F\u0935\u0930\u094D\u0915, \u0916\u093E\u0924\u0947 \u092A\u094D\u0930\u0935\u0947\u0936 \u0935 offers collection-group index \u0924\u092A\u093E\u0938\u093E.',
                  ),
                );
              if (!s.hasData) return const LinearProgressIndicator();
              final rows = filterMessageThreads(
                s.data!.docs
                    .map(
                      (d) => <String, dynamic>{
                        ...d.data(),
                        'id': d.reference.path,
                      },
                    )
                    .toList(),
                query: _search.text,
                group: _filter,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.data!.metadata.isFromCache ||
                      s.data!.metadata.hasPendingWrites)
                    note(
                      ct(
                        'Cached / pending inbox \u2014 not a fresh server view.',
                        '\u0915\u0948\u0936 / \u0932\u0902\u092C\u093F\u0924 \u0907\u0928\u092C\u0949\u0915\u094D\u0938 \u2014 \u0928\u0908 \u0938\u0930\u094D\u0935\u0930 \u091C\u093E\u0928\u0915\u093E\u0930\u0940 \u0928\u0939\u0940\u0902\u0964',
                        '\u0915\u0945\u0936 / \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0907\u0928\u092C\u0949\u0915\u094D\u0938 \u2014 \u0928\u0935\u0940\u0928 \u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u092E\u093E\u0939\u093F\u0924\u0940 \u0928\u093E\u0939\u0940.',
                      ),
                    ),
                  CollectorInboxList(
                    records: rows,
                    onOpen: (v) => openCollector(
                      context,
                      OfferChatScreen(
                        offer: FirebaseFirestore.instance.doc(
                          v['id'] as String,
                        ),
                      ),
                    ),
                  ),
                  note(
                    ct(
                      'Newest 100 proposals, sorted by recorded offer activity within that window. A standalone sell listing has no conversation until a buyer is linked through a real offer.',
                      '\u0928\u0935\u0940\u0928\u0924\u092E 100 \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935, \u0907\u0938\u0940 \u0938\u0942\u091A\u0940 \u092E\u0947\u0902 \u0926\u0930\u094D\u091C \u0911\u092B\u0930 \u0917\u0924\u093F\u0935\u093F\u0927\u093F \u0915\u0947 \u0915\u094D\u0930\u092E \u092E\u0947\u0902\u0964 \u0905\u0932\u0917 \u092C\u093F\u0915\u094D\u0930\u0940 \u0938\u0942\u091A\u0940 \u0915\u0940 \u092C\u093E\u0924\u091A\u0940\u0924 \u0924\u092C \u0924\u0915 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u0940 \u091C\u092C \u0924\u0915 \u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u0911\u092B\u0930 \u0938\u0947 \u0916\u0930\u0940\u0926\u093E\u0930 \u0928 \u091C\u0941\u0921\u093C\u0947\u0964',
                      '\u0928\u0935\u0940\u0928\u0924\u092E 100 \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935, \u092F\u093E\u091A \u092F\u093E\u0926\u0940\u0924\u0940\u0932 \u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u094D\u092F\u093E \u0911\u092B\u0930 \u0915\u0943\u0924\u0940\u0928\u0941\u0938\u093E\u0930. \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u0935\u093F\u0915\u094D\u0930\u0940 \u091C\u093E\u0939\u093F\u0930\u093E\u0924\u0940\u091A\u0940 \u091A\u0930\u094D\u091A\u093E \u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u0911\u092B\u0930\u0928\u0947 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u091C\u094B\u0921\u0947\u092A\u0930\u094D\u092F\u0902\u0924 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    ),
  );
}

/// Pure inbox rows: no invented unread dot, latest message, or verification badge.
class CollectorInboxList extends StatelessWidget {
  const CollectorInboxList({
    required this.records,
    required this.onOpen,
    super.key,
  });
  final List<Map<String, dynamic>> records;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (records.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.forum_outlined, color: collectorGreen, size: 44),
              const SizedBox(height: 12),
              Text(
                ct(
                  'No matching conversations yet',
                  '\u0905\u092D\u0940 \u092E\u0947\u0932 \u0916\u093E\u0924\u0940 \u092C\u093E\u0924\u091A\u0940\u0924 \u0928\u0939\u0940\u0902',
                  '\u0905\u091C\u0942\u0928 \u091C\u0941\u0933\u0923\u093E\u0930\u0940 \u091A\u0930\u094D\u091A\u093E \u0928\u093E\u0939\u0940',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                ct(
                  'Send a saved lot to a real buying request to start.',
                  '\u0936\u0941\u0930\u0942 \u0915\u0930\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u0916\u0930\u0940\u0926 \u092E\u093E\u0901\u0917 \u092A\u0930 \u0938\u0939\u0947\u091C\u093E \u0932\u0949\u091F \u092D\u0947\u091C\u0947\u0902\u0964',
                  '\u0938\u0941\u0930\u0942 \u0915\u0930\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u0916\u0930\u0947\u0926\u0940 \u092E\u093E\u0917\u0923\u0940\u0932\u093E \u091C\u0924\u0928 \u0932\u0949\u091F \u092A\u093E\u0920\u0935\u093E.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ...records.map(
        (v) => Card(
          key: ValueKey('thread_${v['id']}'),
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: Color(0xFFE4EDE5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppSpeech.instance.say(
                ct(
                  'Open conversation',
                  '\u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0947\u0902',
                  '\u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u093E',
                ),
              );
              onOpen(v);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  MaterialPhoto(
                    material: '${v['material']}',
                    width: 50,
                    height: 58,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v['recyclerName'] ?? ct('Linked recycler', '\u091C\u0941\u0921\u093C\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E', '\u091C\u094B\u0921\u0932\u0947\u0932\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E')}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${materialLabel('${v['material']}')} \u2022 ${v['weightKg']} kg',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6C786E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusLabel('${v['status']}'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: collectorGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (offerActivityMillis(v) > 0)
                          Text(
                            '${ct('Offer update', '\u0911\u092B\u0930 \u0905\u092A\u0921\u0947\u091F', '\u0911\u092B\u0930 \u0905\u092A\u0921\u0947\u091F')}: ${trackingDate(Timestamp.fromMillisecondsSinceEpoch(offerActivityMillis(v)))}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7E897F),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: collectorGreen),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.text,
    required this.mine,
    required this.sender,
    required this.timestamp,
    this.pending = false,
    super.key,
  });
  final String text, sender;
  final bool mine, pending;
  final Object? timestamp;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: 0.9,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? collectorGreen : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mine ? collectorGreen : const Color(0xFFE3EAE2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: mine ? Colors.white70 : collectorGreen,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: mine ? Colors.white : const Color(0xFF183322),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pending
                  ? ct(
                      'Awaiting server confirmation',
                      '\u0938\u0930\u094D\u0935\u0930 \u092A\u0941\u0937\u094D\u091F\u093F \u092C\u093E\u0915\u0940',
                      '\u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u092A\u0941\u0937\u094D\u091F\u0940 \u092C\u093E\u0915\u0940',
                    )
                  : trackingDate(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OfferChatScreen extends StatefulWidget {
  const OfferChatScreen({required this.offer, super.key});
  final DocumentReference<Map<String, dynamic>> offer;
  @override
  State<OfferChatScreen> createState() => _OfferChatState();
}

class _OfferChatState extends State<OfferChatScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _service = OfferChatService();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Map<String, String>? _pending;
  String? _message;
  bool _busy = false,
      _outboxReady = false,
      _firstScroll = false,
      _chatAllowed = false;
  int _limit = 50;
  late final _offerStream = widget.offer.snapshots(
    includeMetadataChanges: true,
  );
  late Stream<QuerySnapshot<Map<String, dynamic>>> _history = _historyStream();
  Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream() => widget.offer
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(_limit)
      .snapshots(includeMetadataChanges: true);
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
    });
  }

  Future<void> _restore() async {
    if (_uid == null) return;
    try {
      final value = await _service.pending(_uid, widget.offer.path);
      if (mounted)
        setState(() {
          _pending = value;
          _outboxReady = true;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Local pending message could not load. Sending is disabled to protect it; retry loading.',
            '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u093E\u0964 \u0909\u0938\u0947 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0930\u0916\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u092D\u0947\u091C\u0928\u093E \u092C\u0902\u0926 \u0939\u0948; \u092B\u093F\u0930 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902\u0964',
            '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u0909\u0918\u0921\u0932\u093E \u0928\u093E\u0939\u0940. \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0920\u0947\u0935\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u092A\u093E\u0920\u0935\u0923\u0947 \u092C\u0902\u0926 \u0906\u0939\u0947; \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0921 \u0915\u0930\u093E.',
          ),
        );
    }
  }

  Future<void> _send({bool retry = false}) async {
    if (_busy || !_outboxReady || _uid == null) return;
    if (!retry && !validChatText(_text.text)) {
      setState(
        () => _message = ct(
          'Write 1\u20132000 characters.',
          '1\u20132000 \u0905\u0915\u094D\u0937\u0930 \u0932\u093F\u0916\u0947\u0902\u0964',
          '1\u20132000 \u0905\u0915\u094D\u0937\u0930\u0947 \u0932\u093F\u0939\u093E.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    var serverSaved = false;
    try {
      final item = retry
          ? _pending
          : await _service.prepare(_uid, widget.offer, _text.text);
      if (item == null) throw StateError('no-pending-message');
      if (mounted) setState(() => _pending = item);
      await _service.send(_uid, widget.offer, item);
      serverSaved = true;
      await _service.clearLocal(_uid, widget.offer.path, item['id']!);
      final remaining = await _service.pending(_uid, widget.offer.path);
      if (mounted) {
        setState(() {
          _pending = remaining;
          if (_text.text.trim() == item['text']) _text.clear();
          _message = ct(
            'Saved on server. This does not mean the recycler read it.',
            '\u0938\u0930\u094D\u0935\u0930 \u092A\u0930 \u0938\u0939\u0947\u091C\u093E \u0917\u092F\u093E\u0964 \u0907\u0938\u0915\u093E \u092E\u0924\u0932\u092C \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0928\u0947 \u092A\u0922\u093C \u0932\u093F\u092F\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
            '\u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0935\u0930 \u091C\u0924\u0928 \u091D\u093E\u0932\u0947. \u092F\u093E\u091A\u093E \u0905\u0930\u094D\u0925 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0928\u0947 \u0935\u093E\u091A\u0932\u0947 \u0905\u0938\u093E \u0928\u093E\u0939\u0940.',
          );
        });
        AppSpeech.instance.say(
          ct(
            'Message saved on server',
            '\u0938\u0902\u0926\u0947\u0936 \u0938\u0930\u094D\u0935\u0930 \u092A\u0930 \u0938\u0939\u0947\u091C\u093E',
            '\u0938\u0902\u0926\u0947\u0936 \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0935\u0930 \u091C\u0924\u0928 \u0915\u0947\u0932\u093E',
          ),
        );
        _toEnd();
      }
    } catch (_) {
      try {
        final remaining = await _service.pending(_uid, widget.offer.path);
        if (mounted) setState(() => _pending = remaining);
      } catch (_) {
        if (mounted) setState(() => _outboxReady = false);
      }
      if (mounted)
        setState(
          () => _message = serverSaved
              ? ct(
                  'Server saved this message; local cleanup is pending. Retry the same message, not a new copy.',
                  '\u0938\u0902\u0926\u0947\u0936 \u0938\u0930\u094D\u0935\u0930 \u092A\u0930 \u0938\u0939\u0947\u091C\u093E; \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0938\u092B\u093E\u0908 \u092C\u093E\u0915\u0940 \u0939\u0948\u0964 \u0928\u092F\u093E \u0928\u0939\u0940\u0902, \u092F\u0939\u0940 \u0938\u0902\u0926\u0947\u0936 \u092B\u093F\u0930 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                  '\u0938\u0902\u0926\u0947\u0936 \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0935\u0930 \u091C\u0924\u0928 \u091D\u093E\u0932\u093E; \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0938\u092B\u093E\u0908 \u092C\u093E\u0915\u0940. \u0928\u0935\u0940\u0928 \u0928\u093E\u0939\u0940, \u0939\u093E\u091A \u0938\u0902\u0926\u0947\u0936 \u092A\u0941\u0928\u094D\u0939\u093E \u0924\u092A\u093E\u0938\u093E.',
                )
              : ct(
                  'Send not confirmed. Check connection, current buyer authorization and chat rules. A saved pending message can be checked/retried with the SAME ID; timeout does not cancel a send.',
                  '\u092D\u0947\u091C\u0928\u0947 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902\u0964 \u0928\u0947\u091F\u0935\u0930\u094D\u0915, \u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u0940 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0905\u0928\u0941\u092E\u0924\u093F \u0914\u0930 \u091A\u0948\u091F \u0928\u093F\u092F\u092E \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u0938\u0939\u0947\u091C\u093E \u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u0909\u0938\u0940 ID \u0938\u0947 \u092B\u093F\u0930 \u091C\u093E\u0901\u091A/\u092D\u0947\u091C \u0938\u0915\u0924\u0947 \u0939\u0948\u0902; \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0938\u0947 \u092D\u0947\u091C\u0928\u093E \u0930\u0926\u094D\u0926 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u093E\u0964',
                  '\u092A\u093E\u0920\u0935\u0923\u0947 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940. \u0928\u0947\u091F\u0935\u0930\u094D\u0915, \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930\u093E\u091A\u0940 \u0938\u0927\u094D\u092F\u093E\u091A\u0940 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0935 \u091A\u0945\u091F \u0928\u093F\u092F\u092E \u0924\u092A\u093E\u0938\u093E. \u091C\u0924\u0928 \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u0924\u094D\u092F\u093E\u091A ID \u0928\u0947 \u092A\u0941\u0928\u094D\u0939\u093E \u0924\u092A\u093E\u0938\u0942/\u092A\u093E\u0920\u0935\u0942 \u0936\u0915\u0924\u093E; \u091F\u093E\u0907\u092E\u0906\u0909\u091F\u0928\u0947 \u092A\u093E\u0920\u0935\u0923\u0947 \u0930\u0926\u094D\u0926 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
                ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardLocal() async {
    if (_busy || _pending == null || _uid == null) return;
    if (!await confirmAction(
          context,
          ct(
            'Remove only this phone\u2019s pending copy? This does NOT unsend anything: an earlier timed-out send may still complete. Check history before sending a new copy.',
            '\u0915\u0947\u0935\u0932 \u0907\u0938 \u092B\u094B\u0928 \u0915\u0940 \u0932\u0902\u092C\u093F\u0924 \u0915\u0949\u092A\u0940 \u0939\u091F\u093E\u090F\u0901? \u0907\u0938\u0938\u0947 \u092D\u0947\u091C\u093E \u0938\u0902\u0926\u0947\u0936 \u0935\u093E\u092A\u0938 \u0928\u0939\u0940\u0902 \u0939\u094B\u0917\u093E: \u092A\u0941\u0930\u093E\u0928\u093E \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0935\u093E\u0932\u093E \u092D\u0947\u091C\u0928\u093E \u092A\u0942\u0930\u093E \u0939\u094B \u0938\u0915\u0924\u093E \u0939\u0948\u0964 \u0928\u0908 \u0915\u0949\u092A\u0940 \u092D\u0947\u091C\u0928\u0947 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0907\u0924\u093F\u0939\u093E\u0938 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
            '\u092B\u0915\u094D\u0924 \u092F\u093E \u092B\u094B\u0928\u091A\u0940 \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u092A\u094D\u0930\u0924 \u0915\u093E\u0922\u093E\u092F\u091A\u0940? \u092A\u093E\u0920\u0935\u0932\u0947\u0932\u093E \u0938\u0902\u0926\u0947\u0936 \u092E\u093E\u0917\u0947 \u092F\u0947\u0923\u093E\u0930 \u0928\u093E\u0939\u0940: \u091C\u0941\u0928\u093E \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u092A\u094D\u0930\u092F\u0924\u094D\u0928 \u092A\u0942\u0930\u094D\u0923 \u0939\u094B\u090A \u0936\u0915\u0924\u094B. \u0928\u0935\u0940\u0928 \u092A\u094D\u0930\u0924 \u092A\u093E\u0920\u0935\u0923\u094D\u092F\u093E\u0906\u0927\u0940 \u0907\u0924\u093F\u0939\u093E\u0938 \u092A\u0939\u093E.',
          ),
        ) ||
        !mounted)
      return;
    setState(() => _busy = true);
    try {
      await _service.clearLocal(_uid, widget.offer.path, _pending!['id']!);
      final remaining = await _service.pending(_uid, widget.offer.path);
      if (mounted) setState(() => _pending = remaining);
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Local copy could not be removed.',
            '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0915\u0949\u092A\u0940 \u0928\u0939\u0940\u0902 \u0939\u091F\u0940\u0964',
            '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092A\u094D\u0930\u0924 \u0915\u093E\u0922\u0924\u093E \u0906\u0932\u0940 \u0928\u093E\u0939\u0940.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Conversation',
      '\u092C\u093E\u0924\u091A\u0940\u0924',
      '\u091A\u0930\u094D\u091A\u093E',
    ),
    scrollController: _scroll,
    guide: () => ct(
      'This chat belongs to one real offer. Review updates or send text to the linked participant. Message contents are not read aloud automatically.',
      '\u092F\u0939 \u092C\u093E\u0924\u091A\u0940\u0924 \u090F\u0915 \u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u0911\u092B\u0930 \u0915\u0940 \u0939\u0948\u0964 \u0905\u092A\u0921\u0947\u091F \u0926\u0947\u0916\u0947\u0902 \u092F\u093E \u091C\u0941\u0921\u093C\u0947 \u0935\u094D\u092F\u0915\u094D\u0924\u093F \u0915\u094B \u091F\u0947\u0915\u094D\u0938\u094D\u091F \u092D\u0947\u091C\u0947\u0902\u0964 \u0938\u0902\u0926\u0947\u0936 \u0905\u092A\u0928\u0947 \u0906\u092A \u092C\u094B\u0932\u0915\u0930 \u0928\u0939\u0940\u0902 \u092A\u0922\u093C\u0947 \u091C\u093E\u0924\u0947\u0964',
      '\u0939\u0940 \u091A\u0930\u094D\u091A\u093E \u090F\u0915\u093E \u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u0911\u092B\u0930\u091A\u0940 \u0906\u0939\u0947. \u0905\u092A\u0921\u0947\u091F \u092A\u0939\u093E \u0915\u093F\u0902\u0935\u093E \u091C\u094B\u0921\u0932\u0947\u0932\u094D\u092F\u093E \u0935\u094D\u092F\u0915\u094D\u0924\u0940\u0932\u093E \u092E\u091C\u0915\u0942\u0930 \u092A\u093E\u0920\u0935\u093E. \u0938\u0902\u0926\u0947\u0936 \u0906\u092A\u094B\u0906\u092A \u092E\u094B\u0920\u094D\u092F\u093E\u0928\u0947 \u0935\u093E\u091A\u0932\u0947 \u091C\u093E\u0924 \u0928\u093E\u0939\u0940\u0924.',
    ),
    body: (context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _offerStream,
      builder: (context, s) {
        if (s.hasError)
          return note(
            ct(
              'Conversation unavailable. Check account access and connection.',
              '\u092C\u093E\u0924\u091A\u0940\u0924 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0916\u093E\u0924\u093E \u0905\u0928\u0941\u092E\u0924\u093F \u0914\u0930 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
              '\u091A\u0930\u094D\u091A\u093E \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940. \u0916\u093E\u0924\u0947 \u092A\u094D\u0930\u0935\u0947\u0936 \u0935 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0924\u092A\u093E\u0938\u093E.',
            ),
          );
        if (!s.hasData) return const LinearProgressIndicator();
        final v = s.data!.data();
        if (v == null ||
            _uid == null ||
            (v['collectorUid'] != _uid && v['recyclerUid'] != _uid))
          return note(
            ct(
              'No linked conversation for this account.',
              '\u0907\u0938 \u0916\u093E\u0924\u0947 \u0915\u0940 \u091C\u0941\u0921\u093C\u0940 \u092C\u093E\u0924\u091A\u0940\u0924 \u0928\u0939\u0940\u0902\u0964',
              '\u092F\u093E \u0916\u093E\u0924\u094D\u092F\u093E\u091A\u0940 \u091C\u094B\u0921\u0932\u0947\u0932\u0940 \u091A\u0930\u094D\u091A\u093E \u0928\u093E\u0939\u0940.',
            ),
          );
        final collector = v['collectorUid'] == _uid;
        final active =
            _chatAllowed &&
            v['schemaVersion'] == 2 &&
            chatWritableStatuses.contains(v['status']);
        final online =
            !s.data!.metadata.isFromCache && !s.data!.metadata.hasPendingWrites;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (v['schemaVersion'] == 2)
              ChatSafetyPanel(
                offer: widget.offer,
                collectorUid: '${v['collectorUid']}',
                recyclerUid: '${v['recyclerUid']}',
                onAvailability: (allowed) {
                  if (mounted && _chatAllowed != allowed)
                    setState(() => _chatAllowed = allowed);
                },
              ),

            Row(
              children: [
                MaterialPhoto(
                  material: '${v['material']}',
                  width: 52,
                  height: 60,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collector
                            ? '${v['recyclerName'] ?? ct('Linked recycler', '\u091C\u0941\u0921\u093C\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E', '\u091C\u094B\u0921\u0932\u0947\u0932\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E')}'
                            : ct(
                                'Linked collector',
                                '\u091C\u0941\u0921\u093C\u093E \u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915',
                                '\u091C\u094B\u0921\u0932\u0947\u0932\u093E \u0938\u0902\u0915\u0932\u0915',
                              ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${materialLabel('${v['material']}')} \u2022 ${v['weightKg']} kg',
                      ),
                      Text(
                        statusLabel('${v['status']}'),
                        style: const TextStyle(color: collectorGreen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (collector)
              actionButton(
                ct(
                  'View details & tracking',
                  '\u0935\u093F\u0935\u0930\u0923 \u0914\u0930 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917 \u0926\u0947\u0916\u0947\u0902',
                  '\u0924\u092A\u0936\u0940\u0932 \u0935 \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917 \u092A\u0939\u093E',
                ),
                () => openCollector(
                  context,
                  OfferDetailScreen(ref: widget.offer),
                ),
                icon: Icons.timeline,
              ),
            if (!online)
              note(
                ct(
                  'Cached offer view. Sending still needs a server check.',
                  '\u0915\u0948\u0936 \u0911\u092B\u0930\u0964 \u092D\u0947\u091C\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0938\u0930\u094D\u0935\u0930 \u091C\u093E\u0901\u091A \u091A\u093E\u0939\u093F\u090F\u0964',
                  '\u0915\u0945\u0936 \u0911\u092B\u0930. \u092A\u093E\u0920\u0935\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u0924\u092A\u093E\u0938\u0923\u0940 \u0939\u0935\u0940.',
                ),
              ),
            note(
              ct(
                'Text chat only. No automatic SMS/push, read receipts or live presence. Chat text does not change quote, handover or payment records.',
                '\u0915\u0947\u0935\u0932 \u091F\u0947\u0915\u094D\u0938\u094D\u091F \u091A\u0948\u091F\u0964 \u0905\u092A\u0928\u0947 \u0906\u092A SMS/\u092A\u0941\u0936, \u092A\u0922\u093C\u0928\u0947 \u0915\u0940 \u0930\u0938\u0940\u0926 \u092F\u093E \u0932\u093E\u0907\u0935 \u0909\u092A\u0938\u094D\u0925\u093F\u0924\u093F \u0928\u0939\u0940\u0902\u0964 \u091A\u0948\u091F \u0938\u0947 \u092D\u093E\u0935, \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u092F\u093E \u092D\u0941\u0917\u0924\u093E\u0928 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0928\u0939\u0940\u0902 \u092C\u0926\u0932\u0924\u0947\u0964',
                '\u092B\u0915\u094D\u0924 \u092E\u091C\u0915\u0942\u0930 \u091A\u0945\u091F. \u0906\u092A\u094B\u0906\u092A SMS/\u092A\u0941\u0936, \u0935\u093E\u091A\u0928 \u092A\u093E\u0935\u0924\u0940 \u0915\u093F\u0902\u0935\u093E \u0925\u0947\u091F \u0909\u092A\u0938\u094D\u0925\u093F\u0924\u0940 \u0928\u093E\u0939\u0940. \u091A\u0945\u091F\u0928\u0947 \u0926\u0930, \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0915\u093F\u0902\u0935\u093E \u092A\u0947\u092E\u0947\u0902\u091F \u0928\u094B\u0902\u0926\u0940 \u092C\u0926\u0932\u0924 \u0928\u093E\u0939\u0940\u0924.',
              ),
            ),
            if (v['schemaVersion'] != 2)
              note(
                ct(
                  'Legacy offer: chat is not enabled.',
                  '\u092A\u0941\u0930\u093E\u0928\u093E \u0911\u092B\u0930: \u091A\u0948\u091F \u091A\u093E\u0932\u0942 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                  '\u091C\u0941\u0928\u093E \u0911\u092B\u0930: \u091A\u0945\u091F \u0938\u0941\u0930\u0942 \u0928\u093E\u0939\u0940.',
                ),
              )
            else
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _history,
                builder: (context, m) {
                  if (m.hasError)
                    return note(
                      ct(
                        'Chat history unavailable. Publish the message rules and check access/network. Do not assume an empty conversation.',
                        '\u091A\u0948\u091F \u0907\u0924\u093F\u0939\u093E\u0938 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0938\u0902\u0926\u0947\u0936 \u0928\u093F\u092F\u092E \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0939\u0948\u0902 \u0914\u0930 \u092A\u0939\u0941\u0901\u091A/\u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0938\u0939\u0940 \u0939\u0948, \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u093E\u0932\u0940 \u092E\u093E\u0928\u0915\u0930 \u0928 \u091A\u0932\u0947\u0902\u0964',
                        '\u091A\u0945\u091F \u0907\u0924\u093F\u0939\u093E\u0938 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940. \u0938\u0902\u0926\u0947\u0936 \u0928\u093F\u092F\u092E \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0906\u0939\u0947\u0924 \u0935 \u092A\u094D\u0930\u0935\u0947\u0936/\u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u092F\u094B\u0917\u094D\u092F \u0906\u0939\u0947 \u0924\u0947 \u0924\u092A\u093E\u0938\u093E. \u091A\u0930\u094D\u091A\u093E \u0930\u093F\u0915\u093E\u092E\u0940 \u0938\u092E\u091C\u0942 \u0928\u0915\u093E.',
                      ),
                    );
                  if (!m.hasData) return const LinearProgressIndicator();
                  if (!_firstScroll) {
                    _firstScroll = true;
                    _toEnd();
                  }
                  final docs = m.data!.docs.reversed.toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m.data!.metadata.isFromCache)
                        note(
                          ct(
                            'Cached messages \u2014 not a fresh server view.',
                            '\u0915\u0948\u0936 \u0938\u0902\u0926\u0947\u0936 \u2014 \u0928\u0908 \u0938\u0930\u094D\u0935\u0930 \u091C\u093E\u0928\u0915\u093E\u0930\u0940 \u0928\u0939\u0940\u0902\u0964',
                            '\u0915\u0945\u0936 \u0938\u0902\u0926\u0947\u0936 \u2014 \u0928\u0935\u0940\u0928 \u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u092E\u093E\u0939\u093F\u0924\u0940 \u0928\u093E\u0939\u0940.',
                          ),
                        ),
                      if (m.data!.docs.length >= _limit && _limit < 200)
                        TextButton(
                          onPressed: () {
                            AppSpeech.instance.say(
                              ct(
                                'Load older messages',
                                '\u092A\u0941\u0930\u093E\u0928\u0947 \u0938\u0902\u0926\u0947\u0936 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902',
                                '\u091C\u0941\u0928\u0947 \u0938\u0902\u0926\u0947\u0936 \u0932\u094B\u0921 \u0915\u0930\u093E',
                              ),
                            );
                            setState(() {
                              _limit += 50;
                              _history = _historyStream();
                            });
                          },
                          child: Text(
                            ct(
                              'Load older messages',
                              '\u092A\u0941\u0930\u093E\u0928\u0947 \u0938\u0902\u0926\u0947\u0936 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902',
                              '\u091C\u0941\u0928\u0947 \u0938\u0902\u0926\u0947\u0936 \u0932\u094B\u0921 \u0915\u0930\u093E',
                            ),
                          ),
                        ),
                      if (docs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            ct(
                              'No messages in this view yet.',
                              '\u0907\u0938 \u0938\u0942\u091A\u0940 \u092E\u0947\u0902 \u0905\u092D\u0940 \u0938\u0902\u0926\u0947\u0936 \u0928\u0939\u0940\u0902\u0964',
                              '\u092F\u093E \u0926\u0943\u0936\u094D\u092F\u093E\u0924 \u0905\u091C\u0942\u0928 \u0938\u0902\u0926\u0947\u0936 \u0928\u093E\u0939\u0940\u0924.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ...docs.map((d) {
                        final message = d.data(),
                            mine = d.data()['senderUid'] == _uid;
                        return ChatBubble(
                          key: ValueKey('message_${d.id}'),
                          text: message['text'] is String
                              ? message['text']
                              : ct(
                                  'Unsupported message',
                                  '\u0905\u0938\u092E\u0930\u094D\u0925\u093F\u0924 \u0938\u0902\u0926\u0947\u0936',
                                  '\u0905\u0938\u092E\u0930\u094D\u0925\u093F\u0924 \u0938\u0902\u0926\u0947\u0936',
                                ),
                          mine: mine,
                          sender: mine
                              ? ct(
                                  'You',
                                  '\u0906\u092A',
                                  '\u0924\u0941\u092E\u094D\u0939\u0940',
                                )
                              : collector
                              ? ct(
                                  'Recycler',
                                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E',
                                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E',
                                )
                              : ct(
                                  'Collector',
                                  '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915',
                                  '\u0938\u0902\u0915\u0932\u0915',
                                ),
                          timestamp: message['createdAt'],
                          pending: d.metadata.hasPendingWrites,
                        );
                      }),
                      if (_limit == 200 && docs.length == 200)
                        note(
                          ct(
                            'Most recent 200 messages shown. Older history is outside this view.',
                            '\u0928\u0935\u0940\u0928\u0924\u092E 200 \u0938\u0902\u0926\u0947\u0936 \u0926\u093F\u0916 \u0930\u0939\u0947 \u0939\u0948\u0902\u0964 \u092A\u0941\u0930\u093E\u0928\u093E \u0907\u0924\u093F\u0939\u093E\u0938 \u0907\u0938 \u0938\u0942\u091A\u0940 \u0938\u0947 \u092C\u093E\u0939\u0930 \u0939\u0948\u0964',
                            '\u0928\u0935\u0940\u0928\u0924\u092E 200 \u0938\u0902\u0926\u0947\u0936 \u0926\u093F\u0938\u0924\u093E\u0924. \u091C\u0941\u0928\u093E \u0907\u0924\u093F\u0939\u093E\u0938 \u092F\u093E \u0926\u0943\u0936\u094D\u092F\u093E\u092C\u093E\u0939\u0947\u0930 \u0906\u0939\u0947.',
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (!chatWritableStatuses.contains(v['status']) ||
                v['schemaVersion'] != 2)
              note(
                ct(
                  'This conversation is read-only. Withdrawn/rejected or legacy offers cannot send new messages.',
                  '\u092F\u0939 \u092C\u093E\u0924\u091A\u0940\u0924 \u0915\u0947\u0935\u0932 \u092A\u0922\u093C\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0939\u0948\u0964 \u0935\u093E\u092A\u0938 \u0932\u093F\u090F/\u0905\u0938\u094D\u0935\u0940\u0915\u0943\u0924 \u092F\u093E \u092A\u0941\u0930\u093E\u0928\u0947 \u0911\u092B\u0930 \u092E\u0947\u0902 \u0928\u092F\u093E \u0938\u0902\u0926\u0947\u0936 \u0928\u0939\u0940\u0902 \u092D\u0947\u091C \u0938\u0915\u0924\u0947\u0964',
                  '\u0939\u0940 \u091A\u0930\u094D\u091A\u093E \u092B\u0915\u094D\u0924 \u0935\u093E\u091A\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0906\u0939\u0947. \u092E\u093E\u0917\u0947 \u0918\u0947\u0924\u0932\u0947\u0932\u094D\u092F\u093E/\u0928\u093E\u0915\u093E\u0930\u0932\u0947\u0932\u094D\u092F\u093E \u0915\u093F\u0902\u0935\u093E \u091C\u0941\u0928\u094D\u092F\u093E \u0911\u092B\u0930\u092E\u0927\u094D\u092F\u0947 \u0928\u0935\u0940\u0928 \u0938\u0902\u0926\u0947\u0936 \u092A\u093E\u0920\u0935\u0924\u093E \u092F\u0947\u0924 \u0928\u093E\u0939\u0940.',
                ),
              ),
            if (_pending != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEC9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ct(
                        'Local outbox copy \u2014 check send status',
                        '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0906\u0909\u091F\u092C\u0949\u0915\u094D\u0938 \u0915\u0949\u092A\u0940 \u2014 \u092D\u0947\u091C\u0928\u0947 \u0915\u0940 \u0938\u094D\u0925\u093F\u0924\u093F \u091C\u093E\u0901\u091A\u0947\u0902',
                        '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0906\u0909\u091F\u092C\u0949\u0915\u094D\u0938 \u092A\u094D\u0930\u0924 \u2014 \u092A\u093E\u0920\u0935\u0923\u094D\u092F\u093E\u091A\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u0924\u092A\u093E\u0938\u093E',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_pending!['text']!),
                    actionButton(
                      ct(
                        'Check / retry SAME message',
                        '\u092F\u0939\u0940 \u0938\u0902\u0926\u0947\u0936 \u091C\u093E\u0901\u091A\u0947\u0902 / \u092B\u093F\u0930 \u092D\u0947\u091C\u0947\u0902',
                        '\u0939\u093E\u091A \u0938\u0902\u0926\u0947\u0936 \u0924\u092A\u093E\u0938\u093E / \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093E',
                      ),
                      _busy ? null : () => _send(retry: true),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _discardLocal,
                      child: Text(
                        ct(
                          'Remove local copy only',
                          '\u0915\u0947\u0935\u0932 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0915\u0949\u092A\u0940 \u0939\u091F\u093E\u090F\u0901',
                          '\u092B\u0915\u094D\u0924 \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092A\u094D\u0930\u0924 \u0915\u093E\u0922\u093E',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_outboxReady)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        AppSpeech.instance.say(
                          ct(
                            'Reload local message',
                            '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0938\u0902\u0926\u0947\u0936 \u092B\u093F\u0930 \u0916\u094B\u0932\u0947\u0902',
                            '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0938\u0902\u0926\u0947\u0936 \u092A\u0941\u0928\u094D\u0939\u093E \u0909\u0918\u0921\u093E',
                          ),
                        );
                        unawaited(_restore());
                      },
                child: Text(
                  ct(
                    'Load local pending message',
                    '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902',
                    '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u0932\u094B\u0921 \u0915\u0930\u093E',
                  ),
                ),
              ),
            TextField(
              controller: _text,
              enabled: active && _outboxReady && !_busy && _pending == null,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: ct(
                  'Write a message\u2026',
                  '\u0938\u0902\u0926\u0947\u0936 \u0932\u093F\u0916\u0947\u0902\u2026',
                  '\u0938\u0902\u0926\u0947\u0936 \u0932\u093F\u0939\u093E\u2026',
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            actionButton(
              ct(
                'Send message',
                '\u0938\u0902\u0926\u0947\u0936 \u092D\u0947\u091C\u0947\u0902',
                '\u0938\u0902\u0926\u0947\u0936 \u092A\u093E\u0920\u0935\u093E',
              ),
              active && _outboxReady && !_busy && _pending == null
                  ? () => _send()
                  : null,
              icon: Icons.send_outlined,
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) note(_message!),
            note(
              ct(
                'Pressing Send saves one pending copy on this device before contacting the server. Unsent typing is not saved. Retry is manual; never share OTPs or banking passwords.',
                'Send \u0926\u092C\u093E\u0928\u0947 \u092A\u0930 \u0938\u0930\u094D\u0935\u0930 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0907\u0938 \u0921\u093F\u0935\u093E\u0907\u0938 \u092A\u0930 \u090F\u0915 \u0932\u0902\u092C\u093F\u0924 \u0915\u0949\u092A\u0940 \u0938\u0939\u0947\u091C\u0924\u0947 \u0939\u0948\u0902\u0964 \u092C\u093F\u0928\u093E Send \u0915\u0940 \u091F\u093E\u0907\u092A\u093F\u0902\u0917 \u0928\u0939\u0940\u0902 \u0938\u0939\u0947\u091C\u0924\u0947\u0964 \u092B\u093F\u0930 \u092D\u0947\u091C\u0928\u093E \u092E\u0948\u0928\u0941\u0905\u0932 \u0939\u0948; OTP \u092F\u093E \u092C\u0948\u0902\u0915 \u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0928 \u092D\u0947\u091C\u0947\u0902\u0964',
                'Send \u0926\u093E\u092C\u0932\u094D\u092F\u093E\u0935\u0930 \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0906\u0927\u0940 \u092F\u093E \u0921\u093F\u0935\u094D\u0939\u093E\u0907\u0938\u0935\u0930 \u090F\u0915 \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u092A\u094D\u0930\u0924 \u091C\u0924\u0928 \u0939\u094B\u0924\u0947. Send \u0928 \u0915\u0947\u0932\u0947\u0932\u0940 \u091F\u093E\u092F\u092A\u093F\u0902\u0917 \u091C\u0924\u0928 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u0923\u0947 \u0938\u094D\u0935\u0924\u0903 \u0915\u0930\u093E\u0935\u0947; OTP \u0915\u093F\u0902\u0935\u093E \u092C\u0901\u0915 \u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u092A\u093E\u0920\u0935\u0942 \u0928\u0915\u093E.',
              ),
            ),
          ],
        );
      },
    ),
  );
}
