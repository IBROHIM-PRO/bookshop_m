class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? token;
  final int? parentId;
  final String? imageUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.token,
    this.parentId,
    this.imageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? '',
      token: json['token'],
      parentId: json['parentId'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'token': token,
      'parentId': parentId,
      'imageUrl': imageUrl,
    };
  }
}
