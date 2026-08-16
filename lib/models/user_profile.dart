import 'social_post.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    required this.createdAt,
    this.email,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Member',
    handle: json['handle']?.toString() ?? 'member',
    bio: json['bio']?.toString() ?? '',
    email: json['email']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime(1970),
  );

  final String id;
  final String name;
  final String handle;
  final String bio;
  final String? email;
  final String? avatarUrl;
  final DateTime createdAt;

  SocialUser toSocialUser() =>
      SocialUser(id: id, name: name, handle: handle, avatarUrl: avatarUrl);
}
