class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final String? linkUrl;
  final String importance;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.linkUrl,
    this.importance = 'normal',
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? '') ?? DateTime.now(),
      linkUrl: json['linkUrl'] as String?,
      importance: (json['importance'] ?? 'normal') as String,
    );
  }
}
