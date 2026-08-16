class ClosetItem {
  const ClosetItem({
    required this.id,
    required this.title,
    required this.image,
    this.brand,
    this.price,
    this.pageUrl,
    this.originalImage,
    this.category,
  });

  final String id;
  final String title;
  final String image;
  final String? brand;
  final String? price;
  final String? pageUrl;
  final String? originalImage;
  final String? category;

  factory ClosetItem.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    if (image is! String || image.isEmpty) {
      throw const FormatException('The server returned no garment image.');
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
    'category': category,
  };
}
