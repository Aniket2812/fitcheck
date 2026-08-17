import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/saved_fit.dart';
import '../models/social_post.dart';
import 'ingest_service.dart';
import 'session_service.dart';
import 'social_service.dart';

typedef FetchSavedFits = Future<List<SavedFit>> Function();
typedef SaveFitDraft =
    Future<SavedFit> Function({
      required String caption,
      required String imageUrl,
      required List<PostGarment> garments,
      String? modelPhotoId,
    });
typedef PublishSavedFit =
    Future<SocialPost> Function(String fitId, String caption);
typedef DeleteSavedFit = Future<void> Function(String fitId);

abstract final class SavedFitService {
  static Future<List<SavedFit>> fetch() async {
    final response = await http
        .get(
          Uri.parse('${IngestService.apiUrl}/api/saved-fits'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final data = _json(response);
    _ensureSuccess(response, data);
    return (data['savedFits'] as List? ?? const [])
        .whereType<Map>()
        .map((fit) => _fit(Map<String, dynamic>.from(fit)))
        .toList();
  }

  static Future<SavedFit> save({
    required String caption,
    required String imageUrl,
    required List<PostGarment> garments,
    String? modelPhotoId,
  }) async {
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/saved-fits'),
          headers: {...await _headers(), 'content-type': 'application/json'},
          body: jsonEncode({
            'caption': caption,
            'imageUrl': _serverMedia(imageUrl),
            'garments': garments.map(_garmentPayload).toList(),
            'modelPhotoId': modelPhotoId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final data = _json(response);
    _ensureSuccess(response, data);
    return _fit(Map<String, dynamic>.from(data['savedFit'] as Map? ?? {}));
  }

  static Future<SocialPost> publish(String fitId, String caption) async {
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/saved-fits/$fitId/publish'),
          headers: {...await _headers(), 'content-type': 'application/json'},
          body: jsonEncode({'caption': caption}),
        )
        .timeout(const Duration(seconds: 300));
    final data = _json(response);
    _ensureSuccess(response, data);
    return SocialService.postFromJson(
      Map<String, dynamic>.from(data['post'] as Map? ?? {}),
    );
  }

  static Future<void> delete(String fitId) async {
    final response = await http
        .delete(
          Uri.parse('${IngestService.apiUrl}/api/saved-fits/$fitId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 204) return;
    _ensureSuccess(response, _json(response));
  }

  static SavedFit _fit(Map<String, dynamic> json) {
    json['imageUrl'] = SocialService.mediaUrl(
      json['imageUrl']?.toString() ?? '',
    );
    final garments = json['garments'];
    if (garments is List) {
      for (final garment in garments.whereType<Map>()) {
        garment['imageUrl'] = SocialService.mediaUrl(
          garment['imageUrl']?.toString() ?? '',
        );
        garment['productImageUrls'] =
            (garment['productImageUrls'] as List? ?? const [])
                .map((value) => SocialService.mediaUrl(value.toString()))
                .where((value) => value.isNotEmpty)
                .toList();
      }
    }
    return SavedFit.fromJson(json);
  }

  static Map<String, dynamic> _garmentPayload(PostGarment garment) {
    final json = garment.toJson();
    json['imageUrl'] = _serverMedia(garment.imageUrl);
    json['productImageUrls'] = garment.productImageUrls
        .map(_serverMedia)
        .toList();
    return json;
  }

  static String _serverMedia(String value) =>
      value.startsWith(IngestService.apiUrl)
      ? value.substring(IngestService.apiUrl.length)
      : value;

  static Future<Map<String, String>> _headers() async {
    final session = await SessionService.ensureSession();
    return {'authorization': 'Bearer ${session.token}'};
  }

  static Map<String, dynamic> _json(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
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
        data['error']?.toString() ?? 'Your saved fits need a quick retry.',
      );
    }
  }
}
