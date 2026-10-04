// lib/models/matching_queue.dart
// マッチング待機キュー

class MatchingQueue {
  final String id;
  final String userId;
  final String username;
  final int rating;
  final int minRatingRange; // 対戦相手のレーティング下限
  final int maxRatingRange; // 対戦相手のレーティング上限
  final DateTime queuedAt;
  final String? status; // 'waiting', 'matched', 'cancelled'
  final String? matchedWith; // マッチ相手の UID
  final String? matchId; // 対局 ID
  final List<String> clubIds; // 所属クラブID（同クラブ優先マッチング用）
  final bool clubMatchOnly; // 同クラブ限定マッチング

  MatchingQueue({
    required this.id,
    required this.userId,
    required this.username,
    required this.rating,
    required this.minRatingRange,
    required this.maxRatingRange,
    required this.queuedAt,
    this.status = 'waiting',
    this.matchedWith,
    this.matchId,
    this.clubIds = const [],
    this.clubMatchOnly = false,
  });

  bool get isWaiting => status == 'waiting';
  bool get isMatched => status == 'matched';
  bool get isCancelled => status == 'cancelled';

  /// レーティング範囲をチェック（自分のレートが相手の範囲内か）
  bool canMatch(int otherRating) {
    return otherRating >= minRatingRange && otherRating <= maxRatingRange;
  }

  /// 同クラブメンバーか確認
  bool shareClub(MatchingQueue other) {
    if (clubIds.isEmpty || other.clubIds.isEmpty) return false;
    return clubIds.any((id) => other.clubIds.contains(id));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'rating': rating,
      'min_rating_range': minRatingRange,
      'max_rating_range': maxRatingRange,
      'queued_at': queuedAt,
      'status': status,
      'matched_with': matchedWith,
      'match_id': matchId,
      'club_ids': clubIds,
      'club_match_only': clubMatchOnly,
    };
  }

  factory MatchingQueue.fromJson(Map<String, dynamic> json) {
    return MatchingQueue(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      rating: json['rating'] as int,
      minRatingRange: json['min_rating_range'] as int,
      maxRatingRange: json['max_rating_range'] as int,
      queuedAt: DateTime.parse(json['queued_at'].toString()),
      status: json['status'] as String? ?? 'waiting',
      matchedWith: json['matched_with'] as String?,
      matchId: json['match_id'] as String?,
      clubIds: (json['club_ids'] as List?)?.cast<String>() ?? [],
      clubMatchOnly: json['club_match_only'] as bool? ?? false,
    );
  }
}
