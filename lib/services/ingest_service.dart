import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/closet_item.dart';

typedef IngestLink = Future<ClosetItem> Function(String url);

abstract final class IngestService {
  static const productionApiUrl = 'https://youcam2.15-206-240-61.sslip.io';

  static String get apiUrl {
    const configured = String.fromEnvironment('API_URL');
    if (configured.isNotEmpty) return configured;
    return productionApiUrl;
  }

  static Future<ClosetItem> ingest(String url) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$apiUrl/api/ingest'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          // The server bounds its individual stages and can legitimately
          // spend up to four minutes in the image provider. Wait beyond the
          // server's total ceiling so its useful stage error reaches the UI.
          .timeout(const Duration(seconds: 390));
    } on TimeoutException {
      throw Exception(
        'This link is taking longer than usual. Give it another go in a moment.',
      );
    } catch (_) {
      throw Exception(
        'We couldn’t open that product right now. Try again shortly.',
      );
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // A non-JSON response falls through to the server error below.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ??
            'We couldn’t pull that product in. Check the link and try again.',
      );
    }

    data['productImageUrls'] = (data['productImageUrls'] as List? ?? const [])
        .map((value) {
          final url = value.toString();
          return url.startsWith('/') ? '$apiUrl$url' : url;
        })
        .toList();
    return ClosetItem.fromJson(data);
  }
}
