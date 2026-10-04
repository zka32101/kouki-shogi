// lib/spaced_repetition_screen.dart — 忘却曲線AI (Spaced Repetition with forgetting curve)
// Anki-style SRS for shogi: problems reappear at optimal intervals using SM-2 algorithm
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'purchase_service.dart';
import 'theme/app_theme.dart';

// ===== SRS Item (spaced repetition data) =====
class _SRSItem {
  final String problemId;
  DateTime lastReviewDate;
  DateTime nextReviewDate;
  double easyFactor; // SM-2 ease factor (default 2.5)
  int interval; // days until next review

  _SRSItem({
    required this.problemId,
    required this.lastReviewDate,
    required this.nextReviewDate,
    this.easyFactor = 2.5,
    this.interval = 1,
  });

  Map<String, dynamic> toJson() => {
    'problemId': problemId,
    'lastReviewDate': lastReviewDate.toIso8601String(),
    'nextReviewDate': nextReviewDate.toIso8601String(),
    'easyFactor': easyFactor,
    'interval': interval,
  };

  factory _SRSItem.fromJson(Map<String, dynamic> json) => _SRSItem(
    problemId: json['problemId'] as String,
    lastReviewDate: DateTime.parse(json['lastReviewDate'] as String),
    nextReviewDate: DateTime.parse(json['nextReviewDate'] as String),
    easyFactor: json['easyFactor'] as double? ?? 2.5,
    interval: json['interval'] as int? ?? 1,
  );
}

// ===== Sample Problem Data =====
class _SRSProb {
  final String id;
  final String title;
  final String explanation;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  final AMove answer;

  const _SRSProb({
    required this.id,
    required this.title,
    required this.explanation,
    required this.board,
    this.p1Hand = const {},
    this.p2Hand = const {},
    this.p1Turn = true,
    required this.answer,
  });
}

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

// Sample problems (weaknesses from past mistakes)
List<_SRSProb> _buildSRSProblems() {
  final list = <_SRSProb>[];

  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);
    b[8][5] = Piece(PieceType.king, true);
    b[4][4] = Piece(PieceType.rook, false);
    b[6][6] = Piece(PieceType.bishop, true);
    list.add(_SRSProb(
      id: 'srs_001',
      title: '飛車取り - 復習①',
      explanation: '先手角が7七から5五へ斜めに動き、後手の飛車をタダ取りできます。',
      board: b,
      answer: AMove(fr: 6, fc: 6, tr: 4, tc: 4),
    ));
  }

  {
    final b = _empty();
    b[0][5] = Piece(PieceType.king, false);
    b[8][4] = Piece(PieceType.king, true);
    b[1][7] = Piece(PieceType.rook, false);
    b[3][6] = Piece(PieceType.knight, true);
    list.add(_SRSProb(
      id: 'srs_002',
      title: '桂跳び飛車取り - 復習②',
      explanation: '先手桂馬が3四から2二に跳んで後手飛車を取ります。',
      board: b,
      answer: AMove(fr: 3, fc: 6, tr: 1, tc: 7),
    ));
  }

  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[8][0] = Piece(PieceType.king, true);
    b[7][1] = Piece(PieceType.rook, false);
    b[8][2] = Piece(PieceType.silver, true);
    list.add(_SRSProb(
      id: 'srs_003',
      title: '銀による飛車取り - 復習③',
      explanation: '先手銀が7九から8八へ移動して後手飛車を取ります。',
      board: b,
      answer: AMove(fr: 8, fc: 2, tr: 7, tc: 1),
    ));
  }

  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[2][4] = Piece(PieceType.gold, false);
    b[8][0] = Piece(PieceType.king, true);
    b[4][4] = Piece(PieceType.rook, true);
    list.add(_SRSProb(
      id: 'srs_004',
      title: '王手金取り - 復習④',
      explanation: '先手飛車が5五から前進して5三の後手金を取ります。',
      board: b,
      answer: AMove(fr: 4, fc: 4, tr: 2, tc: 4),
    ));
  }

  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);
    b[8][8] = Piece(PieceType.king, true);
    b[1][1] = Piece(PieceType.gold, true);
    b[0][1] = Piece(PieceType.silver, true);
    b[0][3] = Piece(PieceType.gold, true);
    list.add(_SRSProb(
      id: 'srs_005',
      title: '詰め手筋 - 復習⑤',
      explanation: '先手は持ち駒の角を打って王手をかけます。',
      board: b,
      p1Hand: {PieceType.bishop: 1},
      answer: AMove(fr: -1, fc: -1, tr: 2, tc: 4, drop: PieceType.bishop),
    ));
  }

  // ── 新規問題 ⑥〜⑮ ──────────────────────────────────────────

  {
    // 角[7][5]→[5][3]: 後手飛車を取る。[5][3]から斜め上右→[1][7]で王手
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[1][7] = Piece(PieceType.king, false);
    b[7][5] = Piece(PieceType.bishop, true);
    b[5][3] = Piece(PieceType.rook, false);
    list.add(_SRSProb(
      id: 'srs_006',
      title: '王手飛車取り - 角篇',
      explanation: '先手の角が後手の飛車を取りながら、同時に後手玉に王手をかけます。一石二鳥の手を見つけてください。',
      board: b,
      answer: AMove(fr: 7, fc: 5, tr: 5, tc: 3),
    ));
  }

  {
    // 桂[6][5]→[4][4]: 後手飛車を取る。桂は[2][3]と[2][5]を攻撃→後手玉[2][5]に王手
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[2][5] = Piece(PieceType.king, false);
    b[6][5] = Piece(PieceType.knight, true);
    b[4][4] = Piece(PieceType.rook, false);
    list.add(_SRSProb(
      id: 'srs_007',
      title: '桂馬の王手飛車取り',
      explanation: '先手桂馬が後手の飛車を取りながら、後手玉に王手をかける好手を指してください。桂馬は跳び越せます。',
      board: b,
      answer: AMove(fr: 6, fc: 5, tr: 4, tc: 4),
    ));
  }

  {
    // 金[2][5]→[1][4]: 後手玉[0][4]に王手。金の利きで全逃げ道封鎖。先手飛車[1][8]が[1][4]を守る
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[2][5] = Piece(PieceType.gold, true);
    b[1][8] = Piece(PieceType.rook, true);
    list.add(_SRSProb(
      id: 'srs_008',
      title: '金の一手詰め',
      explanation: '先手の金を斜め前に動かして後手玉を詰ませてください。金の動きと、飛車による金の守りがポイントです。',
      board: b,
      answer: AMove(fr: 2, fc: 5, tr: 1, tc: 4),
    ));
  }

  {
    // 竜[3][4]→[1][4]: 後手玉[0][4]に王手。後手銀[0][3]・後手金[0][5]で横逃げ不可。先手金[2][3]が[1][4]を守る
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[0][3] = Piece(PieceType.silver, false);
    b[0][5] = Piece(PieceType.gold, false);
    b[3][4] = Piece(PieceType.promotedRook, true);
    b[2][3] = Piece(PieceType.gold, true);
    list.add(_SRSProb(
      id: 'srs_009',
      title: '竜の一手詰め',
      explanation: '先手の竜（成り飛車）を前進させて後手玉を詰ませてください。後手の駒が逃げ道を塞いでいる点に注目。',
      board: b,
      answer: AMove(fr: 3, fc: 4, tr: 1, tc: 4),
    ));
  }

  {
    // 角[4][0]→[2][2]: 後手玉[0][4]に[1][3]→[0][4]で王手。先手金[2][3]→[1][4]封鎖、先手香[8][5]→[1][5]封鎖
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[0][3] = Piece(PieceType.silver, false);
    b[0][5] = Piece(PieceType.gold, false);
    b[4][0] = Piece(PieceType.bishop, true);
    b[2][3] = Piece(PieceType.gold, true);
    b[8][5] = Piece(PieceType.lance, true);
    list.add(_SRSProb(
      id: 'srs_010',
      title: '遠見の角 - 大斜め詰め',
      explanation: '先手の角を遠くに動かして後手玉に王手をかけてください。角の長い斜め利きで詰みを実現するのがポイントです。',
      board: b,
      answer: AMove(fr: 4, fc: 0, tr: 2, tc: 2),
    ));
  }

  {
    // 角[5][2]→[3][4]: 後手飛車[3][4]をタダ取り（守り駒なし）
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[5][2] = Piece(PieceType.bishop, true);
    b[3][4] = Piece(PieceType.rook, false);
    b[2][4] = Piece(PieceType.pawn, false);
    list.add(_SRSProb(
      id: 'srs_011',
      title: '飛車をタダ取り',
      explanation: '後手の飛車がタダで取れます。角の利きを活かして大駒を取ってください。',
      board: b,
      answer: AMove(fr: 5, fc: 2, tr: 3, tc: 4),
    ));
  }

  {
    // 角[5][6]→[3][4]: 後手金[1][6]と後手飛車[5][2]を同時に攻撃（両取り）
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[5][6] = Piece(PieceType.bishop, true);
    b[1][6] = Piece(PieceType.gold, false);
    b[5][2] = Piece(PieceType.rook, false);
    list.add(_SRSProb(
      id: 'srs_012',
      title: '角の両取り（ダブルアタック）',
      explanation: '先手の角を動かすと、後手の飛車と金を同時に攻撃できます。一手で二つの駒を狙う「両取り」を見つけてください。',
      board: b,
      answer: AMove(fr: 5, fc: 6, tr: 3, tc: 4),
    ));
  }

  {
    // 竜[3][3]→[1][3]: 後手飛車[1][3]を縦にタダ取り（守り駒なし）
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[3][3] = Piece(PieceType.promotedRook, true);
    b[1][3] = Piece(PieceType.rook, false);
    b[3][7] = Piece(PieceType.silver, false);
    list.add(_SRSProb(
      id: 'srs_013',
      title: '竜で飛車をタダ取り',
      explanation: '先手の竜（成り飛車）で後手の飛車をタダで取れます。縦の利きを使った基本の「タダ取り」です。',
      board: b,
      answer: AMove(fr: 3, fc: 3, tr: 1, tc: 3),
    ));
  }

  {
    // 桂[6][5]→[4][4]: 後手金[4][4]を跳んで取る（守り駒なし）
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[6][5] = Piece(PieceType.knight, true);
    b[4][4] = Piece(PieceType.gold, false);
    b[4][2] = Piece(PieceType.silver, false);
    list.add(_SRSProb(
      id: 'srs_014',
      title: '桂馬の急所 - 金をタダ取り',
      explanation: '先手の桂馬を跳ばせると後手の金をタダで取れます。桂馬は他の駒を跳び越えられる特殊な動きです。',
      board: b,
      answer: AMove(fr: 6, fc: 5, tr: 4, tc: 4),
    ));
  }

  {
    // 飛車[5][4]→[2][4]: 後手金[2][4]を取る。横に銀[5][2]も取れるが金の方が価値が高い
    final b = _empty();
    b[8][0] = Piece(PieceType.king, true);
    b[0][4] = Piece(PieceType.king, false);
    b[5][4] = Piece(PieceType.rook, true);
    b[2][4] = Piece(PieceType.gold, false);
    b[5][2] = Piece(PieceType.silver, false);
    list.add(_SRSProb(
      id: 'srs_015',
      title: '飛車で大駒選択 - どちらを取る？',
      explanation: '先手の飛車は縦に金も、横に銀も取れます。駒の価値（金＞銀）を考えて、より大きな駒を取ってください。',
      board: b,
      answer: AMove(fr: 5, fc: 4, tr: 2, tc: 4),
    ));
  }

  return list;
}

// ===== Main Screen =====
class SpacedRepetitionScreen extends StatefulWidget {
  const SpacedRepetitionScreen({super.key});

  @override
  State<SpacedRepetitionScreen> createState() => _SpacedRepetitionScreenState();
}

class _SpacedRepetitionScreenState extends State<SpacedRepetitionScreen> {
  final List<_SRSProb> _problems = _buildSRSProblems();
  List<_SRSItem> _srsItems = [];
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Check premium status
    final prefs = await SharedPreferences.getInstance();
    _isPremium = PurchaseService.isPremium;

    // Load SRS items
    final srsJson = prefs.getStringList('srs_items_json') ?? [];
    _srsItems = srsJson
        .map((j) => _SRSItem.fromJson(jsonDecode(j)))
        .toList();

    // Initialize missing items with default schedule (1 day, 3 days, 7 days, 14 days, 30 days)
    final now = DateTime.now();
    for (final prob in _problems) {
      if (!_srsItems.any((item) => item.problemId == prob.id)) {
        // New item: first review in 1 day
        _srsItems.add(_SRSItem(
          problemId: prob.id,
          lastReviewDate: now,
          nextReviewDate: now.add(const Duration(days: 1)),
          easyFactor: 2.5,
          interval: 1,
        ));
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSRSItems() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _srsItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('srs_items_json', json);
  }

  // Get problems due for review (nextReviewDate <= today)
  // 保存済みSRSアイテムの problemId が現在の問題集に存在しない場合
  // （バージョンアップで問題が削除・改番された等）は、プレースホルダを
  // 表示すると後段の _reviewProblem() で該当アイテムが見つからずクラッシュする。
  // そのため存在しない問題は結果から除外する。
  List<_SRSProb> _getDueProblems() {
    final now = DateTime.now();
    final byId = {for (final p in _problems) p.id: p};
    return _srsItems
        .where((item) => item.nextReviewDate.isBefore(now) ||
            item.nextReviewDate.isAtSameMomentAs(now))
        .map((item) => byId[item.problemId])
        .whereType<_SRSProb>()
        .toList();
  }

  Future<void> _reviewProblem(_SRSProb prob, bool correct) async {
    // SM-2 algorithm
    // _getDueProblems() が存在する問題のみを返すため通常は必ず一致するが、
    // 念のため見つからない場合は何もしないよう orElse でガードする。
    final matches = _srsItems.where((i) => i.problemId == prob.id);
    if (matches.isEmpty) return;
    final item = matches.first;
    final now = DateTime.now();

    if (correct) {
      // Correct: increase interval
      if (item.interval == 1) {
        item.interval = 3;
      } else if (item.interval == 3) {
        item.interval = 7;
      } else if (item.interval == 7) {
        item.interval = 14;
      } else if (item.interval == 14) {
        item.interval = 30;
      } else {
        // Stay at 30 days after reaching max
        item.interval = 30;
      }
      item.easyFactor = (item.easyFactor + 0.1).clamp(1.3, 2.5);
    } else {
      // Incorrect: reset to 1 day
      item.interval = 1;
      item.easyFactor = (item.easyFactor - 0.2).clamp(1.3, 2.5);
    }

    item.lastReviewDate = now;
    item.nextReviewDate = now.add(Duration(days: item.interval));

    await _saveSRSItems();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('忘却曲線トレーニング 👑',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    // Premium gate
    if (!_isPremium) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('忘却曲線トレーニング 👑',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              const Text(
                'プレミアム機能',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Anki風の復習システム。\n過去の間違い問題が最適な\nタイミングで復習できます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('プレミアムを購入',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final dueProblems = _getDueProblems();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('忘却曲線トレーニング 👑',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: dueProblems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    '本日の復習は完了！',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_srsItems.length} 問の復習スケジュール登録済み',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header with review count
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '今日の復習: ${dueProblems.length}問',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(100),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${((1 - dueProblems.length / _srsItems.length) * 100).toStringAsFixed(0)}% 完了',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 1 - (dueProblems.length / _srsItems.length),
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                // Problem list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: dueProblems.length,
                    itemBuilder: (context, index) {
                      final prob = dueProblems[index];
                      final srsItem = _srsItems.firstWhere((i) => i.problemId == prob.id);
                      return _SRSProblemCard(
                        prob: prob,
                        srsItem: srsItem,
                        onTap: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _SRSDetailScreen(
                                prob: prob,
                                srsItem: srsItem,
                              ),
                            ),
                          );
                          if (result != null) {
                            await _reviewProblem(prob, result);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ===== SRS Problem Card =====
class _SRSProblemCard extends StatelessWidget {
  final _SRSProb prob;
  final _SRSItem srsItem;
  final VoidCallback onTap;

  const _SRSProblemCard({
    required this.prob,
    required this.srsItem,
    required this.onTap,
  });

  String _daysSinceLastReview() {
    final days = DateTime.now().difference(srsItem.lastReviewDate).inDays;
    if (days == 0) return '今日';
    if (days == 1) return '昨日';
    return '$days 日前';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white12,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    prob.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '【復習】',
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '前回不正解: ${_daysSinceLastReview()}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '次の復習: ${srsItem.nextReviewDate.difference(DateTime.now()).inDays} 日後',
              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '難度係数: ${srsItem.easyFactor.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== SRS Detail Screen =====
class _SRSDetailScreen extends StatefulWidget {
  final _SRSProb prob;
  final _SRSItem srsItem;

  const _SRSDetailScreen({required this.prob, required this.srsItem});

  @override
  State<_SRSDetailScreen> createState() => _SRSDetailScreenState();
}

class _SRSDetailScreenState extends State<_SRSDetailScreen> {
  (int, int)? _selectedFrom;
  Set<(int, int)> _moveDots = {};
  bool? _result; // null=未回答, true=正解, false=不正解
  late List<List<Piece?>> _board;

  @override
  void initState() {
    super.initState();
    _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
  }

  void _onCellTap(int r, int c) {
    if (_result != null) return;

    final piece = _board[r][c];

    if (_selectedFrom == null) {
      if (piece != null && piece.isPlayer1 == widget.prob.p1Turn) {
        setState(() {
          _selectedFrom = (r, c);
          _moveDots = _calcSimpleDots(r, c, piece);
        });
      }
    } else {
      final (fr, fc) = _selectedFrom!;
      if (fr == r && fc == c) {
        setState(() {
          _selectedFrom = null;
          _moveDots = {};
        });
        return;
      }
      _checkAnswer(fr, fc, r, c, null);
    }
  }

  void _onHandPieceTap(PieceType type) {
    if (_result != null) return;
    setState(() {
      _selectedFrom = (-1, -1);
      _moveDots = _calcDropDots(type);
    });
  }

  void _onDropTarget(int r, int c, PieceType type) {
    if (_result != null) return;
    _checkAnswer(-1, -1, r, c, type);
  }

  void _checkAnswer(int fr, int fc, int tr, int tc, PieceType? drop) {
    final ans = widget.prob.answer;
    final correct = ans.fr == fr &&
        ans.fc == fc &&
        ans.tr == tr &&
        ans.tc == tc &&
        ans.drop == drop;

    if (drop != null) {
      _board[tr][tc] = Piece(drop, widget.prob.p1Turn);
    } else if (fr >= 0 && fc >= 0) {
      final piece = _board[fr][fc];
      if (piece != null) {
        _board[tr][tc] = piece;
        _board[fr][fc] = null;
      }
    }

    setState(() {
      _result = correct;
      _selectedFrom = null;
      _moveDots = {};
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.pop(context, correct);
      }
    });
  }

  Set<(int, int)> _calcSimpleDots(int r, int c, Piece piece) {
    final dots = <(int, int)>{};
    // Simple example: show adjacent cells
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
          dots.add((nr, nc));
        }
      }
    }
    return dots;
  }

  Set<(int, int)> _calcDropDots(PieceType type) {
    final dots = <(int, int)>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c] == null) {
          dots.add((r, c));
        }
      }
    }
    return dots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('問題を解く',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.prob.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '前回不正解: ${DateTime.now().difference(widget.srsItem.lastReviewDate).inDays} 日前',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Board
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 9,
                        childAspectRatio: 1,
                      ),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 81,
                      itemBuilder: (context, index) {
                        final r = index ~/ 9;
                        final c = index % 9;
                        final piece = _board[r][c];
                        final isSelected = _selectedFrom == (r, c);
                        final canMove = _moveDots.contains((r, c));

                        return GestureDetector(
                          onTap: () => _onCellTap(r, c),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.amber.withAlpha(100)
                                  : canMove
                                      ? Colors.blue.withAlpha(80)
                                      : Colors.white12,
                              border: Border.all(
                                color: Colors.white24,
                                width: 0.5,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (piece != null)
                                  Center(
                                    child: _PieceWidget(piece: piece),
                                  ),
                                if (canMove)
                                  Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(100), width: 0.8),
              ),
              child: Text(
                widget.prob.explanation,
                style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Result feedback
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _result!
                      ? Colors.green.withAlpha(30)
                      : Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _result! ? Colors.green.withAlpha(100) : Colors.red.withAlpha(100),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _result! ? Icons.check_circle : Icons.cancel,
                      color: _result! ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!
                            ? '正解！次の復習: ${widget.srsItem.nextReviewDate.difference(DateTime.now()).inDays + 1} 日後'
                            : '不正解。正解は ${_answerText(widget.prob.answer)}',
                        style: TextStyle(
                          color: _result! ? Colors.green.shade300 : Colors.red.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _answerText(AMove move) {
    if (move.drop != null) {
      return '${move.drop!.name}を${_posText(move.tr, move.tc)}に打つ';
    }
    return '${_posText(move.fr, move.fc)}から${_posText(move.tr, move.tc)}へ';
  }

  String _posText(int r, int c) {
    final col = String.fromCharCode(57 - c); // 9→9筋, 0→1筋
    final row = (r + 1).toString();
    return '$col$row';
  }
}

// ===== Piece Widget =====
class _PieceWidget extends StatelessWidget {
  final Piece piece;

  const _PieceWidget({required this.piece});

  String get _kana {
    switch (piece.type) {
      case PieceType.king:
        return '玉';
      case PieceType.rook:
        return '飛';
      case PieceType.bishop:
        return '角';
      case PieceType.gold:
        return '金';
      case PieceType.silver:
        return '銀';
      case PieceType.knight:
        return '桂';
      case PieceType.lance:
        return '香';
      case PieceType.pawn:
        return '歩';
      case PieceType.promotedRook:
        return '龍';
      case PieceType.promotedBishop:
        return '馬';
      case PieceType.promotedSilver:
        return '全';
      case PieceType.promotedKnight:
        return '圭';
      case PieceType.promotedLance:
        return '杏';
      case PieceType.promotedPawn:
        return 'と';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = piece.isPlayer1 ? Colors.white : Colors.red.shade800;
    final fg = piece.isPlayer1 ? Colors.black : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _kana,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
