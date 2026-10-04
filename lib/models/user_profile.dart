// lib/models/user_profile.dart

class UserProfile {
  final String uid;
  final String username;
  final int rating;
  final int reportCount;
  final bool isBanned;
  final DateTime? bannedAt;
  final DateTime createdAt;
  final int? wins;
  final int? losses;

  UserProfile({
    required this.uid,
    required this.username,
    this.rating = 1500,
    this.reportCount = 0,
    this.isBanned = false,
    this.bannedAt,
    required this.createdAt,
    this.wins = 0,
    this.losses = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'rating': rating,
      'report_count': reportCount,
      'is_banned': isBanned,
      'banned_at': bannedAt,
      'created_at': createdAt,
      'wins': wins ?? 0,
      'losses': losses ?? 0,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      username: json['username'] as String,
      rating: json['rating'] as int? ?? 1500,
      reportCount: json['report_count'] as int? ?? 0,
      isBanned: json['is_banned'] as bool? ?? false,
      bannedAt: json['banned_at'] != null
          ? DateTime.parse(json['banned_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'].toString()),
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
    );
  }
}
