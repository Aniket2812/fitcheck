import 'closet_item.dart';
import 'social_post.dart';

class FashionCollection {
  const FashionCollection({
    required this.id,
    required this.name,
    required this.kind,
    required this.isDefault,
    required this.items,
  });

  factory FashionCollection.fromJson(Map<String, dynamic> json) =>
      FashionCollection(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Collection',
        kind: json['kind']?.toString() ?? 'custom',
        isDefault: json['isDefault'] == true,
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  CollectionItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );

  final String id;
  final String name;
  final String kind;
  final bool isDefault;
  final List<CollectionItem> items;
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.collectionId,
    required this.title,
    required this.imageUrl,
    required this.buyUrl,
    required this.category,
    this.brand,
    this.price,
    this.originalImageUrl,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
    id: json['id']?.toString() ?? '',
    collectionId: json['collectionId']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Fashion item',
    imageUrl: json['imageUrl']?.toString() ?? '',
    buyUrl: json['buyUrl']?.toString() ?? '',
    category: json['category']?.toString() ?? 'upper_body',
    brand: json['brand']?.toString(),
    price: json['price']?.toString(),
    originalImageUrl: json['originalImageUrl']?.toString(),
  );

  final String id;
  final String collectionId;
  final String title;
  final String imageUrl;
  final String buyUrl;
  final String category;
  final String? brand;
  final String? price;
  final String? originalImageUrl;

  PostGarment toGarment({int index = 0}) {
    final position = switch (category) {
      'upper_body' => 0.3,
      'lower_body' => 0.58,
      'full_body' => 0.48,
      'shoes' => 0.86,
      _ => 0.2 + index * 0.12,
    };
    return PostGarment(
      id: id,
      title: title,
      imageUrl: imageUrl,
      buyUrl: buyUrl,
      x: 0.5,
      y: position.clamp(0.1, 0.9),
      brand: brand,
      price: price,
      originalImageUrl: originalImageUrl,
      category: category,
    );
  }

  ClosetItem toClosetItem() => ClosetItem(
    id: id,
    title: title,
    image: imageUrl,
    brand: brand,
    price: price,
    pageUrl: buyUrl,
    originalImage: originalImageUrl,
    category: category,
  );
}
