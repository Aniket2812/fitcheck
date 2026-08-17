class PostTryOnResult {
  const PostTryOnResult({
    required this.imageUrl,
    required this.appliedCount,
    required this.preservesSourceComposition,
  });

  factory PostTryOnResult.fromJson(Map<String, dynamic> json) =>
      PostTryOnResult(
        imageUrl: json['imageUrl']?.toString() ?? '',
        appliedCount: (json['appliedCount'] as num?)?.toInt() ?? 0,
        preservesSourceComposition: json['preservesSourceComposition'] == true,
      );

  final String imageUrl;
  final int appliedCount;
  final bool preservesSourceComposition;
}
