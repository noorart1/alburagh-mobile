class User {
  final int id;
  final String email;
  final String name;
  final String? username;
  final String? phone;
  final String? address;
  final String? token;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.phone,
    this.address,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      name: (json['first_name'] ?? '').toString().isNotEmpty
          ? json['first_name']
          : (json['username'] ?? ''),
      username: json['username']?.toString(),
      phone: json['billing']?['phone'],
      address: json['billing']?['address_1'],
    );
  }

  User copyWith({String? token}) {
    return User(
      id: id,
      email: email,
      name: name,
      username: username,
      phone: phone,
      address: address,
      token: token ?? this.token,
    );
  }
}
