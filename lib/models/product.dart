import '../core/string_utils.dart';

class ProductAttribute {
  final String name;
  final String value;

  const ProductAttribute({required this.name, required this.value});

  factory ProductAttribute.fromJson(Map<String, dynamic> json) =>
      ProductAttribute(
        name: json['name']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}

class Product {
  final int id;
  final String name;
  final String price;
  final String regularPrice;
  final String imageUrl;
  final List<String> imageUrls;
  // Server-generated small (~300x300) version of imageUrl, used by grid/row
  // cards so scrolling a long product list doesn't download and decode the
  // full-size gallery original for every card. Falls back to imageUrl when
  // the backend didn't send one (e.g. cached/older payloads).
  final String thumbnailUrl;
  final String description;
  // The website renders short_description as a bold lead title followed
  // by its body paragraph(s) -- see StringUtils.splitLeadTitle. Empty
  // descriptionTitle means the source HTML didn't follow that convention;
  // show descriptionBody alone in that case.
  final String descriptionTitle;
  final String descriptionBody;
  final String type;
  final String externalUrl;
  final String buttonText;
  final String category;
  final double averageRating;
  final bool inStock;
  final String currencySymbol;
  final List<ProductAttribute> additionalInformation;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.regularPrice,
    required this.imageUrl,
    required this.imageUrls,
    required this.thumbnailUrl,
    required this.description,
    this.descriptionTitle = '',
    this.descriptionBody = '',
    required this.type,
    required this.externalUrl,
    required this.buttonText,
    this.category = '',
    this.averageRating = 0.0,
    this.inStock = true,
    this.currencySymbol = '\$',
    this.additionalInformation = const [],
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

    // Only WooCommerce's own short_description (the
    // woocommerce-product-details__short-description block shown under
    // the title/price on the website) -- deliberately not falling back to
    // the full description field.
    final descriptionHtml = json['short_description']?.toString() ?? '';
    final description = StringUtils.stripHtmlTags(descriptionHtml);
    // toJson() round-trips through local storage (recently-viewed) with
    // the already-split title/body rather than the original HTML -- reuse
    // those directly when present instead of re-deriving from
    // short_description, which by then is plain text with no <strong> tag
    // left to detect a lead title from.
    final parsedDescription = json.containsKey('description_title')
        ? ParsedDescription(
            title: json['description_title']?.toString() ?? '',
            body: json['description_body']?.toString() ?? '',
          )
        : StringUtils.splitLeadTitle(descriptionHtml);

    final categories = json['categories'] is List
        ? (json['categories'] as List)
              .map((c) => c is Map ? c['name']?.toString() ?? '' : '')
              .where((name) => name.isNotEmpty)
              .toList()
        : <String>[];

    final additionalInformation = json['additional_information'] is List
        ? (json['additional_information'] as List)
              .whereType<Map>()
              .map((info) => ProductAttribute.fromJson(
                    Map<String, dynamic>.from(info),
                  ))
              .where((attr) => attr.name.isNotEmpty && attr.value.isNotEmpty)
              .toList()
        : <ProductAttribute>[];

    return Product(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      price: (json['price'] ?? '0').toString(),
      regularPrice: (json['regular_price'] ?? '0').toString(),
      imageUrl: images.isNotEmpty ? images.first : '',
      imageUrls: images,
      thumbnailUrl: (json['thumbnail']?.toString().isNotEmpty ?? false)
          ? json['thumbnail'].toString()
          : (images.isNotEmpty ? images.first : ''),
      description: description,
      descriptionTitle: parsedDescription.title,
      descriptionBody: parsedDescription.body,
      type: json['type']?.toString() ?? '',
      externalUrl: json['external_url']?.toString() ?? '',
      buttonText: json['button_text']?.toString() ?? '',
      category: categories.isNotEmpty ? categories.first : '',
      averageRating:
          double.tryParse(json['average_rating']?.toString() ?? '') ?? 0.0,
      inStock: json['stock_status']?.toString() != 'outofstock',
      currencySymbol: json['currency_symbol']?.toString() ?? '\$',
      additionalInformation: additionalInformation,
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
    'thumbnail': thumbnailUrl,
    'short_description': description,
    'description_title': descriptionTitle,
    'description_body': descriptionBody,
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
    'additional_information': additionalInformation
        .map((attr) => attr.toJson())
        .toList(),
  };
}
