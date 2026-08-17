import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/model_photo.dart';
import 'ingest_service.dart';
import 'session_service.dart';

typedef FetchModelPhotos = Future<List<ModelPhoto>> Function();
typedef UploadModelPhoto = Future<ModelPhoto> Function(XFile photo);
typedef DeleteModelPhoto = Future<void> Function(String id);
typedef SetPrimaryModelPhoto = Future<ModelPhoto> Function(String id);

abstract final class ModelPhotoService {
  static Future<List<ModelPhoto>> fetchPhotos() async {
    final response = await _send(
      () async => http.get(
        Uri.parse('${IngestService.apiUrl}/api/model-photos'),
        headers: await _headers(),
      ),
    );
    final data = _json(response);
    _ensureSuccess(response, data);
    return (data['photos'] as List? ?? const [])
        .whereType<Map>()
        .map((photo) => _photo(Map<String, dynamic>.from(photo)))
        .toList();
  }

  static Future<ModelPhoto> upload(XFile photo) async {
    try {
      final session = await SessionService.ensureSession();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${IngestService.apiUrl}/api/model-photos'),
      );
      request.headers['authorization'] = 'Bearer ${session.token}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await photo.readAsBytes(),
          filename: photo.name,
          contentType: _mediaType(photo.name, photo.mimeType),
        ),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamed);
      final data = _json(response);
      _ensureSuccess(response, data);
      return _photo(Map<String, dynamic>.from(data['photo'] as Map));
    } on TimeoutException {
      throw Exception(_connectionMessage);
    } on http.ClientException {
      throw Exception(_connectionMessage);
    }
  }

  static Future<ModelPhoto> setPrimary(String id) async {
    final response = await _send(
      () async => http.post(
        Uri.parse('${IngestService.apiUrl}/api/model-photos/$id/primary'),
        headers: await _headers(),
      ),
    );
    final data = _json(response);
    _ensureSuccess(response, data);
    return _photo(Map<String, dynamic>.from(data['photo'] as Map));
  }

  static Future<void> delete(String id) async {
    final response = await _send(
      () async => http.delete(
        Uri.parse('${IngestService.apiUrl}/api/model-photos/$id'),
        headers: await _headers(),
      ),
    );
    if (response.statusCode == 204) return;
    _ensureSuccess(response, _json(response));
  }

  static Future<Map<String, String>> _headers() async {
    final session = await SessionService.ensureSession();
    return {'authorization': 'Bearer ${session.token}'};
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw Exception(_connectionMessage);
    } on http.ClientException {
      throw Exception(_connectionMessage);
    }
  }

  static const _connectionMessage =
      'Your photos didn’t load this time. Give it another go.';

  static ModelPhoto _photo(Map<String, dynamic> json) {
    final imageUrl = json['imageUrl']?.toString() ?? '';
    json['imageUrl'] = imageUrl.startsWith('/')
        ? '${IngestService.apiUrl}$imageUrl'
        : imageUrl;
    return ModelPhoto.fromJson(json);
  }

  static MediaType _mediaType(String name, String? supplied) {
    if (supplied == 'image/png' || name.toLowerCase().endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (supplied == 'image/webp' || name.toLowerCase().endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
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
        data['error']?.toString() ?? 'We couldn’t save that photo just yet.',
      );
    }
  }
}
