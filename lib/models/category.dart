class Category {
  final int id;
  final String name;
  final String imageUrl;
  final String? slug;
  final int count;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.slug,
    this.count = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final imageValue = json['image'];
    String imageUrl = '';

    if (imageValue is String && imageValue.isNotEmpty) {
      imageUrl = imageValue;
    } else if (imageValue is Map) {
      imageUrl = imageValue['src']?.toString() ?? '';
    }

    return Category(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: imageUrl,
      slug: json['slug']?.toString(),
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse(json['count']?.toString() ?? '') ?? 0,
    );
  }
}
