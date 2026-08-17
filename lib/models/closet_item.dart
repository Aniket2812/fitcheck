class ClosetItem {
  const ClosetItem({
    required this.id,
    required this.title,
    required this.image,
    this.brand,
    this.price,
    this.pageUrl,
    this.originalImage,
    this.productImageUrls = const [],
    this.category,
  });

  final String id;
  final String title;
  final String image;
  final String? brand;
  final String? price;
  final String? pageUrl;
  final String? originalImage;
  final List<String> productImageUrls;
  final String? category;

  factory ClosetItem.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    if (image is! String || image.isEmpty) {
      throw const FormatException(
        'We couldn’t find a clear product image on that page.',
      );
    }

    return ClosetItem(
      id:
          (json['id'] as String?) ??
          'item-${DateTime.now().millisecondsSinceEpoch}',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Saved piece',
      brand: json['brand']?.toString(),
      price: json['price']?.toString(),
      image: image,
      pageUrl: json['pageUrl']?.toString(),
      originalImage: json['originalImage']?.toString(),
      productImageUrls: (json['productImageUrls'] as List? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .take(5)
          .toList(),
      category: json['category']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'brand': brand,
    'price': price,
    'image': image,
    'pageUrl': pageUrl,
    'originalImage': originalImage,
    'productImageUrls': productImageUrls,
    'category': category,
  };
}
