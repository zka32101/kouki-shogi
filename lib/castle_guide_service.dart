// lib/castle_guide_service.dart — 囲いガイドサービス

import 'piece.dart';

/// 先手（P1）視点の囲い目標配置
/// 座標系: board[row][col], row 0=一段(上/後手側), row 8=九段(下/先手側)
/// col 0=9筋, col 8=1筋
/// 例: 2八玉 → row=7, col=7  /  8八玉 → row=7, col=1
class CastleGuideService {
  static const Map<String, List<(PieceType, int, int)>> _castleTargets = {
    // 矢倉: 8八玉・7八金・7七銀・6七金
    'yagura': [
      (PieceType.king,   7, 1), // 8八玉
      (PieceType.gold,   7, 2), // 7八金
      (PieceType.silver, 6, 2), // 7七銀
      (PieceType.gold,   6, 3), // 6七金
    ],
    // 美濃（振り飛車）: 2八玉・3八銀・5八金
    // (shogi-joutatsu.com 図1-1「本美濃囲い」で座標を確認・修正。以前は
    //  金と銀の座標が入れ替わった上に誤った位置（銀7七・金3八）になっており、
    //  正しくは銀3八・金5八だった)
    'mino': [
      (PieceType.king,   7, 7), // 2八玉
      (PieceType.silver, 7, 6), // 3八銀
      (PieceType.gold,   7, 4), // 5八金
    ],
    // 穴熊: 9九玉・9八金・8八銀（左穴熊）
    'anaguma': [
      (PieceType.king,   8, 0), // 9九玉
      (PieceType.gold,   8, 1), // 8九金
      (PieceType.gold,   8, 2), // 7九金
      (PieceType.silver, 7, 0), // 9八銀
      (PieceType.silver, 7, 1), // 8八銀
    ],
    // 金無双: 3八玉・2八銀・4八金・5八金
    // (shogi-joutatsu.com「金無双」の図で座標を確認・修正。以前は矢倉と
    //  同じ8八玉側の座標が入っており、実際の金無双とは逆サイドだった)
    'kinmusou': [
      (PieceType.king,   7, 6), // 3八玉
      (PieceType.silver, 7, 7), // 2八銀
      (PieceType.gold,   7, 5), // 4八金
      (PieceType.gold,   7, 4), // 5八金
    ],
    // 銀冠: 2八玉・2七銀（冠）・3八金・4七金
    // (shogi-joutatsu.com「銀冠」の図で座標を確認・修正。以前は矢倉と同じ
    //  8八玉側の座標が入っており、実際の銀冠とは逆サイドだった)
    'ginkan': [
      (PieceType.king,   7, 7), // 2八玉
      (PieceType.silver, 6, 7), // 2七銀（冠＝玉の真上）
      (PieceType.gold,   7, 6), // 3八金
      (PieceType.gold,   6, 5), // 4七金
    ],
    // 左美濃（居飛車）: 8八玉・7八銀・5八金・6八金・7七角
    // (shogi-joutatsu.com 図1-1で座標を確認・修正。以前は美濃を左右反転させた
    //  2八玉の座標が入っており、実際の左美濃とは逆サイドのデータだった)
    'hidarimino': [
      (PieceType.king,   7, 1), // 8八玉
      (PieceType.silver, 7, 2), // 7八銀
      (PieceType.gold,   7, 4), // 5八金
      (PieceType.gold,   7, 3), // 6八金
    ],
    // 雁木: 5九玉・6七銀・4八銀・7八金・5八金
    // (shogi-joutatsu.com「雁木囲いの基本形」で座標を確認・修正。以前は
    //  銀が1枚しかなく、雁木の特徴である2枚銀のジグザグ形になっていなかった。
    //  玉の位置も6八ではなく5九が正しい)
    'gangi': [
      (PieceType.king,   8, 4), // 5九玉
      (PieceType.silver, 6, 3), // 6七銀
      (PieceType.silver, 7, 5), // 4八銀
      (PieceType.gold,   7, 2), // 7八金
      (PieceType.gold,   7, 4), // 5八金
    ],
    // 居飛車穴熊: 9九玉・9八香・8八銀・7八金・7九金
    // (shogi-joutatsu.com 図2-1で座標を確認。金が1枚欠けていたため追加)
    'matsuoanaguma': [
      (PieceType.king,   8, 0), // 9九玉
      (PieceType.lance,  7, 0), // 9八香
      (PieceType.silver, 7, 1), // 8八銀
      (PieceType.gold,   7, 2), // 7八金
      (PieceType.gold,   8, 2), // 7九金
    ],
    // elmo囲い: 7八玉・7九銀・6九金
    // (shogi-joutatsu.com「elmo囲い」の図で座標を確認・修正。以前は
    //  玉6八・金5八・銀7七になっており、正しくは玉7八・銀7九・金6九だった)
    'elmo': [
      (PieceType.king,   7, 2), // 7八玉
      (PieceType.silver, 8, 2), // 7九銀
      (PieceType.gold,   8, 3), // 6九金
    ],
  };

  static String castleName(String key) => const {
    'yagura':         '矢倉',
    'mino':           '美濃',
    'anaguma':        '穴熊',
    'kinmusou':       '金無双',
    'ginkan':         '銀冠',
    'hidarimino':     '左美濃',
    'gangi':          '雁木',
    'matsuoanaguma':  '居飛車穴熊',
    'elmo':           'elmo囲い',
  }[key] ?? '美濃';

  /// 現在の盤面で未完成の目標マスへの矢印リストを返す
  /// P1（先手）: 目標座標をそのまま使用
  /// P2（後手）: 行・列を反転（row→8-row, col→8-col）
  ///
  /// 一手ずつの案内にするため、_castleTargets の並び順（組む手順）で
  /// 最初に見つかった未完成の1手だけを返す（[oneAtATime]=false で
  /// 従来通り全ての残り矢印をまとめて返すことも可能）。
  static List<(int, int, int, int)> getGuideArrows(
    List<List<Piece?>> board,
    String castleKey,
    bool isP1, {
    bool oneAtATime = true,
  }) {
    final targets = _castleTargets[castleKey];
    if (targets == null) return [];

    final arrows = <(int, int, int, int)>[];
    final usedFrom = <(int, int)>{};

    for (final (pieceType, targetR, targetC) in targets) {
      final tr = isP1 ? targetR : (8 - targetR);
      final tc = isP1 ? targetC : (8 - targetC);

      // 目標マスに既に正しい駒があれば完了
      final atTarget = board[tr][tc];
      if (atTarget != null && atTarget.type == pieceType && atTarget.isPlayer1 == isP1) {
        continue;
      }

      // 盤上からその駒を探す（未使用優先）
      (int, int)? found;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (usedFrom.contains((r, c))) continue;
          final p = board[r][c];
          if (p != null && p.type == pieceType && p.isPlayer1 == isP1) {
            if (r != tr || c != tc) {
              found = (r, c);
              break;
            }
          }
        }
        if (found != null) break;
      }

      if (found != null) {
        usedFrom.add(found);
        arrows.add((found.$1, found.$2, tr, tc));
        if (oneAtATime) break;
      }
    }

    return arrows;
  }
}
