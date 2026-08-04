import '../core/string_utils.dart';

class Product {
  final int id;
  final String name;
  final String price;
  final String regularPrice;
  final String imageUrl;
  final List<String> imageUrls;
  final String description;
  final String type;
  final String externalUrl;
  final String buttonText;
  final String category;
  final double averageRating;
  final bool inStock;
  final String currencySymbol;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.regularPrice,
    required this.imageUrl,
    required this.imageUrls,
    required this.description,
    required this.type,
    required this.externalUrl,
    required this.buttonText,
    this.category = '',
    this.averageRating = 0.0,
    this.inStock = true,
    this.currencySymbol = '\$',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = json['images'] is List
        ? (json['images'] as List)
              .map(
                (image) => image is Map ? image['src']?.toString() ?? '' : '',
              )
              .where((src) => src.isNotEmpty)
              .toList()
        : <String>[];

    final description = (json['short_description'] ?? json['description'] ?? '')
        .toString();

    final categories = json['categories'] is List
        ? (json['categories'] as List)
              .map((c) => c is Map ? c['name']?.toString() ?? '' : '')
              .where((name) => name.isNotEmpty)
              .toList()
        : <String>[];

    return Product(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      price: (json['price'] ?? '0').toString(),
      regularPrice: (json['regular_price'] ?? '0').toString(),
      imageUrl: images.isNotEmpty ? images.first : '',
      imageUrls: images,
      description: StringUtils.stripHtmlTags(description),
      type: json['type']?.toString() ?? '',
      externalUrl: json['external_url']?.toString() ?? '',
      buttonText: json['button_text']?.toString() ?? '',
      category: categories.isNotEmpty ? categories.first : '',
      averageRating:
          double.tryParse(json['average_rating']?.toString() ?? '') ?? 0.0,
      inStock: json['stock_status']?.toString() != 'outofstock',
      currencySymbol: json['currency_symbol']?.toString() ?? '\$',
    );
  }

  /// Mirrors the shape fromJson() expects, so it round-trips through
  /// storage (e.g. the recently-viewed list) without needing a second,
  /// parallel serialization format.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'regular_price': regularPrice,
    'images': imageUrls.map((src) => {'src': src}).toList(),
    'short_description': description,
    'type': type,
    'external_url': externalUrl,
    'button_text': buttonText,
    'categories': category.isNotEmpty
        ? [
            {'name': category},
          ]
        : <Map<String, String>>[],
    'average_rating': averageRating.toString(),
    'stock_status': inStock ? 'instock' : 'outofstock',
    'currency_symbol': currencySymbol,
  };
}
