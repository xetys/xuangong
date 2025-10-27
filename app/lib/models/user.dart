class User {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'admin' or 'student'
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  // Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  // Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
}
