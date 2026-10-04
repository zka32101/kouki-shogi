// lib/friend_challenge_screen.dart — 友達と弱点シェア対戦

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'services/friend_service.dart';
import 'services/network_service.dart';
import 'services/kifu_analytics_service.dart';
import 'study_calendar_screen.dart';
import 'theme/app_theme.dart';

// ──────────────────────────────────────────────
// Data Models
// ──────────────────────────────────────────────

class FriendWeakness {
  final String friendId;
  final String friendName;
  final String weaknessType; // '美濃', '矢倉', '手筋'
  final int score; // 対戦スコア（0 = 未挑戦）

  FriendWeakness({
    required this.friendId,
    required this.friendName,
    required this.weaknessType,
    this.score = 0,
  });
}

class ChallengeProblem {
  final String id;
  final String title;
  final String weakness; // 弱点カテゴリ
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final AMove answer;
  final String explanation;

  ChallengeProblem({
    required this.id,
    required this.title,
    required this.weakness,
    required this.board,
    required this.p1Hand,
    required this.answer,
    required this.explanation,
  });
}

// ──────────────────────────────────────────────
// Mock Problem Data
// ──────────────────────────────────────────────

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

List<ChallengeProblem> _buildProblems() {
  // ========== 美濃 ==========
  final mino1 = _empty();
  mino1[0][0] = Piece(PieceType.king, false);
  mino1[0][1] = Piece(PieceType.gold, false);
  mino1[1][0] = Piece(PieceType.silver, false);
  mino1[1][1] = Piece(PieceType.gold, false);
  mino1[2][0] = Piece(PieceType.pawn, false);
  mino1[2][1] = Piece(PieceType.pawn, false);
  mino1[2][2] = Piece(PieceType.pawn, false);
  mino1[3][0] = Piece(PieceType.lance, true);
  mino1[5][4] = Piece(PieceType.rook, true);
  mino1[8][8] = Piece(PieceType.king, true);

  final mino2 = _empty();
  mino2[0][0] = Piece(PieceType.king, false);
  mino2[0][1] = Piece(PieceType.gold, false);
  mino2[1][0] = Piece(PieceType.silver, false);
  mino2[1][1] = Piece(PieceType.gold, false);
  mino2[2][0] = Piece(PieceType.pawn, false);
  mino2[2][1] = Piece(PieceType.pawn, false);
  mino2[2][2] = Piece(PieceType.pawn, false);
  mino2[5][3] = Piece(PieceType.knight, true);
  mino2[5][4] = Piece(PieceType.rook, true);
  mino2[8][8] = Piece(PieceType.king, true);

  final mino3 = _empty();
  mino3[0][0] = Piece(PieceType.king, false);
  mino3[0][1] = Piece(PieceType.gold, false);
  mino3[1][0] = Piece(PieceType.silver, false);
  mino3[1][1] = Piece(PieceType.gold, false);
  mino3[2][1] = Piece(PieceType.pawn, false);
  mino3[2][2] = Piece(PieceType.pawn, false);
  mino3[3][1] = Piece(PieceType.silver, true);
  mino3[4][4] = Piece(PieceType.rook, true);
  mino3[8][8] = Piece(PieceType.king, true);

  // ========== 矢倉 ==========
  final yagura1 = _empty();
  yagura1[0][4] = Piece(PieceType.king, false);
  yagura1[0][3] = Piece(PieceType.gold, false);
  yagura1[0][5] = Piece(PieceType.gold, false);
  yagura1[1][4] = Piece(PieceType.silver, false);
  yagura1[1][5] = Piece(PieceType.bishop, false);
  yagura1[2][4] = Piece(PieceType.pawn, false);
  yagura1[4][4] = Piece(PieceType.pawn, true);
  yagura1[5][4] = Piece(PieceType.rook, true);
  yagura1[8][8] = Piece(PieceType.king, true);

  final yagura2 = _empty();
  yagura2[0][4] = Piece(PieceType.king, false);
  yagura2[0][3] = Piece(PieceType.gold, false);
  yagura2[0][5] = Piece(PieceType.gold, false);
  yagura2[1][4] = Piece(PieceType.silver, false);
  yagura2[1][5] = Piece(PieceType.bishop, false);
  yagura2[2][4] = Piece(PieceType.pawn, false);
  yagura2[5][3] = Piece(PieceType.knight, true);
  yagura2[6][4] = Piece(PieceType.rook, true);
  yagura2[8][8] = Piece(PieceType.king, true);

  final yagura3 = _empty();
  yagura3[0][4] = Piece(PieceType.king, false);
  yagura3[0][3] = Piece(PieceType.gold, false);
  yagura3[0][5] = Piece(PieceType.gold, false);
  yagura3[1][4] = Piece(PieceType.silver, false);
  yagura3[1][5] = Piece(PieceType.bishop, false);
  yagura3[2][4] = Piece(PieceType.pawn, false);
  yagura3[3][3] = Piece(PieceType.silver, true);
  yagura3[5][4] = Piece(PieceType.rook, true);
  yagura3[8][8] = Piece(PieceType.king, true);

  // ========== 手筋 ==========
  final tesujutsu1 = _empty();
  tesujutsu1[0][4] = Piece(PieceType.king, false);
  tesujutsu1[1][3] = Piece(PieceType.gold, false);
  tesujutsu1[1][4] = Piece(PieceType.silver, false);
  tesujutsu1[2][4] = Piece(PieceType.pawn, false);
  tesujutsu1[3][2] = Piece(PieceType.pawn, false);
  tesujutsu1[4][2] = Piece(PieceType.rook, true);
  tesujutsu1[4][4] = Piece(PieceType.knight, true);
  tesujutsu1[8][8] = Piece(PieceType.king, true);

  final tesujutsu2 = _empty();
  tesujutsu2[0][3] = Piece(PieceType.king, false);
  tesujutsu2[0][4] = Piece(PieceType.gold, false);
  tesujutsu2[1][2] = Piece(PieceType.silver, false);
  tesujutsu2[1][4] = Piece(PieceType.bishop, false);
  tesujutsu2[2][3] = Piece(PieceType.pawn, false);
  tesujutsu2[3][3] = Piece(PieceType.gold, true);
  tesujutsu2[4][2] = Piece(PieceType.knight, true);
  tesujutsu2[5][4] = Piece(PieceType.rook, true);
  tesujutsu2[8][8] = Piece(PieceType.king, true);

  final tesujutsu3 = _empty();
  tesujutsu3[0][4] = Piece(PieceType.king, false);
  tesujutsu3[0][5] = Piece(PieceType.gold, false);
  tesujutsu3[1][4] = Piece(PieceType.silver, false);
  tesujutsu3[1][5] = Piece(PieceType.pawn, false);
  tesujutsu3[2][2] = Piece(PieceType.bishop, true);
  tesujutsu3[3][4] = Piece(PieceType.silver, true);
  tesujutsu3[4][4] = Piece(PieceType.pawn, true);
  tesujutsu3[6][4] = Piece(PieceType.rook, true);
  tesujutsu3[8][8] = Piece(PieceType.king, true);

  return [
    // 美濃
    ChallengeProblem(
      id: 'mino_001',
      title: '美濃の端攻め',
      weakness: '美濃',
      board: mino1,
      p1Hand: {},
      answer: AMove(fr: 3, fc: 0, tr: 2, tc: 0, promote: false),
      explanation: '香を進めて端を攻める。美濃囲いの弱点は端です。',
    ),
    ChallengeProblem(
      id: 'mino_002',
      title: '美濃への桂跳ね',
      weakness: '美濃',
      board: mino2,
      p1Hand: {},
      answer: AMove(fr: 5, fc: 3, tr: 3, tc: 4, promote: false),
      explanation: '桂馬で盛り上がる。視点を変えたタイミングが大事。',
    ),
    ChallengeProblem(
      id: 'mino_003',
      title: '美濃の銀での攻め',
      weakness: '美濃',
      board: mino3,
      p1Hand: {},
      answer: AMove(fr: 3, fc: 1, tr: 2, tc: 1, promote: false),
      explanation: '銀を使った攻撃。金銀協力で美濃は崩壊します。',
    ),
    // 矢倉
    ChallengeProblem(
      id: 'yagura_001',
      title: '矢倉への４五歩',
      weakness: '矢倉',
      board: yagura1,
      p1Hand: {},
      answer: AMove(fr: 4, fc: 4, tr: 3, tc: 4, promote: false),
      explanation: '中央の歩を進める古典的な攻め方。矢倉囲いはここが弱い。',
    ),
    ChallengeProblem(
      id: 'yagura_002',
      title: '矢倉への桂跳ね',
      weakness: '矢倉',
      board: yagura2,
      p1Hand: {},
      answer: AMove(fr: 5, fc: 3, tr: 3, tc: 4, promote: false),
      explanation: '桂馬で矢倉を崩す。急速な展開が必要です。',
    ),
    ChallengeProblem(
      id: 'yagura_003',
      title: '矢倉への銀突き',
      weakness: '矢倉',
      board: yagura3,
      p1Hand: {},
      answer: AMove(fr: 3, fc: 3, tr: 2, tc: 3, promote: false),
      explanation: '銀を突いて矢倉に亀裂を入れる。相手の守りが乱れます。',
    ),
    // 手筋
    ChallengeProblem(
      id: 'tesujutsu_001',
      title: '飛車の横利き',
      weakness: '手筋',
      board: tesujutsu1,
      p1Hand: {},
      answer: AMove(fr: 4, fc: 2, tr: 4, tc: 1, promote: false),
      explanation: '飛車を横に使う手筋。敵陣に大きなダメージを与えます。',
    ),
    ChallengeProblem(
      id: 'tesujutsu_002',
      title: '角の利きを活かす',
      weakness: '手筋',
      board: tesujutsu2,
      p1Hand: {},
      answer: AMove(fr: 2, fc: 2, tr: 1, tc: 3, promote: false),
      explanation: '角の長い利きで敵陣を支配する。将棋の基本手筋です。',
    ),
    ChallengeProblem(
      id: 'tesujutsu_003',
      title: '銀を活用した手筋',
      weakness: '手筋',
      board: tesujutsu3,
      p1Hand: {},
      answer: AMove(fr: 3, fc: 4, tr: 2, tc: 4, promote: false),
      explanation: '銀の二段構えで敵玉を追い詰める。駒の協力が大事。',
    ),
  ];
}

// 対局の実際の敗因（KifuAnalyticsService に保存された openingName）から、
// この問題集にある3カテゴリ（美濃・矢倉・手筋）のうち練習すべきものを判定する。
// 該当する戦型での負けが記録になければ「手筋」を汎用の練習テーマとする。
Future<String> _deriveWeaknessType() async {
  try {
    final analyses = await KifuAnalyticsService().getAllAnalyses();
    final counts = <String, int>{};
    for (final a in analyses) {
      final name = a.openingName;
      if (a.playerWon || name == null || name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    if (counts.isNotEmpty) {
      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      if (top.contains('美濃')) return '美濃';
      if (top.contains('矢倉')) return '矢倉';
    }
  } catch (_) {}
  return '手筋';
}

// ──────────────────────────────────────────────
// Main Screen
// ──────────────────────────────────────────────

class FriendChallengeScreen extends StatefulWidget {
  const FriendChallengeScreen({super.key});

  @override
  State<FriendChallengeScreen> createState() => _FriendChallengeScreenState();
}

class _FriendChallengeScreenState extends State<FriendChallengeScreen> {
  List<FriendWeakness> _friends = [];
  late List<ChallengeProblem> _problems;
  bool _loading = true;
  bool _loggedIn = false;
  String _weaknessType = '手筋';

  @override
  void initState() {
    super.initState();
    _problems = _buildProblems();
    _load();
  }

  // 実際のフレンド（FriendService、Firestore）と自分の実際の弱点（対局分析）
  // から一覧を構成する。挑戦スコアだけは端末ローカルに保存する
  // （フレンド同士の対局同期までは行わない、あくまで一人用の反復練習）。
  Future<void> _load() async {
    final uid = NetworkService().currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loggedIn = false;
          _loading = false;
        });
      }
      return;
    }

    final weaknessType = await _deriveWeaknessType();
    final prefs = await SharedPreferences.getInstance();
    final scoresJson = prefs.getString('friend_challenge_scores_json');
    final scores = <String, int>{};
    if (scoresJson != null) {
      try {
        final decoded = jsonDecode(scoresJson) as Map<String, dynamic>;
        decoded.forEach((k, v) => scores[k] = v as int);
      } catch (_) {}
    }

    List<FriendInfo> friendInfos = [];
    try {
      friendInfos = await FriendService().watchFriends(uid).first;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loggedIn = true;
      _weaknessType = weaknessType;
      _friends = friendInfos
          .map((f) => FriendWeakness(
                friendId: f.userId,
                friendName: f.username,
                weaknessType: weaknessType,
                score: scores[f.userId] ?? 0,
              ))
          .toList();
      _loading = false;
    });
  }

  Future<void> _saveScore(String friendId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final scoresJson = prefs.getString('friend_challenge_scores_json');
    final scores = <String, int>{};
    if (scoresJson != null) {
      try {
        final decoded = jsonDecode(scoresJson) as Map<String, dynamic>;
        decoded.forEach((k, v) => scores[k] = v as int);
      } catch (_) {}
    }
    scores[friendId] = score;
    await prefs.setString('friend_challenge_scores_json', jsonEncode(scores));
  }

  void _onFriendTap(FriendWeakness friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FriendDetailSheet(
        friend: friend,
        onChallenge: () => _startChallenge(friend),
      ),
    );
  }

  void _startChallenge(FriendWeakness friend) {
    Navigator.pop(context); // Close detail sheet

    final friendProblems = _problems
        .where((p) => p.weakness == friend.weaknessType)
        .toList();

    if (friendProblems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('その弱点の問題がありません')),
      );
      return;
    }

    // Select 3 random problems
    friendProblems.shuffle();
    final selected = friendProblems.take(3).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VsScreen(
          friend: friend,
          problems: selected,
          onComplete: (wins) => _finishChallenge(friend, wins),
        ),
      ),
    );
  }

  void _finishChallenge(FriendWeakness friend, int wins) {
    // Update score
    final idx = _friends.indexWhere((f) => f.friendId == friend.friendId);
    if (idx >= 0) {
      final newScore = friend.score + wins;
      _friends[idx] = FriendWeakness(
        friendId: friend.friendId,
        friendName: friend.friendName,
        weaknessType: friend.weaknessType,
        score: newScore,
      );
      _saveScore(friend.friendId, newScore);
      StudyCalendarScreen.recordActivity('tesuji');
      setState(() {});
    }

    // Show result
    showDialog(
      context: context,
      builder: (_) => _ResultDialog(
        friend: friend,
        wins: wins,
        total: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '友達と弱点シェア対戦',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : !_loggedIn
              ? const Center(
                  child: Text(
                    'ログインするとフレンドとの弱点トレーニングができます',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : _friends.isEmpty
                  ? const Center(
                      child: Text(
                        'フレンドを追加してください\n（フレンド画面から検索・申請できます）',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withAlpha(80)),
                          ),
                          child: Text(
                            '今週の練習テーマ: $_weaknessType（あなたの最近の対局分析から算出）',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                        ..._friends.map((f) => _FriendCard(
                              friend: f,
                              onTap: () => _onFriendTap(f),
                            )),
                      ],
                    ),
    );
  }
}

// ──────────────────────────────────────────────
// Friend Card
// ──────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final FriendWeakness friend;
  final VoidCallback onTap;

  const _FriendCard({
    required this.friend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  friend.friendName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.friendName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.withAlpha(150),
                          ),
                        ),
                        child: Text(
                          '弱点: ${friend.weaknessType}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'スコア: ${friend.score}点',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Friend Detail Sheet
// ──────────────────────────────────────────────

class _FriendDetailSheet extends StatelessWidget {
  final FriendWeakness friend;
  final VoidCallback onChallenge;

  const _FriendDetailSheet({
    required this.friend,
    required this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.amber, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                friend.friendName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            friend.friendName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Weakness
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(150)),
            ),
            child: Text(
              '弱点: ${friend.weaknessType}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Score
          Text(
            'スコア: ${friend.score}点',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Challenge Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onChallenge,
              icon: const Icon(Icons.sports_martial_arts),
              label: const Text('対戦を開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// VS Screen (Problem Solving)
// ──────────────────────────────────────────────

class _VsScreen extends StatefulWidget {
  final FriendWeakness friend;
  final List<ChallengeProblem> problems;
  final Function(int) onComplete;

  const _VsScreen({
    required this.friend,
    required this.problems,
    required this.onComplete,
  });

  @override
  State<_VsScreen> createState() => _VsScreenState();
}

class _VsScreenState extends State<_VsScreen> {
  late int _currentProblemIndex;
  late Set<int> _correctAnswers;
  bool _showingAnswer = false;

  @override
  void initState() {
    super.initState();
    _currentProblemIndex = 0;
    _correctAnswers = {};
  }

  void _onAnswerSubmitted(bool isCorrect) {
    if (isCorrect) {
      _correctAnswers.add(_currentProblemIndex);
    }
    setState(() => _showingAnswer = true);
  }

  void _nextProblem() {
    if (_currentProblemIndex < widget.problems.length - 1) {
      setState(() {
        _currentProblemIndex++;
        _showingAnswer = false;
      });
    } else {
      Navigator.pop(context);
      widget.onComplete(_correctAnswers.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = widget.problems[_currentProblemIndex];
    final isLast = _currentProblemIndex == widget.problems.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          '${widget.friend.friendName} との対戦',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '問題 ${_currentProblemIndex + 1} / ${widget.problems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '正解: ${_correctAnswers.length}/${_currentProblemIndex + (_showingAnswer ? 1 : 0)}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Problem Title
                  Text(
                    problem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '弱点: ${problem.weakness}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Board
                  Center(
                    child: SizedBox(
                      width: 300,
                      height: 300,
                      child: MiniBoardWidget(
                        board: problem.board,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Show answer if revealed
                  if (_showingAnswer) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '回答: ${_positionToString((problem.answer.fr, problem.answer.fc))}→${_positionToString((problem.answer.tr, problem.answer.tc))}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            problem.explanation,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: _showingAnswer
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextProblem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        isLast ? '対戦を終了' : '次の問題へ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _onAnswerSubmitted(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withAlpha(80),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('不正解'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _onAnswerSubmitted(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withAlpha(150),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('正解'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _positionToString((int, int) pos) {
    const cols = ['9', '8', '7', '6', '5', '4', '3', '2', '1'];
    const rows = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return '${cols[pos.$2]}${rows[pos.$1]}';
  }
}

// ──────────────────────────────────────────────
// Result Dialog
// ──────────────────────────────────────────────

class _ResultDialog extends StatelessWidget {
  final FriendWeakness friend;
  final int wins;
  final int total;

  const _ResultDialog({
    required this.friend,
    required this.wins,
    required this.total,
  });

  String _getMessage() {
    if (wins == total) {
      return '完璧だ！${friend.friendName}の${friend.weaknessType}を完全に攻略しました！';
    } else if (wins >= total ~/ 2) {
      return 'いい調子だ！${friend.weaknessType}の弱点を上手く突いています！';
    } else {
      return 'もう少しだ！${friend.friendName}の${friend.weaknessType}をもっと研究しましょう。';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text(
        '対戦終了',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            '$wins / $total',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getMessage(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '閉じる',
            style: TextStyle(color: Colors.amber),
          ),
        ),
      ],
    );
  }
}
