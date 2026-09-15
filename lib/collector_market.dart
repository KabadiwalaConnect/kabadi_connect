import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'collector_ui.dart';
import 'app_speech.dart';
import 'collector_store.dart';
import 'material_photos.dart';
import 'request_tracking.dart';
import 'collector_messages.dart';
import 'collector_reports.dart';
import 'collector_sell_requests.dart';
import 'collector_home_screen.dart'
    show CollectorHomeNavigation, SellCameraScreen;

final _store = CollectorStore.instance;
String showDate(Object? v) {
  if (v is! Timestamp)
    return ct(
      'Not confirmed',
      '\u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902',
      '\u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940',
    );
  final d = v.toDate().toLocal();
  return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

Widget cacheNote(bool cache) => cache
    ? note(
        ct(
          'Offline/cached view. Actions still require server confirmation.',
          '\u0911\u092B\u0932\u093E\u0907\u0928/\u0915\u0948\u0936 \u091C\u093E\u0928\u0915\u093E\u0930\u0940\u0964 \u0915\u093E\u0930\u094D\u0930\u0935\u093E\u0908 \u0915\u0947 \u0932\u093F\u090F \u0938\u0930\u094D\u0935\u0930 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u091A\u093E\u0939\u093F\u090F\u0964',
          '\u0911\u092B\u0932\u093E\u0907\u0928/\u0915\u0945\u0936 \u092E\u093E\u0939\u093F\u0924\u0940. \u0915\u0943\u0924\u0940\u0938\u093E\u0920\u0940 \u0938\u0930\u094D\u0935\u0939\u0930 \u092A\u0941\u0937\u094D\u091F\u0940 \u0906\u0935\u0936\u094D\u092F\u0915.',
        ),
      )
    : const SizedBox.shrink();

class RecyclerRequestsScreen extends StatefulWidget {
  const RecyclerRequestsScreen({super.key});
  @override
  State<RecyclerRequestsScreen> createState() => _RequestsState();
}

class _RequestsState extends State<RecyclerRequestsScreen> {
  String? _city;
  bool _sell = false, _demo = false;
  late final _stream = _store.dbCloud
      .collection('recyclerRequests')
      .where('status', isEqualTo: 'active')
      .where('authorizationStatus', isEqualTo: 'verified')
      .limit(50)
      .snapshots(includeMetadataChanges: true);
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Requests & selling',
      '\u092E\u093E\u0901\u0917 \u0914\u0930 \u092C\u093F\u0915\u094D\u0930\u0940',
      '\u092E\u093E\u0917\u0923\u094D\u092F\u093E \u0935 \u0935\u093F\u0915\u094D\u0930\u0940',
    ),
    guide: () => ct(
      'Choose buyer demand or publish your own collection. Demo preview uses fictional data and cannot send requests.',
      '\u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u0940 \u092E\u093E\u0901\u0917 \u091A\u0941\u0928\u0947\u0902 \u092F\u093E \u0905\u092A\u0928\u093E \u0938\u0902\u0917\u094D\u0930\u0939 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0915\u0930\u0947\u0902\u0964 \u0921\u0947\u092E\u094B \u092E\u0947\u0902 \u0915\u093E\u0932\u094D\u092A\u0928\u093F\u0915 \u0921\u0947\u091F\u093E \u0939\u0948 \u0914\u0930 \u092E\u093E\u0901\u0917 \u0928\u0939\u0940\u0902 \u092D\u0947\u091C\u0940 \u091C\u093E \u0938\u0915\u0924\u0940\u0964',
      '\u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930\u093E\u091A\u0940 \u092E\u093E\u0917\u0923\u0940 \u0928\u093F\u0935\u0921\u093E \u0915\u093F\u0902\u0935\u093E \u0938\u094D\u0935\u0924\u0903\u091A\u0947 \u0938\u0902\u0915\u0932\u0928 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0915\u0930\u093E. \u0921\u0947\u092E\u094B\u0924 \u0915\u093E\u0932\u094D\u092A\u0928\u093F\u0915 \u092E\u093E\u0939\u093F\u0924\u0940 \u0906\u0939\u0947 \u0935 \u092E\u093E\u0917\u0923\u0940 \u092A\u093E\u0920\u0935\u0924\u093E \u092F\u0947\u0924 \u0928\u093E\u0939\u0940.',
    ),
    bottom: () => CollectorHomeNavigation(
      onHome: () {
        AppSpeech.instance.say(
          ct('Home', '\u0939\u094B\u092E', '\u0939\u094B\u092E'),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      onCamera: () => openCollector(
        context,
        SellCameraScreen(
          city: _city == null || _city == '' ? 'Ludhiana' : _city!,
        ),
      ),
      onMessages: () => openCollector(context, const MyOffersScreen()),
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RequestModeBar(
          selling: _sell,
          demo: _demo,
          onSelling: (v) => setState(() => _sell = v),
          onDemo: (v) {
            AppSpeech.instance.say(
              v
                  ? ct(
                      'Demo preview. Sending disabled.',
                      '\u0921\u0947\u092E\u094B \u092A\u094D\u0930\u0940\u0935\u094D\u092F\u0942\u0964 \u092D\u0947\u091C\u0928\u093E \u092C\u0902\u0926 \u0939\u0948\u0964',
                      '\u0921\u0947\u092E\u094B \u092A\u0942\u0930\u094D\u0935\u093E\u0935\u0932\u094B\u0915\u0928. \u092A\u093E\u0920\u0935\u0923\u0947 \u092C\u0902\u0926 \u0906\u0939\u0947.',
                    )
                  : ct(
                      'Real requests',
                      '\u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u092E\u093E\u0901\u0917',
                      '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u092E\u093E\u0917\u0923\u094D\u092F\u093E',
                    ),
            );
            setState(() => _demo = v);
          },
        ),
        if (_demo)
          RequestDemoPanel(selling: _sell)
        else if (_sell)
          const SellCollectionPanel()
        else
          _buyerBody(context),
      ],
    ),
  );
  Widget _buyerBody(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _city,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: ct(
            'City filter',
            '\u0936\u0939\u0930 \u092B\u093C\u093F\u0932\u094D\u091F\u0930',
            '\u0936\u0939\u0930 \u092B\u093F\u0932\u094D\u091F\u0930',
          ),
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(
              ct(
                'All cities',
                '\u0938\u092D\u0940 \u0936\u0939\u0930',
                '\u0938\u0930\u094D\u0935 \u0936\u0939\u0930\u0947',
              ),
            ),
          ),
          ...collectorCities.map(
            (c) => DropdownMenuItem(value: c, child: Text(c)),
          ),
        ],
        onChanged: (v) {
          setState(() => _city = v);
          AppSpeech.instance.say(
            ct(
              'City filter updated',
              '\u0936\u0939\u0930 \u092B\u093C\u093F\u0932\u094D\u091F\u0930 \u092C\u0926\u0932\u093E',
              '\u0936\u0939\u0930 \u092B\u093F\u0932\u094D\u091F\u0930 \u092C\u0926\u0932\u0932\u093E',
            ),
          );
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, s) {
          if (s.hasError) {
            return note(
              ct(
                'Requests unavailable. Check access/rules and network.',
                '\u092E\u093E\u0901\u0917 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0928\u093F\u092F\u092E \u0914\u0930 \u0907\u0902\u091F\u0930\u0928\u0947\u091F \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                '\u092E\u093E\u0917\u0923\u094D\u092F\u093E \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940\u0924. \u0928\u093F\u092F\u092E \u0935 \u0907\u0902\u091F\u0930\u0928\u0947\u091F \u0924\u092A\u093E\u0938\u093E.',
              ),
            );
          }
          if (!s.hasData) return const LinearProgressIndicator();
          final docs = s.data!.docs.where((d) {
            final v = d.data();
            return (_city == null || _city == '' || v['city'] == _city) &&
                v['expiresAt'] is Timestamp &&
                (v['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now());
          }).toList();
          return Column(
            children: [
              cacheNote(s.data!.metadata.isFromCache),
              if (docs.isEmpty)
                note(
                  ct(
                    'No matching live demand. Directory entries do not automatically create requests.',
                    '\u092E\u093F\u0932\u0924\u0940 \u0939\u0941\u0908 \u0938\u0915\u094D\u0930\u093F\u092F \u092E\u093E\u0901\u0917 \u0928\u0939\u0940\u0902\u0964 \u0921\u093E\u092F\u0930\u0947\u0915\u094D\u091F\u0930\u0940 \u0938\u0947 \u092E\u093E\u0901\u0917 \u0905\u092A\u0928\u0947 \u0906\u092A \u0928\u0939\u0940\u0902 \u092C\u0928\u0924\u0940\u0964',
                    '\u091C\u0941\u0933\u0923\u093E\u0930\u0940 \u0938\u0915\u094D\u0930\u093F\u092F \u092E\u093E\u0917\u0923\u0940 \u0928\u093E\u0939\u0940. \u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u0947\u0924\u0942\u0928 \u092E\u093E\u0930\u094D\u092F\u093E \u0906\u092A\u094B\u0906\u092A \u0924\u092F\u093E\u0930 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
                  ),
                ),
              ...docs.map((d) {
                final v = d.data();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            MaterialPhoto(material: '${v['material']}'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${v['recyclerName'] ?? ''}\n${materialLabel('${v['material']}')} \u00B7 ${v['city'] ?? ''}',
                              ),
                            ),
                          ],
                        ),
                        note(
                          '${ct('Expires', '\u0938\u092E\u093E\u092A\u094D\u0924\u093F', '\u092E\u0941\u0926\u0924')}: ${showDate(v['expiresAt'])}',
                        ),
                        if (v['currency'] == 'INR' && v['pricePerKg'] is num)
                          note(
                            '${ct('Indicative request rate', '\u092E\u093E\u0901\u0917 \u0915\u093E \u0938\u0902\u0915\u0947\u0924\u0915 \u092D\u093E\u0935', '\u092E\u093E\u0917\u0923\u0940\u091A\u093E \u0938\u0942\u091A\u0915 \u0926\u0930')}: \u20B9${v['pricePerKg']}/kg',
                          ),
                        actionButton(
                          ct(
                            'View request details',
                            '\u0935\u093F\u0935\u0930\u0923 \u0926\u0947\u0916\u0947\u0902',
                            '\u0924\u092A\u0936\u0940\u0932 \u092A\u0939\u093E',
                          ),
                          s.data!.metadata.isFromCache
                              ? null
                              : () => openCollector(
                                  context,
                                  BuyerRequestDetailsScreen(ref: d.reference),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              note(
                ct(
                  'Up to 50 requests; city/expiry filters apply to this loaded window. Current buyer authorization is checked again by server rules when sending.',
                  '\u0905\u0927\u093F\u0915\u0924\u092E 50 \u092E\u093E\u0901\u0917; \u092B\u093C\u093F\u0932\u094D\u091F\u0930 \u0907\u0938\u0940 \u0938\u0942\u091A\u0940 \u092A\u0930 \u0939\u0948\u0902\u0964 \u092D\u0947\u091C\u0924\u0947 \u0938\u092E\u092F \u0938\u0930\u094D\u0935\u0930 \u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u0940 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0905\u0928\u0941\u092E\u0924\u093F \u092B\u093F\u0930 \u091C\u093E\u0901\u091A\u0947\u0917\u093E\u0964',
                  '\u0915\u092E\u093E\u0932 50 \u092E\u093E\u0917\u0923\u094D\u092F\u093E; \u092B\u093F\u0932\u094D\u091F\u0930 \u092F\u093E\u091A \u092F\u093E\u0926\u0940\u0928\u0935\u0930 \u0906\u0939\u0947\u0924. \u092A\u093E\u0920\u0935\u0924\u093E\u0928\u093E \u0938\u0930\u094D\u0935\u0939\u0930 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930\u093E\u091A\u0940 \u0938\u0927\u094D\u092F\u093E\u091A\u0940 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u092A\u0941\u0928\u094D\u0939\u093E \u0924\u092A\u093E\u0938\u0947\u0932.',
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class OfferLotScreen extends StatefulWidget {
  const OfferLotScreen({
    required this.requestId,
    required this.material,
    super.key,
  });
  final String requestId, material;
  @override
  State<OfferLotScreen> createState() => _OfferLotState();
}

class _OfferLotState extends State<OfferLotScreen> {
  String? _selected, _message;
  bool _busy = false;
  late final _lots = _store.dbCloud
      .collection('users')
      .doc(_store.uid)
      .collection('lots')
      .snapshots(includeMetadataChanges: true);
  Future<void> _send(String id) async {
    if (_busy || _selected != id) return;
    if (!await confirmAction(
          context,
          ct(
            'Send this entire lot as a proposal? It will be locked from other requests until rejected or withdrawn.',
            '\u092A\u0942\u0930\u093E \u0932\u0949\u091F \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u092E\u0947\u0902 \u092D\u0947\u091C\u0947\u0902? \u0905\u0938\u094D\u0935\u0940\u0915\u093E\u0930 \u092F\u093E \u0935\u093E\u092A\u0938 \u0932\u0947\u0928\u0947 \u0924\u0915 \u0926\u0942\u0938\u0930\u0940 \u092E\u093E\u0901\u0917 \u092E\u0947\u0902 \u0928\u0939\u0940\u0902 \u092D\u0947\u091C \u092A\u093E\u090F\u0901\u0917\u0947\u0964',
            '\u0938\u0902\u092A\u0942\u0930\u094D\u0923 \u0932\u0949\u091F \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u092E\u094D\u0939\u0923\u0942\u0928 \u092A\u093E\u0920\u0935\u093E\u092F\u091A\u093E? \u0928\u0915\u093E\u0930 \u0915\u093F\u0902\u0935\u093E \u092E\u093E\u0917\u0947 \u0918\u0947\u0908\u092A\u0930\u094D\u092F\u0902\u0924 \u0926\u0941\u0938\u0931\u094D\u092F\u093E \u092E\u093E\u0917\u0923\u0940\u0932\u093E \u092A\u093E\u0920\u0935\u0924\u093E \u092F\u0947\u0923\u093E\u0930 \u0928\u093E\u0939\u0940.',
          ),
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final uid = _store.uid;
      await _store.propose(widget.requestId, id);
      _store.checkUid(uid);
      if (mounted)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => OfferDetailScreen(
              ref: _store.dbCloud
                  .collection('recyclerRequests')
                  .doc(widget.requestId)
                  .collection('offers')
                  .doc('${uid}_$id'),
            ),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Select lot',
      '\u0932\u0949\u091F \u091A\u0941\u0928\u0947\u0902',
      '\u0932\u0949\u091F \u0928\u093F\u0935\u0921\u093E',
    ),
    guide: () => ct(
      'Tap a card to select. Only Send selected lot submits it. Sync local drafts first.',
      '\u0915\u093E\u0930\u094D\u0921 \u0926\u092C\u093E\u0915\u0930 \u091A\u0941\u0928\u0947\u0902\u0964 \u091A\u0941\u0928\u093E \u0932\u0949\u091F \u092D\u0947\u091C\u0947\u0902 \u0926\u092C\u093E\u0928\u0947 \u0938\u0947 \u0939\u0940 \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u091C\u093E\u090F\u0917\u093E\u0964 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u092A\u0939\u0932\u0947 \u0938\u093F\u0902\u0915 \u0915\u0930\u0947\u0902\u0964',
      '\u0915\u093E\u0930\u094D\u0921 \u0926\u093E\u092C\u0942\u0928 \u0928\u093F\u0935\u0921\u093E. \u0928\u093F\u0935\u0921\u0932\u0947\u0932\u093E \u0932\u0949\u091F \u092A\u093E\u0920\u0935\u093E \u0926\u093E\u092C\u0932\u094D\u092F\u093E\u0935\u0930\u091A \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u091C\u093E\u0908\u0932. \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0906\u0927\u0940 \u0938\u093F\u0902\u0915 \u0915\u0930\u093E.',
    ),
    body: (context) => Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) SpokenNotice(text: _message!),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _lots,
          builder: (context, s) {
            if (s.hasError) return note(friendlyError(s.error!));
            if (!s.hasData) return const LinearProgressIndicator();
            final docs = s.data!.docs
                .where(
                  (d) =>
                      d.data()['status'] == 'draft' &&
                      d.data()['material'] == widget.material,
                )
                .toList();
            return Column(
              children: [
                cacheNote(s.data!.metadata.isFromCache),
                if (docs.isEmpty)
                  note(
                    ct(
                      'No synced matching draft. Create and sync a lot first.',
                      '\u092E\u0947\u0932 \u0916\u093E\u0924\u093E \u0938\u093F\u0902\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0928\u0939\u0940\u0902\u0964 \u092A\u0939\u0932\u0947 \u0932\u0949\u091F \u092C\u0928\u093E\u0915\u0930 \u0938\u093F\u0902\u0915 \u0915\u0930\u0947\u0902\u0964',
                      '\u091C\u0941\u0933\u0923\u093E\u0930\u093E \u0938\u093F\u0902\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0928\u093E\u0939\u0940. \u0906\u0927\u0940 \u0932\u0949\u091F \u0924\u092F\u093E\u0930 \u0935 \u0938\u093F\u0902\u0915 \u0915\u0930\u093E.',
                    ),
                  ),
                ...docs.map((d) {
                  final v = d.data();
                  final selected = d.id == _selected;
                  return Semantics(
                    selected: selected,
                    button: true,
                    child: Card(
                      color: selected ? collectorGreen : Colors.white,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _busy
                            ? null
                            : () {
                                setState(() => _selected = d.id);
                                AppSpeech.instance.say(
                                  ct(
                                    'Lot selected. Review and press Send selected lot.',
                                    '\u0932\u0949\u091F \u091A\u0941\u0928\u093E\u0964 \u091C\u093E\u0901\u091A\u0915\u0930 \u091A\u0941\u0928\u093E \u0932\u0949\u091F \u092D\u0947\u091C\u0947\u0902 \u0926\u092C\u093E\u090F\u0901\u0964',
                                    '\u0932\u0949\u091F \u0928\u093F\u0935\u0921\u0932\u093A. \u0924\u092A\u093E\u0938\u0942\u0928 \u0928\u093F\u0935\u0921\u0932\u0947\u0932\u093E \u0932\u0949\u091F \u092A\u093E\u0920\u0935\u093E \u0926\u093E\u092C\u093E.',
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  MaterialPhoto(material: widget.material),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${materialLabel(widget.material)}\n${v['weightKg']} kg \u00B7 ${v['city']}',
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? Colors.white
                                        : collectorGreen,
                                  ),
                                ],
                              ),
                              if (selected)
                                actionButton(
                                  ct(
                                    'Send selected lot',
                                    '\u091A\u0941\u0928\u093E \u0932\u0949\u091F \u092D\u0947\u091C\u0947\u0902',
                                    '\u0928\u093F\u0935\u0921\u0932\u0947\u0932\u093E \u0932\u0949\u091F \u092A\u093E\u0920\u0935\u093E',
                                  ),
                                  _busy ||
                                          s.data!.metadata.isFromCache ||
                                          d.metadata.hasPendingWrites
                                      ? null
                                      : () => _send(d.id),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    ),
  );
}

// Both historical My Offers and bottom Messages routes open this collector inbox.
class MyOffersScreen extends StatelessWidget {
  const MyOffersScreen({super.key});
  @override
  Widget build(BuildContext context) => const CollectorMessagesScreen();
}

class OfferDetailScreen extends StatefulWidget {
  const OfferDetailScreen({required this.ref, super.key});
  final DocumentReference<Map<String, dynamic>> ref;
  @override
  State<OfferDetailScreen> createState() => _OfferDetailState();
}

class _OfferDetailState extends State<OfferDetailScreen> {
  final _weight = TextEditingController(),
      _amount = TextEditingController(),
      _reference = TextEditingController();
  String _method = 'cash';
  String? _message, _paymentId;
  bool _busy = false;
  @override
  void dispose() {
    _weight.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _change(String status) async {
    if (_busy) return;
    if (!await confirmAction(
          context,
          ct(
            'Confirm this action only after checking the displayed details. A QR code is an identifier, not proof of transfer or payment.',
            '\u0926\u093F\u0916\u093E\u0908 \u091C\u093E\u0928\u0915\u093E\u0930\u0940 \u091C\u093E\u0901\u091A\u0915\u0930 \u0939\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0947\u0902\u0964 QR \u0915\u0947\u0935\u0932 \u092A\u0939\u091A\u093E\u0928 \u0939\u0948, \u0938\u094C\u0902\u092A\u0928\u0947 \u092F\u093E \u092D\u0941\u0917\u0924\u093E\u0928 \u0915\u093E \u0938\u092C\u0942\u0924 \u0928\u0939\u0940\u0902\u0964',
            '\u0926\u093E\u0916\u0935\u0932\u0947\u0932\u0940 \u092E\u093E\u0939\u093F\u0924\u0940 \u0924\u092A\u093E\u0938\u0942\u0928\u091A \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0930\u093E. QR \u0915\u0947\u0935\u0933 \u0913\u0933\u0916 \u0906\u0939\u0947, \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0915\u093F\u0902\u0935\u093E \u092A\u0947\u092E\u0947\u0902\u091F\u091A\u093E \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940.',
          ),
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _store.transition(
        widget.ref,
        status,
        weight: double.tryParse(_weight.text.trim()),
      );
      if (mounted) {
        setState(
          () => _message = ct(
            'Server confirmed the update.',
            '\u0938\u0930\u094D\u0935\u0930 \u0928\u0947 \u0905\u092A\u0921\u0947\u091F \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0940\u0964',
            '\u0938\u0930\u094D\u0935\u0939\u0930\u0928\u0947 \u0905\u092A\u0921\u0947\u091F\u091A\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0947\u0932\u0940.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payment(Map<String, dynamic> v) async {
    if (_busy) return;
    final amount = double.tryParse(_amount.text.trim());
    if (_paymentId == null &&
        (!RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(_amount.text.trim()) ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > 100000000 ||
            _reference.text.length > 100)) {
      setState(
        () => _message = ct(
          'Enter a valid positive amount and short reference.',
          '\u0938\u0939\u0940 \u0927\u0928\u0930\u093E\u0936\u093F \u0914\u0930 \u091B\u094B\u091F\u093E \u0938\u0902\u0926\u0930\u094D\u092D \u0932\u093F\u0916\u0947\u0902\u0964',
          '\u092F\u094B\u0917\u094D\u092F \u0930\u0915\u094D\u0915\u092E \u0935 \u0932\u0939\u093E\u0928 \u0938\u0902\u0926\u0930\u094D\u092D \u0932\u093F\u0939\u093E.',
        ),
      );
      return;
    }
    if (!await confirmAction(
          context,
          ct(
            'Record only money you actually received. This is your statement, not bank verification. Check earlier receipts to avoid duplicates.',
            '\u0915\u0947\u0935\u0932 \u0935\u093E\u0938\u094D\u0924\u0935 \u092E\u0947\u0902 \u092E\u093F\u0932\u0940 \u0930\u093E\u0936\u093F \u0926\u0930\u094D\u091C \u0915\u0930\u0947\u0902\u0964 \u092F\u0939 \u0906\u092A\u0915\u093E \u092C\u092F\u093E\u0928 \u0939\u0948, \u092C\u0948\u0902\u0915 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902\u0964 \u092A\u0939\u0932\u0947 \u0915\u0940 \u0930\u0938\u0940\u0926 \u0926\u0947\u0916\u0915\u0930 \u0921\u0941\u092A\u094D\u0932\u093F\u0915\u0947\u091F \u0938\u0947 \u092C\u091A\u0947\u0902\u0964',
            '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u092E\u093F\u0933\u093E\u0932\u0947\u0932\u0940 \u0930\u0915\u094D\u0915\u092E\u091A \u0928\u094B\u0902\u0926\u0935\u093E. \u0939\u0947 \u0924\u0941\u092E\u091A\u0947 \u0928\u093F\u0935\u0947\u0926\u0928 \u0906\u0939\u0947, \u092C\u0901\u0915 \u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940. \u0906\u0927\u0940\u091A\u094D\u092F\u093E \u092A\u093E\u0935\u0924\u094D\u092F\u093E \u0924\u092A\u093E\u0938\u0942\u0928 \u0926\u0941\u092C\u093E\u0930 \u0928\u094B\u0902\u0926 \u091F\u093E\u0933\u093E.',
          ),
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      _paymentId ??= await _store.stagePayment({
        'requestId': v['requestId'],
        'offerId': widget.ref.id,
        'amount': amount,
        'currency': 'INR',
        'method': _method,
        'reference': _reference.text.trim(),
      });
      await _store.postPayment(_paymentId!);
      _paymentId = null;
      if (mounted) {
        setState(() {
          _amount.clear();
          _reference.clear();
          _message = ct(
            'Receipt statement saved.',
            '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0915\u093E \u092C\u092F\u093E\u0928 \u0938\u0939\u0947\u091C\u093E \u0917\u092F\u093E\u0964',
            '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940\u091A\u0947 \u0928\u093F\u0935\u0947\u0926\u0928 \u091C\u0924\u0928 \u091D\u093E\u0932\u0947.',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = ct(
            'Not confirmed. Retry the same entry here or from Sync. Do not enter it again as a new payment.',
            '\u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902\u0964 \u092F\u0939\u0940 \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F \u092F\u0939\u093E\u0901 \u092F\u093E \u0938\u093F\u0902\u0915 \u0938\u0947 \u0926\u094B\u092C\u093E\u0930\u093E \u092D\u0947\u091C\u0947\u0902\u0964 \u0907\u0938\u0947 \u0928\u092F\u093E \u092D\u0941\u0917\u0924\u093E\u0928 \u092C\u0928\u093E\u0915\u0930 \u092B\u093F\u0930 \u0928 \u0932\u093F\u0916\u0947\u0902\u0964',
            '\u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940. \u0939\u0940\u091A \u0928\u094B\u0902\u0926 \u092F\u0947\u0925\u0947 \u0915\u093F\u0902\u0935\u093E \u0938\u093F\u0902\u0915\u092E\u0927\u0942\u0928 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093A. \u0928\u0935\u0940\u0928 \u092A\u0947\u092E\u0947\u0902\u091F \u092E\u094D\u0939\u0923\u0942\u0928 \u092A\u0941\u0928\u094D\u0939\u093E \u0928\u094B\u0902\u0926\u0935\u0942 \u0928\u0915\u093E.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Details & tracking',
      '\u0935\u093F\u0935\u0930\u0923 \u0914\u0930 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917',
      '\u0924\u092A\u0936\u0940\u0932 \u0935 \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917',
    ),
    guide: () => ct(
      'Read the actual status. Only accept a current quote you agree to. Never hand over hazardous waste to an unverified operator.',
      '\u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u0938\u094D\u0925\u093F\u0924\u093F \u092A\u0922\u093C\u0947\u0902\u0964 \u0938\u0939\u092E\u0924 \u0939\u094B\u0928\u0947 \u092A\u0930 \u0939\u0940 \u0935\u0948\u0927 \u092D\u093E\u0935 \u0938\u094D\u0935\u0940\u0915\u093E\u0930 \u0915\u0930\u0947\u0902\u0964 \u0905\u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0935\u094D\u092F\u0915\u094D\u0924\u093F \u0915\u094B \u0916\u0924\u0930\u0928\u093E\u0915 \u0915\u091A\u0930\u093E \u0928 \u0938\u094C\u0902\u092A\u0947\u0902\u0964',
      '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u0938\u094D\u0925\u093F\u0924\u0940 \u0935\u093E\u091A\u093E. \u0938\u0939\u092E\u0924 \u0905\u0938\u0932\u094D\u092F\u093E\u0938\u091A \u0935\u0948\u0927 \u0926\u0930 \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u093E. \u0905\u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0935\u094D\u092F\u0915\u094D\u0924\u0940\u0932\u093E \u0927\u094B\u0915\u093E\u0926\u093E\u092F\u0915 \u0915\u091A\u0930\u093E \u0926\u0947\u090A \u0928\u0915\u093E.',
    ),
    body: (context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.ref.snapshots(includeMetadataChanges: true),
      builder: (context, s) {
        if (s.hasError) return note(friendlyError(s.error!));
        if (!s.hasData) return const LinearProgressIndicator();
        final v = s.data!.data();
        if (v == null) {
          return note(
            ct(
              'Record not found',
              '\u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E',
              '\u0928\u094B\u0902\u0926 \u0938\u093E\u092A\u0921\u0932\u0940 \u0928\u093E\u0939\u0940',
            ),
          );
        }
        final status = '${v['status']}';
        final enabled =
            !_busy &&
            !s.data!.metadata.isFromCache &&
            !s.data!.metadata.hasPendingWrites &&
            v['schemaVersion'] == 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cacheNote(s.data!.metadata.isFromCache),
            RequestMaterialSummary(data: v, id: widget.ref.id),
            if (v['schemaVersion'] == 2)
              actionButton(
                ct(
                  'Open conversation',
                  '\u092C\u093E\u0924\u091A\u0940\u0924 \u0916\u094B\u0932\u0947\u0902',
                  '\u091A\u0930\u094D\u091A\u093E \u0909\u0918\u0921\u093E',
                ),
                () =>
                    openCollector(context, OfferChatScreen(offer: widget.ref)),
                icon: Icons.chat_bubble_outline,
              ),
            if (v['schemaVersion'] == 2)
              actionButton(
                ct(
                  'Report a problem to admin',
                  '\u090F\u0921\u092E\u093F\u0928 \u0938\u0947 \u0936\u093F\u0915\u093E\u092F\u0924 \u0915\u0930\u0947\u0902',
                  '\u092A\u094D\u0930\u0936\u093E\u0938\u0915\u093E\u0915\u0921\u0947 \u0924\u0915\u094D\u0930\u093E\u0930 \u0928\u094B\u0902\u0926\u0935\u093E',
                ),
                s.data!.metadata.isFromCache ||
                        s.data!.metadata.hasPendingWrites
                    ? null
                    : () => openCollector(
                        context,
                        ReportRecyclerScreen(offerRef: widget.ref),
                      ),
                icon: Icons.flag_outlined,
              ),
            section(statusLabel(status)),
            RequestProgress(
              data: v,
              cached: s.data!.metadata.isFromCache,
              pending: s.data!.metadata.hasPendingWrites,
            ),
            if (v['schemaVersion'] == 2)
              PickupPlanPanel(source: widget.ref, sourceData: v),
            if (status == 'completed')
              OfferReceiptMarker(
                requestId: widget.ref.parent.parent!.id,
                offerId: widget.ref.id,
              ),
            if (v['schemaVersion'] != 2)
              note(
                ct(
                  'Legacy proposal: read-only. It has not been migrated into the new reserved-lot workflow.',
                  '\u092A\u0941\u0930\u093E\u0928\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935: \u0915\u0947\u0935\u0932 \u092A\u0922\u093C\u0947\u0902\u0964 \u0907\u0938\u0947 \u0928\u090F \u0906\u0930\u0915\u094D\u0937\u093F\u0924-\u0932\u0949\u091F \u092A\u094D\u0930\u0935\u093E\u0939 \u092E\u0947\u0902 \u0928\u0939\u0940\u0902 \u092C\u0926\u0932\u093E \u0917\u092F\u093E \u0939\u0948\u0964',
                  '\u091C\u0941\u0928\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935: \u092B\u0915\u094D\u0924 \u0935\u093E\u091A\u093E. \u0928\u0935\u0940\u0928 \u0930\u093E\u0916\u0940\u0935 \u0932\u0949\u091F \u092A\u094D\u0930\u0915\u094D\u0930\u093F\u092F\u0947\u0924 \u0938\u094D\u0925\u0932\u093E\u0902\u0924\u0930 \u0915\u0947\u0932\u0947\u0932\u0947 \u0928\u093E\u0939\u0940.',
                ),
              ),
            if (v['quoteRate'] is num) ...[
              section(
                '${ct('Recycler quote', '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u093E \u092D\u093E\u0935', '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u093E \u0926\u0930')}: \u20B9${v['quoteRate']}/kg',
              ),
              note(
                '${ct('Valid until', '\u0935\u0948\u0927\u0924\u093E', '\u0935\u0948\u0927\u0924\u093E')}: ${showDate(v['quoteExpiresAt'])}',
              ),
              note(
                ct(
                  'Final total uses the mutually confirmed handover weight. No automatic charge.',
                  '\u0905\u0902\u0924\u093F\u092E \u0930\u0915\u092E \u0926\u094B\u0928\u094B\u0902 \u0926\u094D\u0935\u093E\u0930\u093E \u092A\u0941\u0937\u094D\u091F \u0935\u091C\u0928 \u092A\u0930 \u0939\u094B\u0917\u0940\u0964 \u0905\u092A\u0928\u0947 \u0906\u092A \u092A\u0948\u0938\u093E \u0928\u0939\u0940\u0902 \u0915\u091F\u0947\u0917\u093E\u0964',
                  '\u0905\u0902\u0924\u093F\u092E \u0930\u0915\u094D\u0915\u092E \u0926\u094B\u0918\u093E\u0902\u0928\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0947\u0932\u0947\u0932\u094D\u092F\u093E \u0935\u091C\u0928\u093E\u0935\u0930 \u0905\u0938\u0947\u0932. \u0906\u092A\u094B\u0906\u092A \u092A\u0948\u0938\u0947 \u0915\u093E\u092A\u0932\u0947 \u091C\u093E\u0923\u093E\u0930 \u0928\u093E\u0939\u0940\u0924.',
                ),
              ),
            ],
            if (status == 'quoted')
              actionButton(
                ct(
                  'Accept this quote',
                  '\u092F\u0939 \u092D\u093E\u0935 \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u0947\u0902',
                  '\u0939\u094B \u0926\u0930 \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u093E',
                ),
                enabled ? () => _change('accepted') : null,
              ),
            if (['proposed', 'quoted'].contains(status))
              actionButton(
                ct(
                  'Withdraw proposal',
                  '\u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u0935\u093E\u092A\u0938 \u0932\u0947\u0902',
                  '\u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u092E\u093E\u0917\u0947 \u0918\u094D\u092F\u093E',
                ),
                enabled ? () => _change('cancelled') : null,
                icon: Icons.cancel_outlined,
              ),
            if ([
              'accepted',
              'handoverPending',
              'completed',
            ].contains(status)) ...[
              Center(
                child: QrImageView(
                  data: 'KC2|${v['requestId']}|${widget.ref.id}',
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              note(
                ct(
                  'Private transaction identifier. The recycler must sign in and independently confirm handover. Showing/scanning this QR does not complete a sale.',
                  '\u0928\u093F\u091C\u0940 \u0932\u0947\u0928\u0926\u0947\u0928 \u092A\u0939\u091A\u093E\u0928\u0964 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u094B \u0938\u093E\u0907\u0928 \u0907\u0928 \u0915\u0930\u0915\u0947 \u0905\u0932\u0917 \u0938\u0947 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0928\u0940 \u0939\u094B\u0917\u0940\u0964 QR \u0926\u093F\u0916\u093E\u0928\u0947/\u0938\u094D\u0915\u0948\u0928 \u0915\u0930\u0928\u0947 \u0938\u0947 \u092C\u093F\u0915\u094D\u0930\u0940 \u092A\u0942\u0930\u0940 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u0940\u0964',
                  '\u0916\u093E\u091C\u0917\u0940 \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u0913\u0933\u0916. \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0928\u0947 \u0938\u093E\u0907\u0928 \u0907\u0928 \u0915\u0930\u0942\u0928 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0930\u093E\u0935\u0940. QR \u0926\u093E\u0916\u0935\u0932\u094D\u092F\u093E\u0928\u0947/\u0938\u094D\u0915\u0945\u0928 \u0915\u0947\u0932\u094D\u092F\u093E\u0928\u0947 \u0935\u093F\u0915\u094D\u0930\u0940 \u092A\u0942\u0930\u094D\u0923 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
                ),
              ),
            ],
            if (status == 'accepted') ...[
              TextField(
                controller: _weight,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: ct(
                    'Actual scale weight (kg)',
                    '\u0924\u0930\u093E\u091C\u0942 \u0915\u093E \u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u0935\u091C\u0928 (\u0915\u093F\u0932\u094B)',
                    '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u0915\u093E\u091F\u094D\u092F\u093E\u0935\u0930\u0940\u0932 \u0935\u091C\u0928 (\u0915\u093F\u0932\u094B)',
                  ),
                ),
              ),
              actionButton(
                ct(
                  'Request handover confirmation',
                  '\u0938\u094C\u0902\u092A\u0928\u0947 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u092E\u093E\u0901\u0917\u0947\u0902',
                  '\u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092A\u0941\u0937\u094D\u091F\u0940 \u092E\u093E\u0917\u093E',
                ),
                enabled ? () => _change('handoverPending') : null,
              ),
            ],
            if (v['handoverWeightKg'] is num)
              note(
                '${ct('Reported handover weight', '\u0926\u0930\u094D\u091C \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0935\u091C\u0928', '\u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u0947 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0935\u091C\u0928')}: ${v['handoverWeightKg']} kg',
              ),
            if (status == 'handoverPending')
              note(
                ct(
                  'Waiting for the real recycler to confirm. Recycler UI is a separate delivery; collectors cannot confirm on their behalf.',
                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u092C\u093E\u0915\u0940\u0964 \u0909\u0938\u0915\u093E UI \u0905\u0932\u0917 \u092C\u0928\u0947\u0917\u093E; \u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0909\u0938\u0915\u0940 \u0913\u0930 \u0938\u0947 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u0915\u0930 \u0938\u0915\u0924\u093E\u0964',
                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u092C\u093E\u0915\u0940. \u0924\u094D\u092F\u093E\u091A\u093E UI \u0935\u0947\u0917\u0933\u093E \u092C\u0928\u0932\u0947; \u0938\u0902\u0915\u0932\u0915 \u0924\u094D\u092F\u093E\u091A\u094D\u092F\u093E \u0935\u0924\u0940\u0928\u0947 \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0930\u0942 \u0936\u0915\u0924 \u0928\u093E\u0939\u0940.',
                ),
              ),
            if (status == 'completed') ...[
              note(
                '${ct('Handover confirmed', '\u0938\u094C\u0902\u092A\u0928\u093E \u092A\u0941\u0937\u094D\u091F', '\u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092A\u0941\u0937\u094D\u091F')}: ${showDate(v['completedAt'])}',
              ),
              if (v['quoteRate'] is num && v['handoverWeightKg'] is num)
                section(
                  '${ct('Agreed goods value', '\u0938\u0939\u092E\u0924 \u092E\u093E\u0932 \u092E\u0942\u0932\u094D\u092F', '\u0938\u0939\u092E\u0924 \u092E\u093E\u0932 \u092E\u0942\u0932\u094D\u092F')}: \u20B9${((v['quoteRate'] as num) * (v['handoverWeightKg'] as num)).toStringAsFixed(2)}',
                ),
              note(
                ct(
                  'Not proof of final recycling or regulatory compliance.',
                  '\u092F\u0939 \u0905\u0902\u0924\u093F\u092E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u093F\u0902\u0917 \u092F\u093E \u0915\u093E\u0928\u0942\u0928\u0940 \u0905\u0928\u0941\u092A\u093E\u0932\u0928 \u0915\u093E \u092A\u094D\u0930\u092E\u093E\u0923 \u0928\u0939\u0940\u0902\u0964',
                  '\u0939\u093E \u0905\u0902\u0924\u093F\u092E \u092A\u0941\u0928\u0930\u094D\u091A\u0915\u094D\u0930\u0923 \u0915\u093F\u0902\u0935\u093E \u0915\u093E\u092F\u0926\u0947\u0936\u0940\u0930 \u0905\u0928\u0941\u092A\u093E\u0932\u0928\u093E\u091A\u093E \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940.',
                ),
              ),
              TextField(
                controller: _amount,
                enabled: !_busy && _paymentId == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: ct(
                    'Amount actually received (INR)',
                    '\u0935\u093E\u0938\u094D\u0924\u0935 \u092E\u0947\u0902 \u092A\u094D\u0930\u093E\u092A\u094D\u0924 \u0930\u093E\u0936\u093F (\u0930\u0941\u092A\u092F\u0947)',
                    '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u092E\u093F\u0933\u093E\u0932\u0947\u0932\u0940 \u0930\u0915\u094D\u0915\u092E (\u0930\u0941\u092A\u092F\u0947)',
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _method,
                items: ['cash', 'upi', 'bank']
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: _busy || _paymentId != null
                    ? null
                    : (v) => setState(() => _method = v!),
              ),
              TextField(
                controller: _reference,
                enabled: !_busy && _paymentId == null,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: ct(
                    'Optional receipt reference (no PIN/OTP)',
                    '\u0935\u0948\u0915\u0932\u094D\u092A\u093F\u0915 \u0930\u0938\u0940\u0926 \u0938\u0902\u0926\u0930\u094D\u092D (PIN/OTP \u0928\u0939\u0940\u0902)',
                    '\u092A\u0930\u094D\u092F\u093E\u092F\u0940 \u092A\u093E\u0935\u0924\u0940 \u0938\u0902\u0926\u0930\u094D\u092D (PIN/OTP \u0928\u093E\u0939\u0940)',
                  ),
                ),
              ),
              actionButton(
                _paymentId == null
                    ? ct(
                        'Record received payment',
                        '\u092A\u094D\u0930\u093E\u092A\u094D\u0924 \u092D\u0941\u0917\u0924\u093E\u0928 \u0926\u0930\u094D\u091C \u0915\u0930\u0947\u0902',
                        '\u092E\u093F\u0933\u093E\u0932\u0947\u0932\u0947 \u092A\u0947\u092E\u0947\u0902\u091F \u0928\u094B\u0902\u0926\u0935\u093E',
                      )
                    : ct(
                        'Retry same receipt',
                        '\u092F\u0939\u0940 \u0930\u0938\u0940\u0926 \u0926\u094B\u092C\u093E\u0930\u093E \u092D\u0947\u091C\u0947\u0902',
                        '\u0939\u0940\u091A \u092A\u093E\u0935\u0924\u0940 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093A',
                      ),
                enabled ? () => _payment(v) : null,
              ),
              ReceiptList(
                offerId: widget.ref.id,
                requestId: widget.ref.parent.parent!.id,
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) SpokenNotice(text: _message!),
          ],
        );
      },
    ),
  );
}

class ReceiptList extends StatelessWidget {
  const ReceiptList({this.offerId, this.requestId, super.key});
  final String? offerId, requestId;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _store.dbCloud
        .collection('collectorPayments')
        .where('collectorUid', isEqualTo: _store.uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true),
    builder: (context, s) {
      if (s.hasError) return note(friendlyError(s.error!));
      if (!s.hasData) return const LinearProgressIndicator();
      final docs = s.data!.docs
          .where(
            (d) =>
                (offerId == null || d.data()['offerId'] == offerId) &&
                (requestId == null || d.data()['requestId'] == requestId),
          )
          .toList();
      final sum = docs.fold<double>(
        0,
        (a, d) => a + ((d.data()['amount'] as num?)?.toDouble() ?? 0),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cacheNote(s.data!.metadata.isFromCache),
          section(
            '${ct('Recorded receipts in loaded window', '\u0932\u094B\u0921 \u0938\u0942\u091A\u0940 \u092E\u0947\u0902 \u0926\u0930\u094D\u091C \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F\u092F\u093E\u0901', '\u0932\u094B\u0921 \u092F\u093E\u0926\u0940\u0924\u0940\u0932 \u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u094D\u092F\u093E \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940')}: \u20B9${sum.toStringAsFixed(2)}',
          ),
          note(
            ct(
              'Up to 100 newest account receipt records; filters and totals apply only to this window. Not a lifetime total, bank reconciliation or verified earnings.',
              '\u0916\u093E\u0924\u0947 \u0915\u0940 \u0928\u0935\u0940\u0928\u0924\u092E 100 \u0930\u0938\u0940\u0926\u0947\u0902; \u092B\u093C\u093F\u0932\u094D\u091F\u0930 \u0914\u0930 \u091C\u094B\u0921\u093C \u0907\u0938\u0940 \u0938\u0942\u091A\u0940 \u092A\u0930 \u0939\u0948\u0902\u0964 \u092F\u0939 \u0906\u091C\u0940\u0935\u0928 \u0915\u0941\u0932, \u092C\u0948\u0902\u0915 \u092E\u093F\u0932\u093E\u0928 \u092F\u093E \u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0906\u092F \u0928\u0939\u0940\u0902\u0964',
              '\u0916\u093E\u0924\u094D\u092F\u093E\u0924\u0940\u0932 \u0928\u0935\u0940\u0928\u0924\u092E 100 \u092A\u093E\u0935\u0924\u094D\u092F\u093E; \u092B\u093F\u0932\u094D\u091F\u0930 \u0935 \u092C\u0947\u0930\u0940\u091C \u092F\u093E\u091A \u092F\u093E\u0926\u0940\u0935\u0930 \u0906\u0939\u0947\u0924. \u0939\u0940 \u0906\u092F\u0941\u0937\u094D\u092F\u092D\u0930\u093E\u091A\u0940 \u092C\u0947\u0930\u0940\u091C, \u092C\u0901\u0915 \u0924\u093E\u0933\u092E\u0947\u0933 \u0915\u093F\u0902\u0935\u093E \u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0915\u092E\u093E\u0908 \u0928\u093E\u0939\u0940.',
            ),
          ),
          if (docs.isEmpty)
            note(
              ct(
                'No recorded receipts.',
                '\u0915\u094B\u0908 \u0926\u0930\u094D\u091C \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0928\u0939\u0940\u0902\u0964',
                '\u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u094D\u092F\u093E \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0928\u093E\u0939\u0940\u0924.',
              ),
            ),
          ...docs.map((d) {
            final v = d.data();
            return Card(
              child: ListTile(
                title: Text('\u20B9${v['amount']} \u00B7 ${v['method']}'),
                subtitle: Text(
                  '${showDate(v['createdAt'])}\n${ct('Collector-recorded, not bank verified', '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0915\u0940 \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F, \u092C\u0948\u0902\u0915 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902', '\u0938\u0902\u0915\u0932\u0915\u093E\u091A\u0940 \u0928\u094B\u0902\u0926, \u092C\u0901\u0915 \u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940')}',
                ),
                trailing: IconButton(
                  tooltip: ct(
                    'Copy receipt',
                    '\u0930\u0938\u0940\u0926 \u0915\u0949\u092A\u0940 \u0915\u0930\u0947\u0902',
                    '\u092A\u093E\u0935\u0924\u0940 \u0915\u0949\u092A\u0940 \u0915\u0930\u093E',
                  ),
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    if (!await confirmAction(
                      context,
                      ct(
                        'Copy this private receipt statement to the clipboard for sharing? It is not a tax invoice or bank proof.',
                        '\u0938\u093E\u091D\u093E \u0915\u0930\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0928\u093F\u091C\u0940 \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u092C\u092F\u093E\u0928 \u0915\u094D\u0932\u093F\u092A\u092C\u094B\u0930\u094D\u0921 \u092A\u0930 \u0915\u0949\u092A\u0940 \u0915\u0930\u0947\u0902? \u092F\u0939 \u091F\u0948\u0915\u094D\u0938 \u0907\u0928\u0935\u0949\u0907\u0938 \u092F\u093E \u092C\u0948\u0902\u0915 \u092A\u094D\u0930\u092E\u093E\u0923 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                        '\u0936\u0947\u0905\u0930 \u0915\u0930\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0916\u093E\u091C\u0917\u0940 \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0928\u093F\u0935\u0947\u0926\u0928 \u0915\u094D\u0932\u093F\u092A\u092C\u094B\u0930\u094D\u0921\u0935\u0930 \u0915\u0949\u092A\u0940 \u0915\u0930\u093E\u092F\u091A\u0947? \u0939\u0947 \u0915\u0930 \u091A\u0932\u0928 \u0915\u093F\u0902\u0935\u093E \u092C\u0901\u0915 \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940.',
                      ),
                    )) {
                      return;
                    }
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'Kabadi Connect \u2014 COLLECTOR-RECORDED RECEIPT\nNot bank verified / not a tax invoice\nRecord: ${d.id}\nOffer: ${v['offerId']}\nINR ${v['amount']}\nMethod: ${v['method']}\nReference: ${v['reference']}\nRecorded: ${showDate(v['createdAt'])}',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ct(
                              'Copied',
                              '\u0915\u0949\u092A\u0940 \u0939\u0941\u0906',
                              '\u0915\u0949\u092A\u0940 \u091D\u093E\u0932\u0947',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class BuyerRequestDetailsScreen extends StatelessWidget {
  const BuyerRequestDetailsScreen({required this.ref, super.key});
  final DocumentReference<Map<String, dynamic>> ref;
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Request details',
      '\u0905\u0928\u0941\u0930\u094B\u0927 \u0935\u093F\u0935\u0930\u0923',
      '\u0935\u093F\u0928\u0902\u0924\u0940 \u0924\u092A\u0936\u0940\u0932',
    ),
    body: (context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(includeMetadataChanges: true),
      builder: (context, s) {
        if (s.hasError)
          return note(
            ct(
              'Request unavailable or access changed.',
              '\u0905\u0928\u0941\u0930\u094B\u0927 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902 \u092F\u093E \u092A\u0939\u0941\u0901\u091A \u092C\u0926\u0932 \u0917\u0908\u0964',
              '\u0935\u093F\u0928\u0902\u0924\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940 \u0915\u093F\u0902\u0935\u093E \u092A\u094D\u0930\u0935\u0947\u0936 \u092C\u0926\u0932\u0932\u093E.',
            ),
          );
        if (!s.hasData) return const LinearProgressIndicator();
        final v = s.data!.data();
        if (v == null)
          return note(
            ct(
              'Request not found',
              '\u0905\u0928\u0941\u0930\u094B\u0927 \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E',
              '\u0935\u093F\u0928\u0902\u0924\u0940 \u0938\u093E\u092A\u0921\u0932\u0940 \u0928\u093E\u0939\u0940',
            ),
          );
        final enabled =
            !s.data!.metadata.isFromCache &&
            !s.data!.metadata.hasPendingWrites &&
            v['status'] == 'active' &&
            v['authorizationStatus'] == 'verified' &&
            v['expiresAt'] is Timestamp &&
            (v['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cacheNote(s.data!.metadata.isFromCache),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    MaterialPhoto(material: '${v['material']}'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            materialLabel('${v['material']}'),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('${v['recyclerName'] ?? ''}'),
                          Text('${v['city'] ?? ''}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SelectableText('ID: ${ref.id}'),
            note(
              '${ct('Expires', '\u0938\u092E\u093E\u092A\u094D\u0924\u093F', '\u092E\u0941\u0926\u0924')}: ${showDate(v['expiresAt'])}',
            ),
            if (v['currency'] == 'INR' && v['pricePerKg'] is num)
              note(
                '${ct('Indicative buying rate', '\u0938\u093E\u0902\u0915\u0947\u0924\u093F\u0915 \u0916\u0930\u0940\u0926 \u092D\u093E\u0935', '\u0938\u0942\u091A\u0915 \u0916\u0930\u0947\u0926\u0940 \u0926\u0930')}: \u20B9${v['pricePerKg']}/kg',
              ),
            note(
              ct(
                'Choose your own lot to propose a quantity. Pickup address/time must be arranged; no distance, appointment or earnings are assumed.',
                '\u092E\u093E\u0924\u094D\u0930\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935\u093F\u0924 \u0915\u0930\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0905\u092A\u0928\u093E \u0932\u0949\u091F \u091A\u0941\u0928\u0947\u0902\u0964 \u092A\u093F\u0915\u0905\u092A \u092A\u0924\u093E/\u0938\u092E\u092F \u0924\u092F \u0915\u0930\u0928\u093E \u0939\u094B\u0917\u093E; \u0926\u0942\u0930\u0940, \u0938\u092E\u092F \u092F\u093E \u0915\u092E\u093E\u0908 \u0905\u0928\u0941\u092E\u093E\u0928 \u0938\u0947 \u0928\u0939\u0940\u0902 \u0926\u093F\u0916\u093E\u0908 \u0917\u0908 \u0939\u0948\u0964',
                '\u092A\u094D\u0930\u092E\u093E\u0923 \u0938\u0941\u091A\u0935\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0938\u094D\u0935\u0924\u0903\u091A\u093E \u0932\u0949\u091F \u0928\u093F\u0935\u0921\u093E. \u092A\u093F\u0915\u0905\u092A \u092A\u0924\u094D\u0924\u093E/\u0935\u0947\u0933 \u0920\u0930\u0935\u093E\u0935\u0940 \u0932\u093E\u0917\u0947\u0932; \u0905\u0902\u0924\u0930, \u0935\u0947\u0933 \u0915\u093F\u0902\u0935\u093E \u0915\u092E\u093E\u0908 \u0917\u0943\u0939\u0940\u0924 \u0927\u0930\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940.',
              ),
            ),
            if (v['city'] is String)
              actionButton(
                ct(
                  'Search city in Maps (not pickup address)',
                  'Maps \u092E\u0947\u0902 \u0936\u0939\u0930 \u0926\u0947\u0916\u0947\u0902 (\u092A\u093F\u0915\u0905\u092A \u092A\u0924\u093E \u0928\u0939\u0940\u0902)',
                  'Maps \u092E\u0927\u094D\u092F\u0947 \u0936\u0939\u0930 \u092A\u0939\u093E (\u092A\u093F\u0915\u0905\u092A \u092A\u0924\u094D\u0924\u093E \u0928\u093E\u0939\u0940)',
                ),
                () => openTrackingMap(context, v['city']),
                icon: Icons.map_outlined,
              ),
            actionButton(
              ct(
                'Offer my saved lot',
                '\u0905\u092A\u0928\u093E \u0938\u0939\u0947\u091C\u093E \u0932\u0949\u091F \u092D\u0947\u091C\u0947\u0902',
                '\u092E\u093E\u091D\u093E \u091C\u0924\u0928 \u0932\u0949\u091F \u092A\u093E\u0920\u0935\u093A',
              ),
              enabled
                  ? () => openCollector(
                      context,
                      OfferLotScreen(
                        requestId: ref.id,
                        material: '${v['material']}',
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    ),
  );
}

class OfferReceiptMarker extends StatelessWidget {
  const OfferReceiptMarker({
    required this.requestId,
    required this.offerId,
    super.key,
  });
  final String requestId, offerId;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _store.dbCloud
            .collection('collectorPayments')
            .where('collectorUid', isEqualTo: _store.uid)
            .where('requestId', isEqualTo: requestId)
            .where('offerId', isEqualTo: offerId)
            .limit(1)
            .snapshots(includeMetadataChanges: true),
        builder: (context, s) {
          if (s.hasError)
            return note(
              ct(
                'Receipt status unavailable; check ledger.',
                '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0938\u094D\u0925\u093F\u0924\u093F \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902; \u0916\u093E\u0924\u093E \u0926\u0947\u0916\u0947\u0902\u0964',
                '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940; \u0916\u093E\u0924\u0947 \u092A\u0939\u093E.',
              ),
            );
          if (!s.hasData) return const LinearProgressIndicator();
          if (s.data!.metadata.isFromCache || s.data!.metadata.hasPendingWrites)
            return note(
              ct(
                'Receipt status is cached/pending; not fresh confirmation.',
                '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0938\u094D\u0925\u093F\u0924\u093F \u0915\u0948\u0936/\u0932\u0902\u092C\u093F\u0924 \u0939\u0948; \u0928\u0908 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902\u0964',
                '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u0915\u0945\u0936/\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0906\u0939\u0947; \u0928\u0935\u0940\u0928 \u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940.',
              ),
            );
          final found = s.data!.docs.isNotEmpty;
          return Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    found ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: collectorGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      found
                          ? ct(
                              'Receipt recorded \u2014 collector statement, not bank verification or proof of full payment.',
                              '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0926\u0930\u094D\u091C \u2014 \u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0915\u093E \u092C\u092F\u093E\u0928, \u092C\u0948\u0902\u0915 \u092F\u093E \u092A\u0942\u0930\u0947 \u092D\u0941\u0917\u0924\u093E\u0928 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902\u0964',
                              '\u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0928\u094B\u0902\u0926\u0932\u0940 \u2014 \u0938\u0902\u0915\u0932\u0915\u093E\u091A\u0947 \u0928\u093F\u0935\u0947\u0926\u0928, \u092C\u0901\u0915 \u0915\u093F\u0902\u0935\u093E \u092A\u0942\u0930\u094D\u0923 \u092A\u0947\u092E\u0947\u0902\u091F\u091A\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940.',
                            )
                          : ct(
                              'No receipt recorded for this offer yet.',
                              '\u0907\u0938 \u0911\u092B\u0930 \u0915\u0940 \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u0905\u092D\u0940 \u0926\u0930\u094D\u091C \u0928\u0939\u0940\u0902\u0964',
                              '\u092F\u093E \u0911\u092B\u0930\u091A\u0940 \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0905\u091C\u0942\u0928 \u0928\u094B\u0902\u0926\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940.',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
