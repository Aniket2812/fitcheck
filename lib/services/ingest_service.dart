import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/closet_item.dart';

typedef IngestLink = Future<ClosetItem> Function(String url);

abstract final class IngestService {
  static const productionApiUrl = 'https://youcam2.15-206-240-61.sslip.io';
  static const _redirectHosts = {
    'a.co',
    'ajio.me',
    'amzn.in',
    'amzn.to',
    'bit.ly',
    'dl.flipkart.com',
    'fkrt.cc',
    'fkrt.it',
    'myntr.it',
    's.shein.com',
    'shein.top',
    'shop.app',
  };

  static String get apiUrl {
    const configured = String.fromEnvironment('API_URL');
    if (configured.isNotEmpty) return configured;
    // Android debug builds reach the development server through
    // `adb reverse tcp:8787 tcp:8787`. Keeping this automatic prevents local
    // testing from silently hitting the production scraper, whose cloud IP is
    // more likely to receive retailer bot challenges.
    if (kDebugMode) return 'http://127.0.0.1:8787';
    return productionApiUrl;
  }

  /// Retail shorteners often reject AWS addresses even though they redirect
  /// normally on the shopper's connection. Expand them on-device so the API
  /// receives the product slug and ID that OpenAI needs to identify the item.
  @visibleForTesting
  static Future<String> expandProductLink(
    String value, {
    http.Client? client,
  }) async {
    final original = Uri.tryParse(value.trim());
    if (original == null || !_isRedirectHost(original.host)) return value;

    final requestClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final request = http.Request('GET', original)
        ..followRedirects = true
        ..maxRedirects = 8
        ..headers.addAll(const {
          'user-agent':
              'Mozilla/5.0 AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36',
          'accept': 'text/html,application/xhtml+xml,*/*',
        });
      final response = await requestClient
          .send(request)
          .timeout(const Duration(seconds: 20));
      final resolved = switch (response) {
        http.BaseResponseWithUrl(:final url) => url,
        _ => original,
      };
      await response.stream.drain<void>();
      if ((resolved.scheme == 'http' || resolved.scheme == 'https') &&
          resolved != original) {
        return resolved.toString();
      }
    } catch (_) {
      // The server still has its own resolver and OpenAI fallback.
    } finally {
      if (ownsClient) requestClient.close();
    }
    return value;
  }

  static bool _isRedirectHost(String value) {
    final host = value.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return _redirectHosts.contains(host) ||
        host.endsWith('.app.link') ||
        host.endsWith('.onelink.me');
  }

  static Future<ClosetItem> ingest(String url) async {
    http.Response response;
    try {
      final productUrl = await expandProductLink(url);
      response = await http
          .post(
            Uri.parse('$apiUrl/api/ingest'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'url': productUrl}),
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
