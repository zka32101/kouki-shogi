// lib/services/async_duel_service.dart
// フレンドとの非同期詰将棋対戦（レース対戦）。
// 進捗はFirestoreの async_duels コレクションで同期し、両者が解き終わる
// か期限が来た時点でどちらかのクライアントが勝敗を確定させる
// （honor-system方式。tournament_service.dart の対局結果報告と同じ考え方で、
// 期限切れ後に誰もアプリを開かなかった場合は未確定のまま残る点に注意）。

import 'package:cloud_firestore/cloud_firestore.dart';
import '../tsume_builtin_problems.dart';
import 'network_service.dart';

class AsyncDuelProgress {
  final int solvedCount;
  final int totalSolveTimeSec;
  final bool finished;

  const AsyncDuelProgress({
    this.solvedCount = 0,
    this.totalSolveTimeSec = 0,
    this.finished = false,
  });

  factory AsyncDuelProgress.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AsyncDuelProgress();
    return AsyncDuelProgress(
      solvedCount: m['solvedCount'] as int? ?? 0,
      totalSolveTimeSec: m['totalSolveTimeSec'] as int? ?? 0,
      finished: m['finished'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'solvedCount': solvedCount,
        'totalSolveTimeSec': totalSolveTimeSec,
        'finished': finished,
      };
}

class AsyncDuel {
  final String id;
  final String player1Id;
  final String player1Name;
  final String player2Id;
  final String player2Name;
  final String difficulty; // '1手詰め' / '3手詰め' / '5手詰め'
  final List<int> problemIndices; // buildTsumeProblems() 内のインデックス
  final DateTime createdAt;
  final DateTime deadlineAt;
  final String status; // active, completed
  final String? winnerId;
  final AsyncDuelProgress player1Progress;
  final AsyncDuelProgress player2Progress;

  const AsyncDuel({
    required this.id,
    required this.player1Id,
    required this.player1Name,
    required this.player2Id,
    required this.player2Name,
    required this.difficulty,
    required this.problemIndices,
    required this.createdAt,
    required this.deadlineAt,
    required this.status,
    this.winnerId,
    this.player1Progress = const AsyncDuelProgress(),
    this.player2Progress = const AsyncDuelProgress(),
  });

  bool get isExpired =>
      status != 'completed' && DateTime.now().isAfter(deadlineAt);
  int get remainingMinutes =>
      deadlineAt.difference(DateTime.now()).inMinutes;

  String opponentId(String myUid) =>
      myUid == player1Id ? player2Id : player1Id;
  String opponentName(String myUid) =>
      myUid == player1Id ? player2Name : player1Name;
  String myName(String myUid) => myUid == player1Id ? player1Name : player2Name;
  AsyncDuelProgress myProgress(String myUid) =>
      myUid == player1Id ? player1Progress : player2Progress;
  AsyncDuelProgress opponentProgress(String myUid) =>
      myUid == player1Id ? player2Progress : player1Progress;

  List<TsumeProb> get problems {
    final all = buildTsumeProblems();
    return problemIndices.map((i) => all[i]).toList();
  }

  factory AsyncDuel.fromDoc(DocumentSnapshot doc) {
    // フィールド欠損・型不一致でも例外を投げないようにする。ストリーム内で
    // 1件でも壊れたドキュメントがあると fromDoc が例外を投げ、一覧全体が
    // エラー表示になってしまうため、各フィールドをnull安全に読む。
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    return AsyncDuel(
      id: doc.id,
      player1Id: d['player1_id'] as String? ?? '',
      player1Name: d['player1_name'] as String? ?? '?',
      player2Id: d['player2_id'] as String? ?? '',
      player2Name: d['player2_name'] as String? ?? '?',
      difficulty: d['difficulty'] as String? ?? '3手詰め',
      problemIndices: (d['problem_indices'] as List?)
              ?.whereType<int>()
              .toList() ??
          const [],
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadlineAt: (d['deadline_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'active',
      winnerId: d['winner_id'] as String?,
      player1Progress:
          AsyncDuelProgress.fromMap(d['player1_progress'] as Map<String, dynamic>?),
      player2Progress:
          AsyncDuelProgress.fromMap(d['player2_progress'] as Map<String, dynamic>?),
    );
  }
}

class AsyncDuelService {
  static final AsyncDuelService _instance = AsyncDuelService._();
  AsyncDuelService._();
  factory AsyncDuelService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NetworkService _networkService = NetworkService();

  static const _moveCountByDifficulty = {
    '1手詰め': 1,
    '3手詰め': 3,
    '5手詰め': 5,
  };

  List<int> _pickProblemIndices(String difficulty, {int count = 5}) {
    final all = buildTsumeProblems();
    final targetMoves = _moveCountByDifficulty[difficulty] ?? 3;
    final matching = <int>[];
    for (var i = 0; i < all.length; i++) {
      if (all[i].moves == targetMoves) matching.add(i);
    }
    matching.shuffle();
    if (matching.length >= count) return matching.take(count).toList();
    // 該当する手数の問題が足りない場合は他の問題で埋める
    final others = List.generate(all.length, (i) => i)
      ..removeWhere((i) => matching.contains(i));
    others.shuffle();
    return [...matching, ...others.take(count - matching.length)];
  }

  Future<String> createDuel({
    required String opponentId,
    required String opponentName,
    required String difficulty,
    required int deadlineHours,
  }) async {
    final me = _networkService.currentUser;
    if (me == null) throw Exception('ログインが必要です');
    final myProfile = await _networkService.getUserProfile(me.uid);
    final myName = myProfile?.username ?? 'あなた';

    final indices = _pickProblemIndices(difficulty);
    final now = DateTime.now();

    final doc = await _firestore.collection('async_duels').add({
      'player1_id': me.uid,
      'player1_name': myName,
      'player2_id': opponentId,
      'player2_name': opponentName,
      'difficulty': difficulty,
      'problem_indices': indices,
      'created_at': Timestamp.fromDate(now),
      'deadline_at': Timestamp.fromDate(now.add(Duration(hours: deadlineHours))),
      'status': 'active',
      'winner_id': null,
      'player1_progress': const AsyncDuelProgress().toMap(),
      'player2_progress': const AsyncDuelProgress().toMap(),
    });
    return doc.id;
  }

  Stream<List<AsyncDuel>> watchMyDuels(String userId) {
    return _firestore
        .collection('async_duels')
        .where(Filter.or(
          Filter('player1_id', isEqualTo: userId),
          Filter('player2_id', isEqualTo: userId),
        ))
        .snapshots()
        .map((snap) => snap.docs.map((d) => AsyncDuel.fromDoc(d)).toList());
  }

  Stream<AsyncDuel?> watchDuel(String duelId) {
    return _firestore
        .collection('async_duels')
        .doc(duelId)
        .snapshots()
        .map((snap) => snap.exists ? AsyncDuel.fromDoc(snap) : null);
  }

  /// 自分の進捗を反映し、両者が完了 or 期限切れなら勝敗を確定する。
  Future<void> submitProgress(
    String duelId,
    String userId, {
    required int solvedCount,
    required int totalSolveTimeSec,
    required bool finished,
  }) async {
    final ref = _firestore.collection('async_duels').doc(duelId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final duel = AsyncDuel.fromDoc(snap);
      if (duel.status != 'active') return;

      final isP1 = userId == duel.player1Id;
      final myProgress = AsyncDuelProgress(
        solvedCount: solvedCount,
        totalSolveTimeSec: totalSolveTimeSec,
        finished: finished,
      );
      final oppProgress = isP1 ? duel.player2Progress : duel.player1Progress;

      final update = <String, dynamic>{
        (isP1 ? 'player1_progress' : 'player2_progress'): myProgress.toMap(),
      };

      final bothFinished = myProgress.finished && oppProgress.finished;
      final expired = DateTime.now().isAfter(duel.deadlineAt);
      if (bothFinished || expired) {
        String? winnerId;
        if (myProgress.solvedCount != oppProgress.solvedCount) {
          winnerId = myProgress.solvedCount > oppProgress.solvedCount
              ? userId
              : duel.opponentId(userId);
        } else if (myProgress.solvedCount > 0) {
          // 手数が同じなら合計時間が短い方が勝ち
          winnerId = myProgress.totalSolveTimeSec < oppProgress.totalSolveTimeSec
              ? userId
              : (myProgress.totalSolveTimeSec > oppProgress.totalSolveTimeSec
                  ? duel.opponentId(userId)
                  : null); // 完全に同じなら引き分け
        }
        update['status'] = 'completed';
        update['winner_id'] = winnerId;
      }

      tx.update(ref, update);
    });
  }
}
