import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'collector_ui.dart';
import 'app_speech.dart';
import 'material_photos.dart';
import 'direct_sell_quotes.dart';
import 'direct_sell_selection.dart';
import 'direct_sell_handover.dart';
import 'direct_sell_receipts.dart';

String trackingDate(Object? value) {
  if (value is! Timestamp)
    return ct(
      'Not recorded',
      '\u0926\u0930\u094D\u091C \u0928\u0939\u0940\u0902',
      '\u0928\u094B\u0902\u0926 \u0928\u093E\u0939\u0940',
    );
  final d = value.toDate().toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

Uri trackingMapUri(String location) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': location.trim()},
);
Future<void> openTrackingMap(BuildContext context, String location) async {
  if (location.trim().isEmpty) return;
  if (!await confirmAction(
        context,
        ct(
          'Open this location in external Maps? The address will be shared with the map provider. This is not live vehicle tracking.',
          '\u092F\u0939 \u0938\u094D\u0925\u093E\u0928 \u092C\u093E\u0939\u0930\u0940 Maps \u092E\u0947\u0902 \u0916\u094B\u0932\u0947\u0902? \u092A\u0924\u093E \u092E\u0948\u092A \u0938\u0947\u0935\u093E \u0938\u0947 \u0938\u093E\u091D\u093E \u0939\u094B\u0917\u093E\u0964 \u092F\u0939 \u0935\u093E\u0939\u0928 \u0915\u0940 \u0932\u093E\u0907\u0935 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
          '\u0939\u0947 \u0938\u094D\u0925\u093E\u0928 \u092C\u093E\u0939\u0947\u0930\u0940\u0932 Maps \u092E\u0927\u094D\u092F\u0947 \u0909\u0918\u0921\u093E\u092F\u091A\u0947? \u092A\u0924\u094D\u0924\u093E \u0928\u0915\u093E\u0936\u093E \u0938\u0947\u0935\u0947\u0936\u0940 \u0936\u0947\u0905\u0930 \u0939\u094B\u0908\u0932. \u0939\u0947 \u0935\u093E\u0939\u0928\u093E\u091A\u0947 \u0925\u0947\u091F \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917 \u0928\u093E\u0939\u0940.',
        ),
      ) ||
      !context.mounted)
    return;
  try {
    final opened = await launchUrl(
      trackingMapUri(location),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('maps-unavailable');
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ct(
              'Maps could not open. Check connection or your Maps app.',
              'Maps \u0928\u0939\u0940\u0902 \u0916\u0941\u0932\u093E\u0964 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u092F\u093E Maps \u0910\u092A \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
              'Maps \u0909\u0918\u0921\u0932\u0947 \u0928\u093E\u0939\u0940. \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0915\u093F\u0902\u0935\u093E Maps \u0905\u0945\u092A \u0924\u092A\u093E\u0938\u093E.',
            ),
          ),
        ),
      );
  }
}

class RequestMaterialSummary extends StatelessWidget {
  const RequestMaterialSummary({
    required this.data,
    required this.id,
    this.sale = false,
    super.key,
  });
  final Map<String, dynamic> data;
  final String id;
  final bool sale;
  @override
  Widget build(BuildContext context) {
    final rate = data[sale ? 'askingRate' : 'quoteRate'];
    final valid =
        rate is num &&
        rate.isFinite &&
        rate > 0 &&
        data[sale ? 'currency' : 'quoteCurrency'] == 'INR';
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MaterialPhoto(
                  material: '${data['material']}',
                  width: 76,
                  height: 86,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        materialLabel('${data['material']}'),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${data['weightKg'] ?? '\u2014'} kg \u2022 ${data['city'] ?? '\u2014'}',
                      ),
                      if (!sale && data['recyclerName'] is String)
                        Text('${data['recyclerName']}'),
                      Text(
                        valid
                            ? '\u20B9${(rate as num).toStringAsFixed(2)}/kg'
                            : ct(
                                'Quote not recorded',
                                '\u092D\u093E\u0935 \u0926\u0930\u094D\u091C \u0928\u0939\u0940\u0902',
                                '\u0926\u0930 \u0928\u094B\u0902\u0926\u0932\u0947\u0932\u093E \u0928\u093E\u0939\u0940',
                              ),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: collectorGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (valid)
              Text(
                sale
                    ? ct(
                        'Collector asking rate \u2014 not an agreed price',
                        '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0915\u093E \u092E\u093E\u0901\u0917\u093E \u092D\u093E\u0935 \u2014 \u0938\u0939\u092E\u0924 \u0915\u0940\u092E\u0924 \u0928\u0939\u0940\u0902',
                        '\u0938\u0902\u0915\u0932\u0915\u093E\u091A\u093E \u0905\u092A\u0947\u0915\u094D\u0937\u093F\u0924 \u0926\u0930 \u2014 \u092E\u093E\u0928\u094D\u092F \u0915\u093F\u0902\u092E\u0924 \u0928\u093E\u0939\u0940',
                      )
                    : ct(
                        'Recorded recycler quote \u2014 check expiry below; not money received',
                        '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u093E \u0926\u0930\u094D\u091C \u092D\u093E\u0935 \u2014 \u0928\u0940\u091A\u0947 \u0935\u0948\u0927\u0924\u093E \u091C\u093E\u0901\u091A\u0947\u0902; \u092A\u094D\u0930\u093E\u092A\u094D\u0924 \u0930\u093E\u0936\u093F \u0928\u0939\u0940\u0902',
                        '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u093E \u0928\u094B\u0902\u0926\u0935\u0932\u0947\u0932\u093E \u0926\u0930 \u2014 \u0916\u093E\u0932\u0940 \u092E\u0941\u0926\u0924 \u0924\u092A\u093E\u0938\u093E; \u092E\u093F\u0933\u093E\u0932\u0947\u0932\u0940 \u0930\u0915\u094D\u0915\u092E \u0928\u093E\u0939\u0940',
                      ),
              ),
            const SizedBox(height: 8),
            SelectableText(
              '${ct('Request ID', '\u0905\u0928\u0941\u0930\u094B\u0927 ID', '\u0935\u093F\u0928\u0902\u0924\u0940 ID')}: $id',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestProgress extends StatelessWidget {
  const RequestProgress({
    required this.data,
    this.sale = false,
    this.cached = false,
    this.pending = false,
    super.key,
  });
  final Map<String, dynamic> data;
  final bool sale, cached, pending;
  static List<String> recordedKeys(
    Map<String, dynamic> data, {
    bool sale = false,
  }) {
    final keys = sale
        ? ['publishedAt', if (data['status'] == 'withdrawn') 'updatedAt']
        : [
            'createdAt',
            'quotedAt',
            'acceptedAt',
            'handoverRequestedAt',
            'completedAt',
            'cancelledAt',
            'rejectedAt',
          ];
    return keys.where((k) => data[k] is Timestamp).toList();
  }

  Widget _row(String key, String label) {
    final recorded = data[key] is Timestamp && !pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            recorded ? Icons.check_circle : Icons.radio_button_unchecked,
            color: recorded ? collectorGreen : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  recorded
                      ? trackingDate(data[key])
                      : ct(
                          'Not recorded',
                          '\u0926\u0930\u094D\u091C \u0928\u0939\u0940\u0902',
                          '\u0928\u094B\u0902\u0926 \u0928\u093E\u0939\u0940',
                        ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ct(
              'Request tracking',
              '\u0905\u0928\u0941\u0930\u094B\u0927 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917',
              '\u0935\u093F\u0928\u0902\u0924\u0940 \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917',
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (cached || pending)
            Text(
              ct(
                'Cached / pending view \u2014 not fresh server confirmation',
                '\u0915\u0948\u0936 / \u0932\u0902\u092C\u093F\u0924 \u091C\u093E\u0928\u0915\u093E\u0930\u0940 \u2014 \u0928\u0908 \u0938\u0930\u094D\u0935\u0930 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902',
                '\u0915\u0945\u0936 / \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u092E\u093E\u0939\u093F\u0924\u0940 \u2014 \u0928\u0935\u0940\u0928 \u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940',
              ),
            ),
          if (sale) ...[
            _row(
              'publishedAt',
              ct(
                'Sell listing published',
                '\u092C\u093F\u0915\u094D\u0930\u0940 \u092E\u093E\u0901\u0917 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924',
                '\u0935\u093F\u0915\u094D\u0930\u0940 \u092E\u093E\u0917\u0923\u0940 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924',
              ),
            ),
            if (data['status'] == 'withdrawn')
              _row(
                'updatedAt',
                ct(
                  'Listing withdrawn',
                  '\u092E\u093E\u0901\u0917 \u0935\u093E\u092A\u0938 \u0932\u0940 \u0917\u0908',
                  '\u092E\u093E\u0917\u0923\u0940 \u092E\u093E\u0917\u0947 \u0918\u0947\u0924\u0932\u0940',
                ),
              ),
            if (data['status'] == 'reserved')
              _row(
                'selectedAt',
                ct(
                  'Reserved for selected buyer',
                  '\u091A\u0941\u0928\u0947 \u0939\u0941\u090F \u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u0947 \u0932\u093F\u090F \u0906\u0930\u0915\u094D\u0937\u093F\u0924',
                  '\u0928\u093F\u0935\u0921\u0932\u0947\u0932\u094D\u092F\u093E \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930\u093E\u0938\u093E\u0920\u0940 \u0930\u093E\u0916\u0940\u0935',
                ),
              ),
            Text(
              '${ct('Expiry', '\u0938\u092E\u093E\u092A\u094D\u0924\u093F', '\u092E\u0941\u0926\u0924')}: ${trackingDate(data['expiresAt'])}',
            ),
            Text(
              ct(
                'Listing only. Approved recyclers can quote on it; quotes appear below. Reservation, handover and payment are not connected to this listing yet. No transport movement is confirmed.',
                '\u0915\u0947\u0935\u0932 \u0938\u0942\u091A\u0940\u0964 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0907\u0938 \u092A\u0930 \u092D\u093E\u0935 \u0926\u0947 \u0938\u0915\u0924\u0947 \u0939\u0948\u0902; \u092D\u093E\u0935 \u0928\u0940\u091A\u0947 \u0926\u093F\u0916\u0924\u0947 \u0939\u0948\u0902\u0964 \u0906\u0930\u0915\u094D\u0937\u0923, \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0914\u0930 \u092D\u0941\u0917\u0924\u093E\u0928 \u0907\u0938 \u0938\u0942\u091A\u0940 \u0938\u0947 \u0905\u092D\u0940 \u0928\u0939\u0940\u0902 \u091C\u0941\u0921\u093C\u0947\u0964 \u0938\u093E\u092E\u093E\u0928 \u0915\u0940 \u0906\u0935\u093E\u091C\u093E\u0939\u0940 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                '\u092B\u0915\u094D\u0924 \u091C\u093E\u0939\u093F\u0930\u093E\u0924. \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u0947 \u092F\u093E\u0935\u0930 \u0926\u0930 \u0926\u0947\u090A \u0936\u0915\u0924\u093E\u0924; \u0926\u0930 \u0916\u093E\u0932\u0940 \u0926\u093F\u0938\u0924\u093E\u0924. \u0906\u0930\u0915\u094D\u0937\u0923, \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0935 \u092A\u0947\u092E\u0947\u0902\u091F \u092F\u093E \u091C\u093E\u0939\u093F\u0930\u093E\u0924\u0940\u0936\u0940 \u0905\u0926\u094D\u092F\u093E\u092A \u091C\u094B\u0921\u0932\u0947\u0932\u0947 \u0928\u093E\u0939\u0940\u0924. \u092E\u093E\u0932\u093E\u091A\u0940 \u0939\u093E\u0932\u091A\u093E\u0932 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940.',
              ),
            ),
            if (data['status'] == 'reserved')
              Text(
                ct(
                  'RESERVED: only you and the selected recycler see this deal now; no other buyer can quote or take the lot. Cancel from the quotes panel ends the deal and frees the lot. Handover comes in the next update; nothing is paid or moved yet.',
                  '\u0906\u0930\u0915\u094D\u0937\u093F\u0924: \u0905\u092D\u0940 \u0915\u0947\u0935\u0932 \u0906\u092A \u0914\u0930 \u091A\u0941\u0928\u093E \u0917\u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0907\u0938 \u0938\u094C\u0926\u0947 \u0915\u094B \u0926\u0947\u0916 \u0938\u0915\u0924\u0947 \u0939\u0948\u0902; \u0915\u094B\u0908 \u0926\u0942\u0938\u0930\u093E \u0916\u0930\u0940\u0926\u093E\u0930 \u092D\u093E\u0935 \u0928\u0939\u0940\u0902 \u0926\u0947 \u0938\u0915\u0924\u093E \u0914\u0930 \u0932\u0949\u091F \u0928\u0939\u0940\u0902 \u0909\u0920\u093E \u0938\u0915\u0924\u093E\u0964 \u092D\u093E\u0935-\u092A\u0948\u0928\u0932 \u0938\u0947 \u0906\u0930\u0915\u094D\u0937\u0923 \u0930\u0926\u094D\u0926 \u0915\u0930\u0928\u0947 \u092A\u0930 \u0938\u094C\u0926\u093E \u0938\u092E\u093E\u092A\u094D\u0924 \u0939\u094B\u0917\u093E \u0914\u0930 \u0932\u0949\u091F \u092B\u094D\u0930\u0940 \u0939\u094B\u0917\u093E\u0964 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0905\u0917\u0932\u0947 \u0905\u092A\u0921\u0947\u091F \u092E\u0947\u0902 \u0906\u090F\u0917\u093E; \u0905\u092D\u0940 \u0915\u0941\u091B \u092D\u0941\u0917\u0924\u093E\u0928 \u092F\u093E \u0906\u0935\u093E\u091C\u093E\u0939\u0940 \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964',
                  '\u0930\u093E\u0916\u0940\u0935: \u0906\u0924\u093E\u092A\u0932\u093F \u092B\u0915\u094D\u0924 \u0924\u0941\u092E\u094D\u0939\u0940 \u0935 \u0928\u093F\u0935\u0921\u0932\u0947\u0932\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0939\u0947 \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u0926\u093F\u0938\u0924\u094B; \u0907\u0924\u0930 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0926\u0930 \u0926\u0947\u090A \u0936\u0915\u0924 \u0928\u093E\u0939\u0940 \u0915\u093F\u0902\u0935\u093E \u0932\u0949\u091F \u0909\u091A\u0915\u0932 \u0928\u093E\u0939\u0940. \u0926\u0930-\u092A\u0945\u0928\u0947\u0932\u092E\u0927\u094D\u092F\u0947 \u0930\u093E\u0916\u0940\u0935 \u0930\u0926\u094D\u0926 \u0915\u0947\u0932\u094D\u092F\u093E\u0938 \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u0938\u0902\u092A\u0932\u0947\u0932 \u0935 \u0932\u0949\u091F \u092E\u0941\u0915\u094D\u0924 \u0939\u094B\u0908\u0932. \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092A\u0941\u0922\u0940\u0932 \u0905\u092A\u0921\u0947\u091F\u092E\u0927\u094D\u092F\u0947; \u0906\u0924\u093E\u092A\u0932\u0940 \u0915\u093E\u0939\u0940 \u0926\u0947\u092F\u0915 \u0915\u093F\u0902\u0935\u093E \u0939\u093E\u0932\u091A\u093E\u0932 \u0928\u093E\u0939\u0940.',
                ),
              ),
          ] else ...[
            _row(
              'createdAt',
              ct(
                'Lot proposal sent',
                '\u0932\u0949\u091F \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u092D\u0947\u091C\u093A',
                '\u0932\u0949\u091F \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u092A\u093E\u0920\u0935\u0932\u093E',
              ),
            ),
            _row(
              'quotedAt',
              ct(
                'Recycler quote recorded',
                '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u093E \u092D\u093E\u0935 \u0926\u0930\u094D\u091C',
                '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u093E \u0926\u0930 \u0928\u094B\u0902\u0926\u0932\u093E',
              ),
            ),
            _row(
              'acceptedAt',
              ct(
                'Quote accepted / lot reserved',
                '\u092D\u093E\u0935 \u0938\u094D\u0935\u0940\u0915\u093E\u0930 / \u0932\u0949\u091F \u0906\u0930\u0915\u094D\u0937\u093F\u0924',
                '\u0926\u0930 \u0938\u094D\u0935\u0940\u0915\u093E\u0930\u0932\u093E / \u0932\u0949\u091F \u0930\u093E\u0916\u0940\u0935',
              ),
            ),
            _row(
              'handoverRequestedAt',
              ct(
                'Collector requested handover confirmation',
                '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0928\u0947 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u092E\u093E\u0901\u0917\u0940',
                '\u0938\u0902\u0915\u0932\u0915\u093E\u0928\u0947 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923\u093E\u091A\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u092E\u093E\u0917\u093F\u0924\u0932\u0940',
              ),
            ),
            _row(
              'completedAt',
              ct(
                'Recycler confirmed handover',
                '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0928\u0947 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u092A\u0941\u0937\u094D\u091F \u0915\u093F\u092F\u093E',
                '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0928\u0947 \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u092A\u0941\u0937\u094D\u091F \u0915\u0947\u0932\u0947',
              ),
            ),
            if (data['cancelledAt'] is Timestamp)
              _row(
                'cancelledAt',
                ct(
                  'Proposal withdrawn',
                  '\u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u0935\u093E\u092A\u0938 \u0932\u093F\u092F\u093E',
                  '\u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u092E\u093E\u0917\u0947 \u0918\u0947\u0924\u0932\u093E',
                ),
              ),
            if (data['rejectedAt'] is Timestamp)
              _row(
                'rejectedAt',
                ct(
                  'Recycler rejected proposal',
                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0928\u0947 \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u0905\u0938\u094D\u0935\u0940\u0915\u093E\u0930 \u0915\u093F\u092F\u093E',
                  '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0928\u0947 \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u0928\u093E\u0915\u093E\u0930\u0932\u093E',
                ),
              ),
            Text(
              ct(
                'These are deal records, not live GPS, in-transit tracking or proof of recycling. Payment receipts are shown separately.',
                '\u092F\u0947 \u0938\u094C\u0926\u0947 \u0915\u0947 \u0930\u093F\u0915\u0949\u0930\u094D\u0921 \u0939\u0948\u0902, \u0932\u093E\u0907\u0935 GPS, \u0930\u093E\u0938\u094D\u0924\u0947 \u0915\u0940 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917 \u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932 \u0939\u094B\u0928\u0947 \u0915\u093E \u0938\u092C\u0942\u0924 \u0928\u0939\u0940\u0902\u0964 \u092D\u0941\u0917\u0924\u093E\u0928 \u0915\u0940 \u0930\u0938\u0940\u0926\u0947\u0902 \u0905\u0932\u0917 \u0926\u093F\u0916\u093E\u0908 \u091C\u093E\u0924\u0940 \u0939\u0948\u0902\u0964',
                '\u092F\u093E \u0935\u094D\u092F\u0935\u0939\u093E\u0930\u093E\u091A\u094D\u092F\u093E \u0928\u094B\u0902\u0926\u0940 \u0906\u0939\u0947\u0924, \u0925\u0947\u091F GPS, \u092A\u094D\u0930\u0935\u093E\u0938\u093E\u0924\u0940\u0932 \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917 \u0915\u093F\u0902\u0935\u093E \u092A\u0941\u0928\u0930\u094D\u0935\u093E\u092A\u0930\u093E\u091A\u093E \u092A\u0941\u0930\u093E\u0935\u093E \u0928\u093E\u0939\u0940. \u092A\u0947\u092E\u0947\u0902\u091F \u092A\u093E\u0935\u0924\u094D\u092F\u093E \u0935\u0947\u0917\u0933\u094D\u092F\u093E \u0926\u093E\u0916\u0935\u0932\u094D\u092F\u093E \u0906\u0939\u0947\u0924.',
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Sprint1A collector side: REAL quotes of the current publication round,
/// best rate first, read-only. No accept/reject/reserve here (Sprint1B).
/// Data comes only from the server; nothing is simulated or invented.
class SellQuotesPanel extends StatelessWidget {
  const SellQuotesPanel({
    required this.sale,
    required this.saleData,
    super.key,
  });
  final DocumentReference<Map<String, dynamic>> sale;
  final Map<String, dynamic> saleData;

  @override
  Widget build(BuildContext context) {
    final publishedAt = saleData['publishedAt'];
    final status = saleData['status'];
    final open = status == 'open';
    final selectedRate = saleData['selectedRatePaise'];
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ct(
                'Recycler quotes',
                '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0947 \u092D\u093E\u0935',
                '\u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u0947 \u0926\u0930',
              ),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            note(
              ct(
                'Quotes come only from approved recyclers while this listing is open, listed best rate first. A quote never reserves your lot; choosing a buyer, handover and payment come in the next update.',
                '\u092D\u093E\u0935 \u0915\u0947\u0935\u0932 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E\u0913\u0902 \u0938\u0947 \u0906\u0924\u0947 \u0939\u0948\u0902, \u091C\u092C \u0924\u0915 \u092F\u0939 \u0938\u0942\u091A\u0940 \u0916\u0941\u0932\u0940 \u0939\u0948; \u0938\u0930\u094D\u0935\u094B\u0924\u094D\u0924\u092E \u092D\u093E\u0935 \u092A\u0939\u0932\u0947 \u0926\u093F\u0916\u0924\u093E \u0939\u0948\u0964 \u092D\u093E\u0935 \u0938\u0947 \u0906\u092A\u0915\u093E \u0932\u0949\u091F \u0906\u0930\u0915\u094D\u0937\u093F\u0924 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u093E; \u0916\u0930\u0940\u0926\u093E\u0930 \u091A\u0941\u0928\u0928\u093E, \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0914\u0930 \u092D\u0941\u0917\u0924\u093E\u0928 \u0905\u0917\u0932\u0947 \u0905\u092A\u0921\u0947\u091F \u092E\u0947\u0902 \u0906\u090F\u0901\u0917\u0947\u0964',
                '\u0926\u0930 \u092B\u0915\u094D\u0924 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0902\u0915\u0921\u0942\u0928 \u092F\u0947\u0924\u093E\u0924, \u091C\u094B\u092A\u0930\u094D\u092F\u0902\u0924 \u0939\u0940 \u091C\u093E\u0939\u093F\u0930\u093E\u0924 \u0916\u0941\u0932\u0940 \u0906\u0939\u0947; \u0938\u0930\u094D\u0935\u094B\u0924\u094D\u0924\u092E \u0926\u0930 \u0906\u0927\u0940 \u0926\u093F\u0938\u0924\u094B. \u0926\u0930\u093E\u0928\u0947 \u0924\u0941\u092E\u091A\u093E \u0932\u0949\u091F \u0930\u093E\u0916\u0940\u0935 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940; \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0928\u093F\u0935\u0921, \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0935 \u0926\u0947\u092F\u0915 \u092A\u0941\u0922\u0940\u0932 \u0905\u092A\u0921\u0947\u091F\u092E\u0927\u094D\u092F\u0947 \u092F\u0947\u0924\u0940\u0932.',
              ),
            ),
            if (status == 'reserved')
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF286B3B), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ct(
                        'RESERVED \u2014 buyer selected',
                        '\u0906\u0930\u0915\u094D\u0937\u093F\u0924 \u2014 \u0916\u0930\u0940\u0926\u093E\u0930 \u091A\u0941\u0928\u093E \u0917\u092F\u093E',
                        '\u0930\u093E\u0916\u0940\u0935 \u2014 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0928\u093F\u0935\u0921\u0932\u093E',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF286B3B),
                      ),
                    ),
                    Text(
                      '${saleData['selectedRecyclerName'] ?? '\u2014'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      selectedRate is int
                          ? '${formatPaiseAsRupees(selectedRate)} / kg'
                          : ct(
                              'Rate not recorded',
                              '\u092D\u093E\u0935 \u0926\u0930\u094D\u091C \u0928\u0939\u0940\u0902',
                              '\u0926\u0930 \u0928\u094B\u0902\u0926\u0932\u0947\u0932\u093E \u0928\u093E\u0939\u0940',
                            ),
                    ),
                    Text(
                      '${ct('Reserved at', '\u0906\u0930\u0915\u094D\u0937\u0923 \u0938\u092E\u092F', '\u0930\u093E\u0916\u0940\u0935 \u0935\u0947\u0933')}: ${trackingDate(saleData['selectedAt'])}',
                    ),
                    note(
                      ct(
                        'No other buyer can quote or take this lot now. When the material is physically ready, start the handover with the REAL final weight. The selected recycler may decline until then; cancellation closes once handover starts.',
                        'अभी कोई दूसरा खरीदार भाव नहीं दे सकता या लॉट नहीं उठा सकता। माल तैयार होने पर असली अंतिम वज़न के साथ हैंडओवर शुरू करें। तब तक चुना गया रीसायकलकर्ता मना कर सकता है; हैंडओवर शुरू होने पर रद्द करना बंद हो जाता है।',
                        'आता इतर खरेदीदार दर देऊ शकत नाही किंवा लॉट उचलू शकत नाही. माल तयार झाल्यावर खऱ्या अंतिम वजनासह हस्तांतरण सुरू करा. तोपर्यंत निवडलेला रीसायकलर नकार देऊ शकतो; हस्तांतरण सुरू झाल्यावर रद्द करता येत नाही.',
                      ),
                    ),
                    actionButton(
                      ct(
                        'Start handover (enter final weight)',
                        'हैंडओवर शुरू करें (अंतिम वज़न भरें)',
                        'हस्तांतरण सुरू करा (अंतिम वजन भरा)',
                      ),
                      () => _startHandover(context),
                      icon: Icons.local_shipping_outlined,
                    ),
                    actionButton(
                      ct(
                        'Cancel reservation',
                        '\u0906\u0930\u0915\u094D\u0937\u0923 \u0930\u0926\u094D\u0926 \u0915\u0930\u0947\u0902',
                        '\u0930\u093E\u0916\u0940\u0935 \u0930\u0926\u094D\u0926 \u0915\u0930\u093E',
                      ),
                      () => _cancel(context),
                      icon: Icons.cancel_outlined,
                    ),
                  ],
                ),
              ),
            if (status == 'handoverPending')
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB8860B), width: 2),
                ),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: sale
                      .collection('handover')
                      .doc('current')
                      .snapshots(),
                  builder: (context, hs) {
                    final ho = hs.data?.data();
                    final w = ho == null ? null : ho['finalWeightKg'];
                    final rev = ho == null ? null : ho['revision'];
                    final hp = ho == null ? null : ho['ratePaise'];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ct(
                            'HANDOVER STARTED — awaiting buyer confirmation',
                            'हैंडओवर शुरू — खरीदार की पुष्टि बाकी',
                            'हस्तांतरण सुरू — खरेदीदाराच्या पुष्टीची प्रतीक्षा',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A6D1A),
                          ),
                        ),
                        if (w is num)
                          Text(
                            hp is int
                                ? '${ct('Final weight', 'अंतिम वज़न', 'अंतिम वजन')}: ${w} kg • ${ct('Total at agreed rate', 'तय भाव पर कुल', 'ठरलेल्या दराने एकूण')} ${formatPaiseAsRupees((hp * w).round())}'
                                : '${ct('Final weight', 'अंतिम वज़न', 'अंतिम वजन')}: ${w} kg',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        note(
                          ct(
                            'The selected recycler must confirm physical receipt. Free cancellation is CLOSED once handover starts. You can still correct the weight until they confirm.',
                            'चुने गए रीसायकलकर्ता को माल भौतिक रूप से मिलने की पुष्टि करनी होगी। हैंडओवर शुरू होने के बाद मुक्त रद्दीकरण बंद है। पुष्टि से पहले आप वज़न सुधार सकते हैं।',
                            'निवडलेल्या रीसायकलरला प्रत्यक्ष माल मिळाल्याची पुष्टी करावी लागेल. हस्तांतरण सुरू झाल्यावर मुक्त रद्दीकरण बंद आहे. पुष्टीपूर्वी तुम्ही वजन दुरुस्त करू शकता.',
                          ),
                        ),
                        if (ho != null &&
                            ho['status'] == 'proposed' &&
                            rev is int)
                          actionButton(
                            ct(
                              'Edit final weight',
                              'अंतिम वज़न बदलें',
                              'अंतिम वजन बदला',
                            ),
                            () => _editWeight(
                              context,
                              w is num ? w.toDouble() : null,
                              rev,
                            ),
                            icon: Icons.edit_outlined,
                          ),
                      ],
                    );
                  },
                ),
              ),
            if (status == 'completed')
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF286B3B), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ct(
                        'DEAL COMPLETE — handover confirmed',
                        'सौदा पूरा — हैंडओवर पुष्ट',
                        'सौदा पूर्ण — हस्तांतरण पुष्ट',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF286B3B),
                      ),
                    ),
                    ReceiptPanel(saleId: sale.id),
                  ],
                ),
              ),
            if (publishedAt is! Timestamp)
              note(
                ct(
                  'Publication is awaiting server confirmation; quotes will appear after that.',
                  '\u092A\u094D\u0930\u0915\u093E\u0936\u0928 \u0938\u0930\u094D\u0935\u0930 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u093E \u0907\u0902\u0924\u091C\u093E\u0930 \u0915\u0930 \u0930\u0939\u093E \u0939\u0948; \u0909\u0938\u0915\u0947 \u092C\u093E\u0926 \u092D\u093E\u0935 \u0926\u093F\u0916\u0947\u0902\u0917\u0947\u0964',
                  '\u092A\u094D\u0930\u0915\u093E\u0936\u0928 \u0938\u0930\u094D\u0935\u094D\u0939\u0930 \u092A\u0941\u0937\u094D\u091F\u0940\u091A\u0940 \u0935\u093E\u091F \u092A\u093E\u0939\u0924 \u0906\u0939\u0947; \u0924\u094D\u092F\u093E\u0928\u0902\u0924\u0930 \u0926\u0930 \u0926\u093F\u0938\u0924\u0940\u0932.',
                ),
              )
            else
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: DirectSellQuoteService().quotesForRound(
                  sale.id,
                  quoteRoundKey(publishedAt),
                ),
                builder: (context, s) {
                  if (s.hasError)
                    return note(
                      ct(
                        'Quotes could not load. Check your connection and that the quote rules are published.',
                        '\u092D\u093E\u0935 \u0932\u094B\u0921 \u0928\u0939\u0940\u0902 \u0939\u094B \u0938\u0915\u0947\u0964 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0914\u0930 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u092D\u093E\u0935-\u0928\u093F\u092F\u092E \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                        '\u0926\u0930 \u0932\u094B\u0921 \u0939\u094B\u090A \u0936\u0915\u0932\u0947 \u0928\u093E\u0939\u0940\u0924. \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0935 \u092A\u094D\u0930\u0915\u093E\u0936\u093F\u0924 \u0926\u0930-\u0928\u093F\u092F\u092E \u0924\u092A\u093E\u0938\u093E.',
                      ),
                    );
                  if (!s.hasData) return const LinearProgressIndicator();
                  final docs = s.data!.docs;
                  if (docs.isEmpty)
                    return note(
                      status == 'open'
                          ? ct(
                              'No quotes yet. Quotes appear here automatically when an approved recycler responds.',
                              '\u0905\u092D\u0940 \u0915\u094B\u0908 \u092D\u093E\u0935 \u0928\u0939\u0940\u0902\u0964 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0947 \u091C\u0935\u093E\u092C \u092A\u0930 \u092D\u093E\u0935 \u092F\u0939\u093E\u0901 \u0905\u092A\u0928\u0947 \u0906\u092A \u0926\u093F\u0916\u0947\u0902\u0917\u0947\u0964',
                              '\u0905\u091C\u0942\u0928 \u0915\u094B\u0923\u0924\u093E\u0939\u0940 \u0926\u0930 \u0928\u093E\u0939\u0940. \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u094D\u092F\u093E \u092A\u094D\u0930\u0924\u093F\u0938\u093E\u0926\u093E\u0935\u0930 \u0926\u0930 \u092F\u0947\u0925\u0947 \u0906\u092A\u094B\u0906\u092A \u0926\u093F\u0938\u0924\u0940\u0932.',
                            )
                          : ct(
                              'This listing is not open, so no new quotes can arrive. Earlier quotes of this round stay visible as history.',
                              '\u092F\u0939 \u0938\u0942\u091A\u0940 \u0916\u0941\u0932\u0940 \u0928\u0939\u0940\u0902 \u0939\u0948, \u0907\u0938\u0932\u093F\u090F \u0928\u090F \u092D\u093E\u0935 \u0928\u0939\u0940\u0902 \u0906 \u0938\u0915\u0924\u0947\u0964 \u0907\u0938 \u0930\u093E\u0909\u0902\u0921 \u0915\u0947 \u092A\u0939\u0932\u0947 \u092D\u093E\u0935 \u0907\u0924\u093F\u0939\u093E\u0938 \u0915\u0947 \u0930\u0942\u092A \u092E\u0947\u0902 \u0926\u093F\u0916\u0924\u0947 \u0930\u0939\u0947\u0902\u0917\u0947\u0964',
                              '\u0939\u0940 \u091C\u093E\u0939\u093F\u0930\u093E\u0924 \u0916\u0941\u0932\u0940 \u0928\u093E\u0939\u0940, \u092E\u094D\u0939\u0923\u0942\u0928 \u0928\u0935\u0940\u0928 \u0926\u0930 \u092F\u0947\u090A \u0936\u0915\u0924 \u0928\u093E\u0939\u0940\u0924. \u092F\u093E \u092B\u0947\u0930\u0940\u0924\u0940\u0932 \u0906\u0927\u0940\u091A\u0947 \u0926\u0930 \u0907\u0924\u093F\u0939\u093E\u0938\u093E\u0938\u093E\u0920\u0940 \u0926\u093F\u0938\u0924 \u0930\u093E\u0939\u0924\u0940\u0932.',
                            ),
                    );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (s.data!.metadata.isFromCache)
                        note(
                          ct(
                            'Offline data \u2014 the server has not reconfirmed these quotes.',
                            '\u0911\u092B\u0932\u093E\u0907\u0928 \u0921\u0947\u091F\u093E \u2014 \u0938\u0930\u094D\u0935\u0930 \u0928\u0947 \u0907\u0928 \u092D\u093E\u0935\u094B\u0902 \u0915\u0940 \u092B\u093F\u0930 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u0915\u0940\u0964',
                            '\u0911\u092B\u0932\u093E\u0907\u0928 \u092E\u093E\u0939\u093F\u0924\u0940 \u2014 \u0938\u0930\u094D\u0935\u094D\u0939\u0930\u0928\u0947 \u092F\u093E \u0926\u0930\u093E\u0902\u091A\u0940 \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u0941\u0937\u094D\u091F\u0940 \u0915\u0947\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940.',
                          ),
                        ),
                      ...docs.indexed.map(
                        (entry) => _quoteCard(
                          context,
                          entry.$1,
                          entry.$2.data(),
                          open,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _quoteCard(
    BuildContext context,
    int index,
    Map<String, dynamic> q,
    bool open,
  ) {
    final ratePaise = q['ratePaise'];
    final weightKg = q['weightKg'];
    final expiresAt = q['expiresAt'];
    final expired =
        expiresAt is Timestamp && !expiresAt.toDate().isAfter(DateTime.now());
    final rateText = ratePaise is int ? formatPaiseAsRupees(ratePaise) : '?';
    final totalText = ratePaise is int && weightKg is num
        ? formatPaiseAsRupees((ratePaise * weightKg).round())
        : null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: index == 0 ? const Color(0xFF286B3B) : Colors.grey.shade300,
          width: index == 0 ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index == 0
                ? ct(
                    'Highest quote',
                    '\u0938\u092C\u0938\u0947 \u090A\u0901\u091A\u093E \u092D\u093E\u0935',
                    '\u0938\u0930\u094D\u0935\u093E\u0927\u093F\u0915 \u0926\u0930',
                  )
                : ct('Quote', '\u092D\u093E\u0935', '\u0926\u0930'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: index == 0 ? const Color(0xFF286B3B) : null,
            ),
          ),
          Text(
            '${q['recyclerName']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            totalText == null
                ? '$rateText / kg'
                : '$rateText / kg \u2022 ${ct('Approx total', '\u0905\u0928\u0941\u092E\u093E\u0928\u093F\u0924 \u0915\u0941\u0932', '\u0905\u0902\u0926\u093E\u091C\u0947 \u090F\u0915\u0942\u0923')} $totalText',
          ),
          Text(
            '${ct('Sent', '\u092D\u0947\u091C\u093E', '\u092A\u093E\u0920\u0935\u0932\u093E')}: ${trackingDate(q['createdAt'])}',
          ),
          Text(
            '${ct('Valid till', '\u092E\u093E\u0928\u094D\u092F \u091C\u092C \u0924\u0915', '\u0935\u0948\u0927 \u0924\u0947')}: ${trackingDate(q['expiresAt'])}',
          ),
          if (expired)
            note(
              ct(
                'Validity ended. The quote stays as history; it is not a current offer.',
                '\u092E\u093E\u0928\u094D\u092F\u0924\u093E \u0938\u092E\u093E\u092A\u094D\u0924\u0964 \u092D\u093E\u0935 \u0907\u0924\u093F\u0939\u093E\u0938 \u0915\u0947 \u0930\u0942\u092A \u092E\u0947\u0902 \u0930\u0939\u0947\u0917\u093E; \u092F\u0939 \u092E\u094C\u091C\u0942\u0926\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                '\u0935\u0948\u0927\u0924\u093E \u0938\u0902\u092A\u0932\u0940. \u0926\u0930 \u0907\u0924\u093F\u0939\u093E\u0938\u093E\u0938\u093E\u0920\u0940 \u0930\u093E\u0939\u0940\u0932; \u0924\u094B \u0938\u0927\u094D\u092F\u093E\u091A\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u0928\u093E\u0939\u0940.',
              ),
            ),
          if (open && !expired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: actionButton(
                ct(
                  'Select this buyer',
                  '\u0907\u0938 \u0916\u0930\u0940\u0926\u093E\u0930 \u0915\u094B \u091A\u0941\u0928\u0947\u0902',
                  '\u0939\u093E \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0928\u093F\u0935\u0921\u093E',
                ),
                () => _select(context, q),
                icon: Icons.handshake_outlined,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _select(BuildContext context, Map<String, dynamic> q) async {
    final publishedAt = saleData['publishedAt'];
    final lotRevision = saleData['lotRevision'];
    final name = '${q['recyclerName']}';
    final ratePaise = q['ratePaise'];
    if (publishedAt is! Timestamp || lotRevision is! int || ratePaise is! int) {
      return;
    }
    final rate = formatPaiseAsRupees(ratePaise);
    if (!await confirmAction(
          context,
          ct(
            'Select $name as the buyer at $rate/kg? Your lot becomes RESERVED: no other buyer can quote or take it. You may cancel before handover \u2014 the deal ends and the lot is freed. Handover and payment come in later updates.',
            '$name \u0915\u094B $rate/kg \u092A\u0930 \u0916\u0930\u0940\u0926\u093E\u0930 \u091A\u0941\u0928\u0947\u0902? \u0906\u092A\u0915\u093E \u0932\u0949\u091F \u0906\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u094B \u091C\u093E\u090F\u0917\u093E: \u0915\u094B\u0908 \u0926\u0942\u0938\u0930\u093E \u0916\u0930\u0940\u0926\u093E\u0930 \u092D\u093E\u0935 \u0928\u0939\u0940\u0902 \u0926\u0947 \u092A\u093E\u090F\u0917\u093E \u092F\u093E \u0932\u0949\u091F \u0928\u0939\u0940\u0902 \u0909\u0920\u093E \u092A\u093E\u090F\u0917\u093E\u0964 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0906\u092A \u0930\u0926\u094D\u0926 \u0915\u0930 \u0938\u0915\u0924\u0947 \u0939\u0948\u0902 \u2014 \u0938\u094C\u0926\u093E \u0938\u092E\u093E\u092A\u094D\u0924 \u0939\u094B\u0917\u093E \u0914\u0930 \u0932\u0949\u091F \u092B\u094D\u0930\u0940 \u0939\u094B \u091C\u093E\u090F\u0917\u093E\u0964 \u0939\u0948\u0902\u0921\u0913\u0935\u0930 \u0914\u0930 \u092D\u0941\u0917\u0924\u093E\u0928 \u0905\u0917\u0932\u0947 \u0905\u092A\u0921\u0947\u091F\u094D\u0938 \u092E\u0947\u0902 \u0906\u090F\u0901\u0917\u0947\u0964',
            '$name \u0939\u093E $rate/kg \u0926\u0930\u093E\u0928\u0947 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0928\u093F\u0935\u0921\u093E\u092F\u091A\u093E? \u0924\u0941\u092E\u091A\u093E \u0932\u0949\u091F \u0930\u093E\u0916\u0940\u0935 \u0939\u094B\u0908\u0932: \u0907\u0924\u0930 \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0926\u0930 \u0926\u0947\u090A \u0936\u0915\u0923\u093E\u0930 \u0928\u093E\u0939\u0940 \u0915\u093F\u0902\u0935\u093E \u0932\u0949\u091F \u0909\u091A\u0915\u0932 \u0928\u093E\u0939\u0940. \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923\u093E\u092A\u0942\u0930\u094D\u0935 \u0924\u0941\u092E\u094D\u0939\u0940 \u0930\u0926\u094D\u0926 \u0915\u0930\u0942 \u0936\u0915\u0924\u093E \u2014 \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u0938\u0902\u092A\u0932\u0947\u0932 \u0935 \u0932\u0949\u091F \u092E\u0941\u0915\u094D\u0924 \u0939\u094B\u0908\u0932. \u0939\u0938\u094D\u0924\u093E\u0902\u0924\u0930\u0923 \u0935 \u0926\u0947\u092F\u0915 \u092A\u0941\u0922\u0940\u0932 \u0905\u092A\u0921\u0947\u091F\u092E\u0927\u094D\u092F\u0947.',
          ),
        ) ||
        !context.mounted)
      return;
    final out = await DirectSellSelectionService().selectQuote(
      saleId: sale.id,
      round: quoteRoundKey(publishedAt),
      recyclerUid: '${q['recyclerUid']}',
      recyclerName: name,
      ratePaise: ratePaise,
      publishedAt: publishedAt,
      lotRevision: lotRevision,
    );
    if (!context.mounted) return;
    final msg = selectionOutcomeMessage(out);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _cancel(BuildContext context) async {
    if (!await confirmAction(
          context,
          ct(
            'Cancel this reservation? The deal ends, your lot is freed, and quotes of this publication can no longer be selected. You can publish the lot again later as a new listing.',
            '\u092F\u0939 \u0906\u0930\u0915\u094D\u0937\u0923 \u0930\u0926\u094D\u0926 \u0915\u0930\u0947\u0902? \u0938\u094C\u0926\u093E \u0938\u092E\u093E\u092A\u094D\u0924 \u0939\u094B\u0917\u093E, \u0906\u092A\u0915\u093E \u0932\u0949\u091F \u092B\u094D\u0930\u0940 \u0939\u094B\u0917\u093E, \u0914\u0930 \u0907\u0938 \u092A\u094D\u0930\u0915\u093E\u0936\u0928 \u0915\u0947 \u092D\u093E\u0935 \u0906\u0917\u0947 \u091A\u0941\u0928\u0947 \u0928\u0939\u0940\u0902 \u091C\u093E \u0938\u0915\u0947\u0902\u0917\u0947\u0964 \u092C\u093E\u0926 \u092E\u0947\u0902 \u0932\u0949\u091F \u092B\u093F\u0930 \u0928\u090F \u092A\u094D\u0930\u0915\u093E\u0936\u0928 \u0915\u0947 \u0930\u0942\u092A \u092E\u0947\u0902 \u0921\u093E\u0932\u093E \u091C\u093E \u0938\u0915\u0924\u093E \u0939\u0948\u0964',
            '\u0939\u0940 \u0930\u093E\u0916\u0940\u0935 \u0930\u0926\u094D\u0926 \u0915\u0930\u093E\u092F\u091A\u0940? \u0935\u094D\u092F\u0935\u0939\u093E\u0930 \u0938\u0902\u092A\u0932\u0947\u0932, \u0924\u0941\u092E\u091A\u093E \u0932\u0949\u091F \u092E\u0941\u0915\u094D\u0924 \u0939\u094B\u0908\u0932, \u0935 \u092F\u093E \u092A\u094D\u0930\u0915\u093E\u0936\u0928\u093E\u091A\u094D\u092F\u0947 \u0926\u0930 \u092A\u0941\u0922\u0947 \u0928\u093F\u0935\u0921\u0924\u093E \u092F\u0947\u0923\u093E\u0930 \u0928\u093E\u0939\u0940\u0924. \u092A\u0941\u0922\u0947 \u0932\u0949\u091F \u0928\u0935\u0940\u0928 \u091C\u093E\u0939\u093F\u0930\u093E\u0924\u0940\u0938\u093E\u0920\u0940 \u091F\u093E\u0915\u0932\u093E \u0936\u0915\u0924\u094B.',
          ),
        ) ||
        !context.mounted)
      return;
    final out = await DirectSellSelectionService().cancelReservation(sale.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(selectionOutcomeMessage(out))));
  }

  Future<void> _startHandover(BuildContext context) async {
    final w = await _askWeight(context, null);
    if (w == null || !context.mounted) return;
    final out = await DirectSellHandoverService().proposeHandover(
      saleId: sale.id,
      finalWeightKg: w,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(handoverOutcomeMessage(out))));
  }

  Future<void> _editWeight(
    BuildContext context,
    double? current,
    int revision,
  ) async {
    final w = await _askWeight(context, current);
    if (w == null || !context.mounted) return;
    final out = await DirectSellHandoverService().reviseHandoverWeight(
      saleId: sale.id,
      finalWeightKg: w,
      revision: revision,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(handoverOutcomeMessage(out))));
  }

  Future<double?> _askWeight(BuildContext context, double? initial) async {
    final controller = TextEditingController(
      text: initial == null ? '' : initial.toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(
          ct(
            'Final handover weight',
            'अंतिम हैंडओवर वज़न',
            'अंतिम हस्तांतरण वजन',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ct(
                'Enter the REAL weight in kilograms that physically changes hands. The selected recycler confirms this exact figure.',
                'हाथ में दी जाने वाली असली मात्रा किलोग्राम में भरें। चुना गया रीसायकलकर्ता इसी आँकड़े की पुष्टि करेगा।',
                'प्रत्यक्ष हातात दिले जाणारे खरे वजन किलोग्रॅममध्ये भरा. निवडलेला रीसायकलर याच आकड्याची पुष्टी करेल.',
              ),
            ),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'kg'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: Text(ct('Cancel', 'रद्द करें', 'रद्द करा')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dc, true),
            child: Text(ct('Save', 'सहेजें', 'जतन करा')),
          ),
        ],
      ),
    );
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    controller.dispose();
    if (ok != true) return null;
    if (value == null || value <= 0 || value > 10000) return null;
    return value;
  }
}

String handoverOutcomeMessage(HandoverOutcome out) => switch (out) {
  HandoverOutcome.proposed => ct(
    'Handover started. Waiting for the buyer to confirm receipt.',
    'हैंडओवर शुरू। खरीदार के पुष्टि करने का इंतज़ार।',
    'हस्तांतरण सुरू. खरेदीदाराच्या पुष्टीची प्रतीक्षा.',
  ),
  HandoverOutcome.alreadyPending => ct(
    'Handover is already in progress.',
    'हैंडओवर पहले से जारी है।',
    'हस्तांतरण आधीच सुरू आहे.',
  ),
  HandoverOutcome.weightRevised => ct(
    'Final weight updated.',
    'अंतिम वज़न बदल गया।',
    'अंतिम वजन बदलले.',
  ),
  HandoverOutcome.confirmed => ct(
    'Handover confirmed. The deal is complete.',
    'हैंडओवर पुष्ट। सौदा पूरा हुआ।',
    'हस्तांतरण पुष्ट. सौदा पूर्ण.',
  ),
  HandoverOutcome.alreadyCompleted => ct(
    'This deal is already complete.',
    'यह सौदा पहले ही पूरा है।',
    'हा सौदा आधीच पूर्ण आहे.',
  ),
  HandoverOutcome.revisionChanged => ct(
    'The handover details changed meanwhile. Refresh and check.',
    'इस दौरान हैंडओवर विवरण बदल गया। रीफ्रेश करके देखें।',
    'यादरम्यान हस्तांतरण तपशील बदलला. रिफ्रेश करून पहा.',
  ),
  HandoverOutcome.invalidWeight => ct(
    'Enter a valid weight in kg (more than 0, up to 10000).',
    'वैध वज़न किलोग्राम में भरें (0 से अधिक, 10000 तक)।',
    'वैध वजन किलोग्रॅममध्ये भरा (0 पेक्षा जास्त, 10000 पर्यंत).',
  ),
  HandoverOutcome.unconfirmed => ct(
    'Not confirmed yet — the action may still complete. Reopen the details before retrying.',
    'अभी पुष्टि नहीं — कार्यवाही पूरी हो सकती है। दोबारा कोशिश से पहले विवरण फिर खोलें।',
    'अद्याप पुष्टी नाही — कृती पूर्ण होऊ शकते. पुन्हा प्रयत्नापूर्वी तपशील पुन्हा उघडा.',
  ),
  _ => ct(
    'Action did not complete. Reload and try again.',
    'कार्यवाही पूरी नहीं हुई। रीलोड करके फिर कोशिश करें।',
    'कृती पूर्ण झाली नाही. रीलोड करून पुन्हा प्रयत्न करा.',
  ),
};

String selectionOutcomeMessage(SelectionOutcome out) => switch (out) {
  SelectionOutcome.selected => ct(
    'Buyer selected. The lot is now reserved for them.',
    '\u0916\u0930\u0940\u0926\u093E\u0930 \u091A\u0941\u0928\u093E \u0917\u092F\u093E\u0964 \u0932\u0949\u091F \u0905\u092D\u0940 \u0909\u0928\u0915\u0947 \u0932\u093F\u090F \u0906\u0930\u0915\u094D\u0937\u093F\u0924 \u0939\u0948\u0964',
    '\u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0928\u093F\u0935\u0921\u0932\u093E. \u0932\u0949\u091F \u0906\u0924\u093E\u092A\u0932\u0940 \u0924\u094D\u092F\u093E\u0902\u091A\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u0930\u093E\u0916\u0940\u0935.',
  ),
  SelectionOutcome.alreadySelected => ct(
    'This buyer was already selected.',
    '\u092F\u0939 \u0916\u0930\u0940\u0926\u093E\u0930 \u092A\u0939\u0932\u0947 \u0938\u0947 \u091A\u0941\u0928\u093E \u0917\u092F\u093E \u0939\u0948\u0964',
    '\u0939\u093E \u0916\u0930\u0947\u0926\u0940\u0926\u093E\u0930 \u0906\u0927\u0940\u091A \u0928\u093F\u0935\u0921\u0932\u093E\u0939\u094B\u0924\u093E.',
  ),
  SelectionOutcome.cancelled => ct(
    'Reservation cancelled. The lot is free.',
    '\u0906\u0930\u0915\u094D\u0937\u0923 \u0930\u0926\u094D\u0926 \u0939\u0941\u0906\u0964 \u0932\u0949\u091F \u092B\u094D\u0930\u0940 \u0939\u0948\u0964',
    '\u0930\u093E\u0916\u0940\u0935 \u0930\u0926\u094D\u0926. \u0932\u0949\u091F \u092E\u0941\u0915\u094D\u0924.',
  ),
  SelectionOutcome.alreadyCancelled => ct(
    'Already released.',
    '\u092A\u0939\u0932\u0947 \u0939\u0940 \u092B\u094D\u0930\u0940 \u0939\u0948\u0964',
    '\u0906\u0927\u0940\u091A \u092E\u0941\u0915\u094D\u0924.',
  ),
  SelectionOutcome.declined => ct(
    'Declined. The lot is open again.',
    '\u0907\u0928\u0915\u093E\u0930 \u0915\u093F\u092F\u093E\u0964 \u0932\u0949\u091F \u092B\u093F\u0930 \u0916\u0941\u0932\u093E \u0939\u0948\u0964',
    '\u0928\u093E\u0915\u093E\u0930\u0932\u0947. \u0932\u0949\u091F \u092A\u0941\u0928\u094D\u0939\u093E \u0916\u0941\u0932\u094D\u0932\u093E.',
  ),
  SelectionOutcome.quoteExpired => ct(
    'This quote has expired. Choose another valid quote.',
    '\u092F\u0939 \u092D\u093E\u0935 \u0938\u092E\u092F \u0938\u092E\u093E\u092A\u094D\u0924 \u0939\u0948\u0964 \u0926\u0942\u0938\u0930\u093E \u0935\u0948\u0927 \u092D\u093E\u0935 \u091A\u0941\u0928\u0947\u0902\u0964',
    '\u0939\u094D\u092F\u093E \u0926\u0930\u093E\u091A\u0940 \u092E\u0941\u0926\u0924 \u0938\u0902\u092A\u0932\u0940. \u0926\u0941\u0938\u0930\u093E \u0935\u0948\u0927 \u0926\u0930 \u0928\u093F\u0935\u0921\u093E.',
  ),
  SelectionOutcome.listingChanged || SelectionOutcome.lotChanged => ct(
    'The listing changed meanwhile. Reload and check the current state.',
    '\u0907\u0938 \u0926\u094C\u0930\u093E\u0928 \u0938\u0942\u091A\u0940 \u092C\u0926\u0932 \u0917\u0908\u0964 \u0930\u0940\u0932\u094B\u0921 \u0915\u0930\u0915\u0947 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0938\u094D\u0925\u093F\u0924\u093F \u0926\u0947\u0916\u0947\u0902\u0964',
    '\u092F\u093E\u0926\u0930\u092E\u094D\u092F\u093E\u0924 \u091C\u093E\u0939\u093F\u0930\u093E\u0924 \u092C\u0926\u0932\u0932\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0921 \u0915\u0930\u0942\u0928 \u0938\u0927\u094D\u092F\u0940 \u0938\u094D\u0925\u093F\u0924\u0940 \u0924\u092A\u093E\u0938\u093E.',
  ),
  SelectionOutcome.unconfirmed => ct(
    'Not confirmed yet \u2014 the action may still complete. Reopen the details before retrying.',
    '\u0905\u092D\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u2014 \u0915\u093E\u0930\u094D\u0930\u0935\u093E\u0908 \u092A\u0942\u0930\u0940 \u0939\u094B \u0938\u0915\u0924\u0940 \u0939\u0948\u0964 \u0926\u0941\u092C\u093E\u0930\u093E \u0915\u094B\u0936\u093F\u0936 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0935\u093F\u0935\u0930\u0923 \u092B\u093F\u0930 \u0916\u094B\u0932\u0947\u0902\u0964',
    '\u0905\u091C\u0942\u0928 \u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940 \u2014 \u0915\u0943\u0924\u0940 \u092A\u0942\u0930\u094D\u0923 \u0939\u094B\u090A \u0936\u0915\u0924\u0947. \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928\u093E\u092A\u0942\u0930\u094D\u0935 \u0924\u092A\u0936\u0940\u0932 \u092A\u0941\u0928\u094D\u0939\u093E \u0909\u0918\u0921\u093E.',
  ),
  SelectionOutcome.listingUnavailable ||
  SelectionOutcome.notOwner ||
  SelectionOutcome.notSelectedParty ||
  SelectionOutcome.quoteMissing => ct(
    'This action is not available on the current listing.',
    '\u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0938\u0942\u091A\u0940 \u092A\u0930 \u092F\u0939 \u0915\u093E\u0930\u094D\u0930\u0935\u093E\u0908 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964',
    '\u0938\u0927\u094D\u092F\u093E \u091C\u093E\u0939\u093F\u0930\u093E\u0924\u0940\u0935\u0930 \u0939\u0940 \u0915\u0943\u0924\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940.',
  ),
  _ => ct(
    'Action did not complete. Reload and try again.',
    '\u0915\u093E\u0930\u094D\u0930\u0935\u093E\u0908 \u092A\u0942\u0930\u0940 \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964 \u0930\u0940\u0932\u094B\u0921 \u0915\u0930\u0915\u0947 \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0915\u0930\u0947\u0902\u0964',
    '\u0915\u0943\u0924\u0940 \u092A\u0942\u0930\u094D\u0923 \u0928\u093E\u0939\u0940. \u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0921 \u0915\u0930\u0942\u0928 \u092A\u094D\u0930\u092F\u0924\u094D\u0928 \u0915\u0930\u093E.',
  ),
};

class PickupPlanPanel extends StatelessWidget {
  const PickupPlanPanel({
    required this.source,
    required this.sourceData,
    this.sale = false,
    super.key,
  });
  final DocumentReference<Map<String, dynamic>> source;
  final Map<String, dynamic> sourceData;
  final bool sale;
  bool get editable => sale
      ? sourceData['status'] == 'open' &&
            sourceData['expiresAt'] is Timestamp &&
            (sourceData['expiresAt'] as Timestamp).toDate().isAfter(
              DateTime.now(),
            )
      : ['proposed', 'quoted', 'accepted'].contains(sourceData['status']);
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid,
        ref = source.collection('pickupPlan').doc('current');
    final owner = uid != null && sourceData['collectorUid'] == uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(includeMetadataChanges: true),
      builder: (context, s) {
        final d = s.data?.data();
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ct(
                    'Pickup / delivery details',
                    '\u092A\u093F\u0915\u0905\u092A / \u0921\u093F\u0932\u0940\u0935\u0930\u0940 \u0935\u093F\u0935\u0930\u0923',
                    '\u092A\u093F\u0915\u0905\u092A / \u0921\u093F\u0932\u093F\u0935\u094D\u0939\u0930\u0940 \u0924\u092A\u0936\u0940\u0932',
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (s.hasError)
                  Text(
                    ct(
                      'Details unavailable. Check the updated rules and network.',
                      '\u0935\u093F\u0935\u0930\u0923 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0928\u090F \u0928\u093F\u092F\u092E \u0914\u0930 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                      '\u0924\u092A\u0936\u0940\u0932 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940. \u0928\u0935\u0940\u0928 \u0928\u093F\u092F\u092E \u0935 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0924\u092A\u093E\u0938\u093E.',
                    ),
                  )
                else if (!s.hasData)
                  const LinearProgressIndicator()
                else if (d == null)
                  Text(
                    ct(
                      'Location, preferred time and instructions have not been entered.',
                      '\u0938\u094D\u0925\u093E\u0928, \u092A\u0938\u0902\u0926\u0940\u0926\u093E \u0938\u092E\u092F \u0914\u0930 \u0928\u093F\u0930\u094D\u0926\u0947\u0936 \u0905\u092D\u0940 \u0928\u0939\u0940\u0902 \u092D\u0930\u0947 \u0917\u090F\u0964',
                      '\u0938\u094D\u0925\u093E\u0928, \u092A\u0938\u0902\u0924\u0940\u091A\u0940 \u0935\u0947\u0933 \u0935 \u0938\u0942\u091A\u0928\u093E \u0905\u0926\u094D\u092F\u093E\u092A \u092D\u0930\u0932\u0947\u0932\u094D\u092F\u093E \u0928\u093E\u0939\u0940\u0924.',
                    ),
                  )
                else ...[
                  if (s.data!.metadata.isFromCache ||
                      s.data!.metadata.hasPendingWrites)
                    Text(
                      ct(
                        'Cached / pending details',
                        '\u0915\u0948\u0936 / \u0932\u0902\u092C\u093F\u0924 \u0935\u093F\u0935\u0930\u0923',
                        '\u0915\u0945\u0936 / \u092A\u094D\u0930\u0932\u0902\u092C\u093F\u0924 \u0924\u092A\u0936\u0940\u0932',
                      ),
                    ),
                  Text(
                    sale
                        ? ct(
                            'Private collector notes \u2014 not shared with recyclers',
                            '\u0928\u093F\u091C\u0940 \u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0928\u094B\u091F\u094D\u0938 \u2014 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E\u0913\u0902 \u0938\u0947 \u0938\u093E\u091D\u093E \u0928\u0939\u0940\u0902',
                            '\u0916\u093E\u091C\u0917\u0940 \u0938\u0902\u0915\u0932\u0915 \u0928\u094B\u0902\u0926\u0940 \u2014 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0902\u0936\u0940 \u0936\u0947\u0905\u0930 \u0928\u093E\u0939\u0940',
                          )
                        : d['status'] == 'confirmed'
                        ? ct(
                            'Plan confirmed by the linked recycler',
                            '\u091C\u0941\u0921\u093C\u0947 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0928\u0947 \u092F\u094B\u091C\u0928\u093E \u092A\u0941\u0937\u094D\u091F \u0915\u0940',
                            '\u091C\u094B\u0921\u0932\u0947\u0932\u094D\u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0928\u0947 \u092F\u094B\u091C\u0928\u093E \u092A\u0941\u0937\u094D\u091F \u0915\u0947\u0932\u0940',
                          )
                        : ct(
                            'Collector proposal \u2014 not yet agreed by recycler',
                            '\u0938\u0902\u0917\u094D\u0930\u093E\u0939\u0915 \u0915\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u2014 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u0940 \u0938\u0939\u092E\u0924\u093F \u092C\u093E\u0915\u0940',
                            '\u0938\u0902\u0915\u0932\u0915\u093E\u091A\u093E \u092A\u094D\u0930\u0938\u094D\u0924\u093E\u0935 \u2014 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u0940 \u0938\u0902\u092E\u0924\u0940 \u092C\u093E\u0915\u0940',
                          ),
                  ),
                  const SizedBox(height: 12),
                  _detail(
                    Icons.location_on_outlined,
                    ct(
                      'Location',
                      '\u0938\u094D\u0925\u093E\u0928',
                      '\u0938\u094D\u0925\u093E\u0928',
                    ),
                    '${d['locationText']}',
                  ),
                  _detail(
                    Icons.schedule,
                    ct(
                      'Preferred time',
                      '\u092A\u0938\u0902\u0926\u0940\u0926\u093E \u0938\u092E\u092F',
                      '\u092A\u0938\u0902\u0924\u0940\u091A\u0940 \u0935\u0947\u0933',
                    ),
                    '${d['timeText']}',
                  ),
                  _detail(
                    Icons.notes,
                    ct(
                      'Instructions',
                      '\u0928\u093F\u0930\u094D\u0926\u0947\u0936',
                      '\u0938\u0942\u091A\u0928\u093E',
                    ),
                    '${d['note']}',
                  ),
                  if (d['confirmedAt'] is Timestamp)
                    Text(
                      '${ct('Confirmed', '\u092A\u0941\u0937\u094D\u091F\u093F', '\u092A\u0941\u0937\u094D\u091F\u0940')}: ${trackingDate(d['confirmedAt'])}',
                    ),
                  actionButton(
                    ct(
                      'Open in Maps',
                      'Maps \u092E\u0947\u0902 \u0916\u094B\u0932\u0947\u0902',
                      'Maps \u092E\u0927\u094D\u092F\u0947 \u0909\u0918\u0921\u093E',
                    ),
                    () => openTrackingMap(context, '${d['locationText']}'),
                    icon: Icons.map_outlined,
                  ),
                ],
                if (owner && editable)
                  actionButton(
                    ct(
                      'Enter / edit details',
                      '\u0935\u093F\u0935\u0930\u0923 \u092D\u0930\u0947\u0902 / \u092C\u0926\u0932\u0947\u0902',
                      '\u0924\u092A\u0936\u0940\u0932 \u092D\u0930\u093E / \u092C\u0926\u0932\u093E',
                    ),
                    () => openCollector(
                      context,
                      PickupPlanEditor(source: source, sale: sale),
                    ),
                  ),
                if (!sale &&
                    !owner &&
                    uid != null &&
                    sourceData['recyclerUid'] == uid &&
                    editable &&
                    d?['status'] == 'proposed' &&
                    s.hasData &&
                    !s.data!.metadata.isFromCache &&
                    !s.data!.metadata.hasPendingWrites)
                  actionButton(
                    ct(
                      'Confirm this plan',
                      '\u092F\u0939 \u092F\u094B\u091C\u0928\u093E \u092A\u0941\u0937\u094D\u091F \u0915\u0930\u0947\u0902',
                      '\u0939\u0940 \u092F\u094B\u091C\u0928\u093E \u092A\u0941\u0937\u094D\u091F \u0915\u0930\u093E',
                    ),
                    () async {
                      if (!await confirmAction(
                            context,
                            ct(
                              'Confirm this exact location, time and note? This does not confirm collection or payment.',
                              '\u0907\u0938\u0940 \u0938\u094D\u0925\u093E\u0928, \u0938\u092E\u092F \u0914\u0930 \u0928\u094B\u091F \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0915\u0930\u0947\u0902? \u0907\u0938\u0938\u0947 \u0938\u0902\u0917\u094D\u0930\u0939 \u092F\u093E \u092D\u0941\u0917\u0924\u093E\u0928 \u092A\u0941\u0937\u094D\u091F \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u093E\u0964',
                              '\u0939\u0947\u091A \u0938\u094D\u0925\u093E\u0928, \u0935\u0947\u0933 \u0935 \u0928\u094B\u0902\u0926 \u092A\u0941\u0937\u094D\u091F \u0915\u0930\u093E\u092F\u091A\u0940? \u092F\u093E\u0928\u0947 \u0938\u0902\u0915\u0932\u0928 \u0915\u093F\u0902\u0935\u093E \u092A\u0947\u092E\u0947\u0902\u091F \u092A\u0941\u0937\u094D\u091F \u0939\u094B\u0924 \u0928\u093E\u0939\u0940.',
                            ),
                          ) ||
                          !context.mounted)
                        return;
                      try {
                        await source.firestore
                            .runTransaction((t) async {
                              final current = await t.get(ref);
                              if (FirebaseAuth.instance.currentUser?.uid !=
                                      uid ||
                                  current.data()?['revision'] != d!['revision'])
                                throw StateError('plan-changed');
                              if (current.data()?['status'] == 'confirmed' &&
                                  current.data()?['confirmedBy'] == uid)
                                return;
                              t.update(ref, {
                                'status': 'confirmed',
                                'confirmedBy': uid,
                                'confirmedAt': FieldValue.serverTimestamp(),
                              });
                            })
                            .timeout(const Duration(seconds: 25));
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ct(
                                  'Not confirmed. Refresh and check the current plan.',
                                  '\u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u092F\u094B\u091C\u0928\u093E \u092B\u093F\u0930 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
                                  '\u092A\u0941\u0937\u094D\u091F\u0940 \u0928\u093E\u0939\u0940. \u0938\u0927\u094D\u092F\u093E\u091A\u0940 \u092F\u094B\u091C\u0928\u093E \u092A\u0941\u0928\u094D\u0939\u093E \u0924\u092A\u093E\u0938\u093E.',
                                ),
                              ),
                            ),
                          );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detail(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: collectorGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value.isEmpty ? '\u2014' : value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PickupPlanEditor extends StatefulWidget {
  const PickupPlanEditor({required this.source, this.sale = false, super.key});
  final DocumentReference<Map<String, dynamic>> source;
  final bool sale;
  @override
  State<PickupPlanEditor> createState() => _PickupPlanEditorState();
}

class _PickupPlanEditorState extends State<PickupPlanEditor> {
  final _location = TextEditingController(),
      _time = TextEditingController(),
      _note = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  int _revision = 0;
  bool _loading = true, _ready = false, _busy = false, _consent = false;
  String? _message;
  DocumentReference<Map<String, dynamic>> get _ref =>
      widget.source.collection('pickupPlan').doc('current');
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _location.dispose();
    _time.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final d = snap.data();
      _revision = (d?['revision'] as int?) ?? 0;
      _location.text = d?['locationText'] as String? ?? '';
      _time.text = d?['timeText'] as String? ?? '';
      _note.text = d?['note'] as String? ?? '';
      _ready = true;
    } catch (_) {
      _message = ct(
        'Connect to load current details before editing. Unsaved edits are not stored offline.',
        '\u092C\u0926\u0932\u0928\u0947 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0907\u0902\u091F\u0930\u0928\u0947\u091F \u0938\u0947 \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u0935\u093F\u0935\u0930\u0923 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902\u0964 \u092C\u093F\u0928\u093E \u0938\u0939\u0947\u091C\u0947 \u092C\u0926\u0932\u093E\u0935 \u0911\u092B\u0932\u093E\u0907\u0928 \u0928\u0939\u0940\u0902 \u0930\u0916\u0947 \u091C\u093E\u0924\u0947\u0964',
        '\u092C\u0926\u0932\u0923\u094D\u092F\u093E\u0906\u0927\u0940 \u0907\u0902\u091F\u0930\u0928\u0947\u091F\u0935\u0930\u0942\u0928 \u0938\u0927\u094D\u092F\u093E\u091A\u093E \u0924\u092A\u0936\u0940\u0932 \u0932\u094B\u0921 \u0915\u0930\u093E. \u0928 \u091C\u0924\u0928 \u0915\u0947\u0932\u0947\u0932\u0947 \u092C\u0926\u0932 \u0911\u092B\u0932\u093E\u0907\u0928 \u0920\u0947\u0935\u0932\u0947 \u091C\u093E\u0924 \u0928\u093E\u0939\u0940\u0924.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_ready || !_consent || _uid == null) return;
    final location = _location.text.trim(),
        time = _time.text.trim(),
        notes = _note.text.trim();
    if (location.isEmpty ||
        location.length > 240 ||
        time.isEmpty ||
        time.length > 120 ||
        notes.length > 500) {
      setState(
        () => _message = ct(
          'Enter location and preferred date/time within the limits.',
          '\u0938\u0940\u092E\u093E \u0915\u0947 \u092D\u0940\u0924\u0930 \u0938\u094D\u0925\u093E\u0928 \u0914\u0930 \u092A\u0938\u0902\u0926\u0940\u0926\u093E \u0924\u093E\u0930\u0940\u0916/\u0938\u092E\u092F \u092D\u0930\u0947\u0902\u0964',
          '\u092E\u0930\u094D\u092F\u093E\u0926\u0947\u0924 \u0938\u094D\u0925\u093E\u0928 \u0935 \u092A\u0938\u0902\u0924\u0940\u091A\u0940 \u0924\u093E\u0930\u0940\u0916/\u0935\u0947\u0933 \u092D\u0930\u093E.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.source.firestore
          .runTransaction((t) async {
            final old = await t.get(_ref), record = await t.get(widget.source);
            if (FirebaseAuth.instance.currentUser?.uid != _uid ||
                record.data()?['collectorUid'] != _uid ||
                ((old.data()?['revision'] as int?) ?? 0) != _revision)
              throw StateError('changed');
            t.set(_ref, {
              'schemaVersion': 1,
              'collectorUid': _uid,
              'locationText': location,
              'timeText': time,
              'note': notes,
              'revision': _revision + 1,
              'status': widget.sale ? 'private' : 'proposed',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 25));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => _message = ct(
            'Save not confirmed or details changed. The action may still complete after a timeout. Return to details and check before retrying.',
            '\u0938\u0939\u0947\u091C\u0928\u0947 \u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0928\u0939\u0940\u0902 \u092F\u093E \u0935\u093F\u0935\u0930\u0923 \u092C\u0926\u0932 \u0917\u090F\u0964 \u091F\u093E\u0907\u092E\u0906\u0909\u091F \u0915\u0947 \u092C\u093E\u0926 \u092D\u0940 \u0915\u093E\u092E \u092A\u0942\u0930\u093E \u0939\u094B \u0938\u0915\u0924\u093E \u0939\u0948\u0964 \u092B\u093F\u0930 \u0915\u094B\u0936\u093F\u0936 \u0938\u0947 \u092A\u0939\u0932\u0947 \u0935\u093F\u0935\u0930\u0923 \u092E\u0947\u0902 \u0935\u093E\u092A\u0938 \u091C\u093E\u0915\u0930 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
            '\u091C\u0924\u0928 \u092A\u0941\u0937\u094D\u091F \u0928\u093E\u0939\u0940 \u0915\u093F\u0902\u0935\u093E \u0924\u092A\u0936\u0940\u0932 \u092C\u0926\u0932\u0932\u093E. \u091F\u093E\u0907\u092E\u0906\u0909\u091F\u0928\u0902\u0924\u0930\u0939\u0940 \u0915\u0943\u0924\u0940 \u092A\u0942\u0930\u094D\u0923 \u0939\u094B\u090A \u0936\u0915\u0924\u0947. \u092A\u0941\u0928\u094D\u0939\u093E \u092A\u094D\u0930\u092F\u0924\u094D\u0928\u093E\u0906\u0927\u0940 \u0924\u092A\u0936\u0940\u0932\u093E\u0924 \u092A\u0930\u0924 \u091C\u093E\u090A\u0928 \u0924\u092A\u093E\u0938\u093E.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Pickup details',
      '\u092A\u093F\u0915\u0905\u092A \u0935\u093F\u0935\u0930\u0923',
      '\u092A\u093F\u0915\u0905\u092A \u0924\u092A\u0936\u0940\u0932',
    ),
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        note(
          widget.sale
              ? ct(
                  'Private notes for this listing. No recycler has been linked yet.',
                  '\u0907\u0938 \u0938\u0942\u091A\u0940 \u0915\u0947 \u0928\u093F\u091C\u0940 \u0928\u094B\u091F\u094D\u0938\u0964 \u0905\u092D\u0940 \u0915\u094B\u0908 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u091C\u0941\u0921\u093C\u093E \u0928\u0939\u0940\u0902 \u0939\u0948\u0964',
                  '\u092F\u093E \u091C\u093E\u0939\u093F\u0930\u093E\u0924\u0940\u091A\u094D\u092F\u093E \u0916\u093E\u091C\u0917\u0940 \u0928\u094B\u0902\u0926\u0940. \u0905\u091C\u0942\u0928 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u091C\u094B\u0921\u0932\u0947\u0932\u093E \u0928\u093E\u0939\u0940.',
                )
              : ct(
                  'These details are shared only with the linked, currently verified recycler. Editing resets their confirmation. Do not enter OTPs or bank details.',
                  '\u092F\u0947 \u0935\u093F\u0935\u0930\u0923 \u0915\u0947\u0935\u0932 \u091C\u0941\u0921\u093C\u0947, \u0935\u0930\u094D\u0924\u092E\u093E\u0928 \u092E\u0947\u0902 \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0938\u0947 \u0938\u093E\u091D\u093E \u0939\u094B\u0902\u0917\u0947\u0964 \u092C\u0926\u0932\u0928\u0947 \u0938\u0947 \u0909\u0928\u0915\u0940 \u092A\u0941\u0937\u094D\u091F\u093F \u0939\u091F\u0947\u0917\u0940\u0964 OTP \u092F\u093E \u092C\u0948\u0902\u0915 \u0935\u093F\u0935\u0930\u0923 \u0928 \u0932\u093F\u0916\u0947\u0902\u0964',
                  '\u0939\u0947 \u0924\u092A\u0936\u0940\u0932 \u092B\u0915\u094D\u0924 \u091C\u094B\u0921\u0932\u0947\u0932\u094D\u092F\u093E, \u0938\u0927\u094D\u092F\u093E \u0938\u0924\u094D\u092F\u093E\u092A\u093F\u0924 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0936\u0940 \u0936\u0947\u0905\u0930 \u0939\u094B\u0924\u0940\u0932. \u092C\u0926\u0932\u0932\u094D\u092F\u093E\u0938 \u0924\u094D\u092F\u093E\u0902\u091A\u0940 \u092A\u0941\u0937\u094D\u091F\u0940 \u0939\u091F\u0947\u0932. OTP \u0915\u093F\u0902\u0935\u093E \u092C\u0901\u0915 \u0924\u092A\u0936\u0940\u0932 \u0932\u093F\u0939\u0942 \u0928\u0915\u093E.',
                ),
        ),
        if (_loading) const LinearProgressIndicator(),
        TextField(
          controller: _location,
          enabled: _ready && !_busy,
          maxLength: 240,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: ct(
              'Location / address',
              '\u0938\u094D\u0925\u093E\u0928 / \u092A\u0924\u093E',
              '\u0938\u094D\u0925\u093E\u0928 / \u092A\u0924\u094D\u0924\u093E',
            ),
          ),
        ),
        TextField(
          controller: _time,
          enabled: _ready && !_busy,
          maxLength: 120,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: ct(
              'Preferred date and time',
              '\u092A\u0938\u0902\u0926\u0940\u0926\u093E \u0924\u093E\u0930\u0940\u0916 \u0914\u0930 \u0938\u092E\u092F',
              '\u092A\u0938\u0902\u0924\u0940\u091A\u0940 \u0924\u093E\u0930\u0940\u0916 \u0935 \u0935\u0947\u0933',
            ),
          ),
        ),
        TextField(
          controller: _note,
          enabled: _ready && !_busy,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: ct(
              'Instructions (optional)',
              '\u0928\u093F\u0930\u094D\u0926\u0947\u0936 (\u0935\u0948\u0915\u0932\u094D\u092A\u093F\u0915)',
              '\u0938\u0942\u091A\u0928\u093E (\u0910\u091A\u094D\u091B\u093F\u0915)',
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
                      'Consent changed',
                      '\u0938\u0939\u092E\u0924\u093F \u092C\u0926\u0932\u0940',
                      '\u0938\u0902\u092E\u0924\u0940 \u092C\u0926\u0932\u0932\u0940',
                    ),
                  );
                },
          title: Text(
            widget.sale
                ? ct(
                    'Save these as my private notes',
                    '\u0907\u0928\u094D\u0939\u0947\u0902 \u092E\u0947\u0930\u0947 \u0928\u093F\u091C\u0940 \u0928\u094B\u091F\u094D\u0938 \u0915\u0947 \u0930\u0942\u092A \u092E\u0947\u0902 \u0938\u0939\u0947\u091C\u0947\u0902',
                    '\u092F\u093E \u092E\u093E\u091D\u094D\u092F\u093E \u0916\u093E\u091C\u0917\u0940 \u0928\u094B\u0902\u0926\u0940 \u092E\u094D\u0939\u0923\u0942\u0928 \u091C\u0924\u0928 \u0915\u0930\u093E',
                  )
                : ct(
                    'I consent to share these details with this recycler',
                    '\u092E\u0948\u0902 \u0907\u0938 \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0938\u0947 \u092F\u0947 \u0935\u093F\u0935\u0930\u0923 \u0938\u093E\u091D\u093E \u0915\u0930\u0928\u0947 \u0915\u094B \u0938\u0939\u092E\u0924 \u0939\u0942\u0901',
                    '\u092E\u0940 \u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u0936\u0940 \u0939\u0947 \u0924\u092A\u0936\u0940\u0932 \u0936\u0947\u0905\u0930 \u0915\u0930\u0923\u094D\u092F\u093E\u0938 \u0938\u0939\u092E\u0924 \u0906\u0939\u0947',
                  ),
          ),
        ),
        if (_message != null) note(_message!),
        if (!_ready && !_loading)
          actionButton(
            ct(
              'Retry loading',
              '\u092B\u093F\u0930 \u0932\u094B\u0921 \u0915\u0930\u0947\u0902',
              '\u092A\u0941\u0928\u094D\u0939\u093E \u0932\u094B\u0921 \u0915\u0930\u093E',
            ),
            () {
              setState(() => _loading = true);
              unawaited(_load());
            },
          ),
        actionButton(
          ct(
            'Save details',
            '\u0935\u093F\u0935\u0930\u0923 \u0938\u0939\u0947\u091C\u0947\u0902',
            '\u0924\u092A\u0936\u0940\u0932 \u091C\u0924\u0928 \u0915\u0930\u093E',
          ),
          _busy || !_ready || !_consent ? null : _save,
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    ),
  );
}

class SellRequestDetailsScreen extends StatelessWidget {
  const SellRequestDetailsScreen({required this.ref, super.key});
  final DocumentReference<Map<String, dynamic>> ref;
  @override
  Widget build(BuildContext context) => CollectorPage(
    title: () => ct(
      'Request details & tracking',
      '\u0905\u0928\u0941\u0930\u094B\u0927 \u0935\u093F\u0935\u0930\u0923 \u0914\u0930 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917',
      '\u0935\u093F\u0928\u0902\u0924\u0940 \u0924\u092A\u0936\u0940\u0932 \u0935 \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917',
    ),
    body: (context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(includeMetadataChanges: true),
      builder: (context, s) {
        if (s.hasError)
          return note(
            ct(
              'Request unavailable. Check your account, rules and connection.',
              '\u0905\u0928\u0941\u0930\u094B\u0927 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u0939\u0940\u0902\u0964 \u0916\u093E\u0924\u093E, \u0928\u093F\u092F\u092E \u0914\u0930 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u091C\u093E\u0901\u091A\u0947\u0902\u0964',
              '\u0935\u093F\u0928\u0902\u0924\u0940 \u0909\u092A\u0932\u092C\u094D\u0927 \u0928\u093E\u0939\u0940. \u0916\u093E\u0924\u0947, \u0928\u093F\u092F\u092E \u0935 \u0928\u0947\u091F\u0935\u0930\u094D\u0915 \u0924\u092A\u093E\u0938\u093E.',
            ),
          );
        if (!s.hasData) return const LinearProgressIndicator();
        final d = s.data!.data();
        if (d == null)
          return note(
            ct(
              'Request not found',
              '\u0905\u0928\u0941\u0930\u094B\u0927 \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E',
              '\u0935\u093F\u0928\u0902\u0924\u0940 \u0938\u093E\u092A\u0921\u0932\u0940 \u0928\u093E\u0939\u0940',
            ),
          );
        final owner =
            d['collectorUid'] == FirebaseAuth.instance.currentUser?.uid;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RequestMaterialSummary(data: d, id: ref.id, sale: true),
            RequestProgress(
              data: d,
              sale: true,
              cached: s.data!.metadata.isFromCache,
              pending: s.data!.metadata.hasPendingWrites,
            ),
            if (owner) SellQuotesPanel(sale: ref, saleData: d),
            if (owner) PickupPlanPanel(source: ref, sourceData: d, sale: true),
            note(
              ct(
                'This listing does not reserve your goods. Return to My sell requests to withdraw it. No pickup or recycler response is invented.',
                '\u0907\u0938 \u0938\u0942\u091A\u0940 \u0938\u0947 \u0938\u093E\u092E\u093E\u0928 \u0906\u0930\u0915\u094D\u0937\u093F\u0924 \u0928\u0939\u0940\u0902 \u0939\u094B\u0924\u093E\u0964 \u0907\u0938\u0947 \u0935\u093E\u092A\u0938 \u0932\u0947\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u092E\u0947\u0930\u0940 \u092C\u093F\u0915\u094D\u0930\u0940 \u092E\u093E\u0901\u0917 \u092E\u0947\u0902 \u0932\u094C\u091F\u0947\u0902\u0964 \u092A\u093F\u0915\u0905\u092A \u092F\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u093E \u0915\u093E \u091C\u0935\u093E\u092C \u092C\u0928\u093E\u092F\u093E \u0928\u0939\u0940\u0902 \u0917\u092F\u093E \u0939\u0948\u0964',
                '\u092F\u093E \u091C\u093E\u0939\u093F\u0930\u093E\u0924\u0940\u0928\u0947 \u092E\u093E\u0932 \u0930\u093E\u0916\u0940\u0935 \u0939\u094B\u0924 \u0928\u093E\u0939\u0940. \u092E\u093E\u0917\u0947 \u0918\u0947\u0923\u094D\u092F\u093E\u0938\u093E\u0920\u0940 \u092E\u093E\u091D\u094D\u092F\u093E \u0935\u093F\u0915\u094D\u0930\u0940 \u092E\u093E\u0917\u0923\u094D\u092F\u093E\u0902\u0924 \u092A\u0930\u0924 \u091C\u093E. \u092A\u093F\u0915\u0905\u092A \u0915\u093F\u0902\u0935\u093E \u0930\u0940\u0938\u093E\u092F\u0915\u0932\u0915\u0930\u094D\u0924\u094D\u092F\u093E\u091A\u0947 \u0909\u0924\u094D\u0924\u0930 \u092C\u0928\u0935\u0932\u0947\u0932\u0947 \u0928\u093E\u0939\u0940.',
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Local preview only: no backend, no map launch, no real submission callback.
class DemoRequestDetailsScreen extends StatelessWidget {
  const DemoRequestDetailsScreen({
    required this.material,
    required this.city,
    required this.weightKg,
    this.sale = false,
    super.key,
  });
  final String material, city;
  final int weightKg;
  final bool sale;
  @override
  Widget build(BuildContext context) => CollectorPageLayout(
    title: ct(
      'DEMO details',
      '\u0921\u0947\u092E\u094B \u0935\u093F\u0935\u0930\u0923',
      '\u0921\u0947\u092E\u094B \u0924\u092A\u0936\u0940\u0932',
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: const Color(0xFFFFE8B3),
          child: Text(
            ct(
              'DEMO ONLY \u2014 fictional material. No request sent, no tracking events recorded.',
              '\u0915\u0947\u0935\u0932 \u0921\u0947\u092E\u094B \u2014 \u0915\u093E\u0932\u094D\u092A\u0928\u093F\u0915 \u0938\u093E\u092E\u0917\u094D\u0930\u0940\u0964 \u0915\u094B\u0908 \u0905\u0928\u0941\u0930\u094B\u0927 \u0928\u0939\u0940\u0902 \u092D\u0947\u091C\u093E \u0914\u0930 \u091F\u094D\u0930\u0948\u0915\u093F\u0902\u0917 \u0918\u091F\u0928\u093E \u0926\u0930\u094D\u091C \u0928\u0939\u0940\u0902 \u0939\u0941\u0908\u0964',
              '\u092B\u0915\u094D\u0924 \u0921\u0947\u092E\u094B \u2014 \u0915\u093E\u0932\u094D\u092A\u0928\u093F\u0915 \u0938\u093E\u0939\u093F\u0924\u094D\u092F. \u0935\u093F\u0928\u0902\u0924\u0940 \u092A\u093E\u0920\u0935\u0932\u0947\u0932\u0940 \u0928\u093E\u0939\u0940 \u0935 \u091F\u094D\u0930\u0945\u0915\u093F\u0902\u0917 \u0918\u091F\u0928\u093E \u0928\u094B\u0902\u0926\u0932\u0947\u0932\u094D\u092F\u093E \u0928\u093E\u0939\u0940\u0924.',
            ),
          ),
        ),
        RequestMaterialSummary(
          data: {'material': material, 'city': city, 'weightKg': weightKg},
          id: 'DEMO',
          sale: sale,
        ),
        RequestProgress(data: const {}, sale: sale),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              ct(
                'Location, preferred time and notes will appear here after entering real details. No sample address is sent to Maps.',
                '\u0935\u093E\u0938\u094D\u0924\u0935\u093F\u0915 \u0935\u093F\u0935\u0930\u0923 \u092D\u0930\u0928\u0947 \u092A\u0930 \u092F\u0939\u093E\u0901 \u0938\u094D\u0925\u093E\u0928, \u092A\u0938\u0902\u0926\u0940\u0926\u093E \u0938\u092E\u092F \u0914\u0930 \u0928\u094B\u091F\u094D\u0938 \u0926\u093F\u0916\u0947\u0902\u0917\u0947\u0964 \u0915\u094B\u0908 \u0928\u0915\u0932\u0940 \u092A\u0924\u093E Maps \u0915\u094B \u0928\u0939\u0940\u0902 \u092D\u0947\u091C\u093E \u091C\u093E\u0924\u093E\u0964',
                '\u092A\u094D\u0930\u0924\u094D\u092F\u0915\u094D\u0937 \u0924\u092A\u0936\u0940\u0932 \u092D\u0930\u0932\u094D\u092F\u093E\u0935\u0930 \u092F\u0947\u0925\u0947 \u0938\u094D\u0925\u093E\u0928, \u092A\u0938\u0902\u0924\u0940\u091A\u0940 \u0935\u0947\u0933 \u0935 \u0928\u094B\u0902\u0926\u0940 \u0926\u093F\u0938\u0924\u0940\u0932. \u092C\u0928\u093E\u0935\u091F \u092A\u0924\u094D\u0924\u093E Maps \u0932\u093E \u092A\u093E\u0920\u0935\u0932\u093E \u091C\u093E\u0924 \u0928\u093E\u0939\u0940.',
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: null,
          child: Text(
            ct(
              'Demo \u2014 sending disabled',
              '\u0921\u0947\u092E\u094B \u2014 \u092D\u0947\u091C\u0928\u093E \u092C\u0902\u0926',
              '\u0921\u0947\u092E\u094B \u2014 \u092A\u093E\u0920\u0935\u0923\u0947 \u092C\u0902\u0926',
            ),
          ),
        ),
      ],
    ),
  );
}

class ReceiptPanel extends StatelessWidget {
  const ReceiptPanel({required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DirectSellReceiptService().receiptRef(saleId).snapshots(),
      builder: (context, s) {
        if (s.hasError) {
          return note(
            ct(
              'Receipt could not load. Check connection and published rules.',
              'रसीद लोड नहीं हुई। कनेक्शन और प्रकाशित नियम जाँचें।',
              'पावती लोड झाली नाही. कनेक्शन व प्रकाशित नियम तपासा.',
            ),
          );
        }
        final r = s.data?.data();
        if (r != null) {
          final amount = r['amountPaise'] is num
              ? (r['amountPaise'] as num).round()
              : 0;
          final method = '${r['method'] ?? ''}';
          final at = r['recordedAt'] is Timestamp
              ? r['recordedAt'] as Timestamp
              : null;
          return note(
            ct(
              'Payment recorded: Rs ${formatPaiseAsRupees(amount)} via ${method.toUpperCase()}${at == null ? '' : ' · ' + trackingDate(at)}. Collector-recorded receipt - not bank verification.',
              'भुगतान दर्ज: Rs ${formatPaiseAsRupees(amount)} ${method.toUpperCase()} से${at == null ? '' : ' · ' + trackingDate(at)}। कलेक्टर-दर्ज रसीद - बैंक सत्यापन नहीं।',
              'पेमेंट नोंद: Rs ${formatPaiseAsRupees(amount)} ${method.toUpperCase()} द्वारे${at == null ? '' : ' · ' + trackingDate(at)}. कलेक्टर-नोंद पावती - बँक पडताळणी नाही.',
            ),
          );
        }
        return actionButton(
          ct(
            'Record payment received',
            'भुगतान मिला दर्ज करें',
            'पेमेंट मिळाले नोंदवा',
          ),
          () => showDialog<void>(
            context: context,
            builder: (_) => _ReceiptDialog(saleId: saleId),
          ),
          icon: Icons.receipt_long_outlined,
        );
      },
    );
  }
}

class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog({required this.saleId});
  final String saleId;
  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _ref = TextEditingController();
  String _method = 'cash';
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final v = double.tryParse(_amount.text.trim());
    if (v == null || v <= 0 || v > 10000000) {
      setState(
        () => _msg = ct(
          'Enter a valid amount in rupees (max 1,00,00,000).',
          'सही राशि रुपये में भरें (अधिकतम 1,00,00,000)।',
          'योग्य रक्कम रुपयांत भरा (कमाल 1,00,00,000).',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final out = await DirectSellReceiptService().recordReceipt(
      saleId: widget.saleId,
      amountPaise: (v * 100).round(),
      method: _method,
      reference: _ref.text.trim(),
    );
    if (!mounted) return;
    if (out == ReceiptOutcome.recorded) {
      AppSpeech.instance.say(
        ct('Payment recorded.', 'भुगतान दर्ज हुआ।', 'पेमेंट नोंदवले.'),
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _msg = _receiptMessage(out);
    });
  }

  String _receiptMessage(ReceiptOutcome o) {
    switch (o) {
      case ReceiptOutcome.alreadyRecorded:
        return ct(
          'Receipt already recorded for this deal.',
          'इस सौदे की रसीद पहले से दर्ज है।',
          'या सौद्याची पावती आधीच नोंदलेली आहे.',
        );
      case ReceiptOutcome.notOwner:
        return ct(
          'Only the collector of this deal can record its payment.',
          'सिर्फ इस सौदे का कलेक्टर भुगतान दर्ज कर सकता है।',
          'फक्त या सौद्याचा कलेक्टर पेमेंट नोंदवू शकतो.',
        );
      case ReceiptOutcome.notCompleted:
        return ct(
          'A receipt needs a completed deal.',
          'रसीद के लिए पूरा हुआ सौदा चाहिए।',
          'पावतीसाठी पूर्ण झालेला सौदा आवश्यक.',
        );
      case ReceiptOutcome.invalidAmount:
        return ct(
          'Enter a valid amount.',
          'सही राशि भरें।',
          'योग्य रक्कम भरा.',
        );
      case ReceiptOutcome.unconfirmed:
        return ct(
          'Not confirmed yet - reopen this page before retrying.',
          'अभी पुष्टि नहीं - दोबारा खोलकर जाँचें।',
          'अद्याप पुष्टी नाही - पुन्हा उघडून पहा.',
        );
      case ReceiptOutcome.failed:
        return ct(
          'Could not record the receipt. Try again.',
          'रसीद दर्ज नहीं हुई। दोबारा कोशिश करें।',
          'पावती नोंदवता आली नाही. पुन्हा प्रयत्न करा.',
        );
      case ReceiptOutcome.recorded:
        return ct('Payment recorded.', 'भुगतान दर्ज हुआ।', 'पेमेंट नोंदवले.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFAEF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        ct(
          'Record payment received',
          'भुगतान मिला दर्ज करें',
          'पेमेंट मिळाले नोंदवा',
        ),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ct(
              'This saves a collector-recorded receipt for the completed deal. It is NOT bank verification.',
              'यह पूरे हुए सौदे की कलेक्टर-दर्ज रसीद सहेजता है। यह बैंक सत्यापन नहीं है।',
              'हे पूर्ण सौद्याची कलेक्टर-नोंद पावती जतन करते. हे बँक पडताळणी नाही.',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF66756B)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: ct(
                'Amount received (Rs)',
                'मिली राशि (Rs)',
                'मिळालेली रक्कम (Rs)',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final m in ['cash', 'upi', 'bank'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selectedColor: const Color(0xFF286B3B),
                    labelStyle: TextStyle(
                      color: _method == m
                          ? Colors.white
                          : const Color(0xFF286B3B),
                      fontWeight: FontWeight.w700,
                    ),
                    label: Text(m.toUpperCase()),
                    selected: _method == m,
                    onSelected: (v) {
                      if (v) setState(() => _method = m);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ref,
            decoration: InputDecoration(
              labelText: ct(
                'Reference (optional)',
                'संदर्भ (वैकल्पिक)',
                'संदर्भ (ऐच्छिक)',
              ),
            ),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _msg!,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(ct('Cancel', 'रद्द करें', 'रद्द करा')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF286B3B),
          ),
          onPressed: _busy ? null : _save,
          child: Text(
            ct('Save receipt', 'रसीद सहेजें', 'पावती जतन करा'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
