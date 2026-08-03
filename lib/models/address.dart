class Address {
  final int? id;
  final String firstName;
  final String lastName;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String postcode;
  final String country;
  final String phone;
  final String type; // e.g., 'shipping', 'billing', 'home'

  Address({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.address1,
    this.address2 = '',
    required this.city,
    required this.state,
    required this.postcode,
    required this.country,
    required this.phone,
    this.type = 'home',
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      address1: json['address_1'] ?? '',
      address2: json['address_2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postcode: json['postcode'] ?? '',
      country: json['country'] ?? '',
      phone: json['phone'] ?? '',
      type: json['type'] ?? 'home',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      'phone': phone,
      'type': type,
    };
  }

  String get fullAddress {
    return [
      address1,
      address2.isNotEmpty ? address2 : null,
      city,
      state,
      postcode,
      country,
    ].where((e) => e != null && e.isNotEmpty).join(', ');
  }
}
