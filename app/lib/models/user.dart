class User {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'admin' or 'student'
  final bool isActive;
  final int countdownVolume;
  final int startVolume;
  final int halfwayVolume;
  final int finishVolume;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.countdownVolume = 75,
    this.startVolume = 75,
    this.halfwayVolume = 25,
    this.finishVolume = 100,
  });

  // Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      isActive: json['is_active'] as bool? ?? true,
      countdownVolume: json['countdown_volume'] as int? ?? 75,
      startVolume: json['start_volume'] as int? ?? 75,
      halfwayVolume: json['halfway_volume'] as int? ?? 25,
      finishVolume: json['finish_volume'] as int? ?? 100,
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
      'countdown_volume': countdownVolume,
      'start_volume': startVolume,
      'halfway_volume': halfwayVolume,
      'finish_volume': finishVolume,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
}
