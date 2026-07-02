class Category {
  final int id;
  final String name;
  final String imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
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
    );
  }
}
