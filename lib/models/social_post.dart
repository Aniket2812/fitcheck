class SocialUser {
  const SocialUser({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Member',
    handle: json['handle']?.toString() ?? 'member',
    avatarUrl: json['avatarUrl']?.toString(),
  );
}

class PostGarment {
  const PostGarment({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.buyUrl,
    required this.x,
    required this.y,
    this.brand,
    this.price,
    this.originalImageUrl,
    this.category,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String buyUrl;
  final double x;
  final double y;
  final String? brand;
  final String? price;
  final String? originalImageUrl;
  final String? category;

  PostGarment copyWith({double? x, double? y}) => PostGarment(
    id: id,
    title: title,
    imageUrl: imageUrl,
    buyUrl: buyUrl,
    x: x ?? this.x,
    y: y ?? this.y,
    brand: brand,
    price: price,
    originalImageUrl: originalImageUrl,
    category: category,
  );

  factory PostGarment.fromJson(Map<String, dynamic> json) => PostGarment(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Garment',
    imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
    buyUrl: json['buyUrl']?.toString() ?? json['pageUrl']?.toString() ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
    brand: json['brand']?.toString(),
    price: json['price']?.toString(),
    originalImageUrl: json['originalImageUrl']?.toString(),
    category: json['category']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'imageUrl': imageUrl,
    'buyUrl': buyUrl,
    'x': x,
    'y': y,
    'brand': brand,
    'price': price,
    'originalImageUrl': originalImageUrl,
    'category': category,
  };
}

class PostComment {
  const PostComment({
    required this.id,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final String text;
  final SocialUser author;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
    author: SocialUser.fromJson(
      Map<String, dynamic>.from(json['author'] as Map? ?? {}),
    ),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

class SocialPost {
  const SocialPost({
    required this.id,
    required this.caption,
    required this.imageUrl,
    required this.garments,
    required this.author,
    required this.likeCount,
    required this.likedByMe,
    required this.comments,
    required this.createdAt,
  });

  final String id;
  final String caption;
  final String imageUrl;
  final List<PostGarment> garments;
  final SocialUser author;
  final int likeCount;
  final bool likedByMe;
  final List<PostComment> comments;
  final DateTime createdAt;

  factory SocialPost.fromJson(Map<String, dynamic> json) => SocialPost(
    id: json['id']?.toString() ?? '',
    caption: json['caption']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString() ?? '',
    garments: (json['garments'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PostGarment.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    author: SocialUser.fromJson(
      Map<String, dynamic>.from(json['author'] as Map? ?? {}),
    ),
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    likedByMe: json['likedByMe'] == true,
    comments: (json['comments'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PostComment.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}
