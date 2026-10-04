// lib/puzzle_generator_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'piece.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';
import 'purchase_service.dart';
import 'screens/premium_screen.dart';

class _GenPuzzle {
  final String id;
  final String title;
  final int moves; // 1 or 3
  final List<List<Piece?>> board;
  final String answerDesc; // e.g. "▲1一飛成が正解"
  final String createdAt;
  bool solved;

  _GenPuzzle({
    required this.id,
    required this.title,
    required this.moves,
    required this.board,
    required this.answerDesc,
    required this.createdAt,
    this.solved = false,
  });
}

// ── Serialization helpers ────────────────────────────────────────────────────

String _pieceToStr(Piece? p) {
  if (p == null) return '';
  final owner = p.isPlayer1 ? '1' : '0';
  switch (p.type) {
    case PieceType.king:
      return 'K$owner';
    case PieceType.rook:
      return 'R$owner';
    case PieceType.bishop:
      return 'B$owner';
    case PieceType.gold:
      return 'G$owner';
    case PieceType.silver:
      return 'S$owner';
    case PieceType.knight:
      return 'N$owner';
    case PieceType.lance:
      return 'L$owner';
    case PieceType.pawn:
      return 'P$owner';
    case PieceType.promotedRook:
      return '+R$owner';
    case PieceType.promotedBishop:
      return '+B$owner';
    case PieceType.promotedSilver:
      return '+S$owner';
    case PieceType.promotedKnight:
      return '+N$owner';
    case PieceType.promotedLance:
      return '+L$owner';
    case PieceType.promotedPawn:
      return '+P$owner';
    default:
      return '';
  }
}

Piece? _strToPiece(String s) {
  if (s.isEmpty) return null;
  final isP1 = s.endsWith('1');
  final typeStr = s.substring(0, s.length - 1);
  PieceType? t;
  switch (typeStr) {
    case 'K':
      t = PieceType.king;
      break;
    case 'R':
      t = PieceType.rook;
      break;
    case 'B':
      t = PieceType.bishop;
      break;
    case 'G':
      t = PieceType.gold;
      break;
    case 'S':
      t = PieceType.silver;
      break;
    case 'N':
      t = PieceType.knight;
      break;
    case 'L':
      t = PieceType.lance;
      break;
    case 'P':
      t = PieceType.pawn;
      break;
    case '+R':
      t = PieceType.promotedRook;
      break;
    case '+B':
      t = PieceType.promotedBishop;
      break;
    case '+S':
      t = PieceType.promotedSilver;
      break;
    case '+N':
      t = PieceType.promotedKnight;
      break;
    case '+L':
      t = PieceType.promotedLance;
      break;
    case '+P':
      t = PieceType.promotedPawn;
      break;
  }
  if (t == null) return null;
  return Piece(t, isP1);
}

List<List<Piece?>> _boardFromJson(List<dynamic> rows) {
  return List.generate(9, (r) {
    final row = rows[r] as List<dynamic>;
    return List.generate(9, (c) => _strToPiece(row[c] as String));
  });
}

List<List<String>> _boardToJson(List<List<Piece?>> board) {
  return List.generate(
      9, (r) => List.generate(9, (c) => _pieceToStr(board[r][c])));
}

_GenPuzzle _puzzleFromMap(Map<String, dynamic> m) {
  return _GenPuzzle(
    id: m['id'] as String,
    title: m['title'] as String,
    moves: m['moves'] as int,
    board: _boardFromJson(m['board'] as List<dynamic>),
    answerDesc: m['answerDesc'] as String,
    createdAt: m['createdAt'] as String,
    solved: (m['solved'] as bool?) ?? false,
  );
}

Map<String, dynamic> _puzzleToMap(_GenPuzzle p) {
  return {
    'id': p.id,
    'title': p.title,
    'moves': p.moves,
    'board': _boardToJson(p.board),
    'answerDesc': p.answerDesc,
    'createdAt': p.createdAt,
    'solved': p.solved,
  };
}

// ── Template helpers ─────────────────────────────────────────────────────────

List<List<Piece?>> _emptyBoard() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

void _place(List<List<Piece?>> b, int r, int c, Piece p) {
  if (r >= 0 && r < 9 && c >= 0 && c < 9) b[r][c] = p;
}

// ── 8 Templates ──────────────────────────────────────────────────────────────
// (旧版は8テンプレート全てで開始局面から玉に王手がかかっており
//  ―一部は二重・三重王手― 不成立だった。テンプレート1の解答文も
//  「玉の位置に成り込む」という将棋のルール上不可能な手を説明していた。
//  また旧版は生成のたびランダムオフセット(dr,dc)を各駒に個別加算・clamp
//  しており、盤端付近の駒がclampで相対位置を崩す事故も起きていた。
//  TsumeEngineでの検証により発覚・修正: 各テンプレートを開始局面が合法
//  （王手でも行き詰まりでもない）かつ解答手が実際に王手・詰みとなる形に
//  再設計し、位置のランダム化は廃止して固定局面にした)

typedef _TemplateFn = Map<String, dynamic> Function();

Map<String, dynamic> _template1() {
  final b = _emptyBoard();
  _place(b, 0, 8, Piece(PieceType.king, false));
  _place(b, 1, 3, Piece(PieceType.rook, true));
  _place(b, 2, 7, Piece(PieceType.gold, true));
  return {
    'board': b,
    'answerDesc': '▲飛車を9二へ横に成り込むのが正解（龍王の八方に利き、金が守る）',
    'title': '隅の詰み（飛・金）',
  };
}

Map<String, dynamic> _template2() {
  final b = _emptyBoard();
  _place(b, 0, 0, Piece(PieceType.king, false));
  _place(b, 4, 4, Piece(PieceType.pawn, false));
  _place(b, 2, 1, Piece(PieceType.gold, true));
  _place(b, 2, 0, Piece(PieceType.knight, true));
  _place(b, 3, 0, Piece(PieceType.knight, true));
  _place(b, 0, 2, Piece(PieceType.bishop, true));
  return {
    'board': b,
    'answerDesc': '▲角を2二へ進めて斜めから王手、金・桂が逃げ道を塞ぐ',
    'title': '隅の詰み（角・金）',
  };
}

Map<String, dynamic> _template3() {
  final b = _emptyBoard();
  _place(b, 8, 4, Piece(PieceType.king, false));
  _place(b, 4, 4, Piece(PieceType.pawn, false));
  _place(b, 7, 3, Piece(PieceType.gold, true));
  _place(b, 7, 5, Piece(PieceType.gold, true));
  _place(b, 8, 3, Piece(PieceType.lance, true));
  _place(b, 8, 5, Piece(PieceType.lance, true));
  _place(b, 6, 7, Piece(PieceType.rook, true));
  return {
    'board': b,
    'answerDesc': '▲飛車を中段まで進め、金二枚・香二本で中段の玉を追い詰める',
    'title': '中段の詰み（飛・金二枚）',
  };
}

Map<String, dynamic> _template4() {
  final b = _emptyBoard();
  _place(b, 0, 0, Piece(PieceType.king, false));
  _place(b, 4, 4, Piece(PieceType.pawn, false));
  _place(b, 2, 2, Piece(PieceType.silver, true));
  _place(b, 2, 0, Piece(PieceType.knight, true));
  _place(b, 3, 0, Piece(PieceType.knight, true));
  _place(b, 3, 1, Piece(PieceType.knight, true));
  _place(b, 8, 1, Piece(PieceType.lance, true));
  return {
    'board': b,
    'answerDesc': '▲銀を2二へ進めて王手し、桂・香で退路を封じる',
    'title': '銀・香の詰み',
  };
}

Map<String, dynamic> _template5() {
  final b = _emptyBoard();
  _place(b, 0, 4, Piece(PieceType.king, false));
  _place(b, 4, 4, Piece(PieceType.pawn, false));
  _place(b, 1, 2, Piece(PieceType.gold, true));
  _place(b, 1, 6, Piece(PieceType.gold, true));
  _place(b, 3, 3, Piece(PieceType.knight, true));
  _place(b, 1, 5, Piece(PieceType.rook, true));
  return {
    'board': b,
    'answerDesc': '▲飛車を5二へ寄せて正面から迫り、金二枚で逃げ道を塞ぐ',
    'title': '上辺の詰み（飛・金二枚）',
  };
}

Map<String, dynamic> _template6() {
  final b = _emptyBoard();
  _place(b, 8, 0, Piece(PieceType.king, false));
  _place(b, 4, 4, Piece(PieceType.pawn, false));
  _place(b, 8, 2, Piece(PieceType.gold, true));
  _place(b, 6, 1, Piece(PieceType.silver, true));
  _place(b, 7, 3, Piece(PieceType.rook, true));
  return {
    'board': b,
    'answerDesc': '▲飛車を寄せて縦から王手し、金・銀で逃げ道を挟む',
    'title': '端の詰み（飛・金挟み）',
  };
}

Map<String, dynamic> _template7() {
  final b = _emptyBoard();
  _place(b, 0, 0, Piece(PieceType.king, false));
  _place(b, 2, 1, Piece(PieceType.pawn, true));
  _place(b, 2, 0, Piece(PieceType.promotedBishop, true));
  return {
    'board': b,
    'answerDesc': '▲龍馬（成角）を寄せて斜め王手、歩が退路を封鎖',
    'title': '成角・歩の詰み',
  };
}

Map<String, dynamic> _template8() {
  final b = _emptyBoard();
  _place(b, 8, 8, Piece(PieceType.king, false));
  _place(b, 6, 7, Piece(PieceType.silver, true));
  _place(b, 7, 5, Piece(PieceType.promotedRook, true));
  return {
    'board': b,
    'answerDesc': '▲龍（成飛）を寄せて縦に迫り、銀が斜めの逃げ道を封じる',
    'title': '下辺の詰み（龍・銀）',
  };
}

final List<_TemplateFn> _templates = [
  _template1,
  _template2,
  _template3,
  _template4,
  _template5,
  _template6,
  _template7,
  _template8,
];

// ── Screen ───────────────────────────────────────────────────────────────────

class PuzzleGeneratorScreen extends StatefulWidget {
  const PuzzleGeneratorScreen({super.key});

  @override
  State<PuzzleGeneratorScreen> createState() => _PuzzleGeneratorScreenState();
}

class _PuzzleGeneratorScreenState extends State<PuzzleGeneratorScreen> {
  static const _kPuzzlesKey = 'generated_puzzles';

  static const _bgColor = AppTheme.bg;
  static const _appBarColor = AppTheme.surface;
  static const _goldColor = Color(0xFFFFD700);
  static const _cardColor = AppTheme.surface;
  static const _white87 = Color(0xDEFFFFFF);

  List<_GenPuzzle> _collection = [];
  _GenPuzzle? _preview;
  int _selectedMoves = 1;
  bool get _isPremium => PurchaseService.isPremium;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPuzzlesKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _collection =
            list.map((e) => _puzzleFromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _collection = [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _persistCollection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPuzzlesKey,
      jsonEncode(_collection.map(_puzzleToMap).toList()),
    );
  }

  void _generate() {
    final rng = math.Random();
    final idx = rng.nextInt(_templates.length);
    final tpl = _templates[idx]();
    final board = tpl['board'] as List<List<Piece?>>;
    final answerDesc = tpl['answerDesc'] as String;
    final title = tpl['title'] as String;
    final now = DateTime.now();
    final id =
        '${now.millisecondsSinceEpoch}_${rng.nextInt(9999).toString().padLeft(4, '0')}';
    final createdAt =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    setState(() {
      _preview = _GenPuzzle(
        id: id,
        title: '$title（${_selectedMoves}手詰め）',
        moves: _selectedMoves,
        board: board,
        answerDesc: answerDesc,
        createdAt: createdAt,
      );
    });
  }

  Future<void> _savePuzzle(_GenPuzzle puzzle) async {
    if (_collection.any((p) => p.id == puzzle.id)) return;
    setState(() {
      _collection.insert(0, puzzle);
      _preview = null;
    });
    await _persistCollection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コレクションに保存しました'),
          backgroundColor: AppTheme.surface,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSolveDialog(_GenPuzzle puzzle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          puzzle.title,
          style: const TextStyle(color: _white87, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniBoardWidget(board: puzzle.board, size: 260),
            const SizedBox(height: 16),
            Text(
              puzzle.answerDesc,
              style: const TextStyle(color: _goldColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => puzzle.solved = true);
              _persistCollection();
              Navigator.of(ctx).pop();
            },
            child:
                const Text('解けた！', style: TextStyle(color: _goldColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる', style: TextStyle(color: _white87)),
          ),
        ],
      ),
    );
  }

  // ── Widget builders ──────────────────────────────────────────────────────

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'AI詰将棋ジェネレーター',
          style: TextStyle(
            color: _goldColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          'あなただけのオリジナル詰将棋を生成します',
          style: TextStyle(color: _white87, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [1, 3].map((moves) {
        final selected = _selectedMoves == moves;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => setState(() => _selectedMoves = moves),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _goldColor : _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _goldColor,
                  width: selected ? 0 : 1.5,
                ),
              ),
              child: Text(
                '${moves}手詰め',
                style: TextStyle(
                  color: selected ? _bgColor : _goldColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _generate,
        icon: const Text('🎲', style: TextStyle(fontSize: 20)),
        label: const Text(
          '詰将棋を生成する',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.bg,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _goldColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildPreviewCard(_GenPuzzle puzzle) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldColor.withOpacity(0.5), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            puzzle.title,
            style: const TextStyle(
              color: _white87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          MiniBoardWidget(board: puzzle.board, size: 250),
          const SizedBox(height: 12),
          Text(
            puzzle.answerDesc,
            style: const TextStyle(color: _goldColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _savePuzzle(puzzle),
              icon:
                  const Icon(Icons.save_alt, color: _goldColor, size: 18),
              label: const Text(
                'コレクションに保存',
                style: TextStyle(color: _goldColor),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _goldColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionItem(_GenPuzzle puzzle) {
    return GestureDetector(
      onTap: () => _showSolveDialog(puzzle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: puzzle.solved
                ? _goldColor.withOpacity(0.7)
                : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    puzzle.title,
                    style: const TextStyle(
                      color: _white87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _goldColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _goldColor.withOpacity(0.4),
                              width: 1),
                        ),
                        child: Text(
                          '${puzzle.moves}手詰め',
                          style: const TextStyle(
                              color: _goldColor, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        puzzle.createdAt,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (puzzle.solved)
              const Icon(Icons.check_circle, color: _goldColor, size: 22)
            else
              const Icon(Icons.chevron_right,
                  color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildCollection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 8),
        Text(
          'コレクション (${_collection.length})',
          style: const TextStyle(
            color: _white87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (_collection.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'まだ保存された詰将棋はありません',
                style:
                    TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _collection.length,
            itemBuilder: (_, i) =>
                _buildCollectionItem(_collection[i]),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildDifficultySelector(),
          const SizedBox(height: 20),
          _buildGenerateButton(),
          if (_preview != null) ...[
            const SizedBox(height: 20),
            _buildPreviewCard(_preview!),
          ],
          const SizedBox(height: 20),
          _buildCollection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPremiumGate() {
    return Stack(
      children: [
        // Blurred / dimmed main content
        Opacity(
          opacity: 0.18,
          child: _buildMainContent(),
        ),
        // Lock overlay
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _goldColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _goldColor.withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: _goldColor, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'プレミアム機能',
                  style: TextStyle(
                    color: _goldColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'AI詰将棋ジェネレーターは\nプレミアム会員限定の機能です。',
                  style: TextStyle(
                      color: _white87, fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _goldColor,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'プレミアムに登録する',
                      style: TextStyle(
                        color: AppTheme.bg,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        title: const Text(
          'AI詰将棋ジェネレーター 👑',
          style: TextStyle(color: _white87, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: _white87),
        elevation: 2,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _goldColor),
            )
          : _isPremium
              ? _buildMainContent()
              : _buildPremiumGate(),
    );
  }
}
