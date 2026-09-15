import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collector_ui.dart';
import 'app_speech.dart';
import 'collector_messages.dart' show OfferChatScreen;

const chatReportReasons = ['spam', 'abuse', 'fraud', 'unsafe', 'other'];
String chatReportLabel(String reason) => switch (reason) {
  'spam' => ct(
    'Spam',
    '\u0938\u094D\u092A\u0948\u092E',
    '\u0938\u094D\u092A\u0945\u092E',
  ),
  'abuse' => ct(
    'Abusive messages',
    '\u0905\u092A\u092E\u093E\u0928\u091C\u0928\u0915 \u0938\u0902\u0926\u0947\u0936',
    '\u0905\u092A\u092E\u093E\u0928\u093E\u0938\u094D\u092A\u0926 \u0938\u0902\u0926\u0947\u0936',
  ),
  'fraud' => ct(
    'Suspected fraud',
    '\u0927\u094B\u0916\u093E\u0927\u0921\u093C\u0940 \u0915\u093E \u0938\u0902\u0926\u0947\u0939',
    '\u092B\u0938\u0935\u0923\u0941\u0915\u0940\u091A\u093E \u0938\u0902\u0936\u092F',
  ),
  'unsafe' => ct(
    'Unsafe handover request',
    '\u0905\u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u092E\u093E\u0901\u0917',
    '\u0905\u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092E\u093E\u0917\u0923\u0940',
  ),
  _ => ct(
    'Other concern',
    '\u0905\u0928\u094D\u092F \u0938\u092E\u0938\u094D\u092F\u093E',
    '\u0907\u0924\u0930 \u0938\u092E\u0938\u094D\u092F\u093E',
  ),
};
bool chatCanSendFromControls(
  Map<String, dynamic>? own,
  Map<String, dynamic>? peer, {
  required bool loaded,
  required bool error,
}) => loaded && !error && own?['blocked'] != true && peer?['blocked'] != true;

/// Either participant can pause THIS conversation, not the whole business/account.
/// Reports are records for later review; this UI never claims a reviewer responded.
class ChatSafetyPanel extends StatefulWidget {
  const ChatSafetyPanel({
    required this.offer,
    required this.collectorUid,
    required this.recyclerUid,
    required this.onAvailability,
    super.key,
  });
  final DocumentReference<Map<String, dynamic>> offer;
  final String collectorUid, recyclerUid;
  final ValueChanged<bool> onAvailability;
  @override
  State<ChatSafetyPanel> createState() => _ChatSafetyState();
}

class _ChatSafetyState extends State<ChatSafetyPanel> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _busy = false;
  bool? _lastAvailability;
  String? _message;
  late final _own = widget.offer.collection('chatControls').doc(_uid);
  late final _peer = widget.offer
      .collection('chatControls')
      .doc(
        _uid == widget.collectorUid ? widget.recyclerUid : widget.collectorUid,
      );
  late final _ownStream = _own.snapshots(includeMetadataChanges: true),
      _peerStream = _peer.snapshots(includeMetadataChanges: true);
  void _notify(bool allowed) {
    if (_lastAvailability == allowed) return;
    _lastAvailability = allowed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAvailability(allowed);
    });
  }

  Future<void> _change(bool blocked) async {
    if (_busy || _uid == null) return;
    if (!await confirmAction(
          context,
          blocked
              ? ct(
                  'Block new messages in THIS conversation in both directions? Existing history and the deal remain unchanged. This does not cancel an offer, handover or payment.',
                  '\u0907\u0938 \u092C\u093E\u0924\u091A\u0940\u0924 \u092E\u0947\u0902 \u0926\u094B\u0928\u094B\u0902 \u0926\u093F\u0936\u093E\u0913\u0902 \u0915\u0947 \u0928\u090F \u0938\u0902\u0926\u0947\u0936 \u0930\u094B\u0915\u0947\u0902? \u092A\u0941\u0930\u093E\u0928\u093E \u0907\u0924\u093F\u0939\u093E\u0938 \u0914\u0930 \u0938\u094C\u0926\u093E \u0928\u0939\u0940\u0902 \u092C\u0926\u0932\u0947\u0902\u0917\u0947\u0964 \u0911\u092B\u0930, \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u092F\u093E \u092D\u0941\u0917\u0924\u093E\u0928 \u0930\u0926\u094D\u0926 \u0928\u0939\u0940\u0902 \u0939\u094B\u0917\u093E\u0964',
                  '\u092F\u093E \u091A\u0930\u094D\u091A\u0947\u0924 \u0926\u094B\u0928\u094D\u0939\u0940 \u0926\u093F\u0936\u093E\u0902\u091A\u0947 \u0928\u0935\u0940\u0928 \u0938\u0902\u0926\u0947\u0936 \u0925\u093E\u0902\u092C\u0935\u093E\u092F\u091A\u0947? \u091C\u0941\u0928\u093E \u0907\u0924\u093F\u0939\u093E\u0938 \u0935 \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u092C\u0926\u0932\u0923\u093E\u0930 \u0928\u093E\u0939\u0940. \u0911\u092B\u0930, \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0915\u093F\u0902\u0935\u093E \u092A\u0947\u092E\u0947\u0902\u091F \u0930\u0926\u094D\u0926 \u0939\u094B\u0923\u093E\u0930 \u0928\u093E\u0939\u0940.',
                )
              : ct(
                  'Remove your block for this conversation? The other participant may still have it blocked.',
                  '\u0907\u0938 \u092C\u093E\u0924\u091A\u0940\u0924 \u0938\u0947 \u0905\u092A\u0928\u093E \u092C\u094D\u0932\u0949\u0915 \u0939\u091F\u093E\u090F\u0901? \u0926\u0942\u0938\u0930\u0947 \u0935\u094D\u092F\u0915\u094D\u0924\u093F \u0915\u093E \u092C\u094D\u0932\u0949\u0915 \u0930\u0939 \u0938\u0915\u0924\u093E \u0939\u0948\u0964',
                  '\u092F\u093E \u091A\u0930\u094D\u091A\u0947\u0924\u0940\u0932 \u0924\u0941\u092E\u091A\u093E \u092C\u094D\u0932\u0949\u0915 \u0915\u093E\u0922\u093E\u092F\u091A\u093E? \u0926\u0941\u0938\u0931\u094D\u092F\u093E \u0935\u094D\u092F\u0915\u094D\u0924\u0940\u091A\u093E \u092C\u094D\u0932\u0949\u0915 \u0930\u093E\u0939\u0942 \u0936\u0915\u0924\u094B.',
                ),
        ) ||
        !mounted)
      return;
    setState(() => _busy = true);
    try {
      await widget.offer.firestore
          .runTransaction((t) async {
            await t.get(_own);
            if (FirebaseAuth.instance.currentUser?.uid != _uid)
              throw StateError('account-changed');
            t.set(_own, {
              'schemaVersion': 1,
              'ownerUid': _uid,
              'blocked': blocked,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 25));
      if (mounted)
        setState(
          () => _message = ct(
            'Server confirmed your chat setting.',
            '\u0938\u0930\u094D\u0935\u0930 \u0928\u0947 \u091A\u0948\u091F \u0938\u0947\u091F\u093F\u0902\u0917 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0940\u0964',
            '\u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0928\u0947 \u091A\u0945\u091F \u0938\u0947\u091F\u093F\u0902\u0917 \u092A\u0941\u0937\u094D\u091F \u0915\u0947\u0932\u0940.',
          ),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Setting not confirmed. Check connection and rules. A timeout may still complete; inspect the displayed state before retrying.',
            '\u0938\u0947\u091F\u093F\u0902\u0917 \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902\u0964 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0914\u0930 \u0928\u093F\u092F\u092E \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0915\u0947 \u092C\u093E\u0926 \u092D\u0940 \u092A\u0942\u0930\u093E \u0939\u094B \u0938\u0915\u0924\u093E \u0939\u0948; \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0926\u093F\u0916\u093E\u0908 \u0938\u094D\u0925\u093F\u0924\u093F \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
            '\u0938\u0947\u091F\u093F\u0902\u0917 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940. \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0935 \u0928\u093F\u092F\u092E \u0924\u092A\u093E\u0938\u093E. \u091F\u093E\u0907\u092E\u0906\u0909\u091F\u0928\u0902\u0924\u0930\u0939\u0940 \u092A\u0942\u0930\u094D\u0923 \u0939\u094B\u090A \u0936\u0915\u0924\u0947; \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928\u093E\u0906\u0927\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u092A\u0939\u093E.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ownStream,
        builder: (context, a) =>
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _peerStream,
              builder: (context, b) {
                final loaded = a.hasData && b.hasData,
                    error = a.hasError || b.hasError;
                final own = a.data?.data(), peer = b.data?.data();
                final mine = own?['blocked'] == true;
                final allowed = chatCanSendFromControls(
                  own,
                  peer,
                  loaded: loaded,
                  error: error,
                );
                _notify(allowed);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error)
                      note(
                        ct(
                          'Chat controls unavailable. New sending is disabled; check rules/network. History remains separate.',
                          '\u091A\u0948\u091F \u0928\u093F\u092F\u0902\u0924\u094D\u0930\u0923 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0928\u092F\u093E \u0938\u0902\u0926\u0947\u0936 \u092D\u0947\u091C\u0928\u093E \u092C\u0902\u0926 \u0939\u0948; \u0928\u093F\u092F\u092E/\u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u0907\u0924\u093F\u0939\u093E\u0938 \u0905\u0932\u0917 \u0939\u0948\u0964',
                          '\u091A\u0945\u091F \u0928\u093F\u092F\u0902\u0924\u094D\u0930\u0923\u0947 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940\u0924. \u0928\u0935\u0940\u0928 \u0938\u0902\u0926\u0947\u0936 \u092A\u093E\u0920\u0935\u0923\u0947 \u092C\u0902\u0926; \u0928\u093F\u092F\u092E/\u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0924\u092A\u093E\u0938\u093E. \u0907\u0924\u093F\u0939\u093E\u0938 \u0935\u0947\u0917\u0933\u093E \u0906\u0939\u0947.',
                        ),
                      )
                    else if (!loaded)
                      const LinearProgressIndicator()
                    else if (!allowed)
                      note(
                        ct(
                          'New messages are blocked for this conversation. Existing history is retained. This does not cancel the deal.',
                          '\u0907\u0938 \u092C\u093E\u0924\u091A\u0940\u0924 \u0915\u0947 \u0928\u090F \u0938\u0902\u0926\u0947\u0936 \u092C\u094D\u0932\u0949\u0915 \u0939\u0948\u0902\u0964 \u092A\u0941\u0930\u093E\u0928\u093E \u0907\u0924\u093F\u0939\u093E\u0938 \u0930\u0939\u0947\u0917\u093E\u0964 \u0938\u094C\u0926\u093E \u0930\u0926\u094D\u0926 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u093E\u0964',
                          '\u092F\u093E \u091A\u0930\u094D\u091A\u0947\u0924\u0940\u0932 \u0928\u0935\u0940\u0928 \u0938\u0902\u0926\u0947\u0936 \u092C\u094D\u0932\u0949\u0915 \u0906\u0939\u0947\u0924. \u091C\u0941\u0928\u093E \u0907\u0924\u093F\u0939\u093E\u0938 \u0930\u093E\u0939\u0940\u0932. \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u0930\u0926\u094D\u0926 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
                        ),
                      ),
                    if (loaded &&
                        (a.data!.metadata.isFromCache ||
                            b.data!.metadata.isFromCache))
                      note(
                        ct(
                          'Cached chat-control view. Server rules recheck blocks on every new send.',
                          '\u0915\u0948\u0936 \u091A\u0948\u091F \u0928\u093F\u092F\u0902\u0924\u094D\u0930\u0923\u0964 \u0939\u0930 \u0928\u090F \u0938\u0902\u0926\u0947\u0936 \u092A\u0930 \u0938\u0930\u094D\u0935\u0930 \u092C\u094D\u0932\u0949\u0915 \u092B\u093F\u0930 \u091C\u093E\u0901\u091A\u0924\u093E \u0939\u0948\u0964',
                          '\u0915\u0945\u0936 \u091A\u0945\u091F \u0928\u093F\u092F\u0902\u0924\u094D\u0930\u0923\u0947. \u092A\u094D\u0930\u0924\u094D\u092F\u0947\u0915 \u0928\u0935\u0940\u0928 \u0938\u0902\u0926\u0947\u0936\u093E\u0935\u0930 \u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u092C\u094D\u0932\u0949\u0915 \u092A\u0941\u0928\u094D\u0939\u093E \u0924\u092A\u093E\u0938\u0924\u094B.',
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy || !loaded || error
                              ? null
                              : () => _change(!mine),
                          icon: Icon(mine ? Icons.lock_open : Icons.block),
                          label: Text(
                            mine
                                ? ct(
                                    'Unblock this chat',
                                    '\u092F\u0939 \u091A\u0948\u091F \u0905\u0928\u092C\u094D\u0932\u0949\u0915 \u0915\u0930\u0947\u0902',
                                    '\u0939\u093E \u091A\u0945\u091F \u0905\u0928\u092C\u094D\u0932\u0949\u0915 \u0915\u0930\u093E',
                                  )
                                : ct(
                                    'Block this chat',
                                    '\u092F\u0939 \u091A\u0948\u091F \u092C\u094D\u0932\u0949\u0915 \u0915\u0930\u0947\u0902',
                                    '\u0939\u093E \u091A\u0945\u091F \u092C\u094D\u0932\u0949\u0915 \u0915\u0930\u093E',
                                  ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _uid == null || _busy
                              ? null
                              : () => openCollector(
                                  context,
                                  ChatReportScreen(offer: widget.offer),
                                ),
                          icon: const Icon(Icons.flag_outlined),
                          label: Text(
                            ct(
                              'Report concern',
                              '\u0938\u092E\u0938\u094D\u092F\u093E \u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0915\u0930\u0947\u0902',
                              '\u0938\u092E\u0938\u094D\u092F\u093E \u0928\u094B\u0902\u0926\u0935\u093E',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_busy) const LinearProgressIndicator(),
                    if (_message != null) note(_message!),
                  ],
                );
              },
            ),
      );
}

class ChatReportScreen extends StatefulWidget {
  const ChatReportScreen({required this.offer, super.key});
  final DocumentReference<Map<String, dynamic>> offer;
  @override
  State<ChatReportScreen> createState() => _ChatReportState();
}

class _ChatReportState extends State<ChatReportScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _details = TextEditingController();
  String _reason = 'spam';
  bool _busy = false, _consent = false;
  String? _message;
  late final _ref = widget.offer.collection('chatReports').doc(_uid);
  late final _stream = _ref.snapshots(includeMetadataChanges: true);
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_uid == null || _busy || !_consent) return;
    if (_details.text.trim().length > 500) {
      setState(
        () => _message = ct(
          'Shorten the report details (maximum 500 text units).',
          '\u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0915\u093E \u0935\u093F\u0935\u0930\u0923 \u091B\u094B\u091F\u093E \u0915\u0930\u0947\u0902 (\u0905\u0927\u093F\u0915\u0924\u092E 500 \u091F\u0947\u0915\u094D\u0938\u094D\u091F \u0907\u0915\u093E\u0907\u092F\u093E\u0901)\u0964',
          '\u0905\u0939\u0935\u093E\u0932\u093E\u091A\u0947 \u0924\u092A\u0936\u0940\u0932 \u0915\u092E\u0940 \u0915\u0930\u093E (\u0915\u092E\u093E\u0932 500 \u092E\u091C\u0915\u0942\u0930 \u090F\u0915\u0915\u0947).',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await widget.offer.firestore
          .runTransaction<bool>((t) async {
            final old = await t.get(_ref);
            if (FirebaseAuth.instance.currentUser?.uid != _uid)
              throw StateError('account-changed');
            if (old.exists) return false;
            t.set(_ref, {
              'schemaVersion': 1,
              'reporterUid': _uid,
              'reason': _reason,
              'details': _details.text.trim(),
              'status': 'recorded',
              'createdAt': FieldValue.serverTimestamp(),
            });
            return true;
          })
          .timeout(const Duration(seconds: 25));
      if (mounted)
        setState(
          () => _message = created
              ? ct(
                  'Report record saved. No review or response time is confirmed.',
                  '\u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0938\u0939\u0947\u091C\u093E \u0917\u092F\u093E\u0964 \u0938\u092E\u0940\u0915\u094D\u0937\u093E \u092F\u093E \u091C\u0935\u093E\u092C \u0915\u093E \u0938\u092E\u092F \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                  '\u0905\u0939\u0935\u093E\u0932 \u0928\u094B\u0902\u0926 \u091C\u0924\u0928 \u091D\u093E\u0932\u0940. \u092A\u0941\u0928\u0930\u093E\u0935\u0932\u094B\u0915\u0928 \u0915\u093F\u0902\u0935\u093E \u0909\u0924\u094D\u0924\u0930\u093E\u091A\u0940 \u0935\u0947\u0933 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940.',
                )
              : ct(
                  'An earlier report already exists; its original details were kept.',
                  '\u092A\u0939\u0932\u0940 \u0930\u093F\u092A\u094B\u0930\u094D\u091F \u092E\u094C\u091C\u0942\u0926 \u0939\u0948; \u092A\u0941\u0930\u093E\u0928\u0947 \u0935\u093F\u0935\u0930\u0923 \u0930\u0916\u0947 \u0917\u090F\u0964',
                  '\u0906\u0927\u0940\u091A\u093E \u0905\u0939\u0935\u093E\u0932 \u0906\u0939\u0947; \u092E\u0942\u0933 \u0924\u092A\u0936\u0940\u0932 \u0920\u0947\u0935\u0932\u0947 \u0906\u0939\u0947\u0924.',
                ),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Report not confirmed. Check the saved record before retrying; a timeout does not cancel a submission.',
            '\u0930\u093F\u092A\u094B\u0930\u094D\u091F \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902\u0964 \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0938\u0939\u0947\u091C\u093E \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u091C\u093E\u0901\u091A\u0947\u0902; \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0938\u0947 \u092D\u0947\u091C\u0928\u093E \u0930\u0926\u094D\u0926 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u093E\u0964',
            '\u0905\u0939\u0935\u093E\u0932 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928\u093E\u0906\u0927\u0940 \u091C\u0924\u0928 \u0928\u094B\u0902\u0926 \u0924\u092A\u093E\u0938\u093E; \u091F\u093E\u0907\u092E\u0906\u0909\u091F\u0928\u0947 \u0938\u093E\u0926\u0930\u0940\u0915\u0930\u0923 \u0930\u0926\u094D\u0926 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Report conversation',
      '\u092C\u093E\u0924\u091A\u0940\u0924 \u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0915\u0930\u0947\u0902',
      '\u091A\u0930\u094D\u091A\u093E \u0905\u0939\u0935\u093E\u0932',
    ),
    body: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        note(
          ct(
            'One report record per participant for this offer. It is private from the other participant. An admin review workflow is not connected yet; this is not emergency support. Block chat separately if needed.',
            '\u0907\u0938 \u0911\u092B\u0930 \u092E\u0947\u0902 \u0939\u0930 \u0935\u094D\u092F\u0915\u094D\u0924\u093F \u0915\u0940 \u090F\u0915 \u0930\u093F\u092A\u094B\u0930\u094D\u091F\u0964 \u092F\u0939 \u0926\u0942\u0938\u0930\u0947 \u0935\u094D\u092F\u0915\u094D\u0924\u093F \u0938\u0947 \u0928\u093F\u091C\u0940 \u0939\u0948\u0964 \u090F\u0921\u092E\u093F\u0928 \u0938\u092E\u0940\u0915\u094D\u0937\u093E \u0905\u092D\u0940 \u091C\u0941\u0921\u093C\u0940 \u0928\u0939\u0940\u0902 \u0939\u0948; \u092F\u0939 \u0906\u092A\u093E\u0924\u0915\u093E\u0932\u0940\u0928 \u0938\u0939\u093E\u092F\u0924\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964 \u091C\u093C\u0930\u0942\u0930\u0924 \u0939\u094B \u0924\u094B \u091A\u0948\u091F \u0905\u0932\u0917 \u0938\u0947 \u092C\u094D\u0932\u0949\u0915 \u0915\u0930\u0947\u0902\u0964',
            '\u092F\u093E \u0911\u092B\u0930\u0938\u093E\u0920\u0940 \u092A\u094D\u0930\u0924\u094D\u092F\u0947\u0915 \u0935\u094D\u092F\u0915\u094D\u0924\u0940\u091A\u093E \u090F\u0915 \u0905\u0939\u0935\u093E\u0932. \u0924\u094B \u0926\u0941\u0938\u0931\u094D\u092F\u093E \u0935\u094D\u092F\u0915\u094D\u0924\u0940\u092A\u093E\u0938\u0942\u0928 \u0916\u093E\u091C\u0917\u0940 \u0906\u0939\u0947. \u092A\u094D\u0930\u0936\u093E\u0938\u0915 \u092A\u0941\u0928\u0930\u093E\u0935\u0932\u094B\u0915\u0928 \u0905\u091C\u0942\u0928 \u091C\u094B\u0921\u0932\u0947\u0932\u0947 \u0928\u093E\u0939\u0940; \u0939\u0940 \u0906\u092A\u0924\u094D\u0915\u093E\u0932\u0940\u0928 \u092E\u0926\u0924 \u0928\u093E\u0939\u0940. \u0917\u0930\u091C \u0905\u0938\u0932\u094D\u092F\u093E\u0938 \u091A\u0945\u091F \u0935\u0947\u0917\u0933\u093E \u092C\u094D\u0932\u0949\u0915 \u0915\u0930\u093E.',
          ),
        ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, s) {
            if (s.hasError)
              return note(
                ct(
                  'Report records unavailable; check access and rules.',
                  '\u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902; \u0905\u0928\u0941\u092E\u0924\u093F \u0914\u0930 \u0928\u093F\u092F\u092E \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                  '\u0905\u0939\u0935\u093E\u0932 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940; \u092A\u094D\u0930\u0935\u0947\u0936 \u0935 \u0928\u093F\u092F\u092E \u0924\u092A\u093E\u0938\u093E.',
                ),
              );
            if (!s.hasData) return const LinearProgressIndicator();
            final d = s.data!.data();
            if (d != null)
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ct(
                          'Recorded concern',
                          '\u0926\u0930\u094D\u091C \u0938\u092E\u0938\u094D\u092F\u093E',
                          '\u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u0940 \u0938\u092E\u0938\u094D\u092F\u093E',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(chatReportLabel('${d['reason']}')),
                      SelectableText('${d['details'] ?? ''}'),
                      Text(
                        ct(
                          'Recorded does not mean reviewed or resolved.',
                          '\u0926\u0930\u094D\u091C \u0915\u093E \u092E\u0924\u0932\u092C \u0938\u092E\u0940\u0915\u094D\u0937\u093E \u092F\u093E \u0938\u092E\u093E\u0927\u093E\u0928 \u0928\u0939\u0940\u0902\u0964',
                          '\u0928\u094B\u0902\u0926 \u091D\u093E\u0932\u0940 \u092E\u094D\u0939\u0923\u091C\u0947 \u092A\u0941\u0928\u0930\u093E\u0935\u0932\u094B\u0915\u0928 \u0915\u093F\u0902\u0935\u093E \u0928\u093F\u0930\u093E\u0915\u0930\u0923 \u0928\u093E\u0939\u0940.',
                        ),
                      ),
                      if (s.data!.metadata.isFromCache)
                        Text(
                          ct(
                            'Cached record',
                            '\u0915\u0948\u0936 \u0930\u093F\u0915\u0949\u0930\u094D\u0921',
                            '\u0915\u0945\u0936 \u0928\u094B\u0902\u0926',
                          ),
                        ),
                    ],
                  ),
                ),
              );
            return Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  isExpanded: true,
                  items: chatReportReasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(chatReportLabel(r)),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (r) {
                          if (r != null) {
                            setState(() => _reason = r);
                            AppSpeech.instance.say(chatReportLabel(r));
                          }
                        },
                  decoration: InputDecoration(
                    labelText: ct(
                      'Reason',
                      '\u0915\u093E\u0930\u0923',
                      '\u0915\u093E\u0930\u0923',
                    ),
                  ),
                ),
                TextField(
                  controller: _details,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: ct(
                      'Details (optional)',
                      '\u0935\u093F\u0935\u0930\u0923 (\u0935\u0948\u0915\u0932\u094D\u092A\u093F\u0915)',
                      '\u0924\u092A\u0936\u0940\u0932 (\u0910\u091A\u094D\u091B\u093F\u0915)',
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: _consent,
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _consent = v ?? false);
                          AppSpeech.instance.say(
                            ct(
                              'Report consent changed',
                              '\u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0915\u0940 \u0938\u0939\u092E\u0924\u093F \u092C\u0926\u0932\u0940',
                              '\u0905\u0939\u0935\u093E\u0932\u093E\u091A\u0940 \u0938\u0902\u092E\u0924\u0940 \u092C\u0926\u0932\u0932\u0940',
                            ),
                          );
                        },
                  title: Text(
                    ct(
                      'I agree to store this concern for project administrators. No OTPs or banking passwords included.',
                      '\u092E\u0948\u0902 \u092A\u0930\u093F\u092F\u094B\u091C\u0928\u093E \u092A\u094D\u0930\u0936\u093E\u0938\u0915\u094B\u0902 \u0915\u0947 \u0932\u093F\u090F \u0938\u092E\u0938\u094D\u092F\u093E \u0938\u0939\u0947\u091C\u0928\u0947 \u0915\u094B \u0938\u0939\u092E\u0924 \u0939\u0942\u0901\u0964 OTP \u092F\u093E \u092C\u0948\u0902\u0915 \u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0936\u093E\u092E\u093F\u0932 \u0928\u0939\u0940\u0902 \u0939\u0948\u0902\u0964',
                      '\u092E\u0940 \u092A\u094D\u0930\u0915\u0932\u094D\u092A \u092A\u094D\u0930\u0936\u093E\u0938\u0915\u093E\u0902\u0938\u093E\u0920\u0940 \u0938\u092E\u0938\u094D\u092F\u093E \u091C\u0924\u0928 \u0915\u0930\u0923\u094D\u092F\u093E\u0938 \u0938\u0939\u092E\u0924 \u0906\u0939\u0947. OTP \u0915\u093F\u0902\u0935\u093E \u092C\u0901\u0915 \u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0928\u093E\u0939\u0940\u0924.',
                    ),
                  ),
                ),
                actionButton(
                  ct(
                    'Save report record',
                    '\u0930\u093F\u092A\u094B\u0930\u094D\u091F \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0938\u0939\u0947\u091C\u0947\u0902',
                    '\u0905\u0939\u0935\u093E\u0932 \u0928\u094B\u0902\u0926 \u091C\u0924\u0928 \u0915\u0930\u093E',
                  ),
                  _busy || !_consent ? null : _submit,
                ),
              ],
            );
          },
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) note(_message!),
      ],
    ),
  );
}

/// Parses only this account's canonical offer keys; no arbitrary Firestore path.
String? ownPendingOfferPath(String key, String uid) {
  const prefix = 'offer_chat_outbox_';
  if (!key.startsWith(prefix)) return null;
  try {
    final identity = jsonDecode(
      utf8.decode(base64Url.decode(key.substring(prefix.length))),
    );
    if (identity is! List ||
        identity.length != 2 ||
        identity[0] != uid ||
        identity[1] is! String)
      return null;
    final path = identity[1] as String;
    return RegExp(r'^recyclerRequests/[^/]{1,128}/offers/[^/]{1,256}$')
            .hasMatch(path)
        ? path
        : null;
  } catch (_) {
    return null;
  }
}

class PendingChatScreen extends StatefulWidget {
  const PendingChatScreen({super.key});
  @override
  State<PendingChatScreen> createState() => _PendingChatState();
}

class _PendingChatState extends State<PendingChatScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late Future<List<Map<String, String>>> _loadFuture = _load();
  Future<List<Map<String, String>>> _load() async {
    if (_uid == null) throw StateError('sign-in-required');
    final prefs = await SharedPreferences.getInstance();
    final rows = <Map<String, String>>[];
    for (final key in prefs.getKeys()) {
      final path = ownPendingOfferPath(key, _uid);
      if (path == null) continue;
      var preview = ct(
        'Unreadable local copy; open conversation to check.',
        '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0915\u0949\u092A\u0940 \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u0940; \u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0915\u0930 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
        '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092A\u094D\u0930\u0924 \u0935\u093E\u091A\u0924\u093E \u0906\u0932\u0940 \u0928\u093E\u0939\u0940; \u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u0942\u0928 \u0924\u092A\u093E\u0938\u093E.',
      );
      try {
        final v = jsonDecode(prefs.getString(key) ?? '');
        if (v is Map && v['text'] is String) preview = v['text'];
      } catch (_) {}
      rows.add({'path': path, 'text': preview});
    }
    if (FirebaseAuth.instance.currentUser?.uid != _uid)
      throw StateError('account-changed');
    return rows;
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Pending chat messages',
      '\u0932\u0902\u092C\u093F\u0924 \u091A\u0948\u091F \u0938\u0902\u0926\u0947\u0936',
      '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u091A\u0945\u091F \u0938\u0902\u0926\u0947\u0936',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        note(
          ct(
            'Local copies on this phone only. A timed-out send may already be on the server. Open each conversation and check/retry the SAME message ID. Nothing is sent automatically.',
            '\u0915\u0947\u0935\u0932 \u0907\u0938 \u092B\u094B\u0928 \u0915\u0940 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0915\u0949\u092A\u0940\u0964 \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0935\u093E\u0932\u093E \u0938\u0902\u0926\u0947\u0936 \u0938\u0930\u094D\u0935\u0930 \u092A\u0930 \u0939\u094B \u0938\u0915\u0924\u093E \u0939\u0948\u0964 \u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0915\u0930 \u0909\u0938\u0940 ID \u0938\u0947 \u091C\u093E\u0901\u091A\u0947\u0902/\u092B\u093F\u0930 \u092D\u0947\u091C\u0947\u0902\u0964 \u0905\u092A\u0928\u0947 \u0906\u092A \u0915\u0941\u091B \u0928\u0939\u0940\u0902 \u092D\u0947\u091C\u093E \u091C\u093E\u0924\u093E\u0964',
            '\u092B\u0915\u094D\u0924 \u092F\u093E \u092B\u094B\u0928\u0935\u0930\u0940\u0932 \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092A\u094D\u0930\u0924\u0940. \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0938\u0902\u0926\u0947\u0936 \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0935\u0930 \u0905\u0938\u0942 \u0936\u0915\u0924\u094B. \u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u0942\u0928 \u0924\u094D\u092F\u093E\u091A ID \u0928\u0947 \u0924\u092A\u093E\u0938\u093E/\u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093E. \u0906\u092A\u094B\u0906\u092A \u0915\u093E\u0939\u0940 \u092A\u093E\u0920\u0935\u0932\u0947 \u091C\u093E\u0924 \u0928\u093E\u0939\u0940.',
          ),
        ),
        TextButton.icon(
          onPressed: () {
            AppSpeech.instance.say(
              ct(
                'Refresh pending messages',
                '\u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u092B\u093F\u0930 \u0926\u0947\u0916\u0947\u0902',
                '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0938\u0902\u0926\u0947\u0936 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u0939\u093E',
              ),
            );
            setState(() => _loadFuture = _load());
          },
          icon: const Icon(Icons.refresh),
          label: Text(
            ct(
              'Refresh',
              '\u092B\u093F\u0930 \u0926\u0947\u0916\u0947\u0902',
              '\u092A\u0941\u0928\u094D\u0939\u093E \u092A\u0939\u093E',
            ),
          ),
        ),
        FutureBuilder<List<Map<String, String>>>(
          future: _loadFuture,
          builder: (context, s) {
            if (s.hasError)
              return note(
                ct(
                  'Local outbox unavailable. Do not clear app data; check your session and storage.',
                  '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0906\u0909\u091F\u092C\u0949\u0915\u094D\u0938 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0910\u092A \u0921\u0947\u091F\u093E \u0928 \u092E\u093F\u091F\u093E\u090F\u0901; \u0938\u0947\u0936\u0928 \u0914\u0930 \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                  '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0906\u0909\u091F\u092C\u0949\u0915\u094D\u0938 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940. \u0905\u0945\u092A \u0921\u0947\u091F\u093E \u092A\u0941\u0938\u0942 \u0928\u0915\u093E; \u0938\u0947\u0936\u0928 \u0935 \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u0924\u092A\u093E\u0938\u093E.',
                ),
              );
            if (!s.hasData) return const LinearProgressIndicator();
            if (s.data!.isEmpty)
              return note(
                ct(
                  'No pending chat copies on this phone for this account.',
                  '\u0907\u0938 \u0916\u093E\u0924\u0947 \u0915\u0947 \u0932\u093F\u090F \u0907\u0938 \u092B\u094B\u0928 \u092A\u0930 \u0932\u0902\u092C\u093F\u0924 \u091A\u0948\u091F \u0915\u0949\u092A\u0940 \u0928\u0939\u0940\u0902\u0964',
                  '\u092F\u093E \u0916\u093E\u0924\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u092F\u093E \u092B\u094B\u0928\u0935\u0930 \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u091A\u0945\u091F \u092A\u094D\u0930\u0924 \u0928\u093E\u0939\u0940.',
                ),
              );
            return Column(
              children: s.data!
                  .map(
                    (r) => Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              ct(
                                'Pending chat copy',
                                '\u0932\u0902\u092C\u093F\u0924 \u091A\u0948\u091F \u0915\u0949\u092A\u0940',
                                '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u091A\u0945\u091F \u092A\u094D\u0930\u0924',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              r['text']!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SelectableText(
                              r['path']!,
                              style: const TextStyle(fontSize: 11),
                            ),
                            actionButton(
                              ct(
                                'Open and check',
                                '\u0916\u094B\u0932\u0915\u0930 \u091C\u093E\u0901\u091A\u0947\u0902',
                                '\u0909\u0918\u0921\u0942\u0928 \u0924\u092A\u093E\u0938\u093E',
                              ),
                              () async {
                                AppSpeech.instance.say(
                                  ct(
                                    'Open pending conversation',
                                    '\u0932\u0902\u092C\u093F\u0924 \u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0947\u0902',
                                    '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u093E',
                                  ),
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OfferChatScreen(
                                      offer: FirebaseFirestore.instance.doc(
                                        r['path']!,
                                      ),
                                    ),
                                  ),
                                );
                                if (mounted)
                                  setState(() => _loadFuture = _load());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}
