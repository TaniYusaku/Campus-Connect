class User {
  final String id;
  final String username;
  final String? email;
  final String? faculty;
  final int? grade;
  final String? bio;
  final String? profilePhotoUrl;
  final Map<String, String>? snsLinks; // e.g. { 'x': 'id', 'instagram': 'id' }
  final String? gender;
  final DateTime? lastEncounteredAt;
  final int encounterCount;
  final bool isFriend;

  User({
    required this.id,
    required this.username,
    this.email,
    this.faculty,
    this.grade,
    this.bio,
    this.profilePhotoUrl,
    this.snsLinks,
    this.gender,
    this.lastEncounteredAt,
    this.encounterCount = 1,
    this.isFriend = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['snsLinks'];
    Map<String, String>? links;
    if (rawLinks is Map) {
      links = rawLinks.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
    return User(
      id: json['id'] as String,
      username: (json['userName'] ?? '名無しさん') as String,
      email: json['email'] as String?,
      faculty: (json['faculty'] ?? '未設定') as String?,
      grade:
        (json['grade'] is int)
            ? json['grade'] as int
            : int.tryParse('${json['grade'] ?? ''}'),
      bio: json['bio'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      snsLinks: links,
      gender: json['gender'] as String?,
      lastEncounteredAt: _parseEncounteredAt(json['lastEncounteredAt']),
      encounterCount: _parseEncounterCount(json['encounterCount']),
      isFriend: json['isFriend'] == true,
    );
  }

  static DateTime? _parseEncounteredAt(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    return null;
  }

  static int _parseEncounterCount(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 1;
  }
}
