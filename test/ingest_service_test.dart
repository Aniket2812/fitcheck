import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:youcam2/services/ingest_service.dart';

class _RedirectResponse extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _RedirectResponse({required this.url, required http.BaseRequest request})
    : super(const Stream<List<int>>.empty(), 200, request: request);

  @override
  final Uri url;
}

class _RedirectClient extends http.BaseClient {
  _RedirectClient(this.destination);

  final Uri destination;
  Uri? requested;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested = request.url;
    return _RedirectResponse(url: destination, request: request);
  }
}

class _FailingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('blocked');
  }
}

void main() {
  test('debug builds use the ADB-reversed local API by default', () {
    expect(kDebugMode, isTrue);
    expect(IngestService.apiUrl, 'http://127.0.0.1:8787');
  });

  test('expands Flipkart share links before sending them to the API', () async {
    const shared = 'https://dl.flipkart.com/s/example';
    final destination = Uri.parse(
      'https://www.flipkart.com/black-t-shirt/p/item?pid=TSH123',
    );
    final client = _RedirectClient(destination);

    final result = await IngestService.expandProductLink(
      shared,
      client: client,
    );

    expect(client.requested, Uri.parse(shared));
    expect(result, destination.toString());
  });

  test('keeps the original short link if device expansion fails', () async {
    const shared = 'https://dl.flipkart.com/s/example';
    expect(
      await IngestService.expandProductLink(shared, client: _FailingClient()),
      shared,
    );
  });

  test('does not prefetch an ordinary product URL', () async {
    const product = 'https://www.flipkart.com/black-t-shirt/p/item';
    expect(
      await IngestService.expandProductLink(product, client: _FailingClient()),
      product,
    );
  });
}
