import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/closet_item.dart';
import '../models/fashion_collection.dart';
import 'ingest_service.dart';
import 'session_service.dart';

typedef FetchCollections = Future<List<FashionCollection>> Function();
typedef CreateFashionCollection =
    Future<FashionCollection> Function(String name);
typedef SaveCollectionItem =
    Future<CollectionItem> Function(String collectionId, ClosetItem item);
typedef DeleteCollectionItem =
    Future<void> Function(String collectionId, String itemId);

abstract final class CollectionService {
  static Future<List<FashionCollection>> fetchCollections() async {
    final response = await http
        .get(
          Uri.parse('${IngestService.apiUrl}/api/collections'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final data = _json(response);
    _ensureSuccess(response, data);
    return (data['collections'] as List? ?? const [])
        .whereType<Map>()
        .map((collection) => _collection(Map<String, dynamic>.from(collection)))
        .toList();
  }

  static Future<FashionCollection> createCollection(String name) async {
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/collections'),
          headers: {...await _headers(), 'content-type': 'application/json'},
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 20));
    final data = _json(response);
    _ensureSuccess(response, data);
    return _collection(
      Map<String, dynamic>.from(data['collection'] as Map? ?? {}),
    );
  }

  static Future<CollectionItem> addItem(
    String collectionId,
    ClosetItem item,
  ) async {
    final response = await http
        .post(
          Uri.parse(
            '${IngestService.apiUrl}/api/collections/$collectionId/items',
          ),
          headers: {...await _headers(), 'content-type': 'application/json'},
          body: jsonEncode({
            'id': item.id,
            'title': item.title,
            'brand': item.brand,
            'price': item.price,
            'imageUrl': item.image,
            'originalImageUrl': item.originalImage,
            'productImageUrls': item.productImageUrls
                .map(_serverMedia)
                .toList(),
            'buyUrl': item.pageUrl,
            'category': item.category,
          }),
        )
        .timeout(const Duration(seconds: 45));
    final data = _json(response);
    _ensureSuccess(response, data);
    return _item(Map<String, dynamic>.from(data['item'] as Map? ?? {}));
  }

  static Future<void> deleteItem(String collectionId, String itemId) async {
    final response = await http
        .delete(
          Uri.parse(
            '${IngestService.apiUrl}/api/collections/$collectionId/items/$itemId',
          ),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 204) return;
    _ensureSuccess(response, _json(response));
  }

  static Future<Map<String, String>> _headers() async {
    final session = await SessionService.ensureSession();
    return {'authorization': 'Bearer ${session.token}'};
  }

  static FashionCollection _collection(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is List) {
      for (final item in items.whereType<Map>()) {
        item['imageUrl'] = _media(item['imageUrl']?.toString() ?? '');
        item['productImageUrls'] = _mediaList(item['productImageUrls']);
      }
    }
    return FashionCollection.fromJson(json);
  }

  static CollectionItem _item(Map<String, dynamic> json) {
    json['imageUrl'] = _media(json['imageUrl']?.toString() ?? '');
    json['productImageUrls'] = _mediaList(json['productImageUrls']);
    return CollectionItem.fromJson(json);
  }

  static String _media(String value) =>
      value.startsWith('/') ? '${IngestService.apiUrl}$value' : value;

  static String _serverMedia(String value) =>
      value.startsWith(IngestService.apiUrl)
      ? value.substring(IngestService.apiUrl.length)
      : value;

  static List<String> _mediaList(Object? values) =>
      (values as List? ?? const [])
          .map((value) => _media(value.toString()))
          .where((value) => value.isNotEmpty)
          .toList();

  static Map<String, dynamic> _json(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static void _ensureSuccess(
    http.Response response,
    Map<String, dynamic> data,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'Your collections need a quick retry.',
      );
    }
  }
}
