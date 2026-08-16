import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/closet_item.dart';

typedef IngestLink = Future<ClosetItem> Function(String url);

abstract final class IngestService {
  static String get apiUrl {
    const configured = String.fromEnvironment('API_URL');
    if (configured.isNotEmpty) return configured;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://localhost:8787';
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
        'The server did not finish within 6½ minutes. Check its ingest logs before retrying.',
      );
    } catch (_) {
      throw Exception("Can't reach the fitterest server at $apiUrl.");
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // A non-JSON response falls through to the server error below.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'Something went wrong.');
    }

    return ClosetItem.fromJson(data);
  }
}
