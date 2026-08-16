import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import 'ingest_service.dart';
import 'session_service.dart';

typedef FetchProfile = Future<UserProfile> Function();
typedef UpdateProfile =
    Future<UserProfile> Function({
      required String name,
      required String handle,
      required String bio,
    });

abstract final class ProfileService {
  static Future<UserProfile> fetchMe() async {
    final session = await SessionService.ensureSession();
    final response = await http
        .get(
          Uri.parse('${IngestService.apiUrl}/api/me'),
          headers: {'authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));
    return _profile(response);
  }

  static Future<UserProfile> update({
    required String name,
    required String handle,
    required String bio,
  }) async {
    final session = await SessionService.ensureSession();
    final response = await http
        .patch(
          Uri.parse('${IngestService.apiUrl}/api/me'),
          headers: {
            'authorization': 'Bearer ${session.token}',
            'content-type': 'application/json',
          },
          body: jsonEncode({'name': name, 'handle': handle, 'bio': bio}),
        )
        .timeout(const Duration(seconds: 20));
    final profile = _profile(response);
    SessionService.replaceUser(profile.toSocialUser());
    return profile;
  }

  static UserProfile _profile(http.Response response) {
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'Could not load profile.');
    }
    return UserProfile.fromJson(
      Map<String, dynamic>.from(data['user'] as Map? ?? {}),
    );
  }
}
