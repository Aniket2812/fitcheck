class ModelPhoto {
  const ModelPhoto({
    required this.id,
    required this.imageUrl,
    required this.label,
    required this.isPrimary,
    required this.createdAt,
  });

  factory ModelPhoto.fromJson(Map<String, dynamic> json) => ModelPhoto(
    id: json['id']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString() ?? '',
    label: json['label']?.toString() ?? 'My photo',
    isPrimary: json['isPrimary'] == true,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime(1970),
  );

  final String id;
  final String imageUrl;
  final String label;
  final bool isPrimary;
  final DateTime createdAt;

  ModelPhoto copyWith({bool? isPrimary}) => ModelPhoto(
    id: id,
    imageUrl: imageUrl,
    label: label,
    isPrimary: isPrimary ?? this.isPrimary,
    createdAt: createdAt,
  );
}
