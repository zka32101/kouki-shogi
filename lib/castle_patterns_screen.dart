// lib/castle_patterns_screen.dart — 囲いパターン説明

import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'utils/shogi_data_validator.dart';
import 'theme/app_theme.dart';

class CastlePatternsScreen extends StatefulWidget {
  const CastlePatternsScreen({super.key});

  @override
  State<CastlePatternsScreen> createState() => _CastlePatternsScreenState();
}

class _CastlePatternsScreenState extends State<CastlePatternsScreen> {
  String? _selectedDifficulty;

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'フィルター',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '難度',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['初級', '中級', '上級'].map((difficulty) {
                      final isSelected = _selectedDifficulty == difficulty;
                      return FilterChip(
                        label: Text(difficulty),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedDifficulty = selected ? difficulty : null;
                          });
                          this.setState(() {});
                        },
                        backgroundColor: const Color(0xFF0F3460),
                        selectedColor: Colors.amber.shade600,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text(
                      '閉じる',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── 座標系: board[row][col], row=段-1, col=9-筋
  //   例) 8八 → row=7, col=1  /  3七 → row=6, col=6
  static List<List<Piece?>> _empty() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null, growable: true));

  // 居玉（きょぎょく）— 玉が初期位置のまま
  static List<List<Piece?>> _kyogyoku() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);   // 5九玉
    b[8][3] = const Piece(PieceType.gold, true);   // 6九金（初期位置）
    b[8][5] = const Piece(PieceType.gold, true);   // 4九金（初期位置）
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    return b;
  }

  // 矢倉（やぐら）— 8八玉、7八金、7七銀、6七金
  static List<List<Piece?>> _yagura() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[7][4] = const Piece(PieceType.rook, true);   // 5八飛
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[5][3] = const Piece(PieceType.pawn, true);   // 6六歩
    b[5][4] = const Piece(PieceType.pawn, true);   // 5六歩
    return b;
  }

  // 銀矢倉（ぎんやぐら）— 8八玉、7八金、7七銀、6七銀（矢倉の6七金を銀に変えた形）
  // (shougi.jp の図で座標を確認)
  static List<List<Piece?>> _ginYagura() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.silver, true); // 6七銀（銀矢倉の特徴）
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[8][1] = const Piece(PieceType.knight, true); // 8九桂
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    return b;
  }

  // 片矢倉（かたやぐら）— 7八玉、6八金、7七銀、6七金（矢倉より一路控えた形）
  // (shougi.jp の図で座標を確認)
  static List<List<Piece?>> _kataYagura() {
    final b = _empty();
    b[7][2] = const Piece(PieceType.king, true);   // 7八玉
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[8][1] = const Piece(PieceType.knight, true); // 8九桂
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    return b;
  }

  // 串カツ囲い（くしかつがこい）— 9八玉、8八銀、7八金、7九金、7七角
  // (shougi.jp の図で座標を確認)
  static List<List<Piece?>> _kushikatsu() {
    final b = _empty();
    b[7][0] = const Piece(PieceType.king, true);   // 9八玉
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[8][2] = const Piece(PieceType.gold, true);   // 7九金
    b[6][2] = const Piece(PieceType.bishop, true); // 7七角
    b[8][1] = const Piece(PieceType.knight, true); // 8九桂
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    return b;
  }

  // 美濃囲い（みのがこい）— 2八玉、3八銀、5八金（振り飛車）
  // (shogi-joutatsu.com 図1-1「本美濃囲い」で座標を確認・修正。以前は
  //  金と銀の座標が入れ替わった上に誤った位置（銀7七・金3八）になっており、
  //  正しくは銀3八・金5八だった)
  static List<List<Piece?>> _mino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.silver, true); // 3八銀
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[7][5] = const Piece(PieceType.rook, true);   // 4八飛（四間飛車）
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    b[5][6] = const Piece(PieceType.pawn, true);   // 3六歩
    return b;
  }

  // 舟囲い（ふねがこい）— 5八玉、4八金、6八金
  static List<List<Piece?>> _funegakoi() {
    final b = _empty();
    b[7][4] = const Piece(PieceType.king, true);   // 5八玉
    b[7][5] = const Piece(PieceType.gold, true);   // 4八金
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    b[6][5] = const Piece(PieceType.pawn, true);   // 4七歩
    return b;
  }

  // 金無双（きんむそう）— 3八玉、2八銀、4八金、5八金（相振り飛車の囲い）
  // (shogi-joutatsu.com「金無双」の図で座標を確認・修正。以前は矢倉と
  //  同じ8八玉側の座標が入っており、実際の金無双とは逆サイドだった)
  static List<List<Piece?>> _kinmusou() {
    final b = _empty();
    b[7][6] = const Piece(PieceType.king, true);   // 3八玉
    b[7][7] = const Piece(PieceType.silver, true); // 2八銀
    b[7][5] = const Piece(PieceType.gold, true);   // 4八金
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][6] = const Piece(PieceType.pawn, true);   // 3七歩
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    return b;
  }

  // 銀冠（ぎんかん）— 2八玉、3八金、4七金、2七銀（銀が玉の真上で冠の形）
  // (shogi-joutatsu.com「銀冠」の図で座標を確認・修正。以前は矢倉と同じ
  //  8八玉側の座標が入っており、実際の銀冠とは逆サイドだった)
  static List<List<Piece?>> _ginkan() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[6][5] = const Piece(PieceType.gold, true);   // 4七金
    b[6][7] = const Piece(PieceType.silver, true); // 2七銀（冠＝玉の真上）
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[5][8] = const Piece(PieceType.pawn, true);   // 1六歩
    b[5][7] = const Piece(PieceType.pawn, true);   // 2六歩
    b[5][6] = const Piece(PieceType.pawn, true);   // 3六歩
    return b;
  }

  // 左美濃（ひだりみの）— 8八玉、7八銀、6八金、5八金、7七角（居飛車）
  // (shogi-joutatsu.com 図1-1で座標を確認・修正。以前は美濃を左右反転させた
  //  2八玉の座標が入っており、実際の左美濃とは逆サイドのデータだった)
  static List<List<Piece?>> _hidarimino() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.silver, true); // 7八銀
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][2] = const Piece(PieceType.bishop, true); // 7七角
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    return b;
  }

  // 雁木（がんぎ）— 5九玉、7八金、5八金、6七銀、4八銀（銀2枚のジグザグ形）
  // (shogi-joutatsu.com「雁木囲いの基本形」で座標を確認・修正。以前は
  //  銀が1枚しかなく、雁木の特徴である2枚銀のジグザグ形になっていなかった。
  //  玉の位置も6八ではなく5九が正しい)
  static List<List<Piece?>> _gangi() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);   // 5九玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][3] = const Piece(PieceType.silver, true); // 6七銀
    b[7][5] = const Piece(PieceType.silver, true); // 4八銀
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    return b;
  }

  // カニ囲い（かにがこい）— 5九玉、6九金、4九金、5八銀
  static List<List<Piece?>> _kanigakoi() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);   // 5九玉
    b[8][3] = const Piece(PieceType.gold, true);   // 6九金
    b[8][5] = const Piece(PieceType.gold, true);   // 4九金
    b[7][4] = const Piece(PieceType.silver, true); // 5八銀
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    b[6][5] = const Piece(PieceType.pawn, true);   // 4七歩
    return b;
  }

  // 高美濃（たかみの）— 美濃の金が4七に上がった形
  // (shogi-joutatsu.com 図2-2「高美濃囲い」で座標を確認・修正。美濃囲いの
  //  修正に合わせ、銀3八・金4七・金4九の正しい配置にした)
  static List<List<Piece?>> _takamiino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.silver, true); // 3八銀（美濃のまま）
    b[6][5] = const Piece(PieceType.gold, true);   // 4七金（高美濃の特徴）
    b[8][5] = const Piece(PieceType.gold, true);   // 4九金
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[7][5] = const Piece(PieceType.rook, true);   // 4八飛（振り飛車）
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    return b;
  }

  // 穴熊（あなぐま）— 9九玉、8九金、7九金、9八銀、8八銀
  static List<List<Piece?>> _anaguma() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);   // 9九玉
    b[8][1] = const Piece(PieceType.gold, true);   // 8九金
    b[8][2] = const Piece(PieceType.gold, true);   // 7九金
    b[7][0] = const Piece(PieceType.silver, true); // 9八銀
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀（二枚銀が穴熊の特徴）
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[6][2] = const Piece(PieceType.pawn, true);   // 7七歩
    return b;
  }

  // 矢倉角換わり — 矢倉形から角を交換した局面
  static List<List<Piece?>> _yaguraKakuKawari() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[7][4] = const Piece(PieceType.rook, true);   // 5八飛
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[5][3] = const Piece(PieceType.pawn, true);   // 6六歩
    // 角なし（交換済み）
    return b;
  }

  // ビッグ4 — 9九玉＋金2枚・銀2枚で固める四枚穴熊の最強形
  // (shougi.jp の図で座標を確認・修正。以前は金・銀の段が入れ替わっており、
  //  香が9八へ上がって玉が9九に潜り込む形と、金8八・7八、銀8七・7七の
  //  正しい配置になっていなかった)
  static List<List<Piece?>> _bigFour() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);   // 9九玉
    b[7][0] = const Piece(PieceType.lance, true);  // 9八香（玉の真上）
    b[7][1] = const Piece(PieceType.gold, true);   // 8八金
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][1] = const Piece(PieceType.silver, true); // 8七銀
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[8][1] = const Piece(PieceType.knight, true); // 8九桂（未移動）
    return b;
  }

  // 中住まい（なかずまい）— 玉を中央5八に置き、左右の金銀で守る
  // (shougi.jp の図で座標を確認・修正。以前は金・銀の位置が入れ替わって
  //  おり、正しくは金が7八・3八、銀が4八（もう一方は7九のまま）だった)
  static List<List<Piece?>> _nakazumai() {
    final b = _empty();
    b[7][4] = const Piece(PieceType.king, true);   // 5八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[7][5] = const Piece(PieceType.silver, true); // 4八銀
    b[8][2] = const Piece(PieceType.silver, true); // 7九銀（未移動）
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    b[6][5] = const Piece(PieceType.pawn, true);   // 4七歩
    return b;
  }

  // 木村美濃（きむらみの）— 美濃に金を4七へ足した発展形
  // (美濃囲いの修正に合わせ、玉2八・銀3八・金5八の正しい基本形に
  //  4七の金を加えた形にした)
  static List<List<Piece?>> _kimuraMino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.silver, true); // 3八銀
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][5] = const Piece(PieceType.gold, true);   // 4七金（木村美濃の特徴）
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[5][5] = const Piece(PieceType.pawn, true);   // 4六歩
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    return b;
  }

  // 居飛車穴熊（いびしゃあなぐま）— 居飛車側が9九へ玉を潜らせる対振り最堅陣
  // (shogi-joutatsu.com 図2-1で座標を確認。金の1枚が6八ではなく7九だった)
  static List<List<Piece?>> _ibishaAnaguma() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);   // 9九玉
    b[7][0] = const Piece(PieceType.lance, true);  // 9八香
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[8][2] = const Piece(PieceType.gold, true);   // 7九金
    b[8][1] = const Piece(PieceType.knight, true); // 8九桂
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[6][2] = const Piece(PieceType.pawn, true);   // 7七歩
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final allCastles = [
      // 初級
      _CastleData(
        name: '居玉（きょぎょく）',
        description: '玉が初期位置のまま動かない形。手数をかけずに対局できるが守りが薄い。囲いの比較学習に最適。',
        board: _kyogyoku(),
        highlights: const {(8, 4)},
        difficulty: '初級',
        vertStrength: 1, horizStrength: 1, movesToBuild: 0,
      ),
      _CastleData(
        name: '矢倉（やぐら）',
        description: '8八玉・7八金・7七銀・6七金で組む居飛車の代表的な囲い。上部が厚く縦の攻めに強い。横から崩されると弱い。',
        board: _yagura(),
        highlights: const {(7, 1), (7, 2), (6, 2), (6, 3)},
        difficulty: '初級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 8,
      ),
      _CastleData(
        name: '美濃囲い（みのがこい）',
        description: '2八玉・3八銀・5八金の3枚で組む振り飛車の定番囲い。少ない手数で完成し横からの攻めに強い。上（玉頭方向）からは弱い。',
        board: _mino(),
        highlights: const {(7, 7), (7, 6), (7, 4)},
        difficulty: '初級',
        vertStrength: 1, horizStrength: 3, movesToBuild: 6,
      ),
      _CastleData(
        name: '舟囲い（ふねがこい）',
        description: '5八玉・4八金・6八金の最短形。急戦にすぐ対応でき素早く組める。横からの攻めに弱く長期戦不向き。',
        board: _funegakoi(),
        highlights: const {(7, 4), (7, 5), (7, 3)},
        difficulty: '初級',
        vertStrength: 1, horizStrength: 1, movesToBuild: 3,
      ),
      // 中級
      _CastleData(
        name: '金無双（きんむそう）',
        description: '3八玉・2八銀・4八金・5八金でまとめる囲い。相振り飛車でよく使われ素早く組める。上部に比較的強いが横からの攻めに注意。',
        board: _kinmusou(),
        highlights: const {(7, 6), (7, 7), (7, 5), (7, 4)},
        difficulty: '中級',
        vertStrength: 2, horizStrength: 1, movesToBuild: 5,
      ),
      _CastleData(
        name: '銀冠（ぎんかん）',
        description: '2八玉・2七銀・3八金・4七金の形。銀を玉の真上に冠のように乗せ上部の攻めに手厚い。美濃から発展した振り飛車の進化形。',
        board: _ginkan(),
        highlights: const {(7, 7), (6, 7), (7, 6), (6, 5)},
        difficulty: '中級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 10,
      ),
      _CastleData(
        name: '左美濃（ひだりみの）',
        description: '居飛車側が8八玉・7八銀・6八金・5八金と組む形。角を7七に上げて玉の斜め頭を守るのが特徴で、対抗形（居飛車vs振り飛車）で多用される。',
        board: _hidarimino(),
        highlights: const {(7, 1), (7, 2), (7, 3), (7, 4)},
        difficulty: '中級',
        vertStrength: 2, horizStrength: 3, movesToBuild: 7,
      ),
      _CastleData(
        name: '雁木（がんぎ）',
        description: '5九玉・7八金・5八金・6七銀・4八銀の2金2銀をジグザグに構える形。攻守のバランスが良く対矢倉・対居飛車で有力。',
        board: _gangi(),
        highlights: const {(8, 4), (7, 2), (7, 4), (6, 3), (7, 5)},
        difficulty: '中級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 8,
      ),
      _CastleData(
        name: 'カニ囲い（かにがこい）',
        description: '5九玉・6九金・4九金・5八銀の形。カニのハサミのような見た目。急戦志向で素早く攻撃に転じられる実戦的な構え。',
        board: _kanigakoi(),
        highlights: const {(8, 4), (8, 3), (8, 5), (7, 4)},
        difficulty: '中級',
        vertStrength: 1, horizStrength: 2, movesToBuild: 4,
      ),
      _CastleData(
        name: '高美濃（たかみの）',
        description: '美濃囲いの金を4七へ上げた発展形。玉頭が厚くなり美濃より上部の攻めに強い。振り飛車の定番進化形で4手追加で完成。',
        board: _takamiino(),
        highlights: const {(7, 7), (7, 6), (6, 5), (8, 5)},
        difficulty: '中級',
        vertStrength: 2, horizStrength: 3, movesToBuild: 9,
      ),
      // 上級
      _CastleData(
        name: '穴熊（あなぐま）',
        description: '9九玉・8九金・7九金・9八銀・8八銀の形。玉を隅深く潜らせる最強クラスの囲い。組むのに手数がかかる。一度組めば終盤に絶大な威力。',
        board: _anaguma(),
        highlights: const {(8, 0), (8, 1), (8, 2), (7, 0), (7, 1)},
        difficulty: '上級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 15,
      ),
      _CastleData(
        name: '矢倉角換わり',
        description: '矢倉形を維持しつつ角を交換した局面。高度な読みが必要で角打ちの隙を常に意識する必要がある。縦に強い矢倉形が基盤。',
        board: _yaguraKakuKawari(),
        highlights: const {(7, 1), (7, 2), (6, 2), (6, 3)},
        difficulty: '上級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 10,
      ),
      _CastleData(
        name: 'ビッグ4（びっぐふぉー）',
        description: '9九玉・9八香・8八金・7八金・8七銀・7七銀の四枚穴熊。金銀4枚で玉を完全に囲う最強クラスの堅陣。縦横どちらにも強いが組むのに20手以上かかる。',
        board: _bigFour(),
        highlights: const {(8, 0), (7, 0), (7, 1), (7, 2), (6, 1), (6, 2)},
        difficulty: '上級',
        vertStrength: 3, horizStrength: 3, movesToBuild: 20,
      ),
      _CastleData(
        name: '中住まい（なかずまい）',
        description: '5八玉・7八金・3八金・4八銀・7九銀。玉を中央に置き左右の金銀で守る。横に強く相居飛車の急戦で使われる。',
        board: _nakazumai(),
        highlights: const {(7, 4), (7, 2), (7, 6), (7, 5), (8, 2)},
        difficulty: '中級',
        vertStrength: 2, horizStrength: 2, movesToBuild: 6,
      ),
      _CastleData(
        name: '木村美濃（きむらみの）',
        description: '2八玉・3八銀・5八金・4七金。美濃に金を4七へ足して玉頭の守りと反撃力を高めた発展形。横に強く振り飛車で多用。',
        board: _kimuraMino(),
        highlights: const {(7, 7), (7, 6), (7, 4), (6, 5)},
        difficulty: '中級',
        vertStrength: 2, horizStrength: 3, movesToBuild: 8,
      ),
      _CastleData(
        name: '居飛車穴熊（いびしゃあなぐま）',
        description: '9九玉・9八香・8八銀・7八金・6八金。居飛車側が玉を隅へ潜らせる対振り飛車の最堅陣。遠さと固さで終盤に絶大な威力を発揮する。',
        board: _ibishaAnaguma(),
        highlights: const {(8, 0), (7, 1), (7, 2), (7, 3)},
        difficulty: '上級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 12,
      ),
      _CastleData(
        name: '銀矢倉（ぎんやぐら）',
        description: '8八玉・7八金・7七銀・6七銀。矢倉の6七金を銀に変えた形で、銀の斜め利きにより横からの攻めにやや強くなる。',
        board: _ginYagura(),
        highlights: const {(7, 1), (7, 2), (6, 2), (6, 3)},
        difficulty: '中級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 8,
      ),
      _CastleData(
        name: '片矢倉（かたやぐら）',
        description: '7八玉・6八金・7七銀・6七金。矢倉より玉が一路控えた形で、組む手数がやや少なく角換わりで多用される。',
        board: _kataYagura(),
        highlights: const {(7, 2), (7, 3), (6, 2), (6, 3)},
        difficulty: '中級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 7,
      ),
      _CastleData(
        name: '串カツ囲い（くしかつがこい）',
        description: '9八玉・8八銀・7八金・7九金・7七角。玉を9八に寄せつつ角を7七に活用する居飛車の堅陣。穴熊と矢倉の中間的な性質を持つ。',
        board: _kushikatsu(),
        highlights: const {(7, 0), (7, 1), (7, 2), (8, 2), (6, 2)},
        difficulty: '上級',
        vertStrength: 3, horizStrength: 2, movesToBuild: 11,
      ),
    ];

    final filtered = _selectedDifficulty == null
        ? allCastles
        : allCastles.where((c) => c.difficulty == _selectedDifficulty).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('囲いパターン', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.amber),
            tooltip: 'フィルター',
            onPressed: _showFilterMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDifficulty != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('絞込: ', style: TextStyle(color: Colors.amber.shade400, fontSize: 12)),
                  Chip(
                    label: Text(_selectedDifficulty!),
                    backgroundColor: Colors.amber.shade600,
                    labelStyle: const TextStyle(color: Colors.black, fontSize: 11),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('マッチする囲いがありません',
                        style: TextStyle(color: Colors.white.withAlpha(150))))
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _CastleCard(data: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CastleData {
  final String name;
  final String description;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlights;
  final String difficulty;
  final int vertStrength;   // 縦からの攻めへの強さ 1-3
  final int horizStrength;  // 横からの攻めへの強さ 1-3
  final int movesToBuild;   // 完成手数の目安

  const _CastleData({
    required this.name,
    required this.description,
    required this.board,
    required this.highlights,
    required this.difficulty,
    this.vertStrength = 2,
    this.horizStrength = 2,
    this.movesToBuild = 6,
  });
}

class _CastleCard extends StatelessWidget {
  final _CastleData data;
  const _CastleCard({required this.data});

  Color _difficultyColor() {
    switch (data.difficulty) {
      case '初級': return Colors.green.shade400;
      case '中級': return Colors.orange.shade400;
      case '上級': return Colors.red.shade400;
      default:    return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: Colors.amber.shade800.withAlpha(100), width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.name,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _difficultyColor(),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data.difficulty,
                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          // 評価項目バー
          _EvalRow(label: '縦の強さ', value: data.vertStrength, color: Colors.blue.shade400),
          const SizedBox(height: 4),
          _EvalRow(label: '横の強さ', value: data.horizStrength, color: Colors.teal.shade400),
          const SizedBox(height: 4),
          Row(children: [
            SizedBox(
              width: 60,
              child: Text('完成手数',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withAlpha(80)),
              ),
              child: Text(
                data.movesToBuild == 0 ? '0手（組まない）'
                    : '約${data.movesToBuild}手',
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Center(
            child: MiniBoardWidget(
              board: data.board,
              highlightSquares: data.highlights,
              size: 220,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvalRow extends StatelessWidget {
  final String label;
  final int value; // 1-3
  final Color color;
  const _EvalRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 60,
        child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
      ...List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Icon(
          i < value ? Icons.star_rounded : Icons.star_outline_rounded,
          color: color,
          size: 16,
        ),
      )),
    ]);
  }
}
