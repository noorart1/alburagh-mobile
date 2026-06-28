import '../core/string_utils.dart';

class Product {
  final int id;
  final String name;
  final String price;
  final String regularPrice;
  final String imageUrl;
  final List<String> imageUrls;
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.regularPrice,
    required this.imageUrl,
    required this.imageUrls,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = json['images'] is List
        ? (json['images'] as List)
            .map((image) => image is Map ? image['src']?.toString() ?? '' : '')
            .where((src) => src.isNotEmpty)
            .toList()
        : <String>[];

    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'] ?? '0',
      regularPrice: json['regular_price'] ?? '0',
      imageUrl: images.isNotEmpty ? images.first : '',
      imageUrls: images,
      description: StringUtils.stripHtmlTags(json['short_description'] ?? ''),
    );
  }
}
