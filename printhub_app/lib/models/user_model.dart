class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String section;
  final double wallet;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.section = '',
    this.wallet = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:      json['_id'] ?? json['id'] ?? '',
        email:   json['email']   ?? '',
        name:    json['name']    ?? '',
        role:    json['role']    ?? 'student',
        section: json['section'] ?? '',
        wallet:  (json['wallet'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'email': email, 'name': name,
        'role': role, 'section': section, 'wallet': wallet,
      };

  bool get isAdmin => role == 'admin';
}
