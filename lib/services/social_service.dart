import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_photo.dart';
import '../models/post_try_on_result.dart';
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
typedef GenerateOutfitLook =
    Future<String> Function({
      required ModelPhoto modelPhoto,
      required List<PostGarment> garments,
    });
typedef GeneratePostTryOn =
    Future<PostTryOnResult> Function({
      required ModelPhoto modelPhoto,
      required SocialPost post,
    });

abstract final class SocialService {
  static const _feedCacheKey = 'compete.feed.last-good.v1';

  static String mediaUrl(String value) {
    if (value.startsWith('/')) return '${IngestService.apiUrl}$value';
    return value;
  }

  static Future<List<SocialPost>> fetchPosts() async {
    try {
      // The feed endpoint is intentionally public. Do not make the first paint
      // wait for session restore/sign-in; include a token only when one is
      // already available so likedByMe still works for an active session.
      final token = SessionService.current?.token;
      final response = await http
          .get(
            Uri.parse('${IngestService.apiUrl}/api/posts'),
            headers: token == null
                ? const {}
                : {'authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      final data = _json(response);
      _ensureSuccess(response, data);
      final rawPosts = data['posts'] as List? ?? const [];
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_feedCacheKey, jsonEncode(rawPosts));
      return _posts(rawPosts);
    } catch (error) {
      final cached = await _cachedPosts();
      if (cached.isNotEmpty) return cached;
      if (error is TimeoutException || error is http.ClientException) {
        throw Exception(
          'Could not reach the feed server. Keep the backend running and reconnect wireless debugging, then tap Retry.',
        );
      }
      rethrow;
    }
  }

  static List<SocialPost> _posts(List<dynamic> posts) => posts
      .whereType<Map>()
      .map((post) => postFromJson(Map<String, dynamic>.from(post)))
      .toList();

  static Future<List<SocialPost>> _cachedPosts() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_feedCacheKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      return decoded is List ? _posts(decoded) : const [];
    } catch (_) {
      return const [];
    }
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
              'garments': garments.map(_garmentPayload).toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = _json(response);
      _ensureSuccess(response, data);
      return postFromJson(Map<String, dynamic>.from(data['post'] as Map));
    }
    if (photo == null) throw Exception('Choose an outfit photo.');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${IngestService.apiUrl}/api/posts'),
    );
    request.headers['authorization'] = 'Bearer ${session.token}';
    request.fields['caption'] = caption;
    request.fields['garments'] = jsonEncode(
      garments.map(_garmentPayload).toList(),
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
    return postFromJson(Map<String, dynamic>.from(data['post'] as Map));
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
    return postFromJson(Map<String, dynamic>.from(data['post'] as Map));
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
    return postFromJson(Map<String, dynamic>.from(data['post'] as Map));
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

  static Future<String> createOutfitLook({
    required ModelPhoto modelPhoto,
    required List<PostGarment> garments,
  }) async {
    if (garments.isEmpty) {
      throw Exception('Choose at least one collection item.');
    }
    if (garments.any(
      (garment) =>
          garment.originalImageUrl == null ||
          !garment.originalImageUrl!.startsWith('http'),
    )) {
      throw Exception(
        'One of these items has no usable product image. Remove it and add the product link again.',
      );
    }
    final session = await SessionService.ensureSession();
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/try-on/outfit'),
          headers: {
            'authorization': 'Bearer ${session.token}',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'modelPhotoId': modelPhoto.id,
            'garments': garments
                .map(
                  (garment) => {
                    'garmentUrl': garment.originalImageUrl,
                    'category': _youCamCategory(garment),
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(minutes: 12));
    final data = _json(response);
    _ensureSuccess(response, data);
    return mediaUrl(data['imageUrl'].toString());
  }

  static Future<PostTryOnResult> createPostTryOn({
    required ModelPhoto modelPhoto,
    required SocialPost post,
  }) async {
    final session = await SessionService.ensureSession();
    try {
      final response = await http
          .post(
            Uri.parse('${IngestService.apiUrl}/api/try-on/post'),
            headers: {
              'authorization': 'Bearer ${session.token}',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'modelPhotoId': modelPhoto.id,
              'postId': post.id,
            }),
          )
          .timeout(const Duration(minutes: 7));
      final data = _json(response);
      _ensureSuccess(response, data);
      data['imageUrl'] = mediaUrl(data['imageUrl']?.toString() ?? '');
      return PostTryOnResult.fromJson(data);
    } on TimeoutException {
      throw Exception(
        'The fitting service took too long. Your original photo is unchanged; please try again.',
      );
    } on http.ClientException {
      throw Exception(
        'The fitting server disconnected. Keep the backend running and try again.',
      );
    }
  }

  static SocialPost postFromJson(Map<String, dynamic> json) {
    json['imageUrl'] = mediaUrl(json['imageUrl']?.toString() ?? '');
    final garments = json['garments'];
    if (garments is List) {
      for (final garment in garments.whereType<Map>()) {
        garment['imageUrl'] = mediaUrl(garment['imageUrl']?.toString() ?? '');
        garment['productImageUrls'] =
            (garment['productImageUrls'] as List? ?? const [])
                .map((value) => mediaUrl(value.toString()))
                .where((value) => value.isNotEmpty)
                .toList();
      }
    }
    return SocialPost.fromJson(json);
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
