// lib/proverbs_screen.dart — 将棋の格言画面
import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';

// ===== カテゴリ定義 =====
enum _ProverbCategory {
  defense,
  attack,
  pieces,
  general,
}

extension _ProverbCategoryExt on _ProverbCategory {
  String get label => const {
    _ProverbCategory.defense: '守り',
    _ProverbCategory.attack: '攻め',
    _ProverbCategory.pieces: '駒の使い方',
    _ProverbCategory.general: '一般',
  }[this]!;

  IconData get icon => const {
    _ProverbCategory.defense: Icons.shield,
    _ProverbCategory.attack: Icons.sports_kabaddi,
    _ProverbCategory.pieces: Icons.extension,
    _ProverbCategory.general: Icons.menu_book,
  }[this]!;

  Color get color => const {
    _ProverbCategory.defense: Colors.lightBlue,
    _ProverbCategory.attack: Colors.redAccent,
    _ProverbCategory.pieces: Colors.amber,
    _ProverbCategory.general: Colors.white54,
  }[this]!;
}

class ProverbsScreen extends StatelessWidget {
  const ProverbsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grouped = _buildGroupedProverbs();
    // フラットリスト: グループヘッダー + 格言カード
    final items = <_ListItem>[];
    for (final cat in _ProverbCategory.values) {
      final list = grouped[cat];
      if (list == null || list.isEmpty) continue;
      items.add(_HeaderItem(cat));
      for (final p in list) {
        items.add(_CardItem(p));
      }
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '将棋の格言',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is _HeaderItem) return _GroupHeader(category: item.category);
          if (item is _CardItem) return _ProverbCard(data: item.data);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ===== リストアイテム型 =====
abstract class _ListItem {}
class _HeaderItem extends _ListItem {
  final _ProverbCategory category;
  _HeaderItem(this.category);
}
class _CardItem extends _ListItem {
  final _ProverbData data;
  _CardItem(this.data);
}

// ===== グループヘッダーウィジェット =====
class _GroupHeader extends StatelessWidget {
  final _ProverbCategory category;
  const _GroupHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: category.color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: category.color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(category.icon, color: category.color, size: 20),
          const SizedBox(width: 8),
          Text(
            category.label,
            style: TextStyle(
              color: category.color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== データモデル =====
class _ProverbData {
  final String proverb;
  final String explanation;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlightSquares;
  final _ProverbCategory category;
  final String? sourceUrl;
  final String? sourceTitle;

  const _ProverbData({
    required this.proverb,
    required this.explanation,
    required this.board,
    this.highlightSquares = const {},
    required this.category,
    this.sourceUrl,
    this.sourceTitle,
  });
}

// ===== カードウィジェット =====
class _ProverbCard extends StatelessWidget {
  final _ProverbData data;
  const _ProverbCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final catColor = data.category.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: catColor, width: 4),
          top: BorderSide(color: Colors.white.withAlpha(15)),
          right: BorderSide(color: Colors.white.withAlpha(15)),
          bottom: BorderSide(color: Colors.white.withAlpha(15)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.proverb,
              style: TextStyle(
                color: catColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.explanation,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Center(
              child: MiniBoardWidget(
                board: data.board,
                highlightSquares: data.highlightSquares,
                size: 180,
                showLabels: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== ヘルパー関数 =====
List<List<Piece?>> _emptyBoard() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

// ===== 格言データ生成（カテゴリ別グループ）=====
Map<_ProverbCategory, List<_ProverbData>> _buildGroupedProverbs() {
  final all = _buildAllProverbs();
  final map = <_ProverbCategory, List<_ProverbData>>{};
  for (final cat in _ProverbCategory.values) {
    map[cat] = all.where((p) => p.category == cat).toList();
  }
  return map;
}

List<_ProverbData> _buildAllProverbs() {
  return [
    // 1. 飛車角より金銀三枚 [守り]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[7][3] = const Piece(PieceType.gold, true);
      b[7][4] = const Piece(PieceType.gold, true);
      b[7][5] = const Piece(PieceType.silver, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[7][7] = const Piece(PieceType.rook, true);
      b[7][1] = const Piece(PieceType.bishop, true);
      return _ProverbData(
        proverb: '飛車角より金銀三枚',
        explanation: '攻めには飛車・角よりも金銀3枚の方が強力。連携した金銀は崩しにくい陣形を作る。',
        board: b,
        highlightSquares: {(7, 3), (7, 4), (7, 5)},
        category: _ProverbCategory.defense,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/金の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 2. 玉は包むように攻めよ [攻め]
    () {
      final b = _emptyBoard();
      b[1][4] = const Piece(PieceType.king, false);
      b[3][3] = const Piece(PieceType.rook, true);
      b[3][5] = const Piece(PieceType.bishop, true);
      b[2][4] = const Piece(PieceType.gold, true);
      b[8][4] = const Piece(PieceType.king, true);
      return _ProverbData(
        proverb: '玉は包むように攻めよ',
        explanation: '王を逃げ場のない状態に追い込む。前後左右から迫り、逃げ道を塞ぎながら詰める。',
        board: b,
        highlightSquares: {(0, 3), (0, 4), (0, 5), (1, 3), (1, 5), (2, 3), (2, 4), (2, 5)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/玉の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 3. 歩の突き捨てから始まる攻め [攻め]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[4][4] = const Piece(PieceType.pawn, true);
      b[3][4] = const Piece(PieceType.pawn, false);
      b[6][4] = const Piece(PieceType.rook, true);
      b[7][3] = const Piece(PieceType.silver, true);
      return _ProverbData(
        proverb: '歩の突き捨てから始まる攻め',
        explanation: '歩を突き捨てて筋（スジ）を開け、飛車・銀の攻撃路を作る。中盤の常套手段。',
        board: b,
        highlightSquares: {(4, 4), (3, 4)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/歩の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 4. 一歩千金 [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[1][4] = const Piece(PieceType.gold, false);
      b[1][3] = const Piece(PieceType.gold, false);
      b[2][4] = const Piece(PieceType.pawn, true);  // 打った歩
      b[6][4] = const Piece(PieceType.rook, true);
      return _ProverbData(
        proverb: '一歩千金',
        explanation: '1枚の歩が勝負を決める価値を持つことがある。急所に打つ歩は攻守いずれにも絶大な効果。',
        board: b,
        highlightSquares: {(2, 4)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/歩の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 5. 桂の高跳び歩の餌食 [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[4][3] = const Piece(PieceType.knight, true);  // 高跳び桂
      b[3][3] = const Piece(PieceType.pawn, false);   // 歩に捕まる
      b[6][5] = const Piece(PieceType.silver, true);
      return _ProverbData(
        proverb: '桂の高跳び歩の餌食',
        explanation: '桂馬を深く跳ばすと歩で捕まってしまう。桂馬の進出は慎重に。',
        board: b,
        highlightSquares: {(4, 3), (3, 3)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/桂の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 6. 金底の歩岩より固し [守り]
    () {
      final b = _emptyBoard();
      b[8][7] = const Piece(PieceType.king, true);   // 玉は端に退避
      b[0][7] = const Piece(PieceType.king, false);
      b[7][4] = const Piece(PieceType.gold, true);   // 守りの金
      b[8][4] = const Piece(PieceType.pawn, true);   // 金底の歩（金の下に打つ）
      b[2][4] = const Piece(PieceType.rook, false);  // 攻め込む後手飛車
      return _ProverbData(
        proverb: '金底の歩岩より固し',
        explanation: '金の下（底）に打った歩は岩より固い守り。後手の飛車成り込みを完全に防ぐ最強の受け。',
        board: b,
        highlightSquares: {(8, 4), (7, 4)},
        category: _ProverbCategory.defense,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/歩の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 7. 将棋は歩から [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      // 先手歩の陣
      for (int c = 0; c < 9; c++) {
        b[6][c] = const Piece(PieceType.pawn, true);
      }
      // 後手歩の陣
      for (int c = 0; c < 9; c++) {
        b[2][c] = const Piece(PieceType.pawn, false);
      }
      return _ProverbData(
        proverb: '将棋は歩から',
        explanation: '歩の使い方が将棋の基本。歩の突き方・使い方が上達の第一歩。',
        board: b,
        highlightSquares: {(6, 4), (6, 3), (6, 5)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 8. 攻めは飛角銀桂、守りは金銀三枚 [攻め]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      // 攻め駒
      b[4][7] = const Piece(PieceType.rook, true);
      b[7][1] = const Piece(PieceType.bishop, true);
      b[5][5] = const Piece(PieceType.silver, true);
      b[6][3] = const Piece(PieceType.knight, true);
      // 守り駒
      b[8][3] = const Piece(PieceType.gold, true);
      b[8][5] = const Piece(PieceType.gold, true);
      b[7][4] = const Piece(PieceType.silver, true);
      return _ProverbData(
        proverb: '攻めは飛角銀桂、守りは金銀三枚',
        explanation: '飛・角・銀・桂は攻撃的な駒、金・銀3枚で玉を固める。役割分担が大切。',
        board: b,
        highlightSquares: {(4, 7), (7, 1), (5, 5), (6, 3)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 9. 端歩は突くな突かせるな [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[6][0] = const Piece(PieceType.pawn, true);   // 先手端歩
      b[2][0] = const Piece(PieceType.pawn, false);  // 後手端歩
      b[8][8] = const Piece(PieceType.lance, true);
      b[0][8] = const Piece(PieceType.lance, false);
      return _ProverbData(
        proverb: '端歩は突くな突かせるな',
        explanation: '端歩（1筋・9筋の歩）の突き合いは重要な駆け引き。終盤の端攻めに直結する。',
        board: b,
        highlightSquares: {(6, 0), (2, 0)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/歩の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 10. 角は斜めに利いている [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[4][4] = const Piece(PieceType.bishop, true);
      return _ProverbData(
        proverb: '角は斜めに利いている',
        explanation: '角の長い斜め筋の利きを常に意識する。見えにくい角筋は攻防の要。',
        board: b,
        highlightSquares: {(1, 1), (2, 2), (3, 3), (5, 5), (6, 6), (7, 7), (1, 7), (2, 6), (3, 5), (5, 3), (6, 2), (7, 1)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/角の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 11. 三手の読み [一般]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[2][4] = const Piece(PieceType.gold, false);
      b[2][3] = const Piece(PieceType.silver, false);
      b[4][4] = const Piece(PieceType.rook, true);
      b[5][3] = const Piece(PieceType.silver, true);
      b[3][4] = const Piece(PieceType.pawn, true);   // 1手目
      return _ProverbData(
        proverb: '三手の読み',
        explanation: '最低でも3手先（自分の手、相手の手、自分の次の手）を読む習慣が上達の基本。',
        board: b,
        highlightSquares: {(3, 4), (2, 4), (5, 3)},
        category: _ProverbCategory.general,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 12. 受けは金、攻めは銀 [守り]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[7][4] = const Piece(PieceType.gold, true);   // 守りの金
      b[8][3] = const Piece(PieceType.gold, true);   // 守りの金
      b[5][5] = const Piece(PieceType.silver, true); // 攻めの銀
      b[4][4] = const Piece(PieceType.silver, true); // 攻めの銀
      return _ProverbData(
        proverb: '受けは金、攻めは銀',
        explanation: '金は守りに使い、銀は攻めに投入するのが基本方針。金は動かさず玉を固める。',
        board: b,
        highlightSquares: {(7, 4), (8, 3), (5, 5), (4, 4)},
        category: _ProverbCategory.defense,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/銀の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 13. 玉の早逃げ八手の得 [守り]
    () {
      final b = _emptyBoard();
      b[8][7] = const Piece(PieceType.king, true);   // 逃げた後の安全な位置
      b[7][7] = const Piece(PieceType.gold, true);
      b[7][6] = const Piece(PieceType.gold, true);
      b[8][6] = const Piece(PieceType.silver, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[3][4] = const Piece(PieceType.rook, false);  // 後手の攻め駒
      b[3][3] = const Piece(PieceType.silver, false);
      return _ProverbData(
        proverb: '玉の早逃げ八手の得',
        explanation: '中盤から早めに玉を安全な場所に逃しておくと終盤8手分の余裕ができる。',
        board: b,
        highlightSquares: {(8, 7), (7, 7), (7, 6)},
        category: _ProverbCategory.defense,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/玉の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 14. 二枚替えは歩得 [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[3][4] = const Piece(PieceType.rook, false);
      b[3][5] = const Piece(PieceType.bishop, false);
      b[4][4] = const Piece(PieceType.rook, true);
      b[4][5] = const Piece(PieceType.bishop, true);
      return _ProverbData(
        proverb: '二枚替えは歩得',
        explanation: '飛車と角の2枚交換は双方互角に見えるが、実は先に取った側が歩1枚得をしている。',
        board: b,
        highlightSquares: {(3, 4), (3, 5), (4, 4), (4, 5)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 15. 棒銀は歩の突き越しから [攻め]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[7][7] = const Piece(PieceType.rook, true);
      b[6][7] = const Piece(PieceType.silver, true);  // 棒銀
      b[5][7] = const Piece(PieceType.pawn, true);    // 突き越した歩
      b[2][7] = const Piece(PieceType.pawn, false);
      return _ProverbData(
        proverb: '棒銀は歩の突き越しから',
        explanation: '棒銀攻めは2筋の歩を突き越してから銀を進める。歩の突き越しが銀の道を作る。',
        board: b,
        highlightSquares: {(5, 7), (6, 7)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/銀の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 16. 遠見の角に好手あり [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[7][1] = const Piece(PieceType.bishop, true);  // 遠見の角（8八）
      b[3][7] = const Piece(PieceType.silver, false);
      b[2][6] = const Piece(PieceType.pawn, false);
      return _ProverbData(
        proverb: '遠見の角に好手あり',
        explanation: '遠くから角を配置することで意外な好手が生まれる。角は遠くから放つほど威力を発揮する。',
        board: b,
        highlightSquares: {(7, 1), (4, 4), (3, 5), (2, 6)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/角の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 17. 飛車は成り込んで価値が上がる [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[1][7] = const Piece(PieceType.promotedRook, true);  // 竜王（成飛）
      b[0][6] = const Piece(PieceType.gold, false);
      b[0][5] = const Piece(PieceType.silver, false);
      return _ProverbData(
        proverb: '飛車は成り込んで価値が上がる',
        explanation: '飛車は敵陣に成って竜王になると、縦横に加えて斜め1マスも動けるようになり格段に強くなる。',
        board: b,
        highlightSquares: {(1, 7), (0, 7), (0, 6), (0, 8)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/飛の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 18. 桂馬の高飛び使い捨て [駒の使い方]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[3][5] = const Piece(PieceType.knight, true);  // 敵陣に跳び込んだ桂
      b[1][4] = const Piece(PieceType.gold, false);
      b[1][6] = const Piece(PieceType.silver, false);
      b[2][5] = const Piece(PieceType.pawn, false);
      return _ProverbData(
        proverb: '桂馬の高飛び使い捨て',
        explanation: '桂馬は敵陣に跳び込んで相手の駒を攻撃し、取られることで持ち駒を渡す捨て駒に使う。',
        board: b,
        highlightSquares: {(3, 5), (1, 4), (1, 6)},
        category: _ProverbCategory.pieces,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/桂の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 19. 囲いの中の王は硬い [守り]
    () {
      final b = _emptyBoard();
      // 美濃囲い
      b[8][7] = const Piece(PieceType.king, true);
      b[8][6] = const Piece(PieceType.gold, true);
      b[7][7] = const Piece(PieceType.silver, true);
      b[7][8] = const Piece(PieceType.gold, true);
      b[8][8] = const Piece(PieceType.lance, true);
      b[6][6] = const Piece(PieceType.pawn, true);
      b[6][7] = const Piece(PieceType.pawn, true);
      b[6][8] = const Piece(PieceType.pawn, true);
      b[0][4] = const Piece(PieceType.king, false);
      return _ProverbData(
        proverb: '囲いの中の王は硬い',
        explanation: '美濃囲いや矢倉などの囲いを完成させると王が非常に堅くなる。囲い完成が攻撃開始の合図。',
        board: b,
        highlightSquares: {(8, 7), (8, 6), (7, 7), (7, 8), (8, 8)},
        category: _ProverbCategory.defense,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 20. 詰めろの連続が勝利への道 [攻め]
    // (旧版は先手金(0,5)が後手玉(0,4)に横から実際に王手をかけており、
    //  「詰めろ」＝次に詰める脅しであってまだ王手ではない、という
    //  概念と矛盾していた。金を(2,5)に配置し直し、王手ではなく
    //  脅しを示す形にした)
    () {
      final b = _emptyBoard();
      b[0][4] = const Piece(PieceType.king, false);
      b[1][4] = const Piece(PieceType.gold, false);
      b[1][3] = const Piece(PieceType.silver, false);
      b[2][4] = const Piece(PieceType.rook, true);   // 詰めろ（後手金が遮っており今は王手ではない）
      b[2][5] = const Piece(PieceType.gold, true);   // 詰めろ
      b[8][4] = const Piece(PieceType.king, true);
      return _ProverbData(
        proverb: '詰めろの連続が勝利への道',
        explanation: '詰めろ（次に詰める脅し）を連続してかけ続けることで相手に受ける手を強制し勝利に繋げる。',
        board: b,
        highlightSquares: {(2, 4), (2, 5), (0, 3), (0, 4)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 21. 中盤は駒の活用が勝負 [一般]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      // 先手の活用された駒
      b[4][4] = const Piece(PieceType.rook, true);
      b[4][5] = const Piece(PieceType.silver, true);
      b[3][3] = const Piece(PieceType.bishop, true);
      // 後手の働いていない駒
      b[0][0] = const Piece(PieceType.lance, false);
      b[0][8] = const Piece(PieceType.lance, false);
      b[0][1] = const Piece(PieceType.knight, false);
      b[0][7] = const Piece(PieceType.knight, false);
      return _ProverbData(
        proverb: '中盤は駒の活用が勝負',
        explanation: '中盤は全駒を活用した方が圧倒的に有利。働いていない駒がある方が負けに近い。',
        board: b,
        highlightSquares: {(4, 4), (4, 5), (3, 3)},
        category: _ProverbCategory.general,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 22. 垂れ歩は先手必勝 [攻め]
    // (旧版は先手歩(1,4)が後手玉(0,4)の真正面に位置し実際に王手をかけて
    //  おり、「垂れ歩」＝まだ王手ではない静かな脅しの歩、という概念と
    //  矛盾していた。歩・飛車を1列ずらして玉の筋を避け、王手ではない形にした)
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[1][5] = const Piece(PieceType.pawn, true);   // 垂れ歩（敵陣2段目）
      b[1][3] = const Piece(PieceType.gold, false);  // 受けに来た後手の金
      b[3][5] = const Piece(PieceType.rook, true);   // 垂れ歩を支援する飛車
      return _ProverbData(
        proverb: '垂れ歩は先手必勝',
        explanation: '敵陣の2段目に打った歩を「垂れ歩」という。飛車で守られた歩は相手が取れず受けを迫る強力な攻め。',
        board: b,
        highlightSquares: {(1, 5), (1, 3)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/歩の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 23. 継ぎ歩は攻めの第一歩 [攻め]
    () {
      final b = _emptyBoard();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[3][4] = const Piece(PieceType.pawn, false);
      b[4][4] = const Piece(PieceType.pawn, true);   // 継ぎ歩（前進）
      b[6][4] = const Piece(PieceType.rook, true);
      return _ProverbData(
        proverb: '継ぎ歩は攻めの第一歩',
        explanation: '相手の歩の直前に歩を打つ「継ぎ歩」で歩を交換し、攻めの足がかりを作る手筋。',
        board: b,
        highlightSquares: {(4, 4), (3, 4), (5, 4)},
        category: _ProverbCategory.attack,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/歩の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 24. 終盤は秒読みで指せ [一般]
    // (旧版は先手飛車(2,4)と後手玉(0,4)の間の(1,4)が空いており、
    //  実際に王手がかかった状態になっていた。この格言は一般的な終盤の
    //  心構えについてであり特定の王手局面を示す意図ではないため、
    //  後手歩を(1,4)に置いて遮り、王手ではない攻撃陣形の図にした)
    () {
      final b = _emptyBoard();
      b[0][4] = const Piece(PieceType.king, false);
      b[1][3] = const Piece(PieceType.gold, false);
      b[1][4] = const Piece(PieceType.pawn, false);
      b[1][5] = const Piece(PieceType.silver, false);
      b[2][4] = const Piece(PieceType.rook, true);
      b[2][3] = const Piece(PieceType.gold, true);
      b[2][5] = const Piece(PieceType.gold, true);
      b[8][4] = const Piece(PieceType.king, true);
      return _ProverbData(
        proverb: '終盤は秒読みで指せ',
        explanation: '終盤は深く考えすぎず直感で素早く決断する。長考よりも勢いで指す方が良い結果になることも多い。',
        board: b,
        highlightSquares: {(2, 4), (2, 3), (2, 5)},
        category: _ProverbCategory.general,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/全般格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),

    // 25. 打った金は動かすな [守り]
    () {
      final b = _emptyBoard();
      b[8][7] = const Piece(PieceType.king, true);
      b[7][7] = const Piece(PieceType.silver, true);
      b[7][8] = const Piece(PieceType.gold, true);
      b[8][8] = const Piece(PieceType.lance, true);
      b[6][8] = const Piece(PieceType.gold, true);   // 打った金（守りの要）
      b[0][4] = const Piece(PieceType.king, false);
      b[2][8] = const Piece(PieceType.rook, false);  // 攻めてくる飛車
      return _ProverbData(
        proverb: '打った金は動かすな',
        explanation: '守りのために打った金は動かさない。金を動かすと守りが崩れるため、打った場所で頑張るのが原則。',
        board: b,
        highlightSquares: {(6, 8), (7, 8), (8, 7)},
        category: _ProverbCategory.defense,
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/格言/金の格言一覧.html',
        sourceTitle: '将棋講座.com',
      );
    }(),
  ];
}
