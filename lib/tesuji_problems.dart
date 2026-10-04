// lib/tesuji_problems.dart
// 手筋トレーニングの問題データ（純Dart・Flutter非依存）。
// 全問題は tool/validate_tactics.dart で「正解手が合法かつ手筋として成立する」ことを検証する。
//
// 座標規約: board[row][col]  筋 = 9 - col, 段 = row + 1
//   先手(p1=true) 前進=row減少, 敵陣=row 0..2 / 後手 前進=row増加, 敵陣=row 6..8
//
// 各局面には実戦感を出すため「玉の守り駒・歩・他の駒」を配置し、持ち駒も持たせている。
// 追加した駒は正解手の利き・経路・手筋成立を壊さない位置にあること（検証スクリプトで担保）。
import 'dart:convert';
import 'piece.dart';
import 'sfen_parser.dart';

class TesujiProb {
  final String id;
  final String title;
  final String category; // 飛車取り|王手金取り|両取り|守り|詰め|捨て駒|手筋テクニック
  final String explanation;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  final AMove answer;
  final String? sourceUrl;
  final String? sourceTitle;
  final String difficulty; // 初級|中級|上級

  const TesujiProb({
    required this.id,
    required this.title,
    required this.category,
    required this.explanation,
    required this.board,
    this.p1Hand = const {},
    this.p2Hand = const {},
    this.p1Turn = true,
    required this.answer,
    this.sourceUrl,
    this.sourceTitle,
    required this.difficulty,
  });

  /// JSON から復元
  factory TesujiProb.fromJson(Map<String, dynamic> json) {
    // SFEN 文字列から盤面を復元
    final parsed = parseSfen(json['board'] as String);

    return TesujiProb(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      explanation: json['explanation'] as String,
      board: parsed.board,
      p1Hand: _parseHand(json['p1_hand'] as Map<String, dynamic>? ?? {}),
      p2Hand: _parseHand(json['p2_hand'] as Map<String, dynamic>? ?? {}),
      p1Turn: json['p1_turn'] as bool? ?? true,
      answer: AMove.fromJson(json['answer'] as Map<String, dynamic>),
      sourceUrl: json['source_url'] as String?,
      sourceTitle: json['source_title'] as String?,
      difficulty: json['difficulty'] as String? ?? '中級',
    );
  }

  /// JSON に変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'explanation': explanation,
      'board': boardToSfen(board, p1Turn, p1Hand, p2Hand),
      'p1_hand': _serializeHand(p1Hand),
      'p2_hand': _serializeHand(p2Hand),
      'p1_turn': p1Turn,
      'answer': answer.toJson(),
      'source_url': sourceUrl,
      'source_title': sourceTitle,
      'difficulty': difficulty,
    };
  }

  /// 盤面を SFEN 形式の文字列に変換
  static String boardToSfen(
    List<List<Piece?>> board,
    bool p1Turn,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    final buffer = StringBuffer();

    // 盤面部分
    for (int r = 0; r < 9; r++) {
      int emptyCount = 0;
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          final label = _pieceSfenLabel(piece);
          buffer.write(label);
        }
      }
      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }
      if (r < 8) buffer.write('/');
    }

    buffer.write(' ');
    buffer.write(p1Turn ? 'w' : 'b');

    // 持ち駒
    buffer.write(' ');
    _appendHandSfen(buffer, p1Hand, p2Hand);

    buffer.write(' 0');

    return buffer.toString();
  }
}

/// 持ち駒を SFEN 形式で追記
void _appendHandSfen(
  StringBuffer buf,
  Map<PieceType, int> p1Hand,
  Map<PieceType, int> p2Hand,
) {
  if (p1Hand.isEmpty && p2Hand.isEmpty) {
    buf.write('-');
    return;
  }

  // P1 の持ち駒
  for (final entry in p1Hand.entries) {
    final count = entry.value;
    if (count > 0) {
      if (count > 1) buf.write(count);
      buf.write(_pieceSfenChar(entry.key).toUpperCase());
    }
  }

  // P2 の持ち駒
  for (final entry in p2Hand.entries) {
    final count = entry.value;
    if (count > 0) {
      if (count > 1) buf.write(count);
      buf.write(_pieceSfenChar(entry.key).toLowerCase());
    }
  }
}

String _pieceSfenLabel(Piece p) {
  final char = _pieceSfenChar(p.type);
  return p.isPlayer1 ? char.toUpperCase() : char.toLowerCase();
}

String _pieceSfenChar(PieceType t) {
  switch (t) {
    case PieceType.king:
      return 'k';
    case PieceType.rook:
      return 'r';
    case PieceType.bishop:
      return 'b';
    case PieceType.gold:
      return 'g';
    case PieceType.silver:
      return 's';
    case PieceType.knight:
      return 'n';
    case PieceType.lance:
      return 'l';
    case PieceType.pawn:
      return 'p';
    case PieceType.promotedRook:
      return '+r';
    case PieceType.promotedBishop:
      return '+b';
    case PieceType.promotedSilver:
      return '+s';
    case PieceType.promotedKnight:
      return '+n';
    case PieceType.promotedLance:
      return '+l';
    case PieceType.promotedPawn:
      return '+p';
  }
}

Map<PieceType, int> _parseHand(Map<String, dynamic> json) {
  final hand = <PieceType, int>{};
  json.forEach((key, value) {
    final type = _parsePieceTypeFromString(key);
    if (type != null) {
      hand[type] = value as int? ?? 0;
    }
  });
  return hand;
}

Map<String, dynamic> _serializeHand(Map<PieceType, int> hand) {
  final map = <String, dynamic>{};
  hand.forEach((type, count) {
    map[_pieceTypeName(type)] = count;
  });
  return map;
}

String _pieceTypeName(PieceType type) {
  switch (type) {
    case PieceType.king:
      return 'king';
    case PieceType.rook:
      return 'rook';
    case PieceType.bishop:
      return 'bishop';
    case PieceType.gold:
      return 'gold';
    case PieceType.silver:
      return 'silver';
    case PieceType.knight:
      return 'knight';
    case PieceType.lance:
      return 'lance';
    case PieceType.pawn:
      return 'pawn';
    case PieceType.promotedRook:
      return 'promotedRook';
    case PieceType.promotedBishop:
      return 'promotedBishop';
    case PieceType.promotedSilver:
      return 'promotedSilver';
    case PieceType.promotedKnight:
      return 'promotedKnight';
    case PieceType.promotedLance:
      return 'promotedLance';
    case PieceType.promotedPawn:
      return 'promotedPawn';
  }
}

PieceType? _parsePieceTypeFromString(String name) {
  switch (name) {
    case 'king':
      return PieceType.king;
    case 'rook':
      return PieceType.rook;
    case 'bishop':
      return PieceType.bishop;
    case 'gold':
      return PieceType.gold;
    case 'silver':
      return PieceType.silver;
    case 'knight':
      return PieceType.knight;
    case 'lance':
      return PieceType.lance;
    case 'pawn':
      return PieceType.pawn;
    case 'promotedRook':
      return PieceType.promotedRook;
    case 'promotedBishop':
      return PieceType.promotedBishop;
    case 'promotedSilver':
      return PieceType.promotedSilver;
    case 'promotedKnight':
      return PieceType.promotedKnight;
    case 'promotedLance':
      return PieceType.promotedLance;
    case 'promotedPawn':
      return PieceType.promotedPawn;
    default:
      return null;
  }
}

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

const _src = 'https://www.shogi.or.jp/';
const _srcName = '日本将棋連盟';

// 先手の駒を安全に置く（既に駒があれば置かない）
void _p1(List<List<Piece?>> b, int r, int c, PieceType t) {
  if (b[r][c] == null) b[r][c] = Piece(t, true);
}

void _p2(List<List<Piece?>> b, int r, int c, PieceType t) {
  if (b[r][c] == null) b[r][c] = Piece(t, false);
}

List<TesujiProb> buildTesujiProblems() {
  final list = <TesujiProb>[];

  // ============================================================
  // 飛車取り
  // ============================================================

  // ① 角で取る
  {
    final b = _empty();
    b[0][8] = const Piece(PieceType.king, false); // 後手玉 1一
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[4][4] = const Piece(PieceType.rook, false); // 後手飛 5五
    b[7][1] = const Piece(PieceType.bishop, true); // 先手角 8八
    // 周辺の駒
    _p1(b, 8, 1, PieceType.gold); // 先手金 8九
    _p1(b, 6, 0, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    _p1(b, 6, 8, PieceType.pawn);
    _p2(b, 1, 7, PieceType.gold); // 後手金 2二
    _p2(b, 2, 7, PieceType.pawn);
    _p2(b, 2, 8, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_1',
      title: '飛車取り ①（角で取る）',
      category: '飛車取り',
      explanation: '▲5五角。角を8八から5五へ斜めに進め、後手の飛車をタダで取ります。角の斜め効きが飛車に直接届いていることを確認しましょう。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 7, fc: 1, tr: 4, tc: 4),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '初級',
    ));
  }

  // ② 桂で取る
  {
    final b = _empty();
    b[0][2] = const Piece(PieceType.king, false); // 後手玉 7一
    b[8][4] = const Piece(PieceType.king, true); // 先手玉 5九
    b[3][5] = const Piece(PieceType.rook, false); // 後手飛 4四
    b[5][6] = const Piece(PieceType.knight, true); // 先手桂 3六
    _p1(b, 8, 5, PieceType.gold);
    _p1(b, 8, 3, PieceType.silver);
    _p1(b, 6, 3, PieceType.pawn);
    _p1(b, 6, 4, PieceType.pawn);
    _p2(b, 1, 2, PieceType.gold); // 後手金 7二
    _p2(b, 1, 1, PieceType.silver);
    _p2(b, 2, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_2',
      title: '飛車取り ②（桂で取る）',
      category: '飛車取り',
      explanation: '▲4四桂。桂馬を3六から4四へ跳ね、後手の飛車を取ります。桂は駒を飛び越えるので、間に駒があっても関係なく飛車に当たります。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.gold: 1},
      answer: const AMove(fr: 5, fc: 6, tr: 3, tc: 5),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '初級',
    ));
  }

  // ③ 香で取る（成り）
  {
    final b = _empty();
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    b[8][3] = const Piece(PieceType.king, true); // 先手玉 6九
    b[2][8] = const Piece(PieceType.rook, false); // 後手飛 1三
    b[7][8] = const Piece(PieceType.lance, true); // 先手香 1八
    _p1(b, 8, 4, PieceType.gold);
    _p1(b, 8, 2, PieceType.silver);
    _p1(b, 6, 2, PieceType.pawn);
    _p1(b, 6, 3, PieceType.pawn);
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二
    _p2(b, 2, 0, PieceType.pawn);
    _p2(b, 2, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_3',
      title: '飛車取り ③（香で取る）',
      category: '飛車取り',
      explanation: '▲1三香成。香車を1八から一直線に進め、1三の飛車を取りながら敵陣で成ります。途中に駒がないことが条件です。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 7, fc: 8, tr: 2, tc: 8, promote: true),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '初級',
    ));
  }

  // ④ 飛車で取る
  {
    final b = _empty();
    b[0][1] = const Piece(PieceType.king, false); // 後手玉 8一
    b[8][7] = const Piece(PieceType.king, true); // 先手玉 2九
    b[3][2] = const Piece(PieceType.rook, false); // 後手飛 7四
    b[3][7] = const Piece(PieceType.rook, true); // 先手飛 2四
    _p1(b, 8, 6, PieceType.gold);
    _p1(b, 8, 8, PieceType.silver);
    _p1(b, 6, 6, PieceType.pawn);
    _p1(b, 6, 7, PieceType.pawn);
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二
    _p2(b, 2, 1, PieceType.pawn);
    _p2(b, 2, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_4',
      title: '飛車取り ④（飛車で取る）',
      category: '飛車取り',
      explanation: '▲7四飛。先手飛車を横に走らせ、同じ段にいる後手飛車を取ります。大駒同士の取り合いでは、先に取った方が得をします。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 3, fc: 7, tr: 3, tc: 2),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ============================================================
  // 王手金取り
  // ============================================================

  // ① 角
  {
    final b = _empty();
    b[0][2] = const Piece(PieceType.king, false); // 後手玉 7一
    b[0][6] = const Piece(PieceType.gold, false); // 後手金 3一
    b[8][8] = const Piece(PieceType.king, true); // 先手玉 1九
    b[4][2] = const Piece(PieceType.bishop, true); // 先手角 7五
    _p1(b, 8, 7, PieceType.gold);
    _p1(b, 6, 1, PieceType.pawn);
    _p1(b, 6, 7, PieceType.pawn);
    _p2(b, 1, 1, PieceType.silver); // 後手銀 8二
    _p2(b, 2, 2, PieceType.pawn);
    _p2(b, 2, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_1',
      title: '王手金取り ①（角）',
      category: '王手金取り',
      explanation: '▲5三角。角が一方の斜めで7一の玉に王手をかけ、もう一方の斜めで3一の金を狙います。玉が逃げれば金が取れる、角の両効きを使った王手金取りです。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 4, fc: 2, tr: 2, tc: 4),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ② 銀
  {
    final b = _empty();
    b[0][4] = const Piece(PieceType.king, false); // 後手玉 5一
    b[0][2] = const Piece(PieceType.gold, false); // 後手金 7一
    b[8][4] = const Piece(PieceType.king, true); // 先手玉 5九
    b[2][4] = const Piece(PieceType.silver, true); // 先手銀 5三
    _p1(b, 2, 2, PieceType.silver); // 先手銀 7三（4二に紐をつける）
    _p1(b, 8, 5, PieceType.gold);
    _p1(b, 8, 3, PieceType.gold);
    _p1(b, 6, 6, PieceType.pawn);
    _p1(b, 6, 7, PieceType.pawn);
    _p2(b, 1, 1, PieceType.silver); // 後手銀 8二
    _p2(b, 2, 6, PieceType.pawn);
    _p2(b, 2, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_2',
      title: '王手金取り ②（銀）',
      category: '王手金取り',
      explanation: '▲6二銀。銀が5一の玉に王手をかけつつ、7一の金にも当たります。銀は斜め前と横上の複数マスに効くため、王手と金取りを同時に実現できます。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.knight: 1},
      answer: const AMove(fr: 2, fc: 4, tr: 1, tc: 3),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ③ ふんどしの桂
  {
    final b = _empty();
    b[0][4] = const Piece(PieceType.king, false); // 後手玉 5一
    b[0][6] = const Piece(PieceType.gold, false); // 後手金 3一
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[4][6] = const Piece(PieceType.knight, true); // 先手桂 3五
    _p1(b, 8, 1, PieceType.gold);
    _p1(b, 6, 1, PieceType.pawn);
    _p1(b, 6, 2, PieceType.pawn);
    _p2(b, 1, 4, PieceType.pawn); // 後手歩 5二
    _p2(b, 0, 3, PieceType.silver); // 後手銀 6一
    _p2(b, 2, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_3',
      title: '王手金取り ③（ふんどしの桂）',
      category: '王手金取り',
      explanation: '▲4三桂。「ふんどしの桂」。桂が跳んだ先で、5一の玉と3一の金の両方を同時に攻めます。ここで成ると効きが変わってしまうので、成らないのがポイントです。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 4, fc: 6, tr: 2, tc: 5),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '上級',
    ));
  }

  // ============================================================
  // 両取り
  // ============================================================

  // ① 角
  {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[0][8] = const Piece(PieceType.king, false); // 後手玉 1一
    b[2][2] = const Piece(PieceType.rook, false); // 後手飛 7三
    b[2][6] = const Piece(PieceType.gold, false); // 後手金 3三
    b[6][2] = const Piece(PieceType.bishop, true); // 先手角 7七
    _p1(b, 8, 1, PieceType.gold);
    _p1(b, 6, 5, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    _p2(b, 1, 8, PieceType.gold); // 後手金 1二
    _p2(b, 2, 8, PieceType.pawn);
    _p2(b, 1, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_1',
      title: '両取り ①（角）',
      category: '両取り',
      explanation: '▲5五角。角を中央に進めると、二つの斜めの効きが7三の飛車と3三の金に同時に当たります。どちらかしか守れない角の両取りです。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 6, fc: 2, tr: 4, tc: 4),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ② 飛車（十字）
  {
    final b = _empty();
    b[8][8] = const Piece(PieceType.king, true); // 先手玉 1九
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    b[0][3] = const Piece(PieceType.gold, false); // 後手金 6一
    b[1][6] = const Piece(PieceType.silver, false); // 後手銀 3二
    b[4][3] = const Piece(PieceType.rook, true); // 先手飛 6五
    _p1(b, 8, 7, PieceType.gold);
    _p1(b, 6, 0, PieceType.pawn);
    _p1(b, 6, 1, PieceType.pawn);
    _p2(b, 1, 0, PieceType.pawn); // 後手歩 9二
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二
    _p2(b, 2, 8, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_2',
      title: '両取り ②（飛車）',
      category: '両取り',
      explanation: '▲6二飛。飛車を進めると、縦の効きで6一の金、横の効きで3二の銀に同時に当たります。縦横十字に効く飛車の両取りです。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 4, fc: 3, tr: 1, tc: 3),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ③ 桂
  {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[0][8] = const Piece(PieceType.king, false); // 後手玉 1一
    b[0][3] = const Piece(PieceType.gold, false); // 後手金 6一
    b[0][5] = const Piece(PieceType.silver, false); // 後手銀 4一
    b[4][3] = const Piece(PieceType.knight, true); // 先手桂 6五
    _p1(b, 8, 1, PieceType.gold);
    _p1(b, 6, 6, PieceType.pawn);
    _p1(b, 6, 7, PieceType.pawn);
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p2(b, 2, 7, PieceType.pawn);
    _p2(b, 2, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_3',
      title: '両取り ③（桂）',
      category: '両取り',
      explanation: '▲5三桂。桂が跳んだ先から、6一の金と4一の銀の両方に当たります。成ると効きが変わるため、成らずに両取りをかけるのがコツです。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 4, fc: 3, tr: 2, tc: 4),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ============================================================
  // 守り
  // ============================================================

  // ① 合い駒
  {
    final b = _empty();
    b[8][8] = const Piece(PieceType.king, true); // 先手玉 1九
    b[0][8] = const Piece(PieceType.rook, false); // 後手飛 1一（縦の王手）
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    _p1(b, 8, 7, PieceType.gold); // 先手金 2九
    _p1(b, 6, 0, PieceType.pawn);
    _p1(b, 6, 1, PieceType.pawn);
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二
    _p2(b, 2, 0, PieceType.pawn);
    _p2(b, 2, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'mamori_1',
      title: '守り ①（合い駒）',
      category: '守り',
      explanation: '▲1八金。後手飛車が1筋を縦に走って王手しています。玉のすぐ前に金を打って受けます。金は玉が支えているので、飛車では取れません。',
      board: b,
      p1Hand: const {PieceType.gold: 1, PieceType.silver: 1, PieceType.pawn: 1},
      answer: const AMove(fr: -1, fc: -1, tr: 7, tc: 8, drop: PieceType.gold),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '初級',
    ));
  }

  // ② 玉の早逃げ
  {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true); // 先手玉 5九
    b[0][4] = const Piece(PieceType.rook, false); // 後手飛 5一（縦の王手）
    b[5][8] = const Piece(PieceType.bishop, false); // 後手角 1六（4九を狙う）
    b[7][3] = const Piece(PieceType.pawn, true); // 先手歩 6八
    b[7][5] = const Piece(PieceType.pawn, true); // 先手歩 4八
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    _p1(b, 6, 0, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二
    _p2(b, 2, 1, PieceType.pawn);
    _p2(b, 2, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'mamori_2',
      title: '守り ②（玉の早逃げ）',
      category: '守り',
      explanation: '▲6九玉。飛車の縦王手を、横に一路ずれてかわします。4九には後手角が効いているため、6九が唯一の安全地帯です。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.gold: 1},
      answer: const AMove(fr: 8, fc: 4, tr: 8, tc: 3),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ③ 取って受ける
  {
    final b = _empty();
    b[8][1] = const Piece(PieceType.king, true); // 先手玉 8九
    b[7][2] = const Piece(PieceType.silver, false); // 後手銀 7八（王手）
    b[8][2] = const Piece(PieceType.gold, true); // 先手金 7九
    b[0][8] = const Piece(PieceType.king, false); // 後手玉 1一
    _p1(b, 8, 0, PieceType.lance);
    _p1(b, 6, 4, PieceType.pawn);
    _p1(b, 6, 5, PieceType.pawn);
    _p2(b, 1, 7, PieceType.gold); // 後手金 2二
    _p2(b, 2, 7, PieceType.pawn);
    _p2(b, 2, 8, PieceType.pawn);
    list.add(TesujiProb(
      id: 'mamori_3',
      title: '守り ③（取って受ける）',
      category: '守り',
      explanation: '▲同金（7八金）。王手をかけてきた銀を金で取って受けます。攻め駒そのものを取り除くのが、最も確実な受けです。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: 8, fc: 2, tr: 7, tc: 2),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '初級',
    ));
  }

  // ============================================================
  // 詰め（1手詰／後手は持ち駒なし＝合い駒不可）
  // ============================================================

  // ① 頭金
  {
    final b = _empty();
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    b[4][0] = const Piece(PieceType.lance, true); // 先手香 9五（9二の金を支える）
    b[8][8] = const Piece(PieceType.king, true); // 先手玉 1九
    _p1(b, 8, 7, PieceType.gold);
    _p1(b, 6, 5, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    _p2(b, 2, 3, PieceType.pawn);
    _p2(b, 2, 4, PieceType.pawn);
    list.add(TesujiProb(
      id: 'tsume_1',
      title: '詰め ①（頭金）',
      category: '詰め',
      explanation: '▲9二金。玉の頭に金を打って1手詰。逃げ道の8一・8二は金が押さえ、9二の金は9五の香が支えているので取れません。最も基本的な詰みの形です。',
      board: b,
      p1Hand: const {PieceType.gold: 1, PieceType.pawn: 1},
      answer: const AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.gold),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '初級',
    ));
  }

  // ② 送りの金
  {
    final b = _empty();
    b[0][7] = const Piece(PieceType.king, false); // 後手玉 2一
    b[0][8] = const Piece(PieceType.pawn, false); // 後手歩 1一（自分の逃げ道を塞ぐ）
    b[1][6] = const Piece(PieceType.gold, true); // 先手金 3二
    b[3][8] = const Piece(PieceType.knight, true); // 先手桂 1四（2二を支える）
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    _p1(b, 8, 1, PieceType.gold);
    _p1(b, 6, 3, PieceType.pawn);
    _p1(b, 6, 4, PieceType.pawn);
    _p2(b, 2, 4, PieceType.pawn);
    _p2(b, 2, 5, PieceType.pawn);
    list.add(TesujiProb(
      id: 'tsume_2',
      title: '詰め ②（送りの金）',
      category: '詰め',
      explanation: '▲2二金。横から金を寄せて1手詰。逃げ道は1一に自分の歩、他は金が押さえ、2二の金は1四の桂が支えているので取れません。',
      board: b,
      p1Hand: const {PieceType.pawn: 1},
      answer: const AMove(fr: 1, fc: 6, tr: 1, tc: 7),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ============================================================
  // 捨て駒
  // ============================================================

  // ① たたきの歩（同じ筋に先手歩を置かない＝二歩回避）
  {
    final b = _empty();
    b[0][4] = const Piece(PieceType.king, false); // 後手玉 5一
    b[1][4] = const Piece(PieceType.gold, false); // 後手金 5二
    b[8][4] = const Piece(PieceType.king, true); // 先手玉 5九
    _p1(b, 8, 5, PieceType.gold);
    _p1(b, 6, 2, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    _p2(b, 0, 3, PieceType.silver); // 後手銀 6一
    _p2(b, 0, 5, PieceType.silver); // 後手銀 4一
    _p2(b, 2, 2, PieceType.pawn);
    _p2(b, 2, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'sute_1',
      title: '捨て駒 ①（たたきの歩）',
      category: '捨て駒',
      explanation: '▲5三歩。「たたきの歩」。金の頭に歩を打ちつけます。△同金なら金が前に釣り出されて玉が薄くなり、逃げれば歩が拠点として残ります。',
      board: b,
      p1Hand: const {PieceType.pawn: 1, PieceType.silver: 1},
      answer: const AMove(fr: -1, fc: -1, tr: 2, tc: 4, drop: PieceType.pawn),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ② 銀捨て
  {
    final b = _empty();
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    b[1][1] = const Piece(PieceType.gold, false); // 後手金 8二
    b[8][8] = const Piece(PieceType.king, true); // 先手玉 1九
    _p1(b, 8, 7, PieceType.gold);
    _p1(b, 6, 4, PieceType.pawn);
    _p1(b, 6, 5, PieceType.pawn);
    _p2(b, 0, 2, PieceType.lance); // 後手香 7一
    _p2(b, 2, 2, PieceType.pawn);
    _p2(b, 2, 3, PieceType.pawn);
    list.add(TesujiProb(
      id: 'sute_2',
      title: '捨て駒 ②（銀捨て）',
      category: '捨て駒',
      explanation: '▲9二銀。玉に王手をかける銀捨て。△同金と取らせれば8二の金が9二へそっぽに移動し、玉の守りが乱れて寄せが続きます。',
      board: b,
      p1Hand: const {PieceType.silver: 1, PieceType.gold: 1},
      answer: const AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.silver),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '上級',
    ));
  }

  // ============================================================
  // 手筋テクニック
  // ============================================================

  // ① 割り打ちの銀
  {
    final b = _empty();
    b[0][8] = const Piece(PieceType.king, false); // 後手玉 1一
    b[1][2] = const Piece(PieceType.gold, false); // 後手金 7二
    b[1][4] = const Piece(PieceType.gold, false); // 後手金 5二
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    _p1(b, 8, 1, PieceType.gold);
    _p1(b, 6, 5, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    _p2(b, 1, 7, PieceType.silver); // 後手銀 2二
    _p2(b, 2, 7, PieceType.pawn);
    _p2(b, 2, 8, PieceType.pawn);
    list.add(TesujiProb(
      id: 'tech_1',
      title: '手筋テクニック ①（割り打ちの銀）',
      category: '手筋テクニック',
      explanation: '▲6三銀。「割り打ちの銀」。横に並んだ2枚の金の中間に銀を打ち、両方の金に当てます。どちらかの金を確実に取れる好手です。',
      board: b,
      p1Hand: const {PieceType.silver: 1, PieceType.pawn: 1},
      answer: const AMove(fr: -1, fc: -1, tr: 2, tc: 3, drop: PieceType.silver),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ② 田楽刺しの香
  {
    final b = _empty();
    b[0][0] = const Piece(PieceType.king, false); // 後手玉 9一
    b[2][4] = const Piece(PieceType.rook, false); // 後手飛 5三
    b[4][4] = const Piece(PieceType.gold, false); // 後手金 5五
    b[8][8] = const Piece(PieceType.king, true); // 先手玉 1九
    _p1(b, 8, 7, PieceType.gold);
    _p1(b, 6, 1, PieceType.pawn);
    _p1(b, 6, 2, PieceType.pawn);
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二
    _p2(b, 2, 0, PieceType.pawn);
    _p2(b, 2, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'tech_2',
      title: '手筋テクニック ②（田楽刺し）',
      category: '手筋テクニック',
      explanation: '▲5七香。「田楽刺し」。香の縦効きで手前の5五の金を狙い、その奥の5三飛も串刺しにします。金が逃げれば飛車が取れます。',
      board: b,
      p1Hand: const {PieceType.lance: 1, PieceType.pawn: 1},
      answer: const AMove(fr: -1, fc: -1, tr: 6, tc: 4, drop: PieceType.lance),
      sourceUrl: _src, sourceTitle: _srcName, difficulty: '中級',
    ));
  }

  // ─── クリーンデザイン手筋問題 ───

  // book_3: 両取り - 角の両取り
  {
    final b = _empty();
    _p1(b, 5, 1, PieceType.bishop);
    _p2(b, 2, 4, PieceType.rook);
    _p2(b, 4, 4, PieceType.gold);
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'book_3',
      title: '角の両取り',
      category: '両取り',
      explanation: '角を跳ね込んで、相手の飛車と金を同時に狙います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 1, tr: 3, tc: 3),
      difficulty: '初級',
    ));
  }

  // book_4: 両取り - 桂のふんどし
  {
    final b = _empty();
    _p1(b, 4, 4, PieceType.knight);
    _p2(b, 0, 4, PieceType.rook);
    _p2(b, 0, 2, PieceType.gold);
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'book_4',
      title: '桂のふんどし',
      category: '両取り',
      explanation: '桂馬を跳ねて、相手の飛車と金を同時に狙う「ふんどし」の手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 2, tc: 3, promote: false),
      difficulty: '初級',
    ));
  }

  // book_5: 両取り - 銀の両取り
  {
    final b = _empty();
    _p1(b, 5, 4, PieceType.silver);
    _p2(b, 3, 5, PieceType.rook);
    _p2(b, 3, 3, PieceType.gold);
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'book_5',
      title: '銀の両取り',
      category: '両取り',
      explanation: '銀を進出させて、相手の飛車と金を同時に狙います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 4, tr: 4, tc: 4),
      difficulty: '初級',
    ));
  }

  // book_6: 両取り - 龍の両取り
  {
    final b = _empty();
    _p1(b, 4, 4, PieceType.rook);
    _p2(b, 2, 1, PieceType.gold);
    _p2(b, 5, 4, PieceType.silver);
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'book_6',
      title: '龍の両取り',
      category: '両取り',
      explanation: '飛車を成って龍を作り、横と縦で金と銀を同時に狙います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 2, tc: 4, promote: true),
      difficulty: '初級',
    ));
  }

  // book_7: 飛車取り - 角で飛車を狙う
  {
    final b = _empty();
    _p1(b, 5, 5, PieceType.bishop);
    _p2(b, 3, 3, PieceType.rook);
    _p2(b, 0, 0, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    list.add(TesujiProb(
      id: 'book_7',
      title: '角で飛車を狙う',
      category: '飛車取り',
      explanation: '角を斜めに進めて、相手の飛車を斜めから狙います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 5, tr: 4, tc: 4),
      difficulty: '初級',
    ));
  }

  // book_8: 飛車取り - 串刺しの飛車取り
  {
    final b = _empty();
    _p1(b, 5, 3, PieceType.rook);
    _p2(b, 3, 3, PieceType.pawn);
    _p2(b, 0, 3, PieceType.rook);
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'book_8',
      title: '串刺しの飛車取り',
      category: '飛車取り',
      explanation: '飛車で歩を取りながら、その奥の相手飛車を狙う「田楽刺し」の手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 3, tr: 3, tc: 3),
      difficulty: '初級',
    ));
  }

  // book_9: 王手金取り - 桂の王手金取り
  {
    final b = _empty();
    _p1(b, 4, 5, PieceType.knight);
    _p2(b, 0, 3, PieceType.king);
    _p2(b, 0, 5, PieceType.gold);
    _p1(b, 8, 8, PieceType.king);
    list.add(TesujiProb(
      id: 'book_9',
      title: '桂の王手金取り',
      category: '王手金取り',
      explanation: '桂馬を跳ねて王手をかけながら、同時に金を狙います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 5, tr: 2, tc: 4, promote: false),
      difficulty: '初級',
    ));
  }

  // book_10: 王手金取り - 馬の王手金取り
  {
    final b = _empty();
    _p1(b, 3, 5, PieceType.promotedBishop);
    _p1(b, 3, 3, PieceType.silver); // 先手銀（着地点4三に紐をつける）
    _p2(b, 1, 3, PieceType.king);
    _p2(b, 1, 5, PieceType.gold);
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'book_10',
      title: '馬の王手金取り',
      category: '王手金取り',
      explanation: '馬（成り角）を寄せて王手をかけながら、同時に金を取りにいきます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 5, tr: 2, tc: 4),
      difficulty: '初級',
    ));
  }

  // ============================================================
  // 守り（さらに追加）mamori_7〜mamori_10（計100問）
  // ============================================================

  // mamori_7: 玉の早逃げ（先に逃げておく）
  {
    final b = _empty();
    _p2(b, 4, 4, PieceType.rook); // 後手飛 5五（攻撃準備）
    _p1(b, 6, 4, PieceType.king); // 先手玉 5七（危険な位置）
    _p2(b, 0, 0, PieceType.king);
    _p1(b, 7, 2, PieceType.gold);
    _p1(b, 7, 6, PieceType.silver);
    list.add(TesujiProb(
      id: 'mamori_7',
      title: '守り ⑦（玉の早逃げ）',
      category: '守り',
      explanation: '▲6八玉。後手飛車が5筋を攻めているため、玉を6八（横）に逃がします。「玉の早逃げ8手の得」という格言通り、危険を察知したら早めに玉を逃がしましょう。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 6, fc: 4, tr: 7, tc: 3),
      difficulty: '初級',
    ));
  }

  // mamori_8: 守りの金（金で守る）
  {
    final b = _empty();
    _p2(b, 5, 4, PieceType.rook); // 後手飛 5六（縦に王手中）
    _p1(b, 7, 4, PieceType.king); // 先手玉 5八（飛車に王手されている）
    _p1(b, 6, 3, PieceType.gold); // 先手金 6七（守りの位置）
    _p2(b, 0, 8, PieceType.king);
    _p2(b, 2, 3, PieceType.pawn);
    list.add(TesujiProb(
      id: 'mamori_8',
      title: '守り ⑧（金で合い駒して飛車を止める）',
      category: '守り',
      explanation: '▲5七金。後手飛車の王手に金を5七に合い駒します。金で縦の利きを遮断し、玉を守ります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 6, fc: 3, tr: 6, tc: 4),
      difficulty: '初級',
    ));
  }

  // mamori_9: 相手の攻め駒を排除（守りの捌き）
  {
    final b = _empty();
    _p2(b, 4, 4, PieceType.rook); // 後手飛 5五（中央で脅威）
    _p1(b, 5, 4, PieceType.silver); // 先手銀 5六（交換できる）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 6, 2, PieceType.gold);
    list.add(TesujiProb(
      id: 'mamori_9',
      title: '飛車取り ⑨（銀で飛車を取って排除）',
      category: '飛車取り',
      explanation: '▲5五銀。銀で後手の飛車を取ります。相手の強力な攻め駒（飛車）を除去することで、攻撃力を弱めます。「駒の交換による守り」の手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 4, tr: 4, tc: 4),
      difficulty: '中級',
    ));
  }

  // mamori_10: 二重の守り（ダブルガード）
  {
    final b = _empty();
    // 5四(3,4)は▲5四銀打の着地点のため駒を置かない
    _p2(b, 2, 4, PieceType.rook); // 後手飛 5三
    _p2(b, 2, 5, PieceType.bishop); // 後手角 4三
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p1(b, 5, 4, PieceType.rook); // 先手飛（5四に紐）
    list.add(TesujiProb(
      id: 'mamori_10',
      title: '手筋テクニック ⑩（銀打ちで飛車と角を両取り）',
      category: '手筋テクニック',
      explanation: '▲5四銀打。銀を5四に打つと、5三の後手飛車と4三の後手角の両方に当たります。一手で二枚の大駒を攻める「銀の両取り」の手筋です。',
      board: b,
      p1Hand: const {PieceType.silver: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 3, tc: 4, drop: PieceType.silver),
      difficulty: '中級',
    ));
  }

  // ============================================================
  // 飛車取り（追加）hisha_5〜hisha_9
  // ============================================================

  // hisha_5: 竜で飛車取り（横に走る）
  {
    final b = _empty();
    _p1(b, 4, 6, PieceType.promotedRook); // 竜 3五
    _p2(b, 4, 0, PieceType.rook); // 後手飛 9五
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 2, 7, PieceType.gold);
    _p1(b, 6, 8, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_5',
      title: '飛車取り ⑤（竜で取る）',
      category: '飛車取り',
      explanation: '▲9五竜。竜（成り飛車）を横に走らせ、後手の飛車を取ります。竜は飛車の動きに加えて斜め1マスにも動けることを覚えておきましょう。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 6, tr: 4, tc: 0),
      difficulty: '初級',
    ));
  }

  // hisha_6: 銀で飛車を取る
  {
    final b = _empty();
    _p2(b, 2, 3, PieceType.rook); // 後手飛 6三
    _p1(b, 3, 4, PieceType.silver); // 先手銀 5四
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 6, 6, PieceType.pawn);
    _p2(b, 1, 7, PieceType.gold);
    list.add(TesujiProb(
      id: 'hisha_6',
      title: '飛車取り ⑥（銀で取る）',
      category: '飛車取り',
      explanation: '▲6三銀。銀を斜め前に進め、後手の飛車をタダで取ります。銀は斜め方向に強い駒です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 4, tr: 2, tc: 3),
      difficulty: '初級',
    ));
  }

  // hisha_7: 角打ちで飛車取り
  {
    final b = _empty();
    _p2(b, 4, 2, PieceType.rook); // 後手飛 7五
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 2, 6, PieceType.silver);
    _p1(b, 6, 0, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_7',
      title: '飛車取り ⑦（角打ちで取る）',
      category: '飛車取り',
      explanation: '▲6五角打。持ち駒の角を6五に打ち、後手の飛車を斜めから攻めます。角の遠距離攻撃を活かした一手です。',
      board: b,
      p1Hand: const {PieceType.bishop: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 6, tc: 4, drop: PieceType.bishop),
      difficulty: '中級',
    ));
  }

  // hisha_8: 桂で飛車取り
  {
    final b = _empty();
    _p2(b, 2, 5, PieceType.rook); // 後手飛 4三
    _p1(b, 4, 6, PieceType.knight); // 先手桂 3五
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 7, PieceType.gold);
    _p1(b, 6, 4, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_8',
      title: '飛車取り ⑧（桂馬で取る）',
      category: '飛車取り',
      explanation: '▲4三桂成。桂馬を跳ねて後手の飛車を取ります。桂馬は途中の駒を飛び越える特殊な動きが特徴です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 6, tr: 2, tc: 5),
      difficulty: '中級',
    ));
  }

  // hisha_9: 成銀で飛車取り
  {
    final b = _empty();
    _p2(b, 3, 3, PieceType.rook); // 後手飛 6四
    _p1(b, 4, 4, PieceType.promotedSilver); // 先手成銀 5五
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 6, PieceType.pawn);
    _p1(b, 6, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_9',
      title: '飛車取り ⑨（成銀で取る）',
      category: '飛車取り',
      explanation: '▲6四成銀。成銀（NG）を斜め前に進めて飛車を取ります。成銀は金と同じ動きができる強力な駒です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 3, tc: 3),
      difficulty: '中級',
    ));
  }

  // ============================================================
  // 王手金取り（追加）kintori_4〜kintori_8
  // ============================================================

  // kintori_4: 銀の王手金取り
  {
    final b = _empty();
    _p2(b, 0, 6, PieceType.king); // 後手玉 3一
    _p2(b, 0, 4, PieceType.gold); // 後手金 5一
    _p1(b, 2, 5, PieceType.silver); // 先手銀 4三
    _p1(b, 5, 5, PieceType.rook); // 先手飛（1,5=4二を守る）
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 1, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_4',
      title: '王手金取り ④（銀）',
      category: '王手金取り',
      explanation: '▲4二銀。銀を1マス前へ進めると、同時に玉に王手がかかり、隣の金も攻められます。「王手金取り」の典型的な手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 2, fc: 5, tr: 1, tc: 5),
      difficulty: '中級',
    ));
  }

  // kintori_5: 飛車の王手金取り（取って王手）
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 0, 3, PieceType.gold); // 後手金 6一
    _p1(b, 5, 3, PieceType.rook); // 先手飛 6六
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 2, 7, PieceType.pawn);
    _p1(b, 6, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_5',
      title: '王手金取り ⑤（飛車で金を取って王手）',
      category: '王手金取り',
      explanation: '▲6一飛。飛車で金を取った瞬間、同じ段に玉がいるため王手になります。1手で金を取りながら王手、まさに「王手金取り」の典型手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 3, tr: 0, tc: 3),
      difficulty: '中級',
    ));
  }

  // kintori_6: 香車の王手金取り
  {
    final b = _empty();
    _p2(b, 1, 5, PieceType.king); // 後手玉 4二
    _p2(b, 2, 5, PieceType.gold); // 後手金 4三（玉の直下に金）
    _p1(b, 6, 5, PieceType.lance); // 先手香 4七
    _p1(b, 3, 6, PieceType.silver); // 先手銀（着地点4三に紐をつける）
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 0, 3, PieceType.silver);
    _p1(b, 7, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_6',
      title: '王手金取り ⑥（香車）',
      category: '王手金取り',
      explanation: '▲4三香。香車を一直線に走らせ、金を取りながらその上にいる玉に王手をかけます。香車の「突き抜け」を活かした手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 6, fc: 5, tr: 2, tc: 5),
      difficulty: '中級',
    ));
  }

  // kintori_7: 桂の王手金取り②（金を取って玉に王手）
  {
    final b = _empty();
    _p2(b, 0, 4, PieceType.king); // 後手玉 5一
    _p2(b, 2, 3, PieceType.gold); // 後手金 6三
    _p1(b, 4, 4, PieceType.knight); // 先手桂 5五
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 1, 5, PieceType.pawn);
    _p1(b, 6, 2, PieceType.silver);
    list.add(TesujiProb(
      id: 'kintori_7',
      title: '王手金取り ⑦（桂②）',
      category: '王手金取り',
      explanation: '▲6三桂不成。桂馬を跳ねて金を取ります（ここはあえて不成！）。不成の桂馬は前方2段・左右1マスに跳び、6三から5一の玉に直接王手がかかります。成ると金になり王手が消えるのがポイントです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 2, tc: 3),
      difficulty: '中級',
    ));
  }

  // kintori_8: 歩の王手金取り
  {
    final b = _empty();
    _p2(b, 0, 4, PieceType.king); // 後手玉 5一
    _p2(b, 1, 4, PieceType.gold); // 後手金 5二（玉の直下）
    _p1(b, 2, 4, PieceType.pawn); // 先手歩 5三
    _p1(b, 2, 5, PieceType.silver); // 先手銀（着地点5二に紐をつける）
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 3, PieceType.silver);
    _p1(b, 5, 6, PieceType.rook);
    list.add(TesujiProb(
      id: 'kintori_8',
      title: '王手金取り ⑧（歩）',
      category: '王手金取り',
      explanation: '▲5二歩。歩で金を取ると、その歩が玉に当たります。シンプルですが確実な「歩による王手金取り」の手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 2, fc: 4, tr: 1, tc: 4),
      difficulty: '初級',
    ));
  }

  // ============================================================
  // 両取り（追加）ryo_4〜ryo_10
  // ============================================================

  // ryo_4: 角の両取り（飛車と金）
  {
    final b = _empty();
    _p2(b, 3, 3, PieceType.rook); // 後手飛 6四
    _p2(b, 3, 5, PieceType.gold); // 後手金 4四
    _p1(b, 6, 6, PieceType.bishop); // 先手角 3七
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 7, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_4',
      title: '両取り ④（角で飛車と金を同時攻め）',
      category: '両取り',
      explanation: '▲5五角。角を5五に動かすと、対角線上の飛車と金を同時に狙います。どちらを逃げても残りの一方を取れる「両取り」です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 6, fc: 6, tr: 4, tc: 4),
      difficulty: '中級',
    ));
  }

  // ryo_5: 飛車の両取り（横に走って金と銀を攻める）
  {
    final b = _empty();
    _p2(b, 4, 2, PieceType.gold); // 後手金 7五
    _p2(b, 4, 6, PieceType.silver); // 後手銀 3五
    _p1(b, 7, 4, PieceType.rook); // 先手飛 5八
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 2, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_5',
      title: '両取り ⑤（飛車で金と銀を同時攻め）',
      category: '両取り',
      explanation: '▲5五飛。飛車を5五に移動させると、同じ段にある金と銀を同時に狙えます。飛車の横の利きを活かした両取りです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 7, fc: 4, tr: 4, tc: 4),
      difficulty: '中級',
    ));
  }

  // ryo_6: 桂のフォーク（金と飛車を同時攻め）
  {
    final b = _empty();
    _p2(b, 0, 2, PieceType.gold); // 後手金 7一
    _p2(b, 0, 4, PieceType.rook); // 後手飛 5一
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 4, 4, PieceType.knight); // 先手桂 5五
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 6, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_6',
      title: '両取り ⑥（桂でフォーク）',
      category: '両取り',
      explanation: '▲6三桂。桂馬を6三に跳ねると、7一の金と5一の飛車を同時に攻めます。桂馬の「フォーク」と呼ばれる技です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 2, tc: 3),
      difficulty: '中級',
    ));
  }

  // ryo_7: 銀の両取り（飛車と金）
  {
    final b = _empty();
    _p2(b, 3, 3, PieceType.rook); // 後手飛 6四
    _p2(b, 3, 5, PieceType.gold); // 後手金 4四
    _p1(b, 5, 4, PieceType.silver); // 先手銀 5六
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p1(b, 6, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_7',
      title: '両取り ⑦（銀で飛車と金を同時攻め）',
      category: '両取り',
      explanation: '▲5五銀。銀を5五に進めると、斜め前の飛車と金を同時に攻めます。銀の「斜め効き」を活かした両取りです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 4, tr: 4, tc: 4),
      difficulty: '中級',
    ));
  }

  // ryo_8: 角の両取り②（銀と竜を同時攻め）
  {
    final b = _empty();
    _p2(b, 2, 2, PieceType.silver); // 後手銀 7三
    _p2(b, 5, 5, PieceType.promotedRook); // 後手竜 4六
    _p1(b, 5, 1, PieceType.bishop); // 先手角 8六
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p1(b, 7, 3, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_8',
      title: '両取り ⑧（角で銀と竜を同時攻め）',
      category: '両取り',
      explanation: '▲6四角。角を6四に移動させると、斜め上の銀と斜め下の竜を同時に狙います。角の長い利きが両方向に届く好手です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 1, tr: 3, tc: 3),
      difficulty: '上級',
    ));
  }

  // ryo_9: 竜の両取り（縦横に攻める）
  {
    final b = _empty();
    _p2(b, 3, 0, PieceType.gold); // 後手金 9四
    _p2(b, 0, 6, PieceType.bishop); // 後手角 3一
    _p1(b, 3, 8, PieceType.promotedRook); // 先手竜 1四
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 2, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_9',
      title: '両取り ⑨（竜で縦横に攻める）',
      category: '両取り',
      explanation: '▲1四竜→1四から3四に移動。竜を3四に置くと、横の金と縦の角を同時に脅かします。竜の縦横の力を活かした両取りです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 8, tr: 3, tc: 6),
      difficulty: '上級',
    ));
  }

  // ryo_10: 馬の両取り（飛車と銀を同時攻め）
  {
    final b = _empty();
    _p2(b, 3, 3, PieceType.rook); // 後手飛 6四
    _p2(b, 3, 7, PieceType.silver); // 後手銀 2四
    _p1(b, 7, 3, PieceType.promotedBishop); // 先手馬 6八
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p1(b, 6, 1, PieceType.pawn);
    list.add(TesujiProb(
      id: 'ryo_10',
      title: '両取り ⑩（馬で飛車と銀を同時攻め）',
      category: '両取り',
      explanation: '▲5五馬。馬を5五に進めると、斜めの飛車と銀を同時に攻めます。馬（成り角）は角に加え、隣接マスへも動けます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 7, fc: 3, tr: 5, tc: 5),
      difficulty: '上級',
    ));
  }

  // ============================================================
  // 捨て駒（追加）sute_3〜sute_10
  // ============================================================

  // sute_3: 銀打ちの捨て駒（王手して引き出す）
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一（角）
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 5, 8, PieceType.rook); // 先手飛 1六（縦の守り）
    _p2(b, 0, 7, PieceType.gold); // 後手金 2一
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'sute_3',
      title: '捨て駒 ③（銀打ちで引き出す）',
      category: '捨て駒',
      explanation: '▲2二銀打。銀を2二に打って王手をかけます。玉が逃げた後、次の攻めが続く「捨て駒」の手筋です。駒を犠牲にして形勢を崩します。',
      board: b,
      p1Hand: const {PieceType.silver: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.silver),
      difficulty: '中級',
    ));
  }

  // sute_4: 飛車で金を捨てて玉を引き出す
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 1, 8, PieceType.gold); // 後手金 1二（玉を守る）
    _p1(b, 5, 8, PieceType.rook); // 先手飛 1六
    _p1(b, 8, 4, PieceType.king);
    _p2(b, 0, 7, PieceType.silver);
    _p1(b, 3, 0, PieceType.gold); // 先手持ち駒的な攻め金
    list.add(TesujiProb(
      id: 'sute_4',
      title: '捨て駒 ④（飛車で金を取って引き出す）',
      category: '捨て駒',
      explanation: '▲1二飛。飛車で金を取ると、玉に1二を踏ませることができます。飛車を捨てて玉の位置を変える「引き出しの手筋」です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 8, tr: 1, tc: 8),
      difficulty: '中級',
    ));
  }

  // sute_5: 角を打って玉頭に迫る
  {
    final b = _empty();
    _p2(b, 2, 8, PieceType.king); // 後手玉 1三
    _p2(b, 2, 7, PieceType.gold); // 後手金 2三
    _p2(b, 3, 8, PieceType.pawn); // 後手歩 1四
    _p1(b, 5, 5, PieceType.rook); // 先手飛 4六
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'sute_5',
      title: '捨て駒 ⑤（角打ちで玉頭に迫る）',
      category: '捨て駒',
      explanation: '▲3一角打。角を打って王手をかけます。玉が逃げた先でさらに攻める展開を作るための「角の捨て駒」です。',
      board: b,
      p1Hand: const {PieceType.bishop: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 0, tc: 6, drop: PieceType.bishop),
      difficulty: '中級',
    ));
  }

  // sute_6: 歩の突き捨て（突き捨ての歩）
  {
    final b = _empty();
    _p2(b, 4, 3, PieceType.pawn); // 後手歩 6五
    _p1(b, 5, 3, PieceType.pawn); // 先手歩 6六
    _p2(b, 3, 3, PieceType.silver); // 後手銀 6四（歩を守る）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 5, PieceType.rook); // 先手飛 4九
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'sute_6',
      title: '捨て駒 ⑥（突き捨ての歩）',
      category: '捨て駒',
      explanation: '▲6五歩。歩を突き捨てます。銀に取られますが、その後の攻めのために筋（縦線）を通す重要な手筋です。「突き捨ての歩」と呼ばれます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 3, tr: 4, tc: 3),
      difficulty: '中級',
    ));
  }

  // sute_7: 金で玉を引き出す捨て駒
  {
    final b = _empty();
    _p2(b, 0, 7, PieceType.king); // 後手玉 2一（飛車の邪魔にならない位置）
    _p2(b, 0, 8, PieceType.gold); // 後手金 1一（玉の横）
    _p1(b, 4, 8, PieceType.rook); // 先手飛 1五
    _p1(b, 8, 4, PieceType.king);
    _p2(b, 1, 7, PieceType.silver);
    list.add(TesujiProb(
      id: 'sute_7',
      title: '捨て駒 ⑦（金を取って王手）',
      category: '捨て駒',
      explanation: '▲1一飛。飛車で金を取りながら玉に王手をかけます。飛車が1一に入ると、2一の玉に横から王手がかかります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 8, tr: 0, tc: 8),
      difficulty: '中級',
    ));
  }

  // sute_8: 銀の捨て駒（攻めの銀）
  {
    final b = _empty();
    _p2(b, 2, 8, PieceType.silver); // 後手銀 1三（守り）
    _p2(b, 1, 8, PieceType.king); // 後手玉 1二
    _p1(b, 3, 7, PieceType.silver); // 先手銀 2四（1三に届く）
    _p1(b, 7, 8, PieceType.rook); // 先手飛 1八
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'sute_8',
      title: '捨て駒 ⑧（銀の捨て駒で道を開ける）',
      category: '捨て駒',
      explanation: '▲1三銀。銀を1三に進めて後手銀を取りながら玉に王手をかけます。取り返されても、その後の飛車の縦攻撃が通るようになります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 7, tr: 2, tc: 8),
      difficulty: '上級',
    ));
  }

  // sute_9: 角交換の捨て駒
  {
    final b = _empty();
    _p2(b, 3, 3, PieceType.bishop); // 後手角 6四
    _p1(b, 7, 7, PieceType.bishop); // 先手角 2八
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 1, PieceType.gold); // 後手金 8二（角で狙われる位置）
    _p1(b, 7, 5, PieceType.pawn); // 先手歩 2八（角の斜めを空ける）
    list.add(TesujiProb(
      id: 'sute_9',
      title: '捨て駒 ⑨（角交換で金を狙う）',
      category: '捨て駒',
      explanation: '▲6四角。先に角を交換します。角を取った後、自分の角を打ち直すと後手の8二金に当たります。角交換で主導権を握る手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 7, fc: 7, tr: 3, tc: 3),
      difficulty: '中級',
    ));
  }

  // sute_10: 飛車成り込みの捨て駒
  {
    final b = _empty();
    _p2(b, 2, 8, PieceType.silver); // 後手銀 1三（守り）
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p1(b, 5, 8, PieceType.rook); // 先手飛 1六
    _p1(b, 8, 4, PieceType.king);
    _p2(b, 1, 7, PieceType.gold);
    list.add(TesujiProb(
      id: 'sute_10',
      title: '捨て駒 ⑩（飛車成り込みで玉に迫る）',
      category: '捨て駒',
      explanation: '▲1三飛成。飛車を1三に成り込んで銀を取ります。竜になることで王手がかかり、次に詰みを狙います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 8, tr: 2, tc: 8, promote: true),
      difficulty: '上級',
    ));
  }

  // ============================================================
  // 端攻め（新カテゴリ）hashi_1〜hashi_10
  // ============================================================

  // hashi_1: 端歩の突き捨て
  {
    final b = _empty();
    _p1(b, 8, 8, PieceType.lance); // 先手香 1九
    _p1(b, 4, 8, PieceType.pawn); // 先手歩 1五
    _p2(b, 3, 8, PieceType.pawn); // 後手歩 1四（止めている）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 7, PieceType.gold);
    _p1(b, 6, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_1',
      title: '端攻め ①（端歩の突き捨て）',
      category: '端攻め',
      explanation: '▲1四歩。端の歩を突き捨てます。後手が同歩と取れば1筋（端）が開き、香車の攻撃が通ります。端攻めの第一歩です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 8, tr: 3, tc: 8),
      difficulty: '初級',
    ));
  }

  // hashi_2: 香車で端を突破
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 2, 8, PieceType.pawn); // 後手歩 1三
    _p1(b, 8, 8, PieceType.lance); // 先手香 1九
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 7, PieceType.gold);
    _p1(b, 6, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_2',
      title: '端攻め ②（香車で端を突破）',
      category: '端攻め',
      explanation: '▲1三香成。香車で端歩を取りながら成ります。成ると金と同じ動きになり、1一の玉に迫ります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 8, fc: 8, tr: 2, tc: 8, promote: true),
      difficulty: '中級',
    ));
  }

  // hashi_3: 飛車で端を攻める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 2, 8, PieceType.pawn); // 後手歩 1三
    _p1(b, 5, 8, PieceType.rook); // 先手飛 1六
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 7, PieceType.silver);
    _p1(b, 6, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_3',
      title: '端攻め ③（飛車で端の歩を取る）',
      category: '端攻め',
      explanation: '▲1三飛。飛車で端の歩を取ります。その後の香車成りや次の攻めの準備になります。飛車を端に使う攻め方です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 8, tr: 2, tc: 8),
      difficulty: '初級',
    ));
  }

  // hashi_4: 桂馬で端に跳ねる
  {
    final b = _empty();
    _p2(b, 2, 8, PieceType.silver); // 後手銀 1三
    _p1(b, 4, 7, PieceType.knight); // 先手桂 2五
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 7, PieceType.gold);
    _p1(b, 6, 5, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_4',
      title: '端攻め ④（桂馬で端の銀を攻める）',
      category: '端攻め',
      explanation: '▲1三桂成。桂馬を端に跳ねて銀を取ります。桂馬の独特な動きが端守りの銀を攻める手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 7, tr: 2, tc: 8),
      difficulty: '中級',
    ));
  }

  // hashi_5: 香打ちで端を押さえる
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 0, 0, PieceType.rook); // 先手飛 9一（横の守り）
    _p1(b, 8, 4, PieceType.king);
    _p2(b, 0, 7, PieceType.gold);
    list.add(TesujiProb(
      id: 'hashi_5',
      title: '端攻め ⑤（香打ちで端を押さえる）',
      category: '端攻め',
      explanation: '▲1三香打。香を1三に打って後手の玉頭を押さえます。歩があっても香の射程に入り、次に歩を取って進みます。',
      board: b,
      p1Hand: const {PieceType.lance: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 2, tc: 8, drop: PieceType.lance),
      difficulty: '中級',
    ));
  }

  // hashi_6: 端歩の成り込み
  {
    final b = _empty();
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 2, 8, PieceType.pawn); // 先手歩 1三（敵陣）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 7, PieceType.gold);
    _p1(b, 5, 6, PieceType.rook);
    list.add(TesujiProb(
      id: 'hashi_6',
      title: '端攻め ⑥（端歩成り込みでと金を作る）',
      category: '端攻め',
      explanation: '▲1二歩成。歩で後手の歩を取り、と金に成ります。と金（成り歩）は金と同じ動きができ、玉頭に残って守りにくい駒です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 2, fc: 8, tr: 1, tc: 8, promote: true),
      difficulty: '初級',
    ));
  }

  // hashi_7: 銀で端を崩す
  {
    final b = _empty();
    _p2(b, 1, 8, PieceType.gold); // 後手金 1二（端守り）
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p1(b, 3, 7, PieceType.silver); // 先手銀 2四
    _p1(b, 8, 4, PieceType.king);
    _p1(b, 5, 8, PieceType.rook);
    _p2(b, 0, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_7',
      title: '端攻め ⑦（銀で端の金を崩す）',
      category: '端攻め',
      explanation: '▲1三銀成。銀を1三に進めて成ります。次に1二の金を攻めて端を崩します。銀の成り込みで端守りを突破する手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 7, tr: 2, tc: 8, promote: true),
      difficulty: '中級',
    ));
  }

  // hashi_8: 竜で端を制圧
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 0, 7, PieceType.gold); // 後手金 2一
    _p1(b, 3, 8, PieceType.promotedRook); // 先手竜 1四
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 2, 7, PieceType.pawn);
    _p1(b, 6, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_8',
      title: '端攻め ⑧（竜で端の玉に迫る）',
      category: '端攻め',
      explanation: '▲1二竜。竜を1二に近づけて玉に迫ります。竜は1一の玉に王手をかけられる位置に入り、次の攻めを続けます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 8, tr: 1, tc: 8),
      difficulty: '中級',
    ));
  }

  // hashi_9: 端銀の攻め（玉頭を攻める）
  {
    final b = _empty();
    _p2(b, 2, 8, PieceType.king); // 後手玉 1三
    _p2(b, 3, 8, PieceType.pawn); // 後手歩 1四（守り）
    _p1(b, 4, 7, PieceType.silver); // 先手銀 2五
    _p1(b, 8, 4, PieceType.king);
    _p2(b, 2, 7, PieceType.gold);
    _p1(b, 6, 5, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hashi_9',
      title: '端攻め ⑨（銀で玉頭の歩を取る）',
      category: '端攻め',
      explanation: '▲1四銀。銀を1四に進めて後手の歩を取ります。銀が玉の頭（上部）に入り込む端攻めの形です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 7, tr: 3, tc: 8),
      difficulty: '中級',
    ));
  }

  // hashi_10: 端攻めの仕上げ（角でとどめ）
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 0, 7, PieceType.gold); // 後手金 2一
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 3, 5, PieceType.bishop); // 先手角 4四
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 5, 8, PieceType.rook);
    list.add(TesujiProb(
      id: 'hashi_10',
      title: '端攻め ⑩（角で端に利かす）',
      category: '端攻め',
      explanation: '▲2二角成。角で2一の金を取りながら成ります。馬が2一に入り込み、1一の玉に直接脅威を与えます。端攻めの仕上げの形です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 5, tr: 1, tc: 7, promote: true),
      difficulty: '上級',
    ));
  }

  // ============================================================
  // 手筋テクニック（追加）tech_3〜tech_9
  // ============================================================

  // tech_3: 発見王手（開き王手）
  {
    final b = _empty();
    _p2(b, 0, 4, PieceType.king); // 後手玉 5一
    _p1(b, 4, 4, PieceType.bishop); // 先手角 5五（玉の前に）
    _p1(b, 6, 4, PieceType.rook); // 先手飛 5七（角の後ろ）
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 1, 5, PieceType.gold);
    _p2(b, 1, 3, PieceType.silver);
    list.add(TesujiProb(
      id: 'tech_3',
      title: '手筋テクニック ③（開き王手）',
      category: '手筋テクニック',
      explanation: '▲5四角（角を斜めに移動）。角を動かすと飛車の縦の利きが通り、玉に王手がかかります。このような「隠れていた駒の利きを使う王手」を開き王手と言います。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 3, tc: 3),
      difficulty: '中級',
    ));
  }

  // tech_4: 縛り（ピン）
  {
    final b = _empty();
    _p2(b, 1, 1, PieceType.king); // 後手玉 8二
    _p2(b, 3, 3, PieceType.silver); // 後手銀 6四（玉の斜め下）
    _p1(b, 7, 7, PieceType.bishop); // 先手角 2八
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 2, PieceType.gold);
    _p1(b, 7, 6, PieceType.pawn); // 先手歩（角の筋を塞がない位置）
    list.add(TesujiProb(
      id: 'tech_4',
      title: '手筋テクニック ④（縛り・ピン）',
      category: '手筋テクニック',
      explanation: '▲5五角。角を5五に進めると、銀が玉との間にある「ピン」状態を作ります。銀は玉の前に立っているため動けず、次に取られます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 7, fc: 7, tr: 4, tc: 4),
      difficulty: '上級',
    ));
  }

  // tech_5: 位取り（中央の制圧）
  {
    final b = _empty();
    _p1(b, 5, 4, PieceType.pawn); // 先手歩 5六
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 4, 3, PieceType.pawn); // 後手歩 6五（対峙中）
    _p2(b, 3, 4, PieceType.silver);
    _p1(b, 6, 5, PieceType.silver);
    list.add(TesujiProb(
      id: 'tech_5',
      title: '手筋テクニック ⑤（位取り・中央制圧）',
      category: '手筋テクニック',
      explanation: '▲5五歩。歩を5五（中央）に突いて「位」を取ります。中央に歩が立つと広い面積を制圧でき、後の攻めがスムーズになります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 4, tr: 4, tc: 4),
      difficulty: '初級',
    ));
  }

  // tech_6: 合い駒（王手を受ける）
  {
    final b = _empty();
    _p2(b, 0, 4, PieceType.rook); // 後手飛 5一（縦に攻撃中）
    _p1(b, 8, 4, PieceType.king); // 先手玉 5九（王手されている）
    _p2(b, 0, 8, PieceType.king);
    _p2(b, 2, 6, PieceType.gold);
    _p1(b, 6, 0, PieceType.pawn);
    list.add(TesujiProb(
      id: 'tech_6',
      title: '守り ⑥（合い駒で王手を防ぐ）',
      category: '守り',
      explanation: '▲5五金打。後手飛車の王手に合い駒を打ちます。玉と飛車の間に駒を打って王手を防ぐ「合い駒」の基本技術です。',
      board: b,
      p1Hand: const {PieceType.gold: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 4, tc: 4, drop: PieceType.gold),
      difficulty: '初級',
    ));
  }

  // tech_7: 継ぎ歩（連続して攻める歩）
  {
    final b = _empty();
    _p1(b, 5, 3, PieceType.pawn); // 先手歩 6六
    _p2(b, 4, 3, PieceType.pawn); // 後手歩 6五
    _p2(b, 3, 3, PieceType.silver); // 後手銀 6四（歩を守る）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 6, 3, PieceType.rook);
    list.add(TesujiProb(
      id: 'tech_7',
      title: '手筋テクニック ⑦（継ぎ歩で圧力をかける）',
      category: '手筋テクニック',
      explanation: '▲6五歩。後手の歩に歩をぶつけます。「継ぎ歩」とは連続して歩を突いて相手を圧迫する手筋です。攻めの起点を作ります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 3, tr: 4, tc: 3),
      difficulty: '中級',
    ));
  }

  // tech_8: 玉の疎開（安全な場所へ）
  {
    final b = _empty();
    _p2(b, 4, 8, PieceType.rook); // 後手飛 1五（横から攻撃）
    _p1(b, 4, 4, PieceType.king); // 先手玉 5五（同じ段で危険）
    _p2(b, 0, 0, PieceType.king);
    _p2(b, 2, 6, PieceType.gold);
    _p1(b, 6, 2, PieceType.gold);
    list.add(TesujiProb(
      id: 'tech_8',
      title: '守り ⑧（玉の疎開）',
      category: '守り',
      explanation: '▲5六玉。後手の飛車が同じ段にいるため、玉を安全な段に逃がします。「玉の疎開」と呼ばれる防御の手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 5, tc: 4),
      difficulty: '初級',
    ));
  }

  // tech_9: 手番を取る（テンポ良く指す）
  {
    final b = _empty();
    _p1(b, 3, 4, PieceType.gold); // 先手金 5四（前進）
    _p2(b, 2, 4, PieceType.pawn); // 後手歩 5三（攻撃されている）
    _p2(b, 1, 4, PieceType.silver); // 後手銀 5二（守り）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p1(b, 4, 6, PieceType.rook);
    list.add(TesujiProb(
      id: 'tech_9',
      title: '手筋テクニック ⑨（手番を活かした連続攻め）',
      category: '手筋テクニック',
      explanation: '▲5三歩取り。金で歩を取ります。相手が対応せざるを得ない手を指し続けることで「手番」を保ちます。テンポよく攻め続ける基本です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 4, tr: 2, tc: 4),
      difficulty: '中級',
    ));
  }

  // ============================================================
  // 守り（追加）mamori_4〜mamori_6
  // ============================================================

  // mamori_4: 金引き（下がって守る）
  {
    final b = _empty();
    _p2(b, 4, 4, PieceType.rook); // 後手飛 5五（縦横に攻撃）
    _p1(b, 3, 4, PieceType.gold); // 先手金 5四（攻撃されている）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 6, 2, PieceType.silver);
    _p2(b, 2, 6, PieceType.silver);
    list.add(TesujiProb(
      id: 'mamori_4',
      title: '手筋テクニック ④（金引きで安全に）',
      category: '手筋テクニック',
      explanation: '▲5五金→5四から5五以外へ退避。後手の飛車に当たっている金を安全な場所に引きます。「金引き」は守りの基本手筋の一つです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 4, tr: 3, tc: 5),
      difficulty: '初級',
    ));
  }

  // mamori_5: 受けの歩（歩で進撃を止める）
  {
    final b = _empty();
    _p2(b, 3, 4, PieceType.silver); // 後手銀 5四（前進中）
    _p1(b, 5, 4, PieceType.gold); // 先手金 5六（攻められそう）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p1(b, 7, 6, PieceType.rook);
    list.add(TesujiProb(
      id: 'mamori_5',
      title: '手筋テクニック ⑤（受けの歩で進撃を止める）',
      category: '手筋テクニック',
      explanation: '▲5五歩打。後手銀の進撃を歩打で止めます。銀が5四にいるとき、5五に歩を打てば前進を阻止できます。「受けの歩」の基本形です。',
      board: b,
      p1Hand: const {PieceType.pawn: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 4, tc: 4, drop: PieceType.pawn),
      difficulty: '初級',
    ));
  }

  // mamori_6: 合い駒の選択（効果的な合い）
  {
    final b = _empty();
    _p2(b, 5, 5, PieceType.bishop); // 後手角 4六（斜めに王手）
    _p1(b, 7, 7, PieceType.king); // 先手玉 2八（角に王手されている）
    _p2(b, 0, 0, PieceType.king);
    _p2(b, 2, 3, PieceType.rook);
    _p1(b, 8, 2, PieceType.gold);
    list.add(TesujiProb(
      id: 'mamori_6',
      title: '守り ⑥（合い駒で角の王手を防ぐ）',
      category: '守り',
      explanation: '▲3七銀打。後手角の王手に合い駒を打ちます。角と玉の間（6六）に銀を打って王手を防ぎます。打つ駒の種類で次の形が変わります。',
      board: b,
      p1Hand: const {PieceType.silver: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 6, tc: 6, drop: PieceType.silver),
      difficulty: '中級',
    ));
  }

  // ============================================================
  // 成り手筋 nari_1〜nari_7
  // ============================================================

  // nari_1: 歩が成ってと金
  {
    final b = _empty();
    _p1(b, 1, 4, PieceType.pawn); // 先手歩 5二（敵陣）
    _p2(b, 0, 4, PieceType.gold); // 後手金 5一
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 3, PieceType.pawn);
    _p1(b, 4, 6, PieceType.rook);
    list.add(TesujiProb(
      id: 'nari_1',
      title: '成り手筋 ①（歩でと金を作る）',
      category: '成り手筋',
      explanation: '▲5一歩成。歩で金を取りながら「と金」に成ります。と金は金と同じ動きができ、玉頭に作ると非常に強力です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 1, fc: 4, tr: 0, tc: 4, promote: true),
      difficulty: '初級',
    ));
  }

  // nari_2: 銀が成って成銀
  {
    final b = _empty();
    _p1(b, 3, 5, PieceType.silver); // 先手銀 4四（敵陣手前）
    _p2(b, 2, 4, PieceType.pawn); // 後手歩 5三
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 0, 5, PieceType.gold);
    _p1(b, 5, 3, PieceType.rook);
    list.add(TesujiProb(
      id: 'nari_2',
      title: '成り手筋 ②（銀の成り込み）',
      category: '成り手筋',
      explanation: '▲5三銀成。銀を前に進めて歩を取りながら成ります。成銀（NG）は金と同じ動きになり、攻め駒として非常に使いやすくなります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 5, tr: 2, tc: 4, promote: true),
      difficulty: '初級',
    ));
  }

  // nari_3: 桂が成って成桂
  {
    final b = _empty();
    _p1(b, 4, 5, PieceType.knight); // 先手桂 4五
    _p2(b, 2, 4, PieceType.silver); // 後手銀 5三
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 5, PieceType.gold);
    _p1(b, 5, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'nari_3',
      title: '成り手筋 ③（桂の成り込み）',
      category: '成り手筋',
      explanation: '▲5三桂成。桂馬で銀を取りながら成ります。成桂は金と同じ動きになり、敵陣での攻め駒として活躍します。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 5, tr: 2, tc: 4, promote: true),
      difficulty: '中級',
    ));
  }

  // nari_4: 香が成って成香
  {
    final b = _empty();
    _p1(b, 6, 3, PieceType.lance); // 先手香 6四
    _p2(b, 2, 3, PieceType.knight); // 後手桂 6三→実際は敵方の桂
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 4, PieceType.gold);
    _p1(b, 7, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'nari_4',
      title: '成り手筋 ④（香の成り込み）',
      category: '成り手筋',
      explanation: '▲6三香成。香車を前に走らせ、桂馬を取りながら成ります。成香は金と同じ動きになり、敵陣で活躍します。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 6, fc: 3, tr: 2, tc: 3, promote: true),
      difficulty: '中級',
    ));
  }

  // nari_5: 角が成って馬（角行→竜馬）
  {
    final b = _empty();
    _p1(b, 5, 5, PieceType.bishop); // 先手角 4六
    _p2(b, 2, 2, PieceType.rook); // 後手飛 7三
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 3, PieceType.gold);
    _p1(b, 6, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'nari_5',
      title: '成り手筋 ⑤（角が成って馬になる）',
      category: '成り手筋',
      explanation: '▲7三角成。角で後手の飛車を取りながら「馬」に成ります。馬は角の動きに加えて、隣接するマスにも動けます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 5, tr: 2, tc: 2, promote: true),
      difficulty: '中級',
    ));
  }

  // nari_6: 飛が成って竜（飛車→竜王）
  {
    final b = _empty();
    _p1(b, 5, 4, PieceType.rook); // 先手飛 5六
    _p2(b, 2, 4, PieceType.silver); // 後手銀 5三
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 3, PieceType.gold);
    _p1(b, 6, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'nari_6',
      title: '成り手筋 ⑥（飛車が成って竜になる）',
      category: '成り手筋',
      explanation: '▲5三飛成。飛車で銀を取りながら「竜」に成ります。竜は飛車の動きに加えて、斜め隣接マスにも動けます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 4, tr: 2, tc: 4, promote: true),
      difficulty: '初級',
    ));
  }

  // nari_7: 成り捨て（成って捨てる）
  {
    final b = _empty();
    _p1(b, 3, 7, PieceType.silver); // 先手銀 2四
    _p2(b, 1, 8, PieceType.king); // 後手玉 1二
    _p2(b, 0, 8, PieceType.gold); // 後手金 1一（玉の上）
    _p1(b, 5, 8, PieceType.rook); // 先手飛 1六
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'nari_7',
      title: '成り手筋 ⑦（成り捨て）',
      category: '成り手筋',
      explanation: '▲1三銀成。銀を1三に成り込みます。成銀を捨てて玉の守りを崩す「成り捨て」の手筋です。取られても次の攻撃が続きます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 7, tr: 2, tc: 8, promote: true),
      difficulty: '上級',
    ));
  }

  // ============================================================
  // 馬・竜の活用 umaryuu_1〜umaryuu_10
  // ============================================================

  // umaryuu_1: 馬を中央に使う
  {
    final b = _empty();
    _p1(b, 6, 0, PieceType.promotedBishop); // 先手馬 9七
    _p2(b, 3, 3, PieceType.gold); // 後手金 6四（狙い）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 1, 5, PieceType.silver);
    _p1(b, 7, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'umaryuu_1',
      title: '馬・竜の活用 ①（馬を中央へ）',
      category: '馬・竜の活用',
      explanation: '▲6四馬。馬を中央に持ってきて後手の金を狙います。馬は盤の中央に置くほど多くの方向に影響を与えられます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 6, fc: 0, tr: 3, tc: 3),
      difficulty: '初級',
    ));
  }

  // umaryuu_2: 竜で圧力をかける
  {
    final b = _empty();
    _p1(b, 5, 0, PieceType.promotedRook); // 先手竜 9六
    _p2(b, 5, 8, PieceType.rook); // 後手飛 1六（対抗する）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 4, PieceType.king);
    _p2(b, 0, 7, PieceType.gold);
    _p1(b, 7, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'umaryuu_2',
      title: '馬・竜の活用 ②（竜で飛車を圧迫）',
      category: '馬・竜の活用',
      explanation: '▲1六竜。竜を1六に移動させ、後手の飛車と同じ段で圧力をかけます。竜は飛車より強く、対抗できます。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 0, tr: 5, tc: 8),
      difficulty: '中級',
    ));
  }

  // umaryuu_3: 馬を引いて飛車に当てる
  {
    final b = _empty();
    _p1(b, 2, 2, PieceType.promotedBishop); // 先手馬 7三（前線）
    _p1(b, 8, 0, PieceType.king); // 先手玉（安全な場所）
    _p2(b, 4, 3, PieceType.rook); // 後手飛 6五（攻撃中）
    _p2(b, 0, 0, PieceType.king);
    _p2(b, 1, 4, PieceType.silver);
    _p2(b, 6, 4, PieceType.gold); // 後手金（馬で狙える）
    list.add(TesujiProb(
      id: 'umaryuu_3',
      title: '馬・竜の活用 ③（馬を引いて金を狙う）',
      category: '馬・竜の活用',
      explanation: '▲4六馬。馬を引いて後手金に当てます。馬は引くことで自陣を守りながら相手の駒を攻める、攻守一体の万能駒です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 2, fc: 2, tr: 5, tc: 5),
      difficulty: '中級',
    ));
  }

  // umaryuu_4: 竜で王手
  {
    final b = _empty();
    _p1(b, 4, 4, PieceType.promotedRook); // 先手竜 5五
    _p2(b, 0, 4, PieceType.king); // 後手玉 5一
    _p2(b, 2, 5, PieceType.gold); // 後手金 4三
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 3, PieceType.silver);
    list.add(TesujiProb(
      id: 'umaryuu_4',
      title: '馬・竜の活用 ④（竜で縦に王手）',
      category: '馬・竜の活用',
      explanation: '▲5三竜。竜を5三に進めて王手をかけます。玉に隣接せず縦の利きだけで王手できるため、竜自体は安全に残ります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 4, tr: 2, tc: 4),
      difficulty: '中級',
    ));
  }

  // umaryuu_5: 馬の斜め利き活用
  {
    final b = _empty();
    _p2(b, 1, 7, PieceType.gold); // 後手金 2二（馬の目標）
    _p2(b, 4, 6, PieceType.silver); // 後手銀（斜めを塞がない位置）
    _p1(b, 5, 3, PieceType.promotedBishop); // 先手馬 6四
    _p1(b, 2, 8, PieceType.silver); // 先手銀（着地点2二に紐をつける、馬の斜め経路は塞がない）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 2, 7, PieceType.pawn);
    list.add(TesujiProb(
      id: 'umaryuu_5',
      title: '馬・竜の活用 ⑤（馬で斜めに金を狙う）',
      category: '馬・竜の活用',
      explanation: '▲2二馬。馬で後手の金を斜めに取ります。馬は遠くから斜めに攻められるため、守りにくい強力な攻め駒です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 3, tr: 1, tc: 7),
      difficulty: '中級',
    ));
  }

  // umaryuu_6: 竜の横攻め
  {
    final b = _empty();
    _p2(b, 3, 0, PieceType.gold); // 後手金 9四
    _p1(b, 3, 8, PieceType.promotedRook); // 先手竜 1四
    _p2(b, 0, 0, PieceType.king); // 後手玉 9一（竜に王手される位置）
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 0, 1, PieceType.silver); // 後手銀（玉の近く）
    _p1(b, 6, 6, PieceType.pawn);
    list.add(TesujiProb(
      id: 'umaryuu_6',
      title: '馬・竜の活用 ⑥（竜で金を取って王手）',
      category: '馬・竜の活用',
      explanation: '▲9四竜。竜を横に走り9四の金を取ります。竜が9四に来ると9筋で後手玉に王手がかかります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 8, tr: 3, tc: 0),
      difficulty: '初級',
    ));
  }

  // umaryuu_7: 馬で守りを崩す
  {
    final b = _empty();
    _p2(b, 1, 8, PieceType.gold); // 後手金 1二（端守り）
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p1(b, 4, 5, PieceType.promotedBishop); // 先手馬 4五
    _p1(b, 2, 8, PieceType.silver); // 先手銀（着地点1二に紐をつける、馬の斜め経路は塞がない）
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 0, 7, PieceType.silver);
    _p1(b, 6, 3, PieceType.pawn);
    list.add(TesujiProb(
      id: 'umaryuu_7',
      title: '馬・竜の活用 ⑦（馬で端の守りを崩す）',
      category: '馬・竜の活用',
      explanation: '▲1二馬。馬を1二に持ってきて、1一の玉頭に直接迫ります。馬が近づくと隣接マスも攻められ、守りにくくなります。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 4, fc: 5, tr: 1, tc: 8),
      difficulty: '上級',
    ));
  }

  // umaryuu_8: 竜と馬の連携
  {
    final b = _empty();
    _p1(b, 3, 4, PieceType.promotedRook); // 先手竜 5四
    _p1(b, 5, 2, PieceType.promotedBishop); // 先手馬 7六
    _p2(b, 0, 4, PieceType.king); // 後手玉 5一
    _p2(b, 1, 5, PieceType.gold); // 後手金 4二（守り）
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 0, 3, PieceType.silver);
    list.add(TesujiProb(
      id: 'umaryuu_8',
      title: '馬・竜の活用 ⑧（竜で王手して金を攻める）',
      category: '馬・竜の活用',
      explanation: '▲5三竜。竜で王手をかけます。玉に隣接しないので竜は取られず安全、玉が逃げれば馬で金を取ります。竜と馬の連携による攻めです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 4, tr: 2, tc: 4),
      difficulty: '上級',
    ));
  }

  // umaryuu_9: 馬で飛車を取って王手
  {
    final b = _empty();
    _p2(b, 4, 4, PieceType.rook); // 後手飛 5五（馬で取れる）
    _p1(b, 7, 1, PieceType.promotedBishop); // 先手馬 8八
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 0, 3, PieceType.silver);
    list.add(TesujiProb(
      id: 'umaryuu_9',
      title: '馬・竜の活用 ⑨（馬で飛車を取って王手）',
      category: '馬・竜の活用',
      explanation: '▲5五馬。馬を5五に動かして後手飛車を取ります。馬は5五から1一方向の対角線で後手玉に王手もかかります。一手で飛車取りと王手の二役。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 7, fc: 1, tr: 4, tc: 4),
      difficulty: '上級',
    ));
  }

  // umaryuu_10: 竜で玉に迫る
  {
    final b = _empty();
    _p1(b, 3, 6, PieceType.promotedRook); // 先手竜 3四
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一（角）
    _p2(b, 0, 7, PieceType.gold); // 後手金 2一
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 2, 8, PieceType.pawn);
    _p1(b, 5, 5, PieceType.pawn);
    list.add(TesujiProb(
      id: 'umaryuu_10',
      title: '馬・竜の活用 ⑩（竜で金に当てる）',
      category: '馬・竜の活用',
      explanation: '▲3一竜。竜を3一に進め、隣の2一の金に当てます。竜は縦横の長距離移動に加えて隣接1マスにも動けることを活かした手筋です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 6, tr: 0, tc: 6),
      difficulty: '中級',
    ));
  }

  // ============================================================
  // 詰め（追加）tsume_3〜tsume_11
  // ============================================================

  // tsume_3: 馬で詰める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一（角）
    _p2(b, 0, 7, PieceType.gold); // 後手金 2一
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 3, 5, PieceType.promotedBishop); // 先手馬 4四
    _p1(b, 0, 0, PieceType.rook); // 先手飛 9一（横を守る）
    _p1(b, 2, 7, PieceType.pawn); // 先手歩（2二の馬を守る）
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_3',
      title: '詰め ③（馬で詰める）',
      category: '詰め',
      explanation: '▲2二馬。馬を2二に進めて玉に隣接王手をかけます。飛車が横を押さえ、歩が2二の馬を守るため、後手は玉を逃がせません。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 5, tr: 1, tc: 7, promote: false),
      difficulty: '上級',
    ));
  }

  // tsume_4: 竜で詰める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一
    _p2(b, 0, 7, PieceType.lance); // 後手香 2一（金→香に変更：竜を取れない）
    _p2(b, 1, 7, PieceType.pawn); // 後手歩 2二
    _p1(b, 3, 8, PieceType.promotedRook); // 先手竜 1四
    _p1(b, 5, 8, PieceType.rook); // 先手飛 1六（竜を守る）
    _p1(b, 8, 4, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_4',
      title: '詰め ④（竜で玉を追い詰める）',
      category: '詰め',
      explanation: '▲1二竜。竜を1二に進めて玉に王手をかけます。飛車が1六から竜を守り、香車は斜めに動けないため詰みです。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 3, fc: 8, tr: 1, tc: 8),
      difficulty: '上級',
    ));
  }

  // ============================================================
  // 詰め（さらに追加）tsume_5〜tsume_11 （100問達成）
  // ============================================================

  // tsume_5: 金打ちで詰める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king);
    _p2(b, 0, 7, PieceType.silver);
    _p2(b, 1, 8, PieceType.pawn);
    _p1(b, 0, 0, PieceType.rook); // 横を守る（銀が取れない）
    _p1(b, 2, 7, PieceType.pawn); // 先手歩（2二の金を守る）
    _p1(b, 8, 4, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_5',
      title: '詰め ⑤（金打ちで詰める）',
      category: '詰め',
      explanation: '▲2二金打。金を2二に打って王手します。歩が金を守り、飛車が横を押さえているため、玉は逃げ場がありません。',
      board: b,
      p1Hand: const {PieceType.gold: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold),
      difficulty: '中級',
    ));
  }

  // tsume_6: 銀打ちで詰める
  {
    final b = _empty();
    _p2(b, 1, 8, PieceType.king); // 後手玉 1二
    _p2(b, 0, 8, PieceType.gold); // 後手金 1一
    _p2(b, 0, 7, PieceType.pawn); // 後手歩 2一
    _p2(b, 2, 8, PieceType.pawn); // 後手歩 1三（玉の逃げ道を塞ぐ）
    _p1(b, 2, 0, PieceType.rook); // 先手飛 9三（横を押さえ、銀を守る）
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_6',
      title: '詰め ⑥（銀打ちで詰める）',
      category: '詰め',
      explanation: '▲2三銀打。銀を2三に打って王手します。飛車が横に控え銀を守り、後手の歩が逃げ道を塞いでいるため詰みです。',
      board: b,
      p1Hand: const {PieceType.silver: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 2, tc: 7, drop: PieceType.silver),
      difficulty: '中級',
    ));
  }

  // tsume_7: 角打ちで詰める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一（隅）
    _p2(b, 0, 7, PieceType.knight); // 後手桂 2一（斜めに動けない）
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 1, 0, PieceType.rook); // 先手飛 9二（2二を守る）
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_7',
      title: '詰め ⑦（角打ちで詰める）',
      category: '詰め',
      explanation: '▲2二角打。角を2二に打って1一の玉に斜め王手をかけます。飛車が2二を守り、桂馬と歩が逃げ道を塞ぐため詰みです。',
      board: b,
      p1Hand: const {PieceType.bishop: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.bishop),
      difficulty: '上級',
    ));
  }

  // tsume_8: 飛打ちで詰める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一（隅）
    _p2(b, 0, 7, PieceType.knight); // 後手桂 2一（1二に動けない）
    _p2(b, 1, 7, PieceType.pawn); // 後手歩 2二（横を塞ぐ）
    _p1(b, 2, 8, PieceType.gold); // 先手金 1三（1二を守る）
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_8',
      title: '詰め ⑧（飛打ちで詰める）',
      category: '詰め',
      explanation: '▲1二飛打。飛車を1二に打って1一の玉に縦王手をかけます。金が1二を守り、桂馬と歩が逃げ道を塞ぐため詰みです。',
      board: b,
      p1Hand: const {PieceType.rook: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 1, tc: 8, drop: PieceType.rook),
      difficulty: '上級',
    ));
  }

  // tsume_9: 桂打ちで詰める
  {
    final b = _empty();
    _p2(b, 0, 8, PieceType.king); // 後手玉 1一（隅）
    _p2(b, 0, 7, PieceType.pawn); // 後手歩 2一
    _p2(b, 1, 8, PieceType.pawn); // 後手歩 1二
    _p1(b, 1, 0, PieceType.rook); // 先手飛 9二（2二を押さえる）
    _p1(b, 8, 0, PieceType.king);
    list.add(TesujiProb(
      id: 'tsume_9',
      title: '詰め ⑨（桂打ちで詰める）',
      category: '詰め',
      explanation: '▲3二桂打。桂を3二に打つと、跳んで1一の玉に王手がかかります（桂は(r-2,c±1)に利く）。飛車が2二を押さえ、後手の歩が逃げ道を塞ぐため詰みです。',
      board: b,
      p1Hand: const {PieceType.knight: 1},
      p1Turn: true,
      answer: const AMove(fr: -1, fc: -1, tr: 2, tc: 7, drop: PieceType.knight),
      difficulty: '上級',
    ));
  }

  // ============================================================
  // 飛車取り（追加）hisha_10
  // ============================================================

  // hisha_10: 馬で飛車取り
  {
    final b = _empty();
    _p1(b, 5, 1, PieceType.promotedBishop); // 先手馬 8六
    _p2(b, 3, 3, PieceType.rook); // 後手飛 6四（馬の斜め先）
    _p2(b, 0, 8, PieceType.king);
    _p1(b, 8, 0, PieceType.king);
    _p2(b, 1, 7, PieceType.gold);
    _p1(b, 6, 5, PieceType.pawn);
    list.add(TesujiProb(
      id: 'hisha_10',
      title: '飛車取り ⑩（馬で取る）',
      category: '飛車取り',
      explanation: '▲6四馬。馬（成り角）を斜めに動かして後手の飛車を取ります。馬は角の斜め長距離移動に加え、隣接1マスにも動けます。角成り後の馬を攻め駒として活用する基本形です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 1, tr: 3, tc: 3),
      difficulty: '初級',
    ));
  }

  // ============================================================
  // 王手金取り（追加）kintori_9
  // ============================================================

  // kintori_9: 竜で金を取って王手
  {
    final b = _empty();
    _p2(b, 0, 4, PieceType.king); // 後手玉 5一
    _p2(b, 2, 4, PieceType.gold); // 後手金 5三（玉と同筋）
    _p1(b, 5, 4, PieceType.promotedRook); // 先手竜 5六（同じ5筋）
    _p1(b, 8, 8, PieceType.king);
    _p2(b, 1, 3, PieceType.silver);
    _p1(b, 6, 2, PieceType.pawn);
    list.add(TesujiProb(
      id: 'kintori_9',
      title: '王手金取り ⑨（竜）',
      category: '王手金取り',
      explanation: '▲5三竜。竜で5三の金を取ります。竜は縦に5一の玉まで直通しているため、金を取った瞬間に王手がかかります。1手で金取りと王手を兼ねる「王手金取り」です。',
      board: b,
      p1Hand: const {},
      p1Turn: true,
      answer: const AMove(fr: 5, fc: 4, tr: 2, tc: 4),
      difficulty: '中級',
    ));
  }

  return list;
}
