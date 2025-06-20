class User {
  final String id;
  final String username;
  final String? email;
  final String? faculty;
  final int? grade;

  User({
    required this.id,
    required this.username,
    this.email,
    this.faculty,
    this.grade,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['userName'] ?? '名無しさん',
      email: json['email'],
      faculty: json['faculty'] ?? '未設定',
      grade: json['grade'] ?? 0,
    );
  }
} 