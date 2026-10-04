// lib/models/report.dart

class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String matchId;
  final String reason; // 'soft_play', 'time_cheat', 'other'
  final String status; // 'pending', 'reviewed', 'dismissed'
  final DateTime createdAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.matchId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'match_id': matchId,
      'reason': reason,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String,
      matchId: json['match_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'soft_play':
        return 'ソフト指し';
      case 'time_cheat':
        return 'タイムチート';
      default:
        return 'その他の不正';
    }
  }
}
