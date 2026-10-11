class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String section;
  final String department;
  final double wallet;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.section = '',
    this.department = '',
    this.wallet = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:         json['_id'] ?? json['id'] ?? '',
        email:      json['email']      ?? '',
        name:       json['name']       ?? '',
        role:       json['role']       ?? 'student',
        section:    json['section']    ?? '',
        department: json['department'] ?? '',
        wallet:     (json['wallet']    ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'email': email, 'name': name,
        'role': role, 'section': section,
        'department': department, 'wallet': wallet,
      };

  bool get isAdmin   => role == 'admin';
  bool get isFaculty => role == 'faculty';
  bool get isStudent => role == 'student';
}
