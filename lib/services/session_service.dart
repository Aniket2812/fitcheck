import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/social_post.dart';
import 'ingest_service.dart';

class AppSession {
  const AppSession({required this.token, required this.user});

  final String token;
  final SocialUser user;
}

abstract final class SessionService {
  static const _tokenKey = 'compete.session.token.v1';
  static const _deviceKey = 'compete.session.device.v1';
  static AppSession? _session;

  static AppSession? get current => _session;

  static Future<AppSession> ensureSession() async {
    if (_session != null) return _session!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tokenKey);
    if (saved != null) {
      final restored = await _loadCurrent(saved);
      if (restored != null) return _session = restored;
    }

    var device = prefs.getString(_deviceKey);
    if (device == null) {
      device = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await prefs.setString(_deviceKey, device);
    }
    const configured = String.fromEnvironment('DEV_ID_TOKEN');
    final idToken = configured.isNotEmpty
        ? configured
        : 'dev:flutter-$device:creator-$device@compete.local:YouCam Creator';
    final response = await http
        .post(
          Uri.parse('${IngestService.apiUrl}/api/auth/google'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 20));
    final data = _json(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'Could not sign in.');
    }
    final session = AppSession(
      token: data['token'].toString(),
      user: SocialUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
    await prefs.setString(_tokenKey, session.token);
    return _session = session;
  }

  static Future<AppSession?> _loadCurrent(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('${IngestService.apiUrl}/api/me'),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = _json(response);
      return AppSession(
        token: token,
        user: SocialUser.fromJson(
          Map<String, dynamic>.from(data['user'] as Map),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _json(http.Response response) {
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
