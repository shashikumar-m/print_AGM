class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final double wallet;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.wallet = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'student',
      wallet: (json['wallet'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'wallet': wallet,
      };

  bool get isAdmin => role == 'admin';
}
