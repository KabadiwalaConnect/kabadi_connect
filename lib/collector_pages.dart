import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_language.dart';
import 'app_speech.dart';
import 'quick_profile_service.dart';
import 'collector_ui.dart';
import 'collector_store.dart';
import 'collector_market.dart';
import 'collector_session_gate.dart';
import 'language_screen.dart';
import 'material_photos.dart';
import 'recycler_directory_data.dart';
import 'collector_chat_tools.dart';
import 'collector_sell_requests.dart';

final _cs = CollectorStore.instance;

class LotsScreen extends StatefulWidget {
  const LotsScreen({super.key});
  @override
  State<LotsScreen> createState() => _LotsState();
}

class _LotsState extends State<LotsScreen> {
  String? _message;
  late final _remote = _cs.dbCloud
      .collection('users')
      .doc(_cs.uid)
      .collection('lots')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots(includeMetadataChanges: true);
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'My lots',
      '\u092E\u0947\u0930\u0947 \u0932\u0949\u091F',
      '\u092E\u093E\u091D\u0947 \u0932\u0949\u091F',
    ),
    guide: () => ct(
      'Create a local draft, then queue it for sync. Photos stay on this phone. Open a cloud lot to review its status.',
      '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u092C\u0928\u093E\u0915\u0930 \u0938\u093F\u0902\u0915 \u092E\u0947\u0902 \u092D\u0947\u091C\u0947\u0902\u0964 \u092B\u094B\u091F\u094B \u0907\u0938 \u092B\u094B\u0928 \u092A\u0930 \u0930\u0939\u0924\u0940 \u0939\u0948\u0902\u0964 \u0915\u094D\u0932\u093E\u0909\u0921 \u0932\u0949\u091F \u0916\u094B\u0932\u0915\u0930 \u0938\u094D\u0925\u093F\u0924\u093F \u0926\u0947\u0916\u0947\u0902\u0964',
      '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0924\u092F\u093E\u0930 \u0915\u0930\u0942\u0928 \u0938\u093F\u0902\u0915\u0938\u093E\u0920\u0940 \u092A\u093E\u0920\u0935\u093E. \u092B\u094B\u091F\u094B \u092F\u093E \u092B\u094B\u0928\u0935\u0930 \u0930\u093E\u0939\u0924\u093E\u0924. \u0915\u094D\u0932\u093E\u0909\u0921 \u0932\u0949\u091F \u0909\u0918\u0921\u0942\u0928 \u0938\u094D\u0925\u093F\u0924\u0940 \u092A\u0939\u093E.',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actionButton(
          ct(
            'New lot',
            '\u0928\u092F\u093E \u0932\u0949\u091F',
            '\u0928\u0935\u0940\u0928 \u0932\u0949\u091F',
          ),
          () => openCollector(context, const LotEditor()),
          icon: Icons.add_a_photo,
        ),
        actionButton(
          ct(
            'Sell my collection (direct sell)',
            '\u0905\u092A\u0928\u093E \u092E\u093E\u0932 \u092C\u0947\u091A\u0947\u0902 (\u0938\u0940\u0927\u0940 \u092C\u093F\u0915\u094D\u0930\u0940)',
            '\u0924\u0941\u092E\u091A\u093E \u092E\u093E\u0932 \u0935\u093F\u0915\u093E (\u0925\u0947\u091F \u0935\u093F\u0915\u094D\u0930\u0940)',
          ),
          () => openCollector(context, const DirectSellPage()),
          icon: Icons.point_of_sale,
        ),
        actionButton(
          ct(
            'Sign out',
            '\u0938\u093E\u0907\u0928 \u0906\u0909\u091F',
            '\u0938\u093E\u0907\u0928 \u0906\u0909\u091F',
          ),
          () async {
            if (!await confirmAction(
              context,
              ct(
                'Sign out of this account? Your saved lots and requests stay safe on the server and come back when you log in again with the same phone number and PIN.',
                '\u0907\u0938 \u0916\u093E\u0924\u0947 \u0938\u0947 \u0938\u093E\u0907\u0928 \u0906\u0909\u091F \u0915\u0930\u0947\u0902? \u0906\u092A\u0915\u0947 \u0938\u0939\u0947\u091C\u0947 \u0932\u0949\u091F \u0914\u0930 \u0905\u0928\u0941\u0930\u094B\u0927 \u0938\u0930\u094D\u0935\u0930 \u092A\u0930 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0930\u0939\u0924\u0947 \u0939\u0948\u0902 \u0914\u0930 \u0909\u0938\u0940 \u092B\u093C\u094B\u0928 \u0928\u0902\u092C\u0930 + PIN \u0938\u0947 \u092B\u093F\u0930 \u0932\u0949\u0917\u093F\u0928 \u0915\u0930\u0928\u0947 \u092A\u0930 \u0935\u093E\u092A\u0938 \u0906 \u091C\u093E\u0924\u0947 \u0939\u0948\u0902\u0964',
                '\u092F\u093E \u0916\u093E\u0924\u094D\u092F\u093E\u0924\u0942\u0928 \u0938\u093E\u0907\u0928 \u0906\u0909\u091F \u0915\u0930\u093E\u092F\u091A\u0947? \u0924\u0941\u092E\u091A\u0947 \u091C\u0924\u0928 \u0915\u0947\u0932\u0947\u0932\u0947 \u0932\u0949\u091F \u0935 \u0935\u093F\u0928\u0902\u0924\u094D\u092F\u093E \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0935\u0930 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0930\u093E\u0939\u0924\u093E\u0924 \u0935 \u0924\u094D\u092F\u093E\u091A \u092B\u094B\u0928 \u0928\u0902\u092C\u0930 + PIN \u0928\u0947 \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0917\u093F\u0928 \u0915\u0947\u0932\u094D\u092F\u093E\u0938 \u092A\u0930\u0924 \u092F\u0947\u0924\u093E\u0924.',
              ),
            ))
              return;
            await FirebaseAuth.instance.signOut();
          },
          icon: Icons.logout,
        ),
        if (_message != null) SpokenNotice(text: _message!),
        section(
          ct(
            'On this phone',
            '\u0907\u0938 \u092B\u094B\u0928 \u092A\u0930',
            '\u092F\u093E \u092B\u094B\u0928\u0935\u0930',
          ),
        ),
        AnimatedBuilder(
          animation: _cs,
          builder: (context, _) => FutureBuilder<List<Map<String, dynamic>>>(
            future: _cs.drafts(),
            builder: (context, s) {
              if (s.hasError) return note(friendlyError(s.error!));
              if (!s.hasData) return const LinearProgressIndicator();
              return Column(
                children: [
                  if (s.data!.isEmpty)
                    note(
                      ct(
                        'No local drafts.',
                        '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0928\u0939\u0940\u0902\u0964',
                        '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0928\u093E\u0939\u0940\u0924.',
                      ),
                    ),
                  ...s.data!.map((r) {
                    final v = Map<String, dynamic>.from(r['value'] as Map);
                    return Card(
                      child: ListTile(
                        leading: MaterialPhoto(
                          material: '${v['material'] ?? ''}',
                          width: 54,
                          height: 56,
                        ),
                        title: Text(
                          '${materialLabel('${v['material'] ?? ''}')} \u00B7 ${v['weightKg'] ?? '\u2014'} kg',
                        ),
                        subtitle: Text(
                          '${statusLabel('${r['phase']}')}\n${ct('Photo: device only', '\u092B\u094B\u091F\u094B: \u0915\u0947\u0935\u0932 \u092B\u094B\u0928 \u092A\u0930', '\u092B\u094B\u091F\u094B: \u092B\u0915\u094D\u0924 \u092B\u094B\u0928\u0935\u0930')}',
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () => openCollector(
                          context,
                          LotEditor(value: v, base: r['base'] as int),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        section(
          ct(
            'Cloud lots \u2014 newest 100',
            '\u0915\u094D\u0932\u093E\u0909\u0921 \u0932\u0949\u091F \u2014 \u0928\u0935\u0940\u0928\u0924\u092E 100',
            '\u0915\u094D\u0932\u093E\u0909\u0921 \u0932\u0949\u091F \u2014 \u0928\u0935\u0940\u0928\u0924\u092E 100',
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _remote,
          builder: (context, s) {
            if (s.hasError) return note(friendlyError(s.error!));
            if (!s.hasData) return const LinearProgressIndicator();
            return Column(
              children: [
                cacheNote(s.data!.metadata.isFromCache),
                if (s.data!.docs.isEmpty)
                  note(
                    ct(
                      'No cloud lots yet.',
                      '\u0905\u092D\u0940 \u0915\u094D\u0932\u093E\u0909\u0921 \u0932\u0949\u091F \u0928\u0939\u0940\u0902\u0964',
                      '\u0905\u0926\u094D\u092F\u093E\u092A \u0915\u094D\u0932\u093E\u0909\u0921 \u0932\u0949\u091F \u0928\u093E\u0939\u0940\u0924.',
                    ),
                  ),
                ...s.data!.docs.map(
                  (d) => Card(
                    child: ListTile(
                      leading: MaterialPhoto(
                        material: '${d.data()['material']}',
                        width: 54,
                        height: 56,
                      ),
                      title: Text(
                        '${materialLabel('${d.data()['material']}')} \u00B7 ${d.data()['weightKg']} kg',
                      ),
                      subtitle: Text(
                        '${d.data()['city']} \u00B7 ${statusLabel('${d.data()['status']}')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          openCollector(context, LotDetail(ref: d.reference)),
                    ),
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

class LotEditor extends StatefulWidget {
  const LotEditor({this.value, this.base = 0, this.initialMaterial, super.key});
  final Map<String, dynamic>? value;
  final int base;
  final String? initialMaterial;
  @override
  State<LotEditor> createState() => _LotEditorState();
}

class _LotEditorState extends State<LotEditor> {
  late String _id, _city;
  String? _material, _photo, _message;
  bool _busy = false, _checked = false;
  late final TextEditingController _weight;
  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _id = v?['id'] as String? ?? _cs.newId();
    _city = v?['city'] as String? ?? 'Ludhiana';
    if (!collectorCities.contains(_city)) _city = 'Ludhiana';
    _material = v?['material'] as String? ?? widget.initialMaterial;
    _photo = v?['photoPath'] as String?;
    _weight = TextEditingController(text: v?['weightKg']?.toString() ?? '');
    _recover();
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _value => {
    'id': _id,
    'city': _city,
    'material': _material,
    'weightKg': double.tryParse(_weight.text.trim()),
    'photoPath': _photo,
  };
  Future<void> _recover() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'collector_camera_${_cs.uid}';
      final pending = prefs.getString(key);
      // Lost camera data belongs to its original draft, never another account/draft.
      if (pending != _id) return;
      final result = await ImagePicker().retrieveLostData();
      if (result.files?.isNotEmpty == true) {
        final path = await _cs.retainPhoto(result.files!.first.path, _id);
        if (mounted) {
          setState(() => _photo = path);
          await _cs.saveLocal(_value, base: widget.base);
        }
      }
      await prefs.remove(key);
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = ct(
            'Camera recovery unavailable; retake if necessary.',
            '\u0915\u0948\u092E\u0930\u093E \u0930\u093F\u0915\u0935\u0930\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902; \u091C\u093C\u0930\u0942\u0930\u0924 \u0939\u094B \u0924\u094B \u092B\u093F\u0930 \u0932\u0947\u0902\u0964',
            '\u0915\u0945\u092E\u0947\u0930\u093E \u0930\u093F\u0915\u0935\u0930\u094D\u0939\u0930\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940; \u0917\u0930\u091C \u0905\u0938\u0932\u094D\u092F\u093E\u0938 \u092A\u0941\u0928\u094D\u0939\u093E \u0918\u094D\u092F\u093E.',
          ),
        );
      }
    }
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _cs.saveLocal(_value, base: widget.base);
      final prefs = await SharedPreferences.getInstance();
      final key = 'collector_camera_${_cs.uid}';
      await prefs.setString(key, _id);
      final p = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (p != null) {
        final path = await _cs.retainPhoto(p.path, _id);
        if (mounted) {
          setState(() {
            _photo = path;
            _checked = false;
          });
          await _cs.saveLocal(_value, base: widget.base);
        }
      }
      await prefs.remove(key);
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = ct(
            'Photo not saved. Check camera permission/storage.',
            '\u092B\u094B\u091F\u094B \u0938\u0939\u0947\u091C\u0940 \u0928\u0939\u0940\u0902 \u0917\u0908\u0964 \u0915\u0948\u092E\u0930\u093E \u0905\u0928\u0941\u092E\u0924\u093F/\u0938\u094D\u091F\u094B\u0930\u0947\u091C \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
            '\u092B\u094B\u091F\u094B \u091C\u0924\u0928 \u0928\u093E\u0939\u0940. \u0915\u0945\u092E\u0947\u0930\u093E \u092A\u0930\u0935\u093E\u0928\u0917\u0940/\u0938\u094D\u091F\u094B\u0930\u0947\u091C \u0924\u092A\u093E\u0938\u093E.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool queue) async {
    if (_busy) return;
    if (queue &&
        (_photo == null ||
            !_checked ||
            !collectorMaterials.contains(_material) ||
            !CollectorStore.validWeight(_value['weightKg']))) {
      setState(
        () => _message = ct(
          'Take a photo, select/confirm material and enter weight greater than 0 and at most 10000 kg.',
          '\u092B\u094B\u091F\u094B \u0932\u0947\u0902, \u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u091A\u0941\u0928\u0915\u0930 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0947\u0902 \u0914\u0930 0 \u0938\u0947 \u0905\u0927\u093F\u0915, \u0905\u0927\u093F\u0915\u0924\u092E 10000 \u0915\u093F\u0932\u094B \u0935\u091C\u0928 \u0932\u093F\u0916\u0947\u0902\u0964',
          '\u092B\u094B\u091F\u094B \u0918\u094D\u092F\u093E, \u0938\u093E\u0939\u093F\u0924\u094D\u092F \u0928\u093F\u0935\u0921\u0942\u0928 \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0930\u093E \u0906\u0923\u093F 0 \u092A\u0947\u0915\u094D\u0937\u093E \u091C\u093E\u0938\u094D\u0924, \u0915\u092E\u093E\u0932 10000 \u0915\u093F\u0932\u094B \u0935\u091C\u0928 \u0932\u093F\u0939\u093E.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _cs.saveLocal(_value, base: widget.base, queue: queue);
      if (mounted) {
        setState(
          () => _message = queue
              ? ct(
                  'Saved locally and queued. Sync confirms cloud availability; this is not an offer.',
                  '\u092B\u094B\u0928 \u092A\u0930 \u0938\u0939\u0947\u091C\u0915\u0930 \u0915\u0924\u093E\u0930 \u092E\u0947\u0902 \u0930\u0916\u093E\u0964 \u0938\u093F\u0902\u0915 \u0938\u0947 \u0915\u094D\u0932\u093E\u0909\u0921 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0939\u094B\u0917\u0940; \u092F\u0939 \u0911\u092B\u0930 \u0928\u0939\u0940\u0902\u0964',
                  '\u092B\u094B\u0928\u0935\u0930 \u091C\u0924\u0928 \u0915\u0930\u0942\u0928 \u0930\u093E\u0902\u0917\u0947\u0924 \u0920\u0947\u0935\u0932\u0947. \u0938\u093F\u0902\u0915\u0928\u0947 \u0915\u094D\u0932\u093E\u0909\u0921 \u092A\u0941\u0937\u094D\u091F\u0940 \u0939\u094B\u0908\u0932; \u0939\u093E \u0911\u092B\u0930 \u0928\u093E\u0939\u0940.',
                )
              : ct(
                  'Draft saved on this phone.',
                  '\u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0907\u0938 \u092B\u094B\u0928 \u092A\u0930 \u0938\u0939\u0947\u091C\u093E \u0917\u092F\u093E\u0964',
                  '\u0921\u094D\u0930\u093E\u092B\u094D\u091F \u092F\u093E \u092B\u094B\u0928\u0935\u0930 \u091C\u0924\u0928 \u091D\u093E\u0932\u093E.',
                ),
        );
      }
      if (queue) unawaited(_cs.sync());
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Lot draft',
      '\u0932\u0949\u091F \u0921\u094D\u0930\u093E\u092B\u094D\u091F',
      '\u0932\u0949\u091F \u0921\u094D\u0930\u093E\u092B\u094D\u091F',
    ),
    guide: () => ct(
      'Photograph the item without faces or private documents. Choose material manually. Save draft before leaving. AI is paused.',
      '\u091A\u0947\u0939\u0930\u0947 \u0914\u0930 \u0928\u093F\u091C\u0940 \u0915\u093E\u0917\u091C\u093C \u0915\u0947 \u092C\u093F\u0928\u093E \u0938\u093E\u092E\u093E\u0928 \u0915\u0940 \u092B\u094B\u091F\u094B \u0932\u0947\u0902\u0964 \u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u0938\u094D\u0935\u092F\u0902 \u091A\u0941\u0928\u0947\u0902\u0964 \u091C\u093E\u0928\u0947 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0938\u0939\u0947\u091C\u0947\u0902\u0964 AI \u092C\u0902\u0926 \u0939\u0948\u0964',
      '\u091A\u0947\u0939\u0930\u0947 \u0935 \u0916\u093E\u091C\u0917\u0940 \u0915\u093E\u0917\u0926\u093E\u0902\u0936\u093F\u0935\u093E\u092F \u0935\u0938\u094D\u0924\u0942\u091A\u093E \u092B\u094B\u091F\u094B \u0918\u094D\u092F\u093E. \u0938\u093E\u0939\u093F\u0924\u094D\u092F \u0938\u094D\u0935\u0924\u0903 \u0928\u093F\u0935\u0921\u093E. \u091C\u093E\u0923\u094D\u092F\u093E\u092A\u0942\u0930\u094D\u0935\u0940 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u091C\u0924\u0928 \u0915\u0930\u093E. AI \u092C\u0902\u0926 \u0906\u0939\u0947.',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_photo != null)
          Image.file(
            File(_photo!),
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, e, s) => note(
              ct(
                'Local photo unavailable. Retake it.',
                '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u092B\u094B\u091F\u094B \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u0940\u0964 \u0926\u094B\u092C\u093E\u0930\u093E \u0932\u0947\u0902\u0964',
                '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092B\u094B\u091F\u094B \u0928\u093E\u0939\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u0918\u094D\u092F\u093E.',
              ),
            ),
          ),
        actionButton(
          ct(
            'Camera',
            '\u0915\u0948\u092E\u0930\u093E',
            '\u0915\u0945\u092E\u0947\u0930\u093E',
          ),
          _busy ? null : () => _capture(ImageSource.camera),
          icon: Icons.camera_alt,
        ),
        actionButton(
          ct(
            'Choose photo',
            '\u092B\u094B\u091F\u094B \u091A\u0941\u0928\u0947\u0902',
            '\u092B\u094B\u091F\u094B \u0928\u093F\u0935\u0921\u093E',
          ),
          _busy ? null : () => _capture(ImageSource.gallery),
          icon: Icons.photo_library_outlined,
        ),
        note(
          ct(
            'Photo stays in this app on this phone. It is not uploaded, shared with recyclers or proof of weight/composition.',
            '\u092B\u094B\u091F\u094B \u0907\u0938\u0940 \u092B\u094B\u0928 \u0915\u0947 \u0910\u092A \u092E\u0947\u0902 \u0930\u0939\u0947\u0917\u0940\u0964 \u0905\u092A\u0932\u094B\u0921 \u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0938\u0947 \u0938\u093E\u091D\u093E \u0928\u0939\u0940\u0902 \u0939\u094B\u0917\u0940; \u0935\u091C\u0928/\u092C\u0928\u093E\u0935\u091F \u0915\u093E \u092A\u094D\u0930\u092E\u093E\u0923 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
            '\u092B\u094B\u091F\u094B \u092F\u093E\u091A \u092B\u094B\u0928\u091A\u094D\u092F\u093E \u0905\u0945\u092A\u092E\u0927\u094D\u092F\u0947 \u0930\u093E\u0939\u0940\u0932. \u0905\u092A\u0932\u094B\u0921 \u0915\u093F\u0902\u0935\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0936\u0940 \u0936\u0947\u0905\u0930 \u0939\u094B\u0923\u093E\u0930 \u0928\u093E\u0939\u0940; \u0935\u091C\u0928/\u0930\u091A\u0928\u0947\u091A\u093E \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940.',
          ),
        ),
        MaterialPhotoGrid(
          labelFor: materialLabel,
          selected: _material,
          onSelected: _busy
              ? null
              : (m) {
                  setState(() {
                    _material = m;
                    _checked = false;
                  });
                  AppSpeech.instance.say(materialLabel(m));
                },
        ),
        DropdownButtonFormField<String>(
          initialValue: _city,
          decoration: InputDecoration(
            labelText: ct('City', '\u0936\u0939\u0930', '\u0936\u0939\u0930'),
          ),
          items: collectorCities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: _busy ? null : (c) => setState(() => _city = c!),
        ),
        TextField(
          controller: _weight,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: ct(
              'Measured weight (kg)',
              '\u092E\u093E\u092A\u093E \u0935\u091C\u0928 (\u0915\u093F\u0932\u094B)',
              '\u092E\u094B\u091C\u0932\u0947\u0932\u0947 \u0935\u091C\u0928 (\u0915\u093F\u0932\u094B)',
            ),
          ),
        ),
        CheckboxListTile(
          value: _checked,
          onChanged: _busy
              ? null
              : (v) {
                  setState(() => _checked = v ?? false);
                  AppSpeech.instance.say(
                    ct(
                      'Material confirmation updated',
                      '\u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u092C\u0926\u0932\u0940',
                      '\u0938\u093E\u0939\u093F\u0924\u094D\u092F\u093E\u091A\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u092C\u0926\u0932\u0932\u0940',
                    ),
                  );
                },
          title: Text(
            ct(
              'I checked the selected material',
              '\u092E\u0948\u0902\u0928\u0947 \u091A\u0941\u0928\u0940 \u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u091C\u093E\u0901\u091A\u0940 \u0939\u0948',
              '\u092E\u0940 \u0928\u093F\u0935\u0921\u0932\u0947\u0932\u0947 \u0938\u093E\u0939\u093F\u0924\u094D\u092F \u0924\u092A\u093E\u0938\u0932\u0947',
            ),
          ),
        ),
        note(
          ct(
            'Never open, burn or crush batteries/CRTs. Save before leaving this page. Unsaved typing is not a durable draft.',
            '\u092C\u0948\u091F\u0930\u0940/CRT \u0928 \u0916\u094B\u0932\u0947\u0902, \u091C\u0932\u093E\u090F\u0901 \u092F\u093E \u0915\u0941\u091A\u0932\u0947\u0902\u0964 \u092A\u0947\u091C \u091B\u094B\u0921\u093C\u0928\u0947 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0938\u0939\u0947\u091C\u0947\u0902\u0964 \u092C\u093F\u0928\u093E \u0938\u0939\u0947\u091C\u0940 \u091F\u093E\u0907\u092A\u093F\u0902\u0917 \u0938\u094D\u0925\u093E\u092F\u0940 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0928\u0939\u0940\u0902\u0964',
            '\u092C\u0945\u091F\u0930\u0940/CRT \u0909\u0918\u0921\u0942, \u091C\u093E\u0933\u0942 \u0915\u093F\u0902\u0935\u093E \u091A\u093F\u0930\u0921\u0942 \u0928\u0915\u093E. \u092A\u0947\u091C \u0938\u094B\u0921\u0923\u094D\u092F\u093E\u092A\u0942\u0930\u094D\u0935\u0940 \u091C\u0924\u0928 \u0915\u0930\u093E. \u0928 \u091C\u0924\u0928 \u0915\u0947\u0932\u0947\u0932\u0940 \u091F\u093E\u092F\u092A\u093F\u0902\u0917 \u091F\u093F\u0915\u0923\u093E\u0930\u093E \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0928\u093E\u0939\u0940.',
          ),
        ),
        actionButton(
          ct(
            'Save local draft',
            '\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0938\u0939\u0947\u091C\u0947\u0902',
            '\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u091C\u0924\u0928 \u0915\u0930\u093E',
          ),
          _busy ? null : () => _save(false),
          icon: Icons.save_outlined,
        ),
        actionButton(
          ct(
            'Save and queue sync',
            '\u0938\u0939\u0947\u091C\u0947\u0902 \u0914\u0930 \u0938\u093F\u0902\u0915 \u092E\u0947\u0902 \u092D\u0947\u091C\u0947\u0902',
            '\u091C\u0924\u0928 \u0915\u0930\u093E \u0935 \u0938\u093F\u0902\u0915 \u0930\u093E\u0902\u0917\u0947\u0924 \u0920\u0947\u0935\u093E',
          ),
          _busy ? null : () => _save(true),
          icon: Icons.cloud_upload_outlined,
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) SpokenNotice(text: _message!),
        actionButton(
          ct(
            'Open sync status',
            '\u0938\u093F\u0902\u0915 \u0938\u094D\u0925\u093F\u0924\u093F \u0916\u094B\u0932\u0947\u0902',
            '\u0938\u093F\u0902\u0915 \u0938\u094D\u0925\u093F\u0924\u0940 \u0909\u0918\u0921\u093E',
          ),
          () => openCollector(context, const SyncScreen()),
        ),
      ],
    ),
  );
}

class LotDetail extends StatefulWidget {
  const LotDetail({required this.ref, super.key});
  final DocumentReference<Map<String, dynamic>> ref;
  @override
  State<LotDetail> createState() => _LotDetailState();
}

class _LotDetailState extends State<LotDetail> {
  bool _busy = false;
  String? _message;
  Future<void> _edit(Map<String, dynamic> v) async {
    if (_cs.syncing) return;
    final rows = await _cs.drafts();
    final matching = rows.where((r) => r['id'] == widget.ref.id).toList();
    final photo = matching.isEmpty
        ? null
        : (matching.first['value'] as Map)['photoPath'];
    if (!mounted) return;
    if (matching.isNotEmpty && matching.first['phase'] != 'synced') {
      if (!await confirmAction(
            context,
            ct(
              'Replace this phone draft metadata with the displayed cloud version for editing? Review your unsynced changes first. The local photo is kept.',
              '\u092C\u0926\u0932\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u092B\u094B\u0928 \u0915\u093E \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0935\u093F\u0935\u0930\u0923 \u0926\u093F\u0916\u093E\u090F \u0915\u094D\u0932\u093E\u0909\u0921 \u0938\u0902\u0938\u094D\u0915\u0930\u0923 \u0938\u0947 \u092C\u0926\u0932\u0947\u0902? \u092A\u0939\u0932\u0947 \u092C\u093F\u0928\u093E \u0938\u093F\u0902\u0915 \u0939\u0941\u090F \u092C\u0926\u0932\u093E\u0935 \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u092B\u094B\u091F\u094B \u0930\u0939\u0947\u0917\u0940\u0964',
              '\u0938\u0902\u092A\u093E\u0926\u0928\u093E\u0938\u093E\u0920\u0940 \u092B\u094B\u0928\u091A\u093E \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0924\u092A\u0936\u0940\u0932 \u0926\u093E\u0916\u0935\u0932\u0947\u0932\u094D\u092F\u093E \u0915\u094D\u0932\u093E\u0909\u0921 \u0906\u0935\u0943\u0924\u094D\u0924\u0940\u0928\u0947 \u092C\u0926\u0932\u093E\u092F\u091A\u093E? \u0906\u0927\u0940 \u0928 \u0938\u093F\u0902\u0915 \u091D\u093E\u0932\u0947\u0932\u0947 \u092C\u0926\u0932 \u0924\u092A\u093E\u0938\u093E. \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u092B\u094B\u091F\u094B \u0930\u093E\u0939\u0940\u0932.',
            ),
          ) ||
          !mounted) {
        return;
      }
    }
    final value = <String, dynamic>{
      'id': widget.ref.id,
      'material': v['material'],
      'weightKg': v['weightKg'],
      'city': v['city'],
      'photoPath': photo,
    };
    final base = (v['revision'] as num?)?.toInt() ?? 0;
    try {
      await _cs.saveLocal(value, base: base, replaceBase: true);
      if (mounted) openCollector(context, LotEditor(value: value, base: base));
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    }
  }

  Future<void> _archive() async {
    if (!await confirmAction(
          context,
          ct(
            'Archive this unused draft? It will no longer be offered. This is not account deletion.',
            '\u0907\u0938 \u0905\u092A\u094D\u0930\u092F\u0941\u0915\u094D\u0924 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0915\u094B \u0938\u0902\u0917\u094D\u0930\u0939\u093F\u0924 \u0915\u0930\u0947\u0902? \u092B\u093F\u0930 \u0911\u092B\u0930 \u0928\u0939\u0940\u0902 \u092D\u0947\u091C \u0938\u0915\u0947\u0902\u0917\u0947\u0964 \u092F\u0939 \u0916\u093E\u0924\u093E \u0939\u091F\u093E\u0928\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
            '\u0939\u093E \u0928 \u0935\u093E\u092A\u0930\u0932\u0947\u0932\u093E \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0938\u0902\u0917\u094D\u0930\u0939\u093F\u0924 \u0915\u0930\u093E\u092F\u091A\u093E? \u0928\u0902\u0924\u0930 \u0911\u092B\u0930 \u092A\u093E\u0920\u0935\u0924\u093E \u092F\u0947\u0923\u093E\u0930 \u0928\u093E\u0939\u0940. \u0939\u0947 \u0916\u093E\u0924\u0947 \u0939\u091F\u0935\u0923\u0947 \u0928\u093E\u0939\u0940.',
          ),
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _cs.archive(widget.ref.id);
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Lot details',
      '\u0932\u0949\u091F \u0935\u093F\u0935\u0930\u0923',
      '\u0932\u0949\u091F \u0924\u092A\u0936\u0940\u0932',
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
              'Lot missing',
              '\u0932\u0949\u091F \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E',
              '\u0932\u0949\u091F \u0928\u093E\u0939\u0940',
            ),
          );
        }
        final available =
            v['status'] == 'draft' && !s.data!.metadata.isFromCache && !_busy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cacheNote(s.data!.metadata.isFromCache),
            MaterialPhoto(
              material: '${v['material']}',
              width: 180,
              height: 150,
            ),
            section(materialLabel('${v['material']}')),
            note('${v['weightKg']} kg \u00B7 ${v['city']}'),
            section(statusLabel('${v['status']}')),
            note(
              ct(
                'Category illustration above, not your saved photo. Open local draft to see its device-only photo.',
                '\u090A\u092A\u0930 \u0936\u094D\u0930\u0947\u0923\u0940 \u0915\u093E \u091A\u093F\u0924\u094D\u0930 \u0939\u0948, \u0906\u092A\u0915\u0940 \u092B\u094B\u091F\u094B \u0928\u0939\u0940\u0902\u0964 \u092B\u094B\u0928 \u0935\u093E\u0932\u0940 \u092B\u094B\u091F\u094B \u0915\u0947 \u0932\u093F\u090F \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0916\u094B\u0932\u0947\u0902\u0964',
                '\u0935\u0930\u0940\u0932 \u091A\u093F\u0924\u094D\u0930 \u0936\u094D\u0930\u0947\u0923\u0940\u091A\u0947 \u0906\u0939\u0947, \u0924\u0941\u092E\u091A\u093E \u092B\u094B\u091F\u094B \u0928\u093E\u0939\u0940. \u092B\u094B\u0928\u0935\u0930\u0940\u0932 \u092B\u094B\u091F\u094B \u092A\u093E\u0939\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0909\u0918\u0921\u093E.',
              ),
            ),
            if (v['activeOfferId'] is String &&
                (v['activeOfferId'] as String).isNotEmpty)
              actionButton(
                ct(
                  'Open linked offer',
                  '\u091C\u0941\u0921\u093C\u093E \u0911\u092B\u0930 \u0916\u094B\u0932\u0947\u0902',
                  '\u091C\u094B\u0921\u0932\u0947\u0932\u093E \u0911\u092B\u0930 \u0909\u0918\u0921\u093E',
                ),
                () => openCollector(
                  context,
                  OfferDetailScreen(
                    ref: _cs.dbCloud
                        .collection('recyclerRequests')
                        .doc(v['activeRequestId'] as String)
                        .collection('offers')
                        .doc(v['activeOfferId'] as String),
                  ),
                ),
              ),
            actionButton(
              ct(
                'Edit draft',
                '\u0921\u094D\u0930\u093E\u092B\u094D\u091F \u092C\u0926\u0932\u0947\u0902',
                '\u0921\u094D\u0930\u093E\u092B\u094D\u091F \u092C\u0926\u0932\u093E',
              ),
              available ? () => _edit(v) : null,
              icon: Icons.edit,
            ),
            actionButton(
              ct(
                'Archive unused draft',
                '\u0905\u092A\u094D\u0930\u092F\u0941\u0915\u094D\u0924 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0938\u0902\u0917\u094D\u0930\u0939\u093F\u0924 \u0915\u0930\u0947\u0902',
                '\u0928 \u0935\u093E\u092A\u0930\u0932\u0947\u0932\u093E \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0938\u0902\u0917\u094D\u0930\u0939\u093F\u0924 \u0915\u0930\u093E',
              ),
              available ? _archive : null,
              icon: Icons.archive_outlined,
            ),
            actionButton(
              ct(
                'View buying requests',
                '\u0916\u0930\u0940\u0926 \u092E\u093E\u0901\u0917 \u0926\u0947\u0916\u0947\u0902',
                '\u0916\u0930\u0947\u0926\u0940 \u092E\u093E\u0917\u0923\u094D\u092F\u093E \u092A\u0939\u093E',
              ),
              () => openCollector(context, const RecyclerRequestsScreen()),
            ),
            if (_message != null) SpokenNotice(text: _message!),
          ],
        );
      },
    ),
  );
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncState();
}

class _SyncState extends State<SyncScreen> {
  String? _message;
  bool _busy = false;
  Future<void> _sync() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _cs.sync(retryErrors: true);
      final pending = await _cs.paymentQueue();
      for (final p in pending) {
        await _cs.postPayment(p['id'] as String);
      }
      if (mounted) {
        setState(
          () => _message = _cs.lastError == null
              ? ct(
                  'Retry finished. Check each record status.',
                  '\u0926\u094B\u092C\u093E\u0930\u093E \u092D\u0947\u091C\u0928\u0947 \u0915\u093E \u092A\u094D\u0930\u092F\u093E\u0938 \u092A\u0942\u0930\u093E\u0964 \u0939\u0930 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0915\u0940 \u0938\u094D\u0925\u093F\u0924\u093F \u0926\u0947\u0916\u0947\u0902\u0964',
                  '\u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u0923\u094D\u092F\u093E\u091A\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928 \u092A\u0942\u0930\u094D\u0923. \u092A\u094D\u0930\u0924\u094D\u092F\u0947\u0915 \u0928\u094B\u0902\u0926\u0940\u091A\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u092A\u0939\u093E.',
                )
              : ct(
                  'Some drafts need attention. Locked/revision-conflict lots must be reviewed, not overwritten.',
                  '\u0915\u0941\u091B \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u0932\u0949\u0915/\u0938\u0902\u0938\u094D\u0915\u0930\u0923 \u0938\u0902\u0918\u0930\u094D\u0937 \u0935\u093E\u0932\u0947 \u0932\u0949\u091F \u0915\u094B \u092C\u093F\u0928\u093E \u091C\u093E\u0901\u091A\u0947 \u0928 \u092C\u0926\u0932\u0947\u0902\u0964',
                  '\u0915\u093E\u0939\u0940 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0924\u092A\u093E\u0938\u093E. \u0932\u0949\u0915/\u0906\u0935\u0943\u0924\u094D\u0924\u0940 \u0938\u0902\u0918\u0930\u094D\u0937 \u0905\u0938\u0932\u0947\u0932\u0947 \u0932\u0949\u091F \u0928 \u0924\u092A\u093E\u0938\u0924\u093E \u092C\u0926\u0932\u0942 \u0928\u0915\u093E.',
                ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Offline & sync',
      '\u0911\u092B\u0932\u093E\u0907\u0928 \u0914\u0930 \u0938\u093F\u0902\u0915',
      '\u0911\u092B\u0932\u093E\u0907\u0928 \u0935 \u0938\u093F\u0902\u0915',
    ),
    guide: () => ct(
      'Local drafts and photos survive a normal restart. Retry queued data with internet. Never clear storage to fix sync.',
      '\u0938\u0939\u0947\u091C\u0947 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0914\u0930 \u092B\u094B\u091F\u094B \u0938\u093E\u092E\u093E\u0928\u094D\u092F \u0930\u0940\u0938\u094D\u091F\u093E\u0930\u094D\u091F \u0915\u0947 \u092C\u093E\u0926 \u0930\u0939\u0924\u0947 \u0939\u0948\u0902\u0964 \u0907\u0902\u091F\u0930\u0928\u0947\u091F \u092A\u0930 \u0915\u0924\u093E\u0930 \u092B\u093F\u0930 \u092D\u0947\u091C\u0947\u0902\u0964 \u0938\u093F\u0902\u0915 \u0915\u0947 \u0932\u093F\u090F \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u0928 \u092E\u093F\u091F\u093E\u090F\u0901\u0964',
      '\u091C\u0924\u0928 \u0915\u0947\u0932\u0947\u0932\u0947 \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0935 \u092B\u094B\u091F\u094B \u0938\u093E\u092E\u093E\u0928\u094D\u092F \u0930\u0940\u0938\u094D\u091F\u093E\u0930\u094D\u091F\u0928\u0902\u0924\u0930 \u0930\u093E\u0939\u0924\u093E\u0924. \u0907\u0902\u091F\u0930\u0928\u0947\u091F\u0935\u0930 \u0930\u093E\u0902\u0917 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093E. \u0938\u093F\u0902\u0915\u0938\u093E\u0920\u0940 \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u092A\u0941\u0938\u0942 \u0928\u0915\u093E.',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actionButton(
          ct(
            'Review pending chat messages',
            '\u0932\u0902\u092C\u093F\u0924 \u091A\u0948\u091F \u0938\u0902\u0926\u0947\u0936 \u0926\u0947\u0916\u0947\u0902',
            '\u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u091A\u0945\u091F \u0938\u0902\u0926\u0947\u0936 \u092A\u0939\u093E',
          ),
          () => openCollector(context, const PendingChatScreen()),
          icon: Icons.outbox_outlined,
        ),
        note(
          ct(
            'Draft metadata syncs to Firebase. Photos are device-only and are lost if app storage is erased. Local data is UID-scoped, not an independent recovery backup.',
            '\u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0935\u093F\u0935\u0930\u0923 Firebase \u092E\u0947\u0902 \u0938\u093F\u0902\u0915 \u0939\u094B\u0924\u0947 \u0939\u0948\u0902\u0964 \u092B\u094B\u091F\u094B \u0915\u0947\u0935\u0932 \u092B\u094B\u0928 \u092A\u0930 \u0939\u0948\u0902; \u0910\u092A \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u092E\u093F\u091F\u0928\u0947 \u092A\u0930 \u0916\u094B \u091C\u093E\u090F\u0901\u0917\u0940\u0964 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u0947\u091F\u093E UID \u0938\u0947 \u091C\u0941\u0921\u093C\u093E \u0939\u0948, \u0905\u0932\u0917 \u0930\u093F\u0915\u0935\u0930\u0940 \u092C\u0948\u0915\u0905\u092A \u0928\u0939\u0940\u0902\u0964',
            '\u0921\u094D\u0930\u093E\u092B\u094D\u091F \u0924\u092A\u0936\u0940\u0932 Firebase \u0932\u093E \u0938\u093F\u0902\u0915 \u0939\u094B\u0924\u093E\u0924. \u092B\u094B\u091F\u094B \u092B\u0915\u094D\u0924 \u092B\u094B\u0928\u0935\u0930 \u0906\u0939\u0947\u0924; \u0905\u0945\u092A \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u092A\u0941\u0938\u0932\u094D\u092F\u093E\u0938 \u0939\u0930\u0935\u0924\u0940\u0932. \u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u0947\u091F\u093E UID \u0936\u0940 \u091C\u094B\u0921\u0932\u0947\u0932\u093E \u0906\u0939\u0947, \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u092C\u0945\u0915\u0905\u092A \u0928\u093E\u0939\u0940.',
          ),
        ),
        actionButton(
          ct(
            'Retry queued records',
            '\u0915\u0924\u093E\u0930 \u0915\u0940 \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F\u092F\u093E\u0901 \u092B\u093F\u0930 \u092D\u0947\u091C\u0947\u0902',
            '\u0930\u093E\u0902\u0917\u0947\u0924\u0940\u0932 \u0928\u094B\u0902\u0926\u0940 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u093E',
          ),
          _busy ? null : _sync,
          icon: Icons.sync,
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) SpokenNotice(text: _message!),
        AnimatedBuilder(
          animation: _cs,
          builder: (context, _) => FutureBuilder<List<Map<String, dynamic>>>(
            future: _cs.drafts(),
            builder: (context, s) => Column(
              children: [
                if (s.hasError) note(friendlyError(s.error!)),
                ...?(s.data?.map(
                  (r) => ListTile(
                    title: Text(
                      '${materialLabel('${(r['value'] as Map)['material'] ?? ''}')} \u00B7 ${statusLabel('${r['phase']}')}',
                    ),
                    subtitle: r['error'] == null ? null : Text('${r['error']}'),
                  ),
                )),
              ],
            ),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _cs.paymentQueue(),
          builder: (context, s) => note(
            '${ct('Unconfirmed receipt journal entries', '\u0905\u092A\u0941\u0937\u094D\u091F \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u093F \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F\u092F\u093E\u0901', '\u0905\u092A\u0941\u0937\u094D\u091F \u092A\u094D\u0930\u093E\u092A\u094D\u0924\u0940 \u0928\u094B\u0902\u0926\u0940')}: ${s.data?.length ?? '\u2026'}',
          ),
        ),
        note(
          ct(
            'A timeout does not cancel a server operation. Stable IDs make retries idempotent. Never create a second receipt for the same uncertain attempt.',
            '\u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0938\u0930\u094D\u0935\u0930 \u0915\u093E \u0915\u093E\u092E \u0930\u0926\u094D\u0926 \u0928\u0939\u0940\u0902 \u0915\u0930\u0924\u093E\u0964 \u0938\u094D\u0925\u093F\u0930 ID \u0938\u0947 \u0926\u094B\u092C\u093E\u0930\u093E \u092D\u0947\u091C\u0928\u093E \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u0948\u0964 \u0905\u0928\u093F\u0936\u094D\u091A\u093F\u0924 \u092A\u094D\u0930\u092F\u093E\u0938 \u0915\u0947 \u0932\u093F\u090F \u0926\u0942\u0938\u0930\u0940 \u0930\u0938\u0940\u0926 \u0928 \u092C\u0928\u093E\u090F\u0901\u0964',
            '\u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u091A\u0947 \u0915\u093E\u092E \u0930\u0926\u094D\u0926 \u0915\u0930\u0924 \u0928\u093E\u0939\u0940. \u0938\u094D\u0925\u093F\u0930 ID \u092E\u0941\u0933\u0947 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u093E\u0920\u0935\u0923\u0947 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0906\u0939\u0947. \u0905\u0928\u093F\u0936\u094D\u091A\u093F\u0924 \u092A\u094D\u0930\u092F\u0924\u094D\u0928\u093E\u0938\u093E\u0920\u0940 \u0926\u0941\u0938\u0930\u0940 \u092A\u093E\u0935\u0924\u0940 \u092C\u0928\u0935\u0942 \u0928\u0915\u093E.',
          ),
        ),
      ],
    ),
  );
}

/// A directory record is not an authenticated/verified recycler account.
bool directoryHasPastDate(String raw, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  for (final m in RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})').allMatches(raw)) {
    final day = int.parse(m[1]!),
        month = int.parse(m[2]!),
        year = int.parse(m[3]!);
    final d = DateTime(year, month, day);
    if (d.year == year && d.month == month && d.day == day && d.isBefore(today))
      return true;
  }
  return false;
}

List<Map<String, String>> filterRecyclerDirectory({
  String query = '',
  String state = '',
  bool savedOnly = false,
  Set<String> saved = const {},
}) {
  final words = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return recyclerDirectoryData.where((r) {
    final searchable = [
      'name',
      'state',
      'address',
      'regionalOffice',
      'acceptanceText',
    ].map((k) => r[k] ?? '').join(' ').toLowerCase();
    return (state.isEmpty || r['state'] == state) &&
        (!savedOnly || saved.contains(r['id'])) &&
        words.every(searchable.contains);
  }).toList();
}

class RecyclerDirectoryScreen extends StatefulWidget {
  const RecyclerDirectoryScreen({super.key});
  @override
  State<RecyclerDirectoryScreen> createState() => _DirectoryState();
}

class _DirectoryState extends State<RecyclerDirectoryScreen> {
  final _search = TextEditingController();
  final _entryUid = FirebaseAuth.instance.currentUser?.uid;
  Set<String> _saved = {};
  String _state = '';
  String? _message;
  bool _savedOnly = false,
      _loadingSaved = true,
      _saving = false,
      _savedReady = false;
  String get _key => 'directory_saved_$_entryUid';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loadingSaved = true);
    try {
      if (_entryUid == null) return;
      final values =
          (await SharedPreferences.getInstance()).getStringList(_key) ?? [];
      final migrated = <String>{};
      for (final value in values) {
        final names = recyclerDirectoryData
            .where((r) => r['name'] == value)
            .toList();
        migrated.add(names.length == 1 ? names.first['id']! : value);
      }
      if (mounted && FirebaseAuth.instance.currentUser?.uid == _entryUid)
        setState(() {
          _saved = migrated;
          _savedReady = true;
          _message = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Saved contacts could not load. The full directory is still available.',
            '\u0938\u0939\u0947\u091C\u0947 \u0938\u0902\u092A\u0930\u094D\u0915 \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u0947\u0964 \u092A\u0942\u0930\u0940 \u0938\u0942\u091A\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0939\u0948\u0964',
            '\u091C\u0924\u0928 \u0938\u0902\u092A\u0930\u094D\u0915 \u0909\u0918\u0921\u0932\u0947 \u0928\u093E\u0939\u0940\u0924. \u092A\u0942\u0930\u094D\u0923 \u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u093E \u0909\u092A\u0932\u092C\u094D\u0927 \u0906\u0939\u0947.',
          ),
        );
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _bookmark(Map<String, String> r) async {
    if (_entryUid == null ||
        _loadingSaved ||
        !_savedReady ||
        _saving ||
        FirebaseAuth.instance.currentUser?.uid != _entryUid)
      return;
    final next = Set<String>.of(_saved);
    final added = next.add(r['id']!);
    if (!added) next.remove(r['id']);
    setState(() => _saving = true);
    try {
      final ok = await (await SharedPreferences.getInstance()).setStringList(
        _key,
        next.toList(),
      );
      if (!ok) throw StateError('save-failed');
      if (mounted && FirebaseAuth.instance.currentUser?.uid == _entryUid) {
        setState(() {
          _saved = next;
          _message = null;
        });
        AppSpeech.instance.say(
          added
              ? ct(
                  'Contact saved on this phone',
                  '\u0938\u0902\u092A\u0930\u094D\u0915 \u0907\u0938 \u092B\u094B\u0928 \u092A\u0930 \u0938\u0939\u0947\u091C\u093E',
                  '\u0938\u0902\u092A\u0930\u094D\u0915 \u092F\u093E \u092B\u094B\u0928\u0935\u0930 \u091C\u0924\u0928 \u0915\u0947\u0932\u093E',
                )
              : ct(
                  'Saved contact removed',
                  '\u0938\u0939\u0947\u091C\u093E \u0938\u0902\u092A\u0930\u094D\u0915 \u0939\u091F\u093E\u092F\u093E',
                  '\u091C\u0924\u0928 \u0938\u0902\u092A\u0930\u094D\u0915 \u0915\u093E\u0922\u0932\u093E',
                ),
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Bookmark was not confirmed. Please retry.',
            '\u0938\u0939\u0947\u091C\u0928\u0947 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964 \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0915\u0930\u0947\u0902\u0964',
            '\u091C\u0924\u0928 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928 \u0915\u0930\u093E.',
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Recyclers',
      '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E',
      '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u0947',
    ),
    guide: () => ct(
      'Search or filter the directory. Tap a business for address, contacts and source authorization details. These are supplied records, not verified live buyers.',
      '\u0938\u0942\u091A\u0940 \u092E\u0947\u0902 \u0916\u094B\u091C\u0947\u0902 \u092F\u093E \u092B\u093C\u093F\u0932\u094D\u091F\u0930 \u0915\u0930\u0947\u0902\u0964 \u092A\u0924\u093E, \u0938\u0902\u092A\u0930\u094D\u0915 \u0914\u0930 \u0938\u094D\u0930\u094B\u0924 \u0905\u0928\u0941\u092E\u0924\u093F \u0935\u093F\u0935\u0930\u0923 \u0915\u0947 \u0932\u093F\u090F \u0928\u093E\u092E \u0926\u092C\u093E\u090F\u0901\u0964 \u092F\u0947 \u0926\u0940 \u0917\u0908 \u0938\u0942\u091A\u0940 \u0915\u0947 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0939\u0948\u0902, \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0938\u0915\u094D\u0930\u093F\u092F \u0916\u0930\u0940\u0926\u093E\u0930 \u0928\u0939\u0940\u0902\u0964',
      '\u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u0947\u0924 \u0936\u094B\u0927\u093E \u0915\u093F\u0902\u0935\u093E \u092B\u093F\u0932\u094D\u091F\u0930 \u0915\u0930\u093E. \u092A\u0924\u094D\u0924\u093E, \u0938\u0902\u092A\u0930\u094D\u0915 \u0935 \u0938\u094D\u0930\u094B\u0924 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0924\u092A\u0936\u0940\u0932\u093E\u0938\u093E\u0920\u0940 \u0928\u093E\u0935 \u0926\u093E\u092C\u093E. \u092F\u093E \u0926\u093F\u0932\u0947\u0932\u094D\u092F\u093E \u0928\u094B\u0902\u0926\u0940 \u0906\u0939\u0947\u0924, \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0938\u0915\u094D\u0930\u093F\u092F \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0928\u093E\u0939\u0940\u0924.',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: ct(
              'Search name or place',
              '\u0928\u093E\u092E \u092F\u093E \u091C\u0917\u0939 \u0916\u094B\u091C\u0947\u0902',
              '\u0928\u093E\u0935 \u0915\u093F\u0902\u0935\u093E \u0920\u093F\u0915\u093E\u0923 \u0936\u094B\u0927\u093E',
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
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final st in ['', 'Maharashtra', 'Punjab'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selectedColor: collectorGreen,
                    labelStyle: TextStyle(
                      color: _state == st ? Colors.white : collectorGreen,
                      fontWeight: FontWeight.w700,
                    ),
                    label: Text(
                      st.isEmpty
                          ? ct(
                              'All',
                              '\u0938\u092D\u0940',
                              '\u0938\u0930\u094D\u0935',
                            )
                          : st,
                    ),
                    selected: _state == st,
                    onSelected: (_) {
                      setState(() => _state = st);
                      AppSpeech.instance.say(
                        st.isEmpty
                            ? ct(
                                'All states',
                                '\u0938\u092D\u0940 \u0930\u093E\u091C\u094D\u092F',
                                '\u0938\u0930\u094D\u0935 \u0930\u093E\u091C\u094D\u092F\u0947',
                              )
                            : st,
                      );
                    },
                  ),
                ),
              FilterChip(
                label: Text(
                  ct(
                    'Saved',
                    '\u0938\u0939\u0947\u091C\u0947',
                    '\u091C\u0924\u0928',
                  ),
                ),
                selected: _savedOnly,
                onSelected: _loadingSaved || !_savedReady
                    ? null
                    : (v) {
                        setState(() => _savedOnly = v);
                        AppSpeech.instance.say(
                          ct(
                            'Saved filter changed',
                            '\u0938\u0939\u0947\u091C\u0947 \u0938\u0902\u092A\u0930\u094D\u0915 \u092B\u093C\u093F\u0932\u094D\u091F\u0930 \u092C\u0926\u0932\u093E',
                            '\u091C\u0924\u0928 \u0938\u0902\u092A\u0930\u094D\u0915 \u092B\u093F\u0932\u094D\u091F\u0930 \u092C\u0926\u0932\u0932\u093E',
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            ct(
              'Directory records \u2014 verify authorization before handover.',
              '\u0938\u0942\u091A\u0940 \u0915\u0947 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u2014 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0905\u0928\u0941\u092E\u0924\u093F \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
              '\u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u0947\u0924\u0940\u0932 \u0928\u094B\u0902\u0926\u0940 \u2014 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923\u093E\u0906\u0927\u0940 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0924\u092A\u093E\u0938\u093E.',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6E766D)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${filterRecyclerDirectory(query: _search.text, state: _state, savedOnly: _savedOnly, saved: _saved).length} / ${recyclerDirectoryData.length} ${ct('records', '\u0930\u093F\u0915\u0949\u0930\u094D\u0921', '\u0928\u094B\u0902\u0926\u0940')}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  openCollector(context, const RecyclerSourceNotesScreen()),
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(
                ct(
                  'Source notes',
                  '\u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u091F\u094D\u0938',
                  '\u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u0902\u0926\u0940',
                ),
              ),
            ),
          ],
        ),
        if (_message != null) note(_message!),
        if (!_loadingSaved && !_savedReady && _entryUid != null)
          TextButton(
            onPressed: () {
              AppSpeech.instance.say(
                ct(
                  'Retry saved contacts',
                  '\u0938\u0939\u0947\u091C\u0947 \u0938\u0902\u092A\u0930\u094D\u0915 \u092B\u093F\u0930 \u0916\u094B\u0932\u0947\u0902',
                  '\u091C\u0924\u0928 \u0938\u0902\u092A\u0930\u094D\u0915 \u092A\u0941\u0928\u094D\u0939\u093E \u0909\u0918\u0921\u093E',
                ),
              );
              unawaited(_load());
            },
            child: Text(
              ct(
                'Retry saved contacts',
                '\u0938\u0939\u0947\u091C\u0947 \u0938\u0902\u092A\u0930\u094D\u0915 \u092B\u093F\u0930 \u0916\u094B\u0932\u0947\u0902',
                '\u091C\u0924\u0928 \u0938\u0902\u092A\u0930\u094D\u0915 \u092A\u0941\u0928\u094D\u0939\u093E \u0909\u0918\u0921\u093E',
              ),
            ),
          ),
        RecyclerDirectoryList(
          records: filterRecyclerDirectory(
            query: _search.text,
            state: _state,
            savedOnly: _savedOnly,
            saved: _saved,
          ),
          saved: _saved,
          onOpen: (r) =>
              openCollector(context, RecyclerDirectoryDetailScreen(record: r)),
          onBookmark:
              _loadingSaved || !_savedReady || _saving || _entryUid == null
              ? null
              : _bookmark,
        ),
      ],
    ),
  );
}

/// Only a compact name/location row. Full licence/contact text is on tap.
class RecyclerDirectoryList extends StatelessWidget {
  const RecyclerDirectoryList({
    required this.records,
    required this.onOpen,
    this.saved = const {},
    this.onBookmark,
    super.key,
  });
  final List<Map<String, String>> records;
  final Set<String> saved;
  final ValueChanged<Map<String, String>> onOpen;
  final ValueChanged<Map<String, String>>? onBookmark;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (records.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            ct(
              'No matching recyclers. Try another search or filter.',
              '\u092E\u0947\u0932 \u0916\u093E\u0924\u0947 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0928\u0939\u0940\u0902\u0964 \u0926\u0942\u0938\u0930\u0940 \u0916\u094B\u091C \u092F\u093E \u092B\u093C\u093F\u0932\u094D\u091F\u0930 \u0906\u091C\u093C\u092E\u093E\u090F\u0901\u0964',
              '\u091C\u0941\u0933\u0923\u093E\u0930\u0947 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u0947 \u0928\u093E\u0939\u0940\u0924. \u0926\u0941\u0938\u0930\u093E \u0936\u094B\u0927 \u0915\u093F\u0902\u0935\u093E \u092B\u093F\u0932\u094D\u091F\u0930 \u0935\u093E\u092A\u0930\u093E.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ...records.map(
        (r) => Card(
          key: ValueKey('directory_${r['id']}'),
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5EBE4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppSpeech.instance.say(
                ct(
                  'Open recycler details',
                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0935\u093F\u0935\u0930\u0923 \u0916\u094B\u0932\u0947\u0902',
                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0924\u092A\u0936\u0940\u0932 \u0909\u0918\u0921\u093E',
                ),
              );
              onOpen(r);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFFEAF3E5),
                    child: Icon(
                      Icons.factory_outlined,
                      color: collectorGreen,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          r['state'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6D776E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: saved.contains(r['id'])
                        ? ct(
                            'Remove saved contact',
                            '\u0938\u0939\u0947\u091C\u093E \u0938\u0902\u092A\u0930\u094D\u0915 \u0939\u091F\u093E\u090F\u0901',
                            '\u091C\u0924\u0928 \u0938\u0902\u092A\u0930\u094D\u0915 \u0915\u093E\u0922\u093E',
                          )
                        : ct(
                            'Save contact',
                            '\u0938\u0902\u092A\u0930\u094D\u0915 \u0938\u0939\u0947\u091C\u0947\u0902',
                            '\u0938\u0902\u092A\u0930\u094D\u0915 \u091C\u0924\u0928 \u0915\u0930\u093E',
                          ),
                    onPressed: onBookmark == null ? null : () => onBookmark!(r),
                    icon: Icon(
                      saved.contains(r['id'])
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: collectorGreen,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF82907F),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _directoryExternal(
  BuildContext context,
  Uri uri,
  String message,
) async {
  if (!await confirmAction(context, message) || !context.mounted) return;
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
      throw StateError('no-handler');
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ct(
              'No suitable app opened. Use the displayed business details manually.',
              '\u0909\u092A\u092F\u0941\u0915\u094D\u0924 \u0910\u092A \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u093E\u0964 \u0926\u093F\u0916\u093E\u090F \u0938\u0902\u092A\u0930\u094D\u0915 \u0935\u093F\u0935\u0930\u0923 \u0938\u094D\u0935\u092F\u0902 \u0907\u0938\u094D\u0924\u0947\u092E\u093E\u0932 \u0915\u0930\u0947\u0902\u0964',
              '\u092F\u094B\u0917\u094D\u092F \u0905\u0945\u092A \u0909\u0918\u0921\u0932\u0947 \u0928\u093E\u0939\u0940. \u0926\u093E\u0916\u0935\u0932\u0947\u0932\u093E \u0938\u0902\u092A\u0930\u094D\u0915 \u0924\u092A\u0936\u0940\u0932 \u0938\u094D\u0935\u0924\u0903 \u0935\u093E\u092A\u0930\u093E.',
            ),
          ),
        ),
      );
  }
}

class RecyclerDirectoryDetailScreen extends StatelessWidget {
  const RecyclerDirectoryDetailScreen({required this.record, super.key});
  final Map<String, String> record;
  String value(String key) => record[key]?.trim().isNotEmpty == true
      ? record[key]!
      : ct(
          'Not supplied',
          '\u0928\u0939\u0940\u0902 \u0926\u093F\u092F\u093E \u0917\u092F\u093E',
          '\u0926\u093F\u0932\u0947\u0932\u093E \u0928\u093E\u0939\u0940',
        );
  Widget _field(String title, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6D776E)),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value(key),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final phone = (record['phone'] ?? '').trim(),
        email = (record['email'] ?? '').trim(),
        address = (record['address'] ?? '').trim();
    final phoneValid = RegExp(r'^\d{10}$').hasMatch(phone);
    final emailValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return CollectorPage(
      title: () => ct(
        'Recycler details',
        '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0935\u093F\u0935\u0930\u0923',
        '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0924\u092A\u0936\u0940\u0932',
      ),
      body: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFEAF3E5),
              child: Icon(
                Icons.factory_outlined,
                color: collectorGreen,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value('name'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: collectorGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(value('state')),
          const SizedBox(height: 18),
          _field(
            ct(
              'Address',
              '\u092A\u0924\u093E',
              '\u092A\u0924\u094D\u0924\u093E',
            ),
            'address',
          ),
          _field(
            ct(
              'Regional office / district (source field)',
              '\u0915\u094D\u0937\u0947\u0924\u094D\u0930\u0940\u092F \u0915\u093E\u0930\u094D\u092F\u093E\u0932\u092F / \u091C\u093F\u0932\u093E (\u0938\u094D\u0930\u094B\u0924 \u092B\u093C\u0940\u0932\u094D\u0921)',
              '\u092A\u094D\u0930\u093E\u0926\u0947\u0936\u093F\u0915 \u0915\u093E\u0930\u094D\u092F\u093E\u0932\u092F / \u091C\u093F\u0932\u094D\u0939\u093E (\u0938\u094D\u0930\u094B\u0924 \u0915\u094D\u0937\u0947\u0924\u094D\u0930)',
            ),
            'regionalOffice',
          ),
          if (address.isNotEmpty)
            actionButton(
              ct(
                'Open business address in Maps',
                'Maps \u092E\u0947\u0902 \u0935\u094D\u092F\u0935\u0938\u093E\u092F \u0915\u093E \u092A\u0924\u093E \u0916\u094B\u0932\u0947\u0902',
                'Maps \u092E\u0927\u094D\u092F\u0947 \u0935\u094D\u092F\u0935\u0938\u093E\u092F\u093E\u091A\u093E \u092A\u0924\u094D\u0924\u093E \u0909\u0918\u0921\u093E',
              ),
              () => _directoryExternal(
                context,
                Uri.https('www.google.com', '/maps/search/', {
                  'api': '1',
                  'query': '${record['name']}, $address',
                }),
                ct(
                  'Open the listed business address in external Maps? No distance or pickup promise is supplied.',
                  '\u0926\u093F\u092F\u093E \u0935\u094D\u092F\u0935\u0938\u093E\u092F \u092A\u0924\u093E \u092C\u093E\u0939\u0930\u0940 Maps \u092E\u0947\u0902 \u0916\u094B\u0932\u0947\u0902? \u0926\u0942\u0930\u0940 \u092F\u093E \u092A\u093F\u0915\u0905\u092A \u0915\u093E \u0935\u093E\u0926\u093E \u0928\u0939\u0940\u0902 \u0926\u093F\u092F\u093E \u0917\u092F\u093E \u0939\u0948\u0964',
                  '\u0926\u093F\u0932\u0947\u0932\u093E \u0935\u094D\u092F\u0935\u0938\u093E\u092F \u092A\u0924\u094D\u0924\u093E \u092C\u093E\u0939\u0947\u0930\u0940\u0932 Maps \u092E\u0927\u094D\u092F\u0947 \u0909\u0918\u0921\u093E\u092F\u091A\u093E? \u0905\u0902\u0924\u0930 \u0915\u093F\u0902\u0935\u093E \u092A\u093F\u0915\u0905\u092A\u091A\u0947 \u0935\u091A\u0928 \u0926\u093F\u0932\u0947\u0932\u0947 \u0928\u093E\u0939\u0940.',
                ),
              ),
              icon: Icons.map_outlined,
            ),
          const SizedBox(height: 16),
          _field(
            ct(
              'Phone (source)',
              '\u092B\u094B\u0928 (\u0938\u094D\u0930\u094B\u0924)',
              '\u092B\u094B\u0928 (\u0938\u094D\u0930\u094B\u0924)',
            ),
            'phone',
          ),
          if (phoneValid)
            actionButton(
              ct(
                'Open dialer',
                '\u0921\u093E\u092F\u0932\u0930 \u0916\u094B\u0932\u0947\u0902',
                '\u0921\u093E\u092F\u0932\u0930 \u0909\u0918\u0921\u093E',
              ),
              () => _directoryExternal(
                context,
                Uri(scheme: 'tel', path: '+91$phone'),
                ct(
                  'Open the listed business number in your dialer? The contact has not been independently verified.',
                  '\u0938\u0942\u091A\u0940 \u0915\u093E \u0935\u094D\u092F\u0935\u0938\u093E\u092F \u0928\u0902\u092C\u0930 \u0921\u093E\u092F\u0932\u0930 \u092E\u0947\u0902 \u0916\u094B\u0932\u0947\u0902? \u0938\u0902\u092A\u0930\u094D\u0915 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u0930\u0942\u092A \u0938\u0947 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                  '\u092F\u093E\u0926\u0940\u0924\u0940\u0932 \u0935\u094D\u092F\u0935\u0938\u093E\u092F \u0915\u094D\u0930\u092E\u093E\u0902\u0915 \u0921\u093E\u092F\u0932\u0930\u092E\u0927\u094D\u092F\u0947 \u0909\u0918\u0921\u093E\u092F\u091A\u093E? \u0938\u0902\u092A\u0930\u094D\u0915 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930\u092A\u0923\u0947 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0928\u093E\u0939\u0940.',
                ),
              ),
              icon: Icons.call_outlined,
            ),
          _field(
            ct(
              'Email (source)',
              '\u0908\u092E\u0947\u0932 (\u0938\u094D\u0930\u094B\u0924)',
              '\u0908\u092E\u0947\u0932 (\u0938\u094D\u0930\u094B\u0924)',
            ),
            'email',
          ),
          if (emailValid)
            actionButton(
              ct(
                'Open email app',
                '\u0908\u092E\u0947\u0932 \u0910\u092A \u0916\u094B\u0932\u0947\u0902',
                '\u0908\u092E\u0947\u0932 \u0905\u0945\u092A \u0909\u0918\u0921\u093E',
              ),
              () => _directoryExternal(
                context,
                Uri(scheme: 'mailto', path: email),
                ct(
                  'Open your email app with this listed address? Nothing is sent automatically.',
                  '\u0938\u0942\u091A\u0940 \u0915\u0947 \u092A\u0924\u0947 \u0915\u0947 \u0938\u093E\u0925 \u0908\u092E\u0947\u0932 \u0910\u092A \u0916\u094B\u0932\u0947\u0902? \u0905\u092A\u0928\u0947 \u0906\u092A \u0915\u0941\u091B \u0928\u0939\u0940\u0902 \u092D\u0947\u091C\u093E \u091C\u093E\u090F\u0917\u093E\u0964',
                  '\u092F\u093E\u0926\u0940\u0924\u0940\u0932 \u092A\u0924\u094D\u0924\u094D\u092F\u093E\u0938\u0939 \u0908\u092E\u0947\u0932 \u0905\u0945\u092A \u0909\u0918\u0921\u093E\u092F\u091A\u0947? \u0906\u092A\u094B\u0906\u092A \u0915\u093E\u0939\u0940 \u092A\u093E\u0920\u0935\u0932\u0947 \u091C\u093E\u0923\u093E\u0930 \u0928\u093E\u0939\u0940.',
                ),
              ),
              icon: Icons.email_outlined,
            ),
          const Divider(height: 28),
          _field(
            ct(
              'Listed type and annual capacity',
              '\u0938\u0942\u091A\u0940 \u0915\u093E \u092A\u094D\u0930\u0915\u093E\u0930 \u0914\u0930 \u0935\u093E\u0930\u094D\u0937\u093F\u0915 \u0915\u094D\u0937\u092E\u0924\u093E',
              '\u092F\u093E\u0926\u0940\u0924\u0940\u0932 \u092A\u094D\u0930\u0915\u093E\u0930 \u0935 \u0935\u093E\u0930\u094D\u0937\u093F\u0915 \u0915\u094D\u0937\u092E\u0924\u093E',
            ),
            'acceptanceText',
          ),
          note(
            ct(
              'Annual capacity is not available pickup quantity. The source does not specify which individual materials are accepted.',
              '\u0935\u093E\u0930\u094D\u0937\u093F\u0915 \u0915\u094D\u0937\u092E\u0924\u093E \u0909\u092A\u0932\u092C\u094D\u0927 \u092A\u093F\u0915\u0905\u092A \u092E\u093E\u0924\u094D\u0930\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964 \u0938\u094D\u0930\u094B\u0924 \u0905\u0932\u0917-\u0905\u0932\u0917 \u0938\u094D\u0935\u0940\u0915\u093E\u0930 \u0915\u0940 \u091C\u093E\u0928\u0947 \u0935\u093E\u0932\u0940 \u0938\u093E\u092E\u0917\u094D\u0930\u0940 \u0928\u0939\u0940\u0902 \u092C\u0924\u093E\u0924\u093E\u0964',
              '\u0935\u093E\u0930\u094D\u0937\u093F\u0915 \u0915\u094D\u0937\u092E\u0924\u093E \u092E\u094D\u0939\u0923\u091C\u0947 \u0909\u092A\u0932\u092C\u094D\u0927 \u092A\u093F\u0915\u0905\u092A \u092A\u094D\u0930\u092E\u093E\u0923 \u0928\u093E\u0939\u0940. \u0938\u094D\u0930\u094B\u0924 \u0935\u0947\u0917\u0935\u0947\u0917\u0933\u0947 \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u0932\u0947 \u091C\u093E\u0923\u093E\u0930\u0947 \u0938\u093E\u0939\u093F\u0924\u094D\u092F \u0938\u093E\u0902\u0917\u0924 \u0928\u093E\u0939\u0940.',
            ),
          ),
          _field(
            ct(
              'License / authorization references',
              '\u0932\u093E\u0907\u0938\u0947\u0902\u0938 / \u0905\u0928\u0941\u092E\u0924\u093F \u0938\u0902\u0926\u0930\u094D\u092D',
              '\u092A\u0930\u0935\u093E\u0928\u093E / \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0938\u0902\u0926\u0930\u094D\u092D',
            ),
            'authorizationReference',
          ),
          _field(
            ct(
              'Validity exactly as supplied',
              '\u0926\u0940 \u0917\u0908 \u0935\u0948\u0927\u0924\u093E',
              '\u0926\u093F\u0932\u0947\u0932\u0940 \u0935\u0948\u0927\u0924\u093E',
            ),
            'validity',
          ),
          note(
            directoryHasPastDate(record['validity'] ?? '', DateTime.now())
                ? ct(
                    'Some listed dates have passed according to this device date. Recheck current authorization with the regulator; no renewal is assumed.',
                    '\u0921\u093F\u0935\u093E\u0907\u0938 \u0915\u0940 \u0924\u093E\u0930\u0940\u0916 \u0915\u0947 \u0905\u0928\u0941\u0938\u093E\u0930 \u0915\u0941\u091B \u0926\u0940 \u0917\u0908 \u0924\u093E\u0930\u0940\u0916\u0947\u0902 \u092C\u0940\u0924 \u0917\u0908 \u0939\u0948\u0902\u0964 \u0928\u093F\u092F\u093E\u092E\u0915 \u0938\u0947 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0905\u0928\u0941\u092E\u0924\u093F \u091C\u093E\u0901\u091A\u0947\u0902; \u0928\u0935\u0940\u0928\u0940\u0915\u0930\u0923 \u092E\u093E\u0928\u093E \u0928\u0939\u0940\u0902 \u0917\u092F\u093E \u0939\u0948\u0964',
                    '\u0921\u093F\u0935\u094D\u0939\u093E\u0907\u0938\u091A\u094D\u092F\u093E \u0924\u093E\u0930\u0916\u0947\u0928\u0941\u0938\u093E\u0930 \u0915\u093E\u0939\u0940 \u0926\u093F\u0932\u0947\u0932\u094D\u092F\u093E \u0924\u093E\u0930\u0916\u093E \u0909\u0932\u091F\u0932\u094D\u092F\u093E \u0906\u0939\u0947\u0924. \u0928\u093F\u092F\u093E\u092E\u0915\u093E\u0915\u0921\u0947 \u0938\u0927\u094D\u092F\u093E\u091A\u0940 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0924\u092A\u093E\u0938\u093E; \u0928\u0942\u0924\u0928\u0940\u0915\u0930\u0923 \u0917\u0943\u0939\u0940\u0924 \u0927\u0930\u0932\u0947\u0932\u0947 \u0928\u093E\u0939\u0940.',
                  )
                : ct(
                    'Listed dates do not prove current authorization. Verify the exact license and permitted scope before handover.',
                    '\u0926\u0940 \u0917\u0908 \u0924\u093E\u0930\u0940\u0916\u0947\u0902 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0905\u0928\u0941\u092E\u0924\u093F \u0915\u093E \u092A\u094D\u0930\u092E\u093E\u0923 \u0928\u0939\u0940\u0902 \u0939\u0948\u0902\u0964 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0938\u0939\u0940 \u0932\u093E\u0907\u0938\u0947\u0902\u0938 \u0914\u0930 \u0905\u0928\u0941\u092E\u0924 \u0926\u093E\u092F\u0930\u093E \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                    '\u0926\u093F\u0932\u0947\u0932\u094D\u092F\u093E \u0924\u093E\u0930\u0916\u093E \u0938\u0927\u094D\u092F\u093E\u091A\u094D\u092F\u093E \u092A\u0930\u0935\u093E\u0928\u0917\u0940\u091A\u093E \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940\u0924. \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923\u093E\u0906\u0927\u0940 \u092F\u094B\u0917\u094D\u092F \u092A\u0930\u0935\u093E\u0928\u093E \u0935 \u0905\u0928\u0941\u092E\u0924 \u0935\u094D\u092F\u093E\u092A\u094D\u0924\u0940 \u0924\u092A\u093E\u0938\u093E.',
                  ),
          ),
          if (record['state'] == 'Punjab')
            note(
              ct(
                'Punjab source combines recyclers/refurbishers. EPR Registration: Registered is source text without a registration number or validity date here, not app verification. Contacts and numeric capacity are absent; verify with PPCB.',
                '\u092A\u0902\u091C\u093E\u092C \u0938\u094D\u0930\u094B\u0924 \u092E\u0947\u0902 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E/\u0930\u093F\u092B\u0930\u094D\u092C\u093F\u0936\u0930 \u0938\u0902\u092F\u0941\u0915\u094D\u0924 \u0939\u0948\u0902\u0964 EPR Registration: Registered \u0938\u094D\u0930\u094B\u0924 \u0915\u093E \u092A\u093E\u0920 \u0939\u0948; \u092F\u0939\u093E\u0901 \u092A\u0902\u091C\u0940\u0915\u0930\u0923 \u0928\u0902\u092C\u0930 \u092F\u093E \u0935\u0948\u0927\u0924\u093E \u0924\u093E\u0930\u0940\u0916 \u0928\u0939\u0940\u0902 \u0939\u0948, \u0910\u092A \u0938\u0924\u094D\u092F\u093E\u092A\u0928 \u0928\u0939\u0940\u0902\u0964 \u0938\u0902\u092A\u0930\u094D\u0915 \u0914\u0930 \u0938\u0902\u0916\u094D\u092F\u093E\u0924\u094D\u092E\u0915 \u0915\u094D\u0937\u092E\u0924\u093E \u0928\u0939\u0940\u0902 \u0926\u0940 \u0917\u0908; PPCB \u0938\u0947 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                '\u092A\u0902\u091C\u093E\u092C \u0938\u094D\u0930\u094B\u0924\u093E\u092E\u0927\u094D\u092F\u0947 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u0947/\u0930\u093F\u092B\u0930\u094D\u092C\u093F\u0936\u0930\u094D\u0938 \u090F\u0915\u0924\u094D\u0930 \u0906\u0939\u0947\u0924. EPR Registration: Registered \u0939\u093E \u0938\u094D\u0930\u094B\u0924 \u092E\u091C\u0915\u0942\u0930 \u0906\u0939\u0947; \u092F\u0947\u0925\u0947 \u0928\u094B\u0902\u0926\u0923\u0940 \u0915\u094D\u0930\u092E\u093E\u0902\u0915 \u0915\u093F\u0902\u0935\u093E \u0935\u0948\u0927\u0924\u093E \u0924\u093E\u0930\u0940\u0916 \u0928\u093E\u0939\u0940, \u0905\u0945\u092A \u092A\u0921\u0924\u093E\u0933\u0923\u0940 \u0928\u093E\u0939\u0940. \u0938\u0902\u092A\u0930\u094D\u0915 \u0935 \u0938\u0902\u0916\u094D\u092F\u093E\u0924\u094D\u092E\u0915 \u0915\u094D\u0937\u092E\u0924\u093E \u0928\u093E\u0939\u0940; PPCB \u0915\u0921\u0947 \u0924\u092A\u093E\u0938\u093E.',
              ),
            ),
          note(
            ct(
              'Directory entry only \u2014 not a verified app account, active buying request or guaranteed pickup.',
              '\u0915\u0947\u0935\u0932 \u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u093E \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F \u2014 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0910\u092A \u0916\u093E\u0924\u093E, \u0938\u0915\u094D\u0930\u093F\u092F \u0916\u0930\u0940\u0926 \u092E\u093E\u0901\u0917 \u092F\u093E \u092A\u093F\u0915\u0905\u092A \u0915\u0940 \u0917\u093E\u0930\u0902\u091F\u0940 \u0928\u0939\u0940\u0902\u0964',
              '\u092B\u0915\u094D\u0924 \u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u0947\u0924\u0940\u0932 \u0928\u094B\u0902\u0926 \u2014 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0905\u0945\u092A \u0916\u093E\u0924\u0947, \u0938\u0915\u094D\u0930\u093F\u092F \u0916\u0930\u0947\u0926\u0940 \u092E\u093E\u0917\u0923\u0940 \u0915\u093F\u0902\u0935\u093E \u092A\u093F\u0915\u0905\u092A\u091A\u0940 \u0939\u092E\u0940 \u0928\u093E\u0939\u0940.',
            ),
          ),
          TextButton(
            onPressed: () =>
                openCollector(context, const RecyclerSourceNotesScreen()),
            child: Text(
              ct(
                'Read source notes',
                '\u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u091F\u094D\u0938 \u092A\u0922\u093C\u0947\u0902',
                '\u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u0902\u0926\u0940 \u0935\u093E\u091A\u093E',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecyclerSourceNotesScreen extends StatelessWidget {
  const RecyclerSourceNotesScreen({super.key});
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Directory source notes',
      '\u0938\u0942\u091A\u0940 \u0915\u0947 \u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u091F\u094D\u0938',
      '\u0928\u093F\u0930\u094D\u0926\u0947\u0936\u093F\u0915\u0947\u091A\u094D\u092F\u093E \u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u0902\u0926\u0940',
    ),
    body: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        note(
          ct(
            '49 supplied rows: 41 Maharashtra, 8 Punjab. Source notes below are preserved in their original English. Not independently re-verified. Similar names/sites are not silently merged.',
            '49 \u0926\u0940 \u0917\u0908 \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F\u092F\u093E\u0901: 41 \u092E\u0939\u093E\u0930\u093E\u0937\u094D\u091F\u094D\u0930, 8 \u092A\u0902\u091C\u093E\u092C\u0964 \u0928\u0940\u091A\u0947 \u0938\u094D\u0930\u094B\u0924 \u0915\u0947 \u092E\u0942\u0932 \u0905\u0902\u0917\u094D\u0930\u0947\u091C\u093C\u0940 \u0928\u094B\u091F\u094D\u0938 \u0939\u0948\u0902\u0964 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u091C\u093E\u0901\u091A \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964 \u092E\u093F\u0932\u0924\u0947 \u0928\u093E\u092E/\u0938\u094D\u0925\u0932 \u0905\u092A\u0928\u0947 \u0906\u092A \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E\u090F \u0917\u090F\u0964',
            '49 \u0926\u093F\u0932\u0947\u0932\u094D\u092F\u093E \u0928\u094B\u0902\u0926\u0940: 41 \u092E\u0939\u093E\u0930\u093E\u0937\u094D\u091F\u094D\u0930, 8 \u092A\u0902\u091C\u093E\u092C. \u0916\u093E\u0932\u0940 \u092E\u0942\u0933 \u0907\u0902\u0917\u094D\u0930\u091C\u0940 \u0938\u094D\u0930\u094B\u0924 \u0928\u094B\u0902\u0926\u0940 \u0906\u0939\u0947\u0924. \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u092A\u0921\u0924\u093E\u0933\u0923\u0940 \u0915\u0947\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940. \u0938\u092E\u093E\u0928 \u0928\u093E\u0935\u0947/\u0938\u094D\u0925\u0933\u0947 \u0906\u092A\u094B\u0906\u092A \u090F\u0915\u0924\u094D\u0930 \u0915\u0947\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940\u0924.',
          ),
        ),
        ...recyclerDirectoryNotes.map(
          (text) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(text),
          ),
        ),
      ],
    ),
  );
}

class PricesScreen extends StatefulWidget {
  const PricesScreen({super.key});
  @override
  State<PricesScreen> createState() => _PricesState();
}

class _PricesState extends State<PricesScreen> {
  String _city = 'Ludhiana', _material = 'Copper';
  final _kg = TextEditingController(text: '1');
  late final Future<Map<String, dynamic>> _data = rootBundle
      .loadString('assets/data/price_dataset.json')
      .then((s) => Map<String, dynamic>.from(jsonDecode(s) as Map));
  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Reference prices',
      '\u0938\u0902\u0926\u0930\u094D\u092D \u092D\u093E\u0935',
      '\u0938\u0902\u0926\u0930\u094D\u092D \u0926\u0930',
    ),
    guide: () => ct(
      'These are dated INR-per-kilogram references, not live buyer offers or guaranteed sale values. Check the source date.',
      '\u092F\u0947 \u0924\u093E\u0930\u0940\u0916 \u0935\u093E\u0932\u0947 \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u0938\u0902\u0926\u0930\u094D\u092D \u0939\u0948\u0902, \u0932\u093E\u0907\u0935 \u0916\u0930\u0940\u0926\u093E\u0930 \u0911\u092B\u0930 \u092F\u093E \u092C\u093F\u0915\u094D\u0930\u0940 \u0915\u0940 \u0917\u093E\u0930\u0902\u091F\u0940 \u0928\u0939\u0940\u0902\u0964 \u0938\u094D\u0930\u094B\u0924 \u0915\u0940 \u0924\u093E\u0930\u0940\u0916 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
      '\u0939\u0947 \u0924\u093E\u0930\u0940\u0916 \u0905\u0938\u0932\u0947\u0932\u0947 \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u0938\u0902\u0926\u0930\u094D\u092D \u0906\u0939\u0947\u0924, \u0925\u0947\u091F \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0911\u092B\u0930 \u0915\u093F\u0902\u0935\u093E \u0935\u093F\u0915\u094D\u0930\u0940\u091A\u0940 \u0939\u092E\u0940 \u0928\u093E\u0939\u0940. \u0938\u094D\u0930\u094B\u0924 \u0924\u093E\u0930\u0940\u0916 \u0924\u092A\u093E\u0938\u093E.',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _city,
          isExpanded: true,
          items: collectorCities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _city = v);
              AppSpeech.instance.say(v);
            }
          },
        ),
        MaterialPhotoGrid(
          labelFor: materialLabel,
          selected: _material,
          onSelected: (m) {
            setState(() => _material = m);
            AppSpeech.instance.say(materialLabel(m));
          },
        ),
        TextField(
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: ct(
              'Weight for reference calculation (kg)',
              '\u0938\u0902\u0926\u0930\u094D\u092D \u0917\u0923\u0928\u093E \u0915\u093E \u0935\u091C\u0928 (\u0915\u093F\u0932\u094B)',
              '\u0938\u0902\u0926\u0930\u094D\u092D \u0917\u0923\u0928\u0947\u0938\u093E\u0920\u0940 \u0935\u091C\u0928 (\u0915\u093F\u0932\u094B)',
            ),
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, s) {
            if (s.hasError) {
              return note(
                ct(
                  'Price asset could not load. Check assets/data/price_dataset.json and pubspec.',
                  '\u092D\u093E\u0935 \u0915\u0940 \u092B\u093C\u093E\u0907\u0932 \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u0940\u0964 JSON \u0914\u0930 pubspec \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                  '\u0926\u0930 \u092B\u093E\u0907\u0932 \u0909\u0918\u0921\u0932\u0940 \u0928\u093E\u0939\u0940. JSON \u0935 pubspec \u0924\u092A\u093E\u0938\u093E.',
                ),
              );
            }
            if (!s.hasData) return const LinearProgressIndicator();
            final latest = s.data!['latest_prices'];
            final entry = latest is Map && latest[_material] is Map
                ? (latest[_material] as Map)[_city]
                : null;
            if (entry is! Map) {
              return note(
                ct(
                  'No matching rate.',
                  '\u092E\u0947\u0932 \u0916\u093E\u0924\u093E \u092D\u093E\u0935 \u0928\u0939\u0940\u0902\u0964',
                  '\u091C\u0941\u0933\u0923\u093E\u0930\u093E \u0926\u0930 \u0928\u093E\u0939\u0940.',
                ),
              );
            }
            final kg = double.tryParse(_kg.text.trim());
            final price = entry['price'];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('\u20B9${entry['price']} / kg'),
                note(
                  '${ct('Dataset date', '\u0921\u0947\u091F\u093E\u0938\u0947\u091F \u0924\u093F\u0925\u093F', '\u0921\u0947\u091F\u093E\u0938\u0947\u091F \u0924\u093E\u0930\u0940\u0916')}: ${entry['date']} (DD-MM-YYYY)',
                ),
                note(
                  '${ct('Source range', '\u0938\u094D\u0930\u094B\u0924 \u0938\u0940\u092E\u093E', '\u0938\u094D\u0930\u094B\u0924 \u092E\u0930\u094D\u092F\u093E\u0926\u093E')}: \u20B9${entry['low']} \u2013 \u20B9${entry['high']} / kg',
                ),
                if (CollectorStore.validWeight(kg) &&
                    price is num &&
                    price.isFinite &&
                    price > 0)
                  section(
                    '${ct('Reference multiplication', '\u0938\u0902\u0926\u0930\u094D\u092D \u0917\u0941\u0923\u093E', '\u0938\u0902\u0926\u0930\u094D\u092D \u0917\u0941\u0923\u093E\u0915\u093E\u0930')}: \u20B9${(price * kg!).toStringAsFixed(2)}',
                  ),
                note(
                  ct(
                    'Currency confirmed as INR/kg for this dataset. Independent market provenance is not verified. Low/high ranges and totals are dated references, not guaranteed sale prices.',
                    '\u0907\u0938 \u0921\u0947\u091F\u093E\u0938\u0947\u091F \u0915\u0940 \u092E\u0941\u0926\u094D\u0930\u093E \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u092A\u0941\u0937\u094D\u091F \u0939\u0948\u0964 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u092C\u093E\u091C\u093C\u093E\u0930 \u0938\u094D\u0930\u094B\u0924 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964 \u0915\u092E/\u0905\u0927\u093F\u0915 \u0938\u0940\u092E\u093E \u0914\u0930 \u0915\u0941\u0932 \u0924\u093E\u0930\u0940\u0916 \u0935\u093E\u0932\u0947 \u0938\u0902\u0926\u0930\u094D\u092D \u0939\u0948\u0902, \u092C\u093F\u0915\u094D\u0930\u0940 \u0915\u0940 \u0917\u093E\u0930\u0902\u091F\u0940 \u0928\u0939\u0940\u0902\u0964',
                    '\u092F\u093E \u0921\u0947\u091F\u093E\u0938\u0947\u091F\u091A\u0947 \u091A\u0932\u0928 \u0930\u0941\u092A\u092F\u0947 \u092A\u094D\u0930\u0924\u093F \u0915\u093F\u0932\u094B \u092A\u0941\u0937\u094D\u091F \u0906\u0939\u0947. \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u092C\u093E\u091C\u093E\u0930 \u0938\u094D\u0930\u094B\u0924 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0928\u093E\u0939\u0940. \u0915\u092E\u0940/\u091C\u093E\u0938\u094D\u0924 \u092E\u0930\u094D\u092F\u093E\u0926\u093E \u0935 \u092C\u0947\u0930\u0940\u091C \u0924\u093E\u0930\u0940\u0916 \u0905\u0938\u0932\u0947\u0932\u0947 \u0938\u0902\u0926\u0930\u094D\u092D \u0906\u0939\u0947\u0924, \u0935\u093F\u0915\u094D\u0930\u0940\u091A\u0940 \u0939\u092E\u0940 \u0928\u093E\u0939\u0940.',
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  final _name = TextEditingController(),
      _mobile = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _loaded = false, _busy = false;
  String? _message;
  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final mobile = QuickProfileService.normalizeContactMobile(_mobile.text);
    final name = _name.text.trim();
    if (mobile == null || name.length < 2 || name.length > 100) {
      setState(
        () => _message = ct(
          'Check name and Indian mobile contact.',
          '\u0928\u093E\u092E \u0914\u0930 \u092D\u093E\u0930\u0924\u0940\u092F \u092E\u094B\u092C\u093E\u0907\u0932 \u0938\u0902\u092A\u0930\u094D\u0915 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
          '\u0928\u093E\u0935 \u0935 \u092D\u093E\u0930\u0924\u0940\u092F \u092E\u094B\u092C\u093E\u0907\u0932 \u0938\u0902\u092A\u0930\u094D\u0915 \u0924\u092A\u093E\u0938\u093E.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final u = FirebaseAuth.instance.currentUser!;
      final ref = _cs.dbCloud.collection('users').doc(u.uid);
      await _cs.dbCloud
          .runTransaction((t) async {
            final s = await t.get(ref);
            if (!s.exists) throw StateError('profile-missing');
            t.update(ref, {
              'name': name,
              'mobileNumber': mobile,
              'mobileVerified': false,
              'language': appLanguage.code,
              if (u.email != null) 'email': u.email,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 25));
      await appLanguage.save();
      if (mounted) {
        setState(
          () => _message = ct(
            'Profile saved. Role and UID unchanged.',
            '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0938\u0939\u0947\u091C\u0940\u0964 \u092D\u0942\u092E\u093F\u0915\u093E \u0914\u0930 UID \u0928\u0939\u0940\u0902 \u092C\u0926\u0932\u0947\u0964',
            '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u091C\u0924\u0928. \u092D\u0942\u092E\u093F\u0915\u093E \u0935 UID \u092C\u0926\u0932\u0932\u0947 \u0928\u093E\u0939\u0940\u0924.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.length < 8) {
      setState(
        () => _message = ct(
          'Enter your own email and a password of at least 8 characters.',
          '\u0905\u092A\u0928\u093E \u0908\u092E\u0947\u0932 \u0914\u0930 \u0915\u092E \u0938\u0947 \u0915\u092E 8 \u0905\u0915\u094D\u0937\u0930\u094B\u0902 \u0915\u093E \u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0932\u093F\u0916\u0947\u0902\u0964',
          '\u0938\u094D\u0935\u0924\u0903\u091A\u093E \u0908\u092E\u0947\u0932 \u0935 \u0915\u093F\u092E\u093E\u0928 8 \u0905\u0915\u094D\u0937\u0930\u093E\u0902\u091A\u093E \u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0932\u093F\u0939\u093E.',
        ),
      );
      return;
    }
    if (!await confirmAction(
          context,
          ct(
            'Link your own email/password to THIS guest account? The same UID and records will be preserved. An email already linked to another account will not be merged.',
            '\u0907\u0938\u0940 \u0917\u0947\u0938\u094D\u091F \u0916\u093E\u0924\u0947 \u0938\u0947 \u0905\u092A\u0928\u093E \u0908\u092E\u0947\u0932/\u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u091C\u094B\u0921\u093C\u0947\u0902? UID \u0914\u0930 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0935\u0939\u0940 \u0930\u0939\u0947\u0902\u0917\u0947\u0964 \u0926\u0942\u0938\u0930\u0947 \u0916\u093E\u0924\u0947 \u0935\u093E\u0932\u093E \u0908\u092E\u0947\u0932 \u092E\u093F\u0932\u093E\u092F\u093E \u0928\u0939\u0940\u0902 \u091C\u093E\u090F\u0917\u093E\u0964',
            '\u092F\u093E\u091A \u0917\u0947\u0938\u094D\u091F \u0916\u093E\u0924\u094D\u092F\u093E\u0932\u093E \u0938\u094D\u0935\u0924\u0903\u091A\u093E \u0908\u092E\u0947\u0932/\u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u091C\u094B\u0921\u093E\u092F\u091A\u093E? UID \u0935 \u0928\u094B\u0902\u0926\u0940 \u0924\u094D\u092F\u093E\u091A \u0930\u093E\u0939\u0924\u0940\u0932. \u0926\u0941\u0938\u0931\u094D\u092F\u093E \u0916\u093E\u0924\u094D\u092F\u093E\u091A\u093E \u0908\u092E\u0947\u0932 \u090F\u0915\u0924\u094D\u0930 \u0939\u094B\u0923\u093E\u0930 \u0928\u093E\u0939\u0940.',
          ),
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final u = FirebaseAuth.instance.currentUser!;
      if (!u.isAnonymous) throw StateError('already-linked');
      final result = await u.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: _password.text),
      );
      _password.clear();
      if (result.user?.uid != u.uid) throw StateError('uid-changed');
      await result.user!.getIdToken(true);
      await _cs.dbCloud
          .collection('users')
          .doc(u.uid)
          .update({
            'email': result.user!.email,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 25));
      if (mounted) {
        setState(
          () => _message = ct(
            'Recovery linked to the same account. Use Email recovery from registration on a new installation.',
            '\u0907\u0938\u0940 \u0916\u093E\u0924\u0947 \u0938\u0947 \u0930\u093F\u0915\u0935\u0930\u0940 \u091C\u0941\u0921\u093C\u0940\u0964 \u0928\u090F \u0907\u0902\u0938\u094D\u091F\u0949\u0932\u0947\u0936\u0928 \u092A\u0930 \u092A\u0902\u091C\u0940\u0915\u0930\u0923 \u0938\u0947 \u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u0930\u0940 \u0916\u094B\u0932\u0947\u0902\u0964',
            '\u092F\u093E\u091A \u0916\u093E\u0924\u094D\u092F\u093E\u0932\u093E \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u091C\u094B\u0921\u0932\u0940. \u0928\u0935\u0940\u0928 \u0907\u0902\u0938\u094D\u091F\u0949\u0932\u0947\u0936\u0928\u0935\u0930 \u0928\u094B\u0902\u0926\u0923\u0940\u0924\u0942\u0928 \u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u0909\u0918\u0921\u093E.',
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _message =
              '${ct('Link not fully confirmed; account was not switched. Check current sign-in status before retrying.', '\u0932\u093F\u0902\u0915 \u092A\u0942\u0930\u0940 \u0924\u0930\u0939 \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902; \u0916\u093E\u0924\u093E \u092C\u0926\u0932\u093E \u0928\u0939\u0940\u0902\u0964 \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0938\u093E\u0907\u0928-\u0907\u0928 \u0926\u0947\u0916\u0947\u0902\u0964', '\u0932\u093F\u0902\u0915 \u092A\u0942\u0930\u094D\u0923 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940; \u0916\u093E\u0924\u0947 \u092C\u0926\u0932\u0932\u0947 \u0928\u093E\u0939\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928\u093E\u092A\u0942\u0930\u094D\u0935\u0940 \u0938\u0927\u094D\u092F\u093E\u091A\u0947 \u0938\u093E\u0907\u0928 \u0907\u0928 \u092A\u0939\u093E.')} (${e.code})',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = ct(
            'Link/profile update not fully confirmed. If already linked, do not relink: use Save profile to repair metadata.',
            '\u0932\u093F\u0902\u0915/\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0905\u092A\u0921\u0947\u091F \u092A\u0942\u0930\u0940 \u0924\u0930\u0939 \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902\u0964 \u092A\u0939\u0932\u0947 \u0938\u0947 \u0932\u093F\u0902\u0915 \u0939\u0948 \u0924\u094B \u092B\u093F\u0930 \u0932\u093F\u0902\u0915 \u0928 \u0915\u0930\u0947\u0902; \u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0938\u0939\u0947\u091C\u0915\u0930 \u0935\u093F\u0935\u0930\u0923 \u0920\u0940\u0915 \u0915\u0930\u0947\u0902\u0964',
            '\u0932\u093F\u0902\u0915/\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u0905\u092A\u0921\u0947\u091F \u092A\u0942\u0930\u094D\u0923 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940. \u0906\u0927\u0940\u091A \u0932\u093F\u0902\u0915 \u0905\u0938\u0932\u094D\u092F\u093E\u0938 \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u093F\u0902\u0915 \u0915\u0930\u0942 \u0928\u0915\u093E; \u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u091C\u0924\u0928 \u0915\u0930\u0942\u0928 \u0924\u092A\u0936\u0940\u0932 \u0926\u0941\u0930\u0941\u0938\u094D\u0924 \u0915\u0930\u093E.',
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
      'Profile & recovery',
      '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0914\u0930 \u0930\u093F\u0915\u0935\u0930\u0940',
      '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u0935 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940',
    ),
    guide: () => ct(
      'Your UID keeps records together. Mobile is an unverified contact. Optionally link your own email for recovery before changing phones or clearing storage.',
      'UID \u0938\u0947 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u091C\u0941\u0921\u093C\u0947 \u0930\u0939\u0924\u0947 \u0939\u0948\u0902\u0964 \u092E\u094B\u092C\u093E\u0907\u0932 \u0905\u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0938\u0902\u092A\u0930\u094D\u0915 \u0939\u0948\u0964 \u092B\u094B\u0928 \u092C\u0926\u0932\u0928\u0947 \u092F\u093E \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u092E\u093F\u091F\u093E\u0928\u0947 \u0938\u0947 \u092A\u0939\u0932\u0947 \u091A\u093E\u0939\u0947\u0902 \u0924\u094B \u0905\u092A\u0928\u093E \u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u0930\u0940 \u0915\u0947 \u0932\u093F\u090F \u091C\u094B\u0921\u093C\u0947\u0902\u0964',
      'UID \u092E\u0941\u0933\u0947 \u0928\u094B\u0902\u0926\u0940 \u091C\u094B\u0921\u0932\u0947\u0932\u094D\u092F\u093E \u0930\u093E\u0939\u0924\u093E\u0924. \u092E\u094B\u092C\u093E\u0907\u0932 \u0905\u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u0938\u0902\u092A\u0930\u094D\u0915 \u0906\u0939\u0947. \u092B\u094B\u0928 \u092C\u0926\u0932\u0923\u094D\u092F\u093E\u092A\u0942\u0930\u094D\u0935\u0940 \u0915\u093F\u0902\u0935\u093E \u0938\u094D\u091F\u094B\u0930\u0947\u091C \u092A\u0941\u0938\u0923\u094D\u092F\u093E\u092A\u0942\u0930\u094D\u0935\u0940 \u0939\u0935\u0947 \u0905\u0938\u0932\u094D\u092F\u093E\u0938 \u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940\u0938\u093E\u0920\u0940 \u091C\u094B\u0921\u093E.',
    ),
    body: (context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _cs.dbCloud.collection('users').doc(_cs.uid).snapshots(),
      builder: (context, s) {
        if (s.hasError) return note(friendlyError(s.error!));
        if (!s.hasData) return const LinearProgressIndicator();
        final v = s.data!.data();
        if (v == null) {
          return note(
            ct(
              'Profile missing. Do not create another UID.',
              '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u0940\u0964 \u0928\u092F\u093E UID \u0928 \u092C\u0928\u093E\u090F\u0901\u0964',
              '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u0928\u093E\u0939\u0940. \u0928\u0935\u0940\u0928 UID \u092C\u0928\u0935\u0942 \u0928\u0915\u093E.',
            ),
          );
        }
        if (!_loaded) {
          _name.text = '${v['name'] ?? ''}';
          _mobile.text = '${v['mobileNumber'] ?? ''}';
          _loaded = true;
        }
        final u = FirebaseAuth.instance.currentUser!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: ct(
                  'Name',
                  '\u0928\u093E\u092E',
                  '\u0928\u093E\u0935',
                ),
              ),
            ),
            TextField(
              controller: _mobile,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: ct(
                  'Unverified mobile contact',
                  '\u0905\u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u092E\u094B\u092C\u093E\u0907\u0932 \u0938\u0902\u092A\u0930\u094D\u0915',
                  '\u0905\u092A\u094D\u0930\u092E\u093E\u0923\u093F\u0924 \u092E\u094B\u092C\u093E\u0907\u0932 \u0938\u0902\u092A\u0930\u094D\u0915',
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: appLanguage.code,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(
                  value: 'hi',
                  child: Text('\u0939\u093F\u0902\u0926\u0940'),
                ),
                DropdownMenuItem(
                  value: 'mr',
                  child: Text('\u092E\u0930\u093E\u0920\u0940'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      appLanguage.select(v!);
                      setState(() {});
                      AppSpeech.instance.say(
                        ct(
                          'Language selected; save profile.',
                          '\u092D\u093E\u0937\u093E \u091A\u0941\u0928\u0940; \u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0938\u0939\u0947\u091C\u0947\u0902\u0964',
                          '\u092D\u093E\u0937\u093E \u0928\u093F\u0935\u0921\u0932\u0940; \u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u091C\u0924\u0928 \u0915\u0930\u093E.',
                        ),
                      );
                    },
            ),
            actionButton(
              ct(
                'Save profile',
                '\u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932 \u0938\u0939\u0947\u091C\u0947\u0902',
                '\u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932 \u091C\u0924\u0928 \u0915\u0930\u093E',
              ),
              _busy ? null : _save,
              icon: Icons.save_outlined,
            ),
            section(
              u.isAnonymous
                  ? ct(
                      'Guest: recovery not linked',
                      '\u0917\u0947\u0938\u094D\u091F: \u0930\u093F\u0915\u0935\u0930\u0940 \u0928\u0939\u0940\u0902 \u091C\u0941\u0921\u093C\u0940',
                      '\u0917\u0947\u0938\u094D\u091F: \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u091C\u094B\u0921\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940',
                    )
                  : ct(
                      'Existing linked account',
                      '\u092E\u094C\u091C\u0942\u0926\u093E \u0932\u093F\u0902\u0915 \u0916\u093E\u0924\u093E',
                      '\u0938\u0927\u094D\u092F\u093E\u091A\u0947 \u0932\u093F\u0902\u0915 \u0916\u093E\u0924\u0947',
                    ),
            ),
            if (u.isAnonymous) ...[
              note(
                ct(
                  'Optional email recovery, not mobile OTP. Enable Email/Password in Firebase first. Passwords are handled by Firebase Auth, not stored in profile/local drafts.',
                  '\u0935\u0948\u0915\u0932\u094D\u092A\u093F\u0915 \u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u0930\u0940, \u092E\u094B\u092C\u093E\u0907\u0932 OTP \u0928\u0939\u0940\u0902\u0964 \u092A\u0939\u0932\u0947 Firebase \u092E\u0947\u0902 Email/Password \u0938\u0915\u094D\u0937\u092E \u0915\u0930\u0947\u0902\u0964 \u092A\u093E\u0938\u0935\u0930\u094D\u0921 Firebase Auth \u0938\u0902\u092D\u093E\u0932\u0947\u0917\u093E; \u092A\u094D\u0930\u094B\u092B\u093C\u093E\u0907\u0932/\u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0921\u094D\u0930\u093E\u092B\u094D\u091F \u092E\u0947\u0902 \u0928\u0939\u0940\u0902 \u0938\u0939\u0947\u091C\u0924\u0947\u0964',
                  '\u092A\u0930\u094D\u092F\u093E\u092F\u0940 \u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940, \u092E\u094B\u092C\u093E\u0907\u0932 OTP \u0928\u093E\u0939\u0940. \u0906\u0927\u0940 Firebase \u092E\u0927\u094D\u092F\u0947 Email/Password \u0938\u0915\u094D\u0937\u092E \u0915\u0930\u093E. \u092A\u093E\u0938\u0935\u0930\u094D\u0921 Firebase Auth \u0939\u093E\u0924\u093E\u0933\u0947\u0932; \u092A\u094D\u0930\u094B\u092B\u093E\u0907\u0932/\u0938\u094D\u0925\u093E\u0928\u093F\u0915 \u0921\u094D\u0930\u093E\u092B\u094D\u091F\u092E\u0927\u094D\u092F\u0947 \u0938\u093E\u0920\u0935\u0924 \u0928\u093E\u0939\u0940.',
                ),
              ),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: ct(
                    'Your own email',
                    '\u0905\u092A\u0928\u093E \u0908\u092E\u0947\u0932',
                    '\u0938\u094D\u0935\u0924\u0903\u091A\u093E \u0908\u092E\u0947\u0932',
                  ),
                ),
              ),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: ct(
                    'New recovery password',
                    '\u0928\u092F\u093E \u0930\u093F\u0915\u0935\u0930\u0940 \u092A\u093E\u0938\u0935\u0930\u094D\u0921',
                    '\u0928\u0935\u0940\u0928 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u092A\u093E\u0938\u0935\u0930\u094D\u0921',
                  ),
                ),
              ),
              actionButton(
                ct(
                  'Link recovery to this account',
                  '\u0907\u0938\u0940 \u0916\u093E\u0924\u0947 \u0938\u0947 \u0930\u093F\u0915\u0935\u0930\u0940 \u091C\u094B\u0921\u093C\u0947\u0902',
                  '\u092F\u093E\u091A \u0916\u093E\u0924\u094D\u092F\u093E\u0932\u093E \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u091C\u094B\u0921\u093E',
                ),
                _busy ? null : _link,
                icon: Icons.lock_outline,
              ),
            ] else
              note(
                ct(
                  'A typed mobile number still does not identify/recover the account. Use the linked authentication method. No account-switch or sign-out button is exposed here.',
                  '\u091F\u093E\u0907\u092A \u0915\u093F\u092F\u093E \u092E\u094B\u092C\u093E\u0907\u0932 \u0905\u092C \u092D\u0940 \u092A\u0939\u091A\u093E\u0928/\u0930\u093F\u0915\u0935\u0930\u0940 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964 \u091C\u0941\u0921\u093C\u093E \u092A\u094D\u0930\u092E\u093E\u0923\u0940\u0915\u0930\u0923 \u0924\u0930\u0940\u0915\u093E \u0907\u0938\u094D\u0924\u0947\u092E\u093E\u0932 \u0915\u0930\u0947\u0902\u0964 \u092F\u0939\u093E\u0901 \u0916\u093E\u0924\u093E \u092C\u0926\u0932\u0928\u0947 \u092F\u093E \u0938\u093E\u0907\u0928 \u0906\u0909\u091F \u0915\u093E \u092C\u091F\u0928 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                  '\u091F\u093E\u0907\u092A \u0915\u0947\u0932\u0947\u0932\u093E \u092E\u094B\u092C\u093E\u0907\u0932 \u0905\u0926\u094D\u092F\u093E\u092A \u0913\u0933\u0916/\u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u0928\u093E\u0939\u0940. \u091C\u094B\u0921\u0932\u0947\u0932\u0940 \u092A\u094D\u0930\u092E\u093E\u0923\u0940\u0915\u0930\u0923 \u092A\u0926\u094D\u0927\u0924 \u0935\u093E\u092A\u0930\u093E. \u092F\u0947\u0925\u0947 \u0916\u093E\u0924\u0947 \u092C\u0926\u0932\u0923\u094D\u092F\u093E\u091A\u0947 \u0915\u093F\u0902\u0935\u093E \u0938\u093E\u0907\u0928 \u0906\u0909\u091F\u091A\u0947 \u092C\u091F\u0923 \u0928\u093E\u0939\u0940.',
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) SpokenNotice(text: _message!),
          ],
        );
      },
    ),
  );
}

class RecoveryLoginScreen extends StatefulWidget {
  const RecoveryLoginScreen({super.key});
  @override
  State<RecoveryLoginScreen> createState() => _RecoveryState();
}

class _RecoveryState extends State<RecoveryLoginScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(bool reset) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (reset) {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _email.text.trim(),
        );
        if (mounted) {
          setState(
            () => _message = ct(
              'If this address has an eligible account, check its inbox and spam folder.',
              '\u0907\u0938 \u092A\u0924\u0947 \u0915\u093E \u092F\u094B\u0917\u094D\u092F \u0916\u093E\u0924\u093E \u0939\u0948 \u0924\u094B \u0907\u0928\u092C\u0949\u0915\u094D\u0938 \u0914\u0930 \u0938\u094D\u092A\u0948\u092E \u0926\u0947\u0916\u0947\u0902\u0964',
              '\u092F\u093E \u092A\u0924\u094D\u0924\u094D\u092F\u093E\u091A\u0947 \u092A\u093E\u0924\u094D\u0930 \u0916\u093E\u0924\u0947 \u0905\u0938\u0932\u094D\u092F\u093E\u0938 \u0907\u0928\u092C\u0949\u0915\u094D\u0938 \u0935 \u0938\u094D\u092A\u0945\u092E \u092A\u0939\u093E.',
            ),
          );
        }
      } else {
        if (FirebaseAuth.instance.currentUser != null) {
          throw StateError('already-signed-in-no-switch');
        }
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        _password.clear();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const CollectorSessionGate(onboarding: LanguageScreen()),
            ),
            (_) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = ct(
            'Recovery not confirmed. Check credentials/provider/network. Existing signed-in accounts will not be switched.',
            '\u0930\u093F\u0915\u0935\u0930\u0940 \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902\u0964 \u0935\u093F\u0935\u0930\u0923/\u092A\u094D\u0930\u094B\u0935\u093E\u0907\u0921\u0930/\u0907\u0902\u091F\u0930\u0928\u0947\u091F \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u092E\u094C\u091C\u0942\u0926\u093E \u0938\u093E\u0907\u0928-\u0907\u0928 \u0916\u093E\u0924\u093E \u092C\u0926\u0932\u093E \u0928\u0939\u0940\u0902 \u091C\u093E\u090F\u0917\u093E\u0964',
            '\u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940. \u0924\u092A\u0936\u0940\u0932/\u092A\u094D\u0930\u094B\u0935\u093E\u0907\u0921\u0930/\u0907\u0902\u091F\u0930\u0928\u0947\u091F \u0924\u092A\u093E\u0938\u093E. \u0938\u0927\u094D\u092F\u093E\u091A\u0947 \u0938\u093E\u0907\u0928 \u0907\u0928 \u0916\u093E\u0924\u0947 \u092C\u0926\u0932\u0932\u0947 \u091C\u093E\u0923\u093E\u0930 \u0928\u093E\u0939\u0940.',
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
      'Email recovery',
      '\u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u0930\u0940',
      '\u0908\u092E\u0947\u0932 \u0930\u093F\u0915\u0935\u094D\u0939\u0930\u0940',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        note(
          ct(
            'Only for an account previously linked to email/password. This does not create a new account. Never share passwords or OTPs.',
            '\u0915\u0947\u0935\u0932 \u092A\u0939\u0932\u0947 \u0938\u0947 \u0908\u092E\u0947\u0932/\u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0938\u0947 \u091C\u0941\u0921\u093C\u0947 \u0916\u093E\u0924\u0947 \u0915\u0947 \u0932\u093F\u090F\u0964 \u0928\u092F\u093E \u0916\u093E\u0924\u093E \u0928\u0939\u0940\u0902 \u092C\u0928\u0947\u0917\u093E\u0964 \u092A\u093E\u0938\u0935\u0930\u094D\u0921/OTP \u0938\u093E\u091D\u093E \u0928 \u0915\u0930\u0947\u0902\u0964',
            '\u092B\u0915\u094D\u0924 \u0906\u0927\u0940 \u0908\u092E\u0947\u0932/\u092A\u093E\u0938\u0935\u0930\u094D\u0921\u0932\u093E \u091C\u094B\u0921\u0932\u0947\u0932\u094D\u092F\u093E \u0916\u093E\u0924\u094D\u092F\u093E\u0938\u093E\u0920\u0940. \u0928\u0935\u0940\u0928 \u0916\u093E\u0924\u0947 \u0924\u092F\u093E\u0930 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940. \u092A\u093E\u0938\u0935\u0930\u094D\u0921/OTP \u0936\u0947\u0905\u0930 \u0915\u0930\u0942 \u0928\u0915\u093E.',
          ),
        ),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: ct(
              'Email',
              '\u0908\u092E\u0947\u0932',
              '\u0908\u092E\u0947\u0932',
            ),
          ),
        ),
        TextField(
          controller: _password,
          enabled: !_busy,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: ct(
              'Password',
              '\u092A\u093E\u0938\u0935\u0930\u094D\u0921',
              '\u092A\u093E\u0938\u0935\u0930\u094D\u0921',
            ),
          ),
        ),
        actionButton(
          ct(
            'Recover linked account',
            '\u091C\u0941\u0921\u093C\u093E \u0916\u093E\u0924\u093E \u0916\u094B\u0932\u0947\u0902',
            '\u091C\u094B\u0921\u0932\u0947\u0932\u0947 \u0916\u093E\u0924\u0947 \u0909\u0918\u0921\u093E',
          ),
          _busy ? null : () => _run(false),
        ),
        actionButton(
          ct(
            'Send password reset email',
            '\u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0930\u0940\u0938\u0947\u091F \u0908\u092E\u0947\u0932 \u092D\u0947\u091C\u0947\u0902',
            '\u092A\u093E\u0938\u0935\u0930\u094D\u0921 \u0930\u0940\u0938\u0947\u091F \u0908\u092E\u0947\u0932 \u092A\u093E\u0920\u0935\u093E',
          ),
          _busy ? null : () => _run(true),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) SpokenNotice(text: _message!),
      ],
    ),
  );
}

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Safety & help',
      '\u0938\u0941\u0930\u0915\u094D\u0937\u093E \u0914\u0930 \u0938\u0939\u093E\u092F\u0924\u093E',
      '\u0938\u0941\u0930\u0915\u094D\u0937\u093E \u0935 \u092E\u0926\u0924',
    ),
    guide: () => ct(
      'Keep hazardous items intact. Never burn wires or open batteries and CRTs. Verify the receiving recycler and keep your receipt.',
      '\u0916\u0924\u0930\u0928\u093E\u0915 \u0938\u093E\u092E\u093E\u0928 \u0938\u093E\u092C\u0941\u0924 \u0930\u0916\u0947\u0902\u0964 \u0924\u093E\u0930 \u0928 \u091C\u0932\u093E\u090F\u0901; \u092C\u0948\u091F\u0930\u0940 \u0914\u0930 CRT \u0928 \u0916\u094B\u0932\u0947\u0902\u0964 \u0932\u0947\u0928\u0947 \u0935\u093E\u0932\u0947 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0947\u0902 \u0914\u0930 \u0930\u0938\u0940\u0926 \u0930\u0916\u0947\u0902\u0964',
      '\u0927\u094B\u0915\u093E\u0926\u093E\u092F\u0915 \u0935\u0938\u094D\u0924\u0942 \u0905\u0916\u0902\u0921 \u0920\u0947\u0935\u093A. \u0924\u093E\u0930\u093E \u091C\u093E\u0933\u0942 \u0928\u0915\u093E; \u092C\u0945\u091F\u0930\u0940 \u0935 CRT \u0909\u0918\u0921\u0941 \u0928\u0915\u093E. \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u0923\u093E\u0930\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0924\u092A\u093E\u0938\u093E \u0935 \u092A\u093E\u0935\u0924\u0940 \u0920\u0947\u0935\u093A.',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          ct(
            'Before collection',
            '\u0907\u0915\u091F\u094D\u0920\u093E \u0915\u0930\u0928\u0947 \u0938\u0947 \u092A\u0939\u0932\u0947',
            '\u0938\u0902\u0915\u0932\u0928\u093E\u092A\u0942\u0930\u094D\u0935\u0940',
          ),
        ),
        note(
          ct(
            'Obtain the owner\u2019s permission. Arrange secure data erasure by the owner or an authorized service. Removing a device from this app does not erase data on that device.',
            '\u092E\u093E\u0932\u093F\u0915 \u0915\u0940 \u0905\u0928\u0941\u092E\u0924\u093F \u0932\u0947\u0902\u0964 \u092E\u093E\u0932\u093F\u0915 \u092F\u093E \u0905\u0927\u093F\u0915\u0943\u0924 \u0938\u0947\u0935\u093E \u0938\u0947 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0921\u0947\u091F\u093E \u092E\u093F\u091F\u0935\u093E\u090F\u0901\u0964 \u0907\u0938 \u0910\u092A \u0938\u0947 \u0921\u093F\u0935\u093E\u0907\u0938 \u0939\u091F\u093E\u0928\u0947 \u0938\u0947 \u0909\u0938\u0915\u0947 \u0905\u0902\u0926\u0930 \u0915\u093E \u0921\u0947\u091F\u093E \u0928\u0939\u0940\u0902 \u092E\u093F\u091F\u0924\u093E\u0964',
            '\u092E\u093E\u0932\u0915\u093E\u091A\u0940 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0918\u094D\u092F\u093E. \u092E\u093E\u0932\u0915 \u0915\u093F\u0902\u0935\u093E \u0905\u0927\u093F\u0915\u0943\u0924 \u0938\u0947\u0935\u0947\u0915\u0921\u0941\u0928 \u0938\u0941\u0930\u0915\u094D\u0937\u093F\u0924 \u0921\u0947\u091F\u093E \u092A\u0941\u0938\u0942\u0928 \u0918\u094D\u092F\u093E. \u092F\u093E \u0905\u0945\u092A\u092E\u0927\u0942\u0928 \u0921\u093F\u0935\u094D\u0939\u093E\u0907\u0938 \u0915\u093E\u0922\u0932\u094D\u092F\u093E\u0928\u0947 \u0924\u094D\u092F\u093E\u0924\u0940\u0932 \u0921\u0947\u091F\u093E \u092A\u0941\u0938\u0932\u093E \u091C\u093E\u0924 \u0928\u093E\u0939\u0940.',
          ),
        ),
        section(
          ct(
            'Handling',
            '\u0938\u0901\u092D\u093E\u0932\u0928\u093E',
            '\u0939\u093E\u0924\u093E\u0933\u0923\u0940',
          ),
        ),
        note(
          ct(
            'Do not dismantle swollen/leaking batteries, mercury lamps or CRTs. Keep damaged items isolated, avoid heat/short circuits, and obtain trained handling guidance. Do not mix them with household waste.',
            '\u092B\u0942\u0932\u0940/\u0930\u093F\u0938\u0924\u0940 \u092C\u0948\u091F\u0930\u0940, \u092A\u093E\u0930\u093E \u0932\u0948\u0902\u092A \u092F\u093E CRT \u0928 \u0916\u094B\u0932\u0947\u0902\u0964 \u0916\u0930\u093E\u092C \u0938\u093E\u092E\u093E\u0928 \u0905\u0932\u0917 \u0930\u0916\u0947\u0902, \u0917\u0930\u094D\u092E\u0940/\u0936\u0949\u0930\u094D\u091F \u0938\u0930\u094D\u0915\u093F\u091F \u0938\u0947 \u092C\u091A\u093E\u090F\u0901 \u0914\u0930 \u092A\u094D\u0930\u0936\u093F\u0915\u094D\u0937\u093F\u0924 \u0938\u0939\u093E\u092F\u0924\u093E \u0932\u0947\u0902\u0964 \u0918\u0930\u0947\u0932\u0942 \u0915\u091A\u0930\u0947 \u092E\u0947\u0902 \u0928 \u092E\u093F\u0932\u093E\u090F\u0901\u0964',
            '\u092B\u0941\u0917\u0932\u0947\u0932\u094D\u092F\u093E/\u0917\u0933\u0923\u093E\u0931\u094D\u092F\u093E \u092C\u0945\u091F\u0930\u0940, \u092A\u093E\u0930\u093E \u0926\u093F\u0935\u0947 \u0915\u093F\u0902\u0935\u093E CRT \u0909\u0918\u0921\u0941 \u0928\u0915\u093E. \u0916\u0930\u093E\u092C \u0935\u0938\u094D\u0924\u0942 \u0935\u0947\u0917\u0933\u094D\u092F\u093E \u0920\u0947\u0935\u093E, \u0909\u0937\u094D\u0923\u0924\u093E/\u0936\u0949\u0930\u094D\u091F \u0938\u0930\u094D\u0915\u093F\u091F \u091F\u093E\u0933\u093E \u0935 \u092A\u094D\u0930\u0936\u093F\u0915\u094D\u0937\u093F\u0924 \u092E\u0926\u0924 \u0918\u094D\u092F\u093E. \u0918\u0930\u0917\u0941\u0924\u0940 \u0915\u091A\u0931\u094D\u092F\u093E\u0924 \u092E\u093F\u0938\u0933\u0941 \u0928\u0915\u093E.',
          ),
        ),
        section(
          ct(
            'Handover & payment',
            '\u0938\u094C\u0902\u092A\u0928\u093E \u0914\u0930 \u092D\u0941\u0917\u0924\u093E\u0928',
            '\u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0935 \u092A\u0947\u092E\u0947\u0902\u091F',
          ),
        ),
        note(
          ct(
            'Check current recycler authorization and accepted waste categories independently. Agree rate and measured weight. Confirm money in your own bank/account; screenshots, QR scans and app entries are not bank proof. Never reveal a PIN or OTP to receive money.',
            '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0940 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0905\u0928\u0941\u092E\u0924\u093F \u0914\u0930 \u0938\u094D\u0935\u0940\u0915\u0943\u0924 \u0936\u094D\u0930\u0947\u0923\u093F\u092F\u093E\u0901 \u0905\u0932\u0917 \u0938\u0947 \u091C\u093E\u0901\u091A\u0947\u0902\u0964 \u092D\u093E\u0935 \u0914\u0930 \u092E\u093E\u092A\u0947 \u0935\u091C\u0928 \u092A\u0930 \u0938\u0939\u092E\u0924 \u0939\u094B\u0902\u0964 \u0905\u092A\u0928\u0947 \u092C\u0948\u0902\u0915/\u0916\u093E\u0924\u0947 \u092E\u0947\u0902 \u092A\u0948\u0938\u093E \u0926\u0947\u0916\u0947\u0902; \u0938\u094D\u0915\u094D\u0930\u0940\u0928\u0936\u0949\u091F, QR \u0914\u0930 \u0910\u092A \u092A\u094D\u0930\u0935\u093F\u0937\u094D\u091F\u093F \u092C\u0948\u0902\u0915 \u092A\u094D\u0930\u092E\u093E\u0923 \u0928\u0939\u0940\u0902\u0964 \u092A\u0948\u0938\u093E \u092A\u093E\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F PIN/OTP \u0928 \u092C\u0924\u093E\u090F\u0901\u0964',
            '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u0940 \u0938\u0927\u094D\u092F\u093E\u091A\u0940 \u092A\u0930\u0935\u093E\u0928\u0917\u0940 \u0935 \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u0932\u0947\u0932\u094D\u092F\u093E \u0936\u094D\u0930\u0947\u0923\u0940 \u0938\u094D\u0935\u0924\u0902\u0924\u094D\u0930 \u0924\u092A\u093E\u0938\u093E. \u0926\u0930 \u0935 \u092E\u094B\u091C\u0932\u0947\u0932\u094D\u092F\u093E \u0935\u091C\u0928\u093E\u0935\u0930 \u0938\u0939\u092E\u0924 \u0935\u094D\u0939\u093E. \u0938\u094D\u0935\u0924\u0903\u091A\u094D\u092F\u093E \u092C\u0901\u0915/\u0916\u093E\u0924\u094D\u092F\u093E\u0924 \u092A\u0948\u0938\u0947 \u0924\u092A\u093E\u0938\u093E; \u0938\u094D\u0915\u094D\u0930\u0940\u0928\u0936\u0949\u091F, QR \u0935 \u0905\u0945\u092A \u0928\u094B\u0902\u0926 \u092C\u0901\u0915 \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940. \u092A\u0948\u0938\u0947 \u092E\u093F\u0933\u0935\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 PIN/OTP \u0938\u093E\u0902\u0917\u0942 \u0928\u0915\u093E.',
          ),
        ),
        note(
          ct(
            'Emergency in India: contact 112 when there is immediate danger. This app is not an emergency dispatch or regulatory certification service.',
            '\u092D\u093E\u0930\u0924 \u092E\u0947\u0902 \u0924\u0924\u094D\u0915\u093E\u0932 \u0916\u0924\u0930\u0947 \u092A\u0930 112 \u0938\u0947 \u0938\u0902\u092A\u0930\u094D\u0915 \u0915\u0930\u0947\u0902\u0964 \u092F\u0939 \u0910\u092A \u0906\u092A\u093E\u0924\u0915\u093E\u0932\u0940\u0928 \u0938\u0939\u093E\u092F\u0924\u093E \u092D\u0947\u091C\u0928\u0947 \u092F\u093E \u0915\u093E\u0928\u0942\u0928\u0940 \u092A\u094D\u0930\u092E\u093E\u0923\u0928 \u0915\u0940 \u0938\u0947\u0935\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
            '\u092D\u093E\u0930\u0924\u093E\u0924 \u0924\u093E\u0924\u0921\u0940\u091A\u093E \u0927\u094B\u0915\u093E \u0905\u0938\u0932\u094D\u092F\u093E\u0938 112 \u0936\u0940 \u0938\u0902\u092A\u0930\u094D\u0915 \u0915\u0930\u093E. \u0939\u0947 \u0905\u0945\u092A \u0906\u092A\u0924\u094D\u0915\u093E\u0932\u0940\u0928 \u092E\u0926\u0924 \u092A\u093E\u0920\u0935\u0923\u094D\u092F\u093E\u091A\u0940 \u0915\u093F\u0902\u0935\u093E \u0915\u093E\u092F\u0926\u0947\u0936\u0940\u0930 \u092A\u094D\u0930\u092E\u093E\u0923\u0928 \u0938\u0947\u0935\u093E \u0928\u093E\u0939\u0940.',
          ),
        ),
      ],
    ),
  );
}

/// Sprint1B entry: the direct-sell flow (list a cloud lot, verified
/// recyclers quote, select one to reserve). Hosts the existing panel.
class DirectSellPage extends StatelessWidget {
  const DirectSellPage({super.key});
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Sell my collection',
      '\u0905\u092A\u0928\u093E \u092E\u093E\u0932 \u092C\u0947\u091A\u0947\u0902',
      '\u0924\u0941\u092E\u091A\u093E \u092E\u093E\u0932 \u0935\u093F\u0915\u093E',
    ),
    body: (_) => const SellCollectionPanel(),
  );
}
