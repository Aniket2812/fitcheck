import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/model_photo.dart';
import '../models/social_post.dart';
import 'ingest_service.dart';
import 'session_service.dart';

typedef CheckYouCamConfigured = Future<bool> Function();
typedef GenerateYouCamLook =
    Future<String> Function({
      XFile? photo,
      ModelPhoto? modelPhoto,
      required PostGarment garment,
    });

abstract final class SocialService {
  static String mediaUrl(String value) {
    if (value.startsWith('/')) return '${IngestService.apiUrl}$value';
    return value;
  }

  static Future<List<SocialPost>> fetchPosts() async {
    final session = await SessionService.ensureSession();
    final response = await http
        .get(
          Uri.parse('${IngestService.apiUrl}/api/posts'),
          headers: {'authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 20));
    final data = _json(response);
    _ensureSuccess(response, data);
    return (data['posts'] as List? ?? const [])
        .whereType<Map>()
        .map((post) => _post(Map<String, dynamic>.from(post)))
        .toList();
  }

  static Future<SocialPost> createPost({
    required XFile? photo,
    String? photoUrl,
    required String caption,
    required List<PostGarment> garments,
  }) async {
    final session = await SessionService.ensureSession();
    if (photoUrl != null) {
      final response = await http
          .post(
            Uri.parse('${IngestService.apiUrl}/api/posts'),
            headers: {
              'authorization': 'Bearer ${session.token}',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'caption': caption,
              'imageUrl': photoUrl.startsWith(IngestService.apiUrl)
                  ? photoUrl.substring(IngestService.apiUrl.length)
                  : photoUrl,
              'garments': garments.map((item) => item.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = _json(response);
      _ensureSuccess(response, data);
      return _post(Map<String, dynamic>.from(data['post'] as Map));
    }
    if (photo == null) throw Exception('Choose an outfit photo.');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${IngestService.apiUrl}/api/posts'),
    );
    request.headers['authorization'] = 'Bearer ${session.token}';
    request.fields['caption'] = caption;
    request.fields['garments'] = jsonEncode(
      garments.map((item) => item.toJson()).toList(),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await photo.readAsBytes(),
        filename: photo.name,
        contentType: _mediaType(photo.name, photo.mimeType),
      ),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final data = _json(response);
    _ensureSuccess(response, data);
    return _post(Map<String, dynamic>.from(data['post'] as Map));
  }

  static Future<SocialPost> toggleLike(String postId) async {
    final session = await SessionService.ensureSession();
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/posts/$postId/like'),
          headers: {'authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));
    final data = _json(response);
    _ensureSuccess(response, data);
    return _post(Map<String, dynamic>.from(data['post'] as Map));
  }

  static Future<SocialPost> addComment(String postId, String text) async {
    final session = await SessionService.ensureSession();
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/posts/$postId/comments'),
          headers: {
            'authorization': 'Bearer ${session.token}',
            'content-type': 'application/json',
          },
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _json(response);
    _ensureSuccess(response, data);
    return _post(Map<String, dynamic>.from(data['post'] as Map));
  }

  static Future<bool> youCamConfigured() async {
    try {
      final response = await http
          .get(Uri.parse('${IngestService.apiUrl}/api/try-on/config'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200 &&
          _json(response)['configured'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> createYouCamLook({
    XFile? photo,
    ModelPhoto? modelPhoto,
    required PostGarment garment,
  }) async {
    final reference = garment.originalImageUrl;
    if (reference == null || !reference.startsWith('http')) {
      throw Exception('This garment has no public reference image for YouCam.');
    }
    final session = await SessionService.ensureSession();
    if (modelPhoto != null) {
      final response = await http
          .post(
            Uri.parse('${IngestService.apiUrl}/api/try-on/model'),
            headers: {
              'authorization': 'Bearer ${session.token}',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'modelPhotoId': modelPhoto.id,
              'garmentUrl': reference,
              'category': _youCamCategory(garment),
            }),
          )
          .timeout(const Duration(minutes: 4));
      final data = _json(response);
      _ensureSuccess(response, data);
      return mediaUrl(data['imageUrl'].toString());
    }
    if (photo == null) throw Exception('Choose a full-body photo.');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${IngestService.apiUrl}/api/try-on'),
    );
    request.headers['authorization'] = 'Bearer ${session.token}';
    request.fields['garmentUrl'] = reference;
    request.fields['category'] = _youCamCategory(garment);
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        await photo.readAsBytes(),
        filename: photo.name,
        contentType: _mediaType(photo.name, photo.mimeType),
      ),
    );
    final streamed = await request.send().timeout(const Duration(minutes: 4));
    final response = await http.Response.fromStream(streamed);
    final data = _json(response);
    _ensureSuccess(response, data);
    return mediaUrl(data['imageUrl'].toString());
  }

  static SocialPost _post(Map<String, dynamic> json) {
    json['imageUrl'] = mediaUrl(json['imageUrl']?.toString() ?? '');
    final garments = json['garments'];
    if (garments is List) {
      for (final garment in garments.whereType<Map>()) {
        garment['imageUrl'] = mediaUrl(garment['imageUrl']?.toString() ?? '');
      }
    }
    return SocialPost.fromJson(json);
  }

  static MediaType _mediaType(String name, String? supplied) {
    if (supplied == 'image/png' || name.toLowerCase().endsWith('.png')) {
      return MediaType('image', 'png');
    }
    return MediaType('image', 'jpeg');
  }

  static String _youCamCategory(PostGarment garment) {
    final value = '${garment.category ?? ''} ${garment.title}'.toLowerCase();
    if (RegExp(
      r'\b(shoe|shoes|sneaker|loafer|boot|sandal|heel)',
    ).hasMatch(value)) {
      return 'shoes';
    }
    if (RegExp(
      r'\b(ring|earring|bracelet|necklace|watch|bag|belt|sunglasses|accessor)',
    ).hasMatch(value)) {
      return 'accessory';
    }
    if (value.contains('bottom') ||
        value.contains('lower_body') ||
        RegExp(
          r'\b(jeans|trouser|pants|shorts|skirt|jogger|leggings)',
        ).hasMatch(value)) {
      return 'lower_body';
    }
    if (value.contains('dress') ||
        value.contains('full_body') ||
        RegExp(r'\b(gown|jumpsuit|romper|saree|sari)').hasMatch(value)) {
      return 'full_body';
    }
    return 'upper_body';
  }

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
        data['error']?.toString() ??
            'The server could not complete the request.',
      );
    }
  }
}
