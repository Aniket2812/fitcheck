import 'social_post.dart';

class SavedFit {
  const SavedFit({
    required this.id,
    required this.caption,
    required this.imageUrl,
    required this.garments,
    required this.createdAt,
    required this.updatedAt,
    this.modelPhotoId,
  });

  factory SavedFit.fromJson(Map<String, dynamic> json) => SavedFit(
    id: json['id']?.toString() ?? '',
    caption: json['caption']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString() ?? '',
    garments: (json['garments'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PostGarment.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    modelPhotoId: json['modelPhotoId']?.toString(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.now(),
  );

  final String id;
  final String caption;
  final String imageUrl;
  final List<PostGarment> garments;
  final String? modelPhotoId;
  final DateTime createdAt;
  final DateTime updatedAt;
}
