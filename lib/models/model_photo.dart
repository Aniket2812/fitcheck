class ModelPhoto {
  const ModelPhoto({
    required this.id,
    required this.imageUrl,
    required this.label,
    required this.isPrimary,
    required this.createdAt,
    this.width,
    this.height,
    this.youCamReady = true,
  });

  factory ModelPhoto.fromJson(Map<String, dynamic> json) => ModelPhoto(
    id: json['id']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString() ?? '',
    label: json['label']?.toString() ?? 'My photo',
    isPrimary: json['isPrimary'] == true,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    youCamReady: json['youCamReady'] != false,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime(1970),
  );

  final String id;
  final String imageUrl;
  final String label;
  final bool isPrimary;
  final DateTime createdAt;
  final int? width;
  final int? height;
  final bool youCamReady;

  ModelPhoto copyWith({bool? isPrimary}) => ModelPhoto(
    id: id,
    imageUrl: imageUrl,
    label: label,
    isPrimary: isPrimary ?? this.isPrimary,
    width: width,
    height: height,
    youCamReady: youCamReady,
    createdAt: createdAt,
  );
}
