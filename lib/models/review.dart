class Review {
  final int id;
  final String author;
  final int rating;
  final String content;
  final String date;

  Review({
    required this.id,
    required this.author,
    required this.rating,
    required this.content,
    required this.date,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      author: json['author']?.toString() ?? '',
      rating: json['rating'] is int
          ? json['rating']
          : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      content: json['content']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}
