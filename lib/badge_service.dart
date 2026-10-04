// lib/badge_service.dart — バッジ制度サービス

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── バッジID ─────────────────────────────────────────────────
enum BadgeId {
  // 対局数
  firstGame,       // 初対局
  game10,          // 10局達成
  game50,          // 50局達成
  game100,         // 100局達成
  game200,         // 200局達成
  game500,         // 500局達成
  // 連勝
  win3,            // 3連勝
  win5,            // 5連勝
  win10,           // 10連勝
  winStreak7,      // 7連勝達成
  // 勝率
  highWinRate,     // 通算勝率70%以上（最低30局）
  // レーティング
  rating700,       // 10級到達
  rating1000,      // 3級到達
  rating1200,      // 初段到達
  rating1500,      // 有段者（1500到達）
  rating1800,      // 高段者（1800到達）
  rating2000,      // 名人候補（2000到達）
  // 詰将棋
  tsume5,          // 詰将棋5問クリア
  tsume20,         // 詰将棋20問クリア
  tsume50,         // 詰将棋50問クリア
  tsumeMaster,     // 詰将棋全問クリア（100問）
  // 変則
  variantPlay,     // 変則将棋を1戦
  variantMaster,   // 全変則ルールで対局
  // AI対局
  beatMedium,      // 中級AIに初勝利
  beatHard,        // 上級AIに初勝利
  beatSuperHard,   // 最上級AIに初勝利
  ai10wins,        // AIに10勝
  ai50wins,        // AIに50勝
  // ネット対局
  netFirst,        // 初めてネット対局完了
  netWin10,        // ネット対局10勝
  // 連続対局
  consecutive3days,  // 3日連続対局
  consecutive7days,  // 7日連続対局
  consecutive30days, // 30日連続対局
  // 棋譜研究
  teachingMode,    // 棋譜を10局保存して研究
  // 特殊勝利
  speedWin,        // 20手以内で勝利
}

// ── バッジ定義 ────────────────────────────────────────────────
class BadgeDef {
  final BadgeId id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<BadgeDef> allBadges = [
  BadgeDef(
    id: BadgeId.firstGame,
    title: '初陣',
    description: '初めて対局を完了した',
    icon: Icons.sports_esports,
    color: Colors.amber,
  ),
  BadgeDef(
    id: BadgeId.game10,
    title: '10局達成',
    description: '対局数が10局に達した',
    icon: Icons.timelapse,
    color: Colors.orange,
  ),
  BadgeDef(
    id: BadgeId.game50,
    title: '50局達成',
    description: '対局数が50局に達した',
    icon: Icons.military_tech,
    color: Colors.deepOrange,
  ),
  BadgeDef(
    id: BadgeId.game100,
    title: '100局達成',
    description: '対局数が100局に達した',
    icon: Icons.emoji_events,
    color: Colors.red,
  ),
  BadgeDef(
    id: BadgeId.win3,
    title: '3連勝',
    description: '3連勝を達成した',
    icon: Icons.whatshot,
    color: Colors.lightBlue,
  ),
  BadgeDef(
    id: BadgeId.win5,
    title: '5連勝',
    description: '5連勝を達成した',
    icon: Icons.bolt,
    color: Colors.blue,
  ),
  BadgeDef(
    id: BadgeId.win10,
    title: '10連勝',
    description: '10連勝を達成した',
    icon: Icons.local_fire_department,
    color: Colors.indigo,
  ),
  BadgeDef(
    id: BadgeId.rating700,
    title: '10級到達',
    description: 'レーティング700以上を記録した',
    icon: Icons.star_border,
    color: Colors.teal,
  ),
  BadgeDef(
    id: BadgeId.rating1000,
    title: '3級到達',
    description: 'レーティング1000以上を記録した',
    icon: Icons.star_half,
    color: Colors.cyan,
  ),
  BadgeDef(
    id: BadgeId.rating1200,
    title: '初段到達',
    description: 'レーティング1200以上を記録した',
    icon: Icons.star,
    color: Colors.amberAccent,
  ),
  BadgeDef(
    id: BadgeId.tsume5,
    title: '詰将棋入門',
    description: '詰将棋を5問クリアした',
    icon: Icons.extension,
    color: Colors.purple,
  ),
  BadgeDef(
    id: BadgeId.tsume20,
    title: '詰将棋マスター',
    description: '詰将棋を20問クリアした',
    icon: Icons.psychology,
    color: Colors.deepPurple,
  ),
  BadgeDef(
    id: BadgeId.variantPlay,
    title: '変則将棋デビュー',
    description: '変則将棋を1戦完了した',
    icon: Icons.auto_awesome,
    color: Colors.pink,
  ),
  // ── 対局数（追加） ──────────────────────────────────────────
  BadgeDef(
    id: BadgeId.game200,
    title: '200局達成',
    description: '対局数が200局に達した',
    icon: Icons.workspace_premium,
    color: Colors.deepOrange,
  ),
  BadgeDef(
    id: BadgeId.game500,
    title: '500局達成',
    description: '対局数が500局に達した',
    icon: Icons.diamond,
    color: Colors.red,
  ),
  // ── 連勝（追加） ────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.winStreak7,
    title: '7連勝',
    description: '7連勝を達成した',
    icon: Icons.flash_on,
    color: Colors.deepPurple,
  ),
  // ── 勝率 ────────────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.highWinRate,
    title: '高勝率',
    description: '通算勝率70%以上を達成した（最低30局）',
    icon: Icons.trending_up,
    color: Colors.green,
  ),
  // ── レーティング（追加） ────────────────────────────────────
  BadgeDef(
    id: BadgeId.rating1500,
    title: '有段者',
    description: 'レーティング1500以上を記録した',
    icon: Icons.grade,
    color: Colors.orange,
  ),
  BadgeDef(
    id: BadgeId.rating1800,
    title: '高段者',
    description: 'レーティング1800以上を記録した',
    icon: Icons.stars,
    color: Colors.deepOrange,
  ),
  BadgeDef(
    id: BadgeId.rating2000,
    title: '名人候補',
    description: 'レーティング2000以上を記録した',
    icon: Icons.emoji_events,
    color: Colors.red,
  ),
  // ── 詰将棋（追加） ─────────────────────────────────────────
  BadgeDef(
    id: BadgeId.tsume50,
    title: '詰将棋達人',
    description: '詰将棋を50問クリアした',
    icon: Icons.lightbulb,
    color: Colors.purple,
  ),
  BadgeDef(
    id: BadgeId.tsumeMaster,
    title: '詰将棋完全制覇',
    description: '詰将棋を100問すべてクリアした',
    icon: Icons.military_tech,
    color: Colors.deepPurple,
  ),
  // ── 変則（追加） ────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.variantMaster,
    title: '変則マスター',
    description: '全変則ルールで対局した',
    icon: Icons.shuffle,
    color: Colors.pinkAccent,
  ),
  // ── AI対局 ──────────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.beatMedium,
    title: '中級AI撃破',
    description: '中級AIに初めて勝利した',
    icon: Icons.smart_toy,
    color: Colors.teal,
  ),
  BadgeDef(
    id: BadgeId.beatHard,
    title: '上級AI撃破',
    description: '上級AIに初めて勝利した',
    icon: Icons.computer,
    color: Colors.cyan,
  ),
  BadgeDef(
    id: BadgeId.beatSuperHard,
    title: '最上級AI撃破',
    description: '最上級AIに初めて勝利した',
    icon: Icons.precision_manufacturing,
    color: Colors.blue,
  ),
  BadgeDef(
    id: BadgeId.ai10wins,
    title: 'AI10勝',
    description: 'AIに10勝を達成した',
    icon: Icons.emoji_events,
    color: Colors.lightBlue,
  ),
  BadgeDef(
    id: BadgeId.ai50wins,
    title: 'AI50勝',
    description: 'AIに50勝を達成した',
    icon: Icons.workspace_premium,
    color: Colors.indigo,
  ),
  // ── ネット対局 ──────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.netFirst,
    title: 'ネット対局デビュー',
    description: '初めてネット対局を完了した',
    icon: Icons.wifi,
    color: Colors.green,
  ),
  BadgeDef(
    id: BadgeId.netWin10,
    title: 'ネット10勝',
    description: 'ネット対局で10勝を達成した',
    icon: Icons.public,
    color: Colors.teal,
  ),
  // ── 連続対局 ────────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.consecutive3days,
    title: '3日連続',
    description: '3日連続で対局した',
    icon: Icons.calendar_today,
    color: Colors.lightGreen,
  ),
  BadgeDef(
    id: BadgeId.consecutive7days,
    title: '1週間連続',
    description: '7日連続で対局した',
    icon: Icons.date_range,
    color: Colors.green,
  ),
  BadgeDef(
    id: BadgeId.consecutive30days,
    title: '1ヶ月連続',
    description: '30日連続で対局した',
    icon: Icons.event_available,
    color: Colors.teal,
  ),
  // ── 棋譜研究 ────────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.teachingMode,
    title: '棋譜研究家',
    description: '棋譜を10局以上保存して研究した',
    icon: Icons.menu_book,
    color: Colors.brown,
  ),
  // ── 特殊勝利 ────────────────────────────────────────────────
  BadgeDef(
    id: BadgeId.speedWin,
    title: '電光石火',
    description: '20手以内で勝利した',
    icon: Icons.speed,
    color: Colors.yellow,
  ),
];

BadgeDef badgeById(BadgeId id) => allBadges.firstWhere((b) => b.id == id);

// ── SharedPreferences キー ────────────────────────────────────
const _kUnlocked       = 'badge_unlocked';      // JSON list of badge id names
const _kDates          = 'badge_dates';          // JSON map: id -> date string
const _kWinStreak      = 'badge_win_streak';     // int
const _kLastPlayDate   = 'badge_last_play_date'; // String (yyyy-MM-dd)
const _kStreakDays     = 'badge_streak_days';    // int

// ── バッジサービス ────────────────────────────────────────────
class BadgeService {
  /// 解除済みバッジIDセット（キャッシュなし、毎回 prefs から）
  static Future<Set<BadgeId>> unlockedIds(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_kUnlocked) ?? '[]';
      final list = (jsonDecode(raw) as List).whereType<String>().toList();
      final result = <BadgeId>{};
      for (final s in list) {
        try {
          result.add(BadgeId.values.firstWhere((e) => e.name == s));
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// 解除日マップ
  static Map<BadgeId, String> unlockDates(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kDates) ?? '{}';
      final map = (jsonDecode(raw) as Map);
      final result = <BadgeId, String>{};
      map.forEach((k, v) {
        if (k is! String || v is! String) return;
        try {
          final id = BadgeId.values.firstWhere((e) => e.name == k);
          result[id] = v;
        } catch (_) {}
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// ゲーム終了後に呼ぶ。新たに解除されたバッジリストを返す。
  /// [isWin]         : 今回の対局でヒューマンが勝ったか
  /// [isVariant]     : 変則将棋だったか
  /// [isAiGame]      : AI対局だったか
  /// [aiLevel]       : AIレベル ('easy' / 'medium' / 'hard' / 'super_hard')
  /// [isNetGame]     : ネット対局だったか
  /// [moveCount]     : 今回の対局の手数（勝利時のみ意味を持つ）
  /// [variantTypes]  : 今回使用した変則ルール名リスト（variantMaster チェック用）
  static Future<List<BadgeDef>> check(
    SharedPreferences prefs, {
    required bool isWin,
    required bool isVariant,
    bool isAiGame = false,
    String aiLevel = '',
    bool isNetGame = false,
    int moveCount = 999,
    List<String> variantTypes = const [],
  }) async {
    final unlocked = await unlockedIds(prefs);
    final newlyUnlocked = <BadgeDef>[];

    Future<void> tryUnlock(BadgeId id) async {
      if (!unlocked.contains(id)) {
        unlocked.add(id);
        newlyUnlocked.add(badgeById(id));
      }
    }

    // ── 対局数 ───────────────────────────────────────────────
    final total = prefs.getInt('stats_total') ?? 0;
    if (total >= 1)   await tryUnlock(BadgeId.firstGame);
    if (total >= 10)  await tryUnlock(BadgeId.game10);
    if (total >= 50)  await tryUnlock(BadgeId.game50);
    if (total >= 100) await tryUnlock(BadgeId.game100);
    if (total >= 200) await tryUnlock(BadgeId.game200);
    if (total >= 500) await tryUnlock(BadgeId.game500);

    // ── 連勝 ─────────────────────────────────────────────────
    int streak = prefs.getInt(_kWinStreak) ?? 0;
    if (isWin) {
      streak++;
    } else {
      streak = 0;
    }
    await prefs.setInt(_kWinStreak, streak);
    if (streak >= 3)  await tryUnlock(BadgeId.win3);
    if (streak >= 5)  await tryUnlock(BadgeId.win5);
    if (streak >= 7)  await tryUnlock(BadgeId.winStreak7);
    if (streak >= 10) await tryUnlock(BadgeId.win10);

    // ── 勝率 ─────────────────────────────────────────────────
    if (total >= 30) {
      final totalWins = prefs.getInt('stats_total_wins') ?? 0;
      if (totalWins / total >= 0.70) {
        await tryUnlock(BadgeId.highWinRate);
      }
    }

    // ── レーティング ─────────────────────────────────────────
    final rating = prefs.getInt('rating_current') ?? 700;
    if (rating >= 700)  await tryUnlock(BadgeId.rating700);
    if (rating >= 1000) await tryUnlock(BadgeId.rating1000);
    if (rating >= 1200) await tryUnlock(BadgeId.rating1200);
    if (rating >= 1500) await tryUnlock(BadgeId.rating1500);
    if (rating >= 1800) await tryUnlock(BadgeId.rating1800);
    if (rating >= 2000) await tryUnlock(BadgeId.rating2000);

    // ── 詰将棋 ───────────────────────────────────────────────
    // tsume_screen が tsume_clear_0..N を保存する想定
    // (内蔵37問+外部詰将棋データ最大257問程度まで対応できる範囲でチェック)
    int tsumeCleared = 0;
    for (int i = 0; i < 300; i++) {
      if (prefs.getBool('tsume_clear_$i') == true) tsumeCleared++;
    }
    if (tsumeCleared >= 5)   await tryUnlock(BadgeId.tsume5);
    if (tsumeCleared >= 20)  await tryUnlock(BadgeId.tsume20);
    if (tsumeCleared >= 50)  await tryUnlock(BadgeId.tsume50);
    if (tsumeCleared >= 100) await tryUnlock(BadgeId.tsumeMaster);

    // ── 変則将棋 ─────────────────────────────────────────────
    if (isVariant) await tryUnlock(BadgeId.variantPlay);

    // variantMaster: 全変則ルールで対局済みかチェック
    // stats_variant_* キーを使用 (各ルールで対局するたびにセットされる想定)
    const allVariantRules = ['annan', 'kyoto', 'dobutsu', 'minishogi', 'hasami'];
    final allVariantPlayed = allVariantRules.every(
      (rule) => prefs.getBool('stats_variant_$rule') == true,
    );
    if (allVariantPlayed) await tryUnlock(BadgeId.variantMaster);

    // ── AI対局 ───────────────────────────────────────────────
    if (isAiGame) {
      final aiWins = prefs.getInt('stats_p1_wins_ai') ?? 0;
      if (aiWins >= 10) await tryUnlock(BadgeId.ai10wins);
      if (aiWins >= 50) await tryUnlock(BadgeId.ai50wins);

      if (isWin) {
        // 初勝利系フラグ（未設定なら今回が初勝利）
        if (aiLevel == 'medium' &&
            !(prefs.getBool('badge_beat_medium') ?? false)) {
          await prefs.setBool('badge_beat_medium', true);
          await tryUnlock(BadgeId.beatMedium);
        }
        if (aiLevel == 'hard' &&
            !(prefs.getBool('badge_beat_hard') ?? false)) {
          await prefs.setBool('badge_beat_hard', true);
          await tryUnlock(BadgeId.beatHard);
        }
        if (aiLevel == 'super_hard' &&
            !(prefs.getBool('badge_beat_super_hard') ?? false)) {
          await prefs.setBool('badge_beat_super_hard', true);
          await tryUnlock(BadgeId.beatSuperHard);
        }
      }
    }

    // ── ネット対局 ───────────────────────────────────────────
    if (isNetGame) {
      final totalNet = prefs.getInt('stats_total_net') ?? 0;
      if (totalNet >= 1) await tryUnlock(BadgeId.netFirst);
      final netWins = prefs.getInt('stats_net_wins') ?? 0;
      if (netWins >= 10) await tryUnlock(BadgeId.netWin10);
    }

    // ── 連続対局（デイリーストリーク） ───────────────────────
    final today = DateTime.now().toString().substring(0, 10);
    final lastPlayDate = prefs.getString(_kLastPlayDate) ?? '';
    int dayStreak = prefs.getInt(_kStreakDays) ?? 0;

    if (lastPlayDate == today) {
      // 今日すでに対局済み → ストリーク変化なし
    } else {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toString()
          .substring(0, 10);
      if (lastPlayDate == yesterday) {
        dayStreak++;
      } else {
        dayStreak = 1; // ストリーク途切れ、今日からリスタート
      }
      await prefs.setString(_kLastPlayDate, today);
      await prefs.setInt(_kStreakDays, dayStreak);
    }

    if (dayStreak >= 3)  await tryUnlock(BadgeId.consecutive3days);
    if (dayStreak >= 7)  await tryUnlock(BadgeId.consecutive7days);
    if (dayStreak >= 30) await tryUnlock(BadgeId.consecutive30days);

    // ── 棋譜研究 ─────────────────────────────────────────────
    // kifu_records: 保存棋譜数（JSON list の length）
    final kifuRaw = prefs.getString('kifu_records') ?? '[]';
    int kifuCount = 0;
    try { kifuCount = (jsonDecode(kifuRaw) as List).length; } catch (_) {}
    if (kifuCount >= 10) await tryUnlock(BadgeId.teachingMode);

    // ── 特殊勝利 ─────────────────────────────────────────────
    if (isWin && moveCount <= 20) await tryUnlock(BadgeId.speedWin);

    // ── 保存 ─────────────────────────────────────────────────
    if (newlyUnlocked.isNotEmpty) {
      final now = DateTime.now().toString().substring(0, 10);
      // 解除済みリスト保存
      await prefs.setString(
          _kUnlocked, jsonEncode(unlocked.map((e) => e.name).toList()));
      // 日付マップ更新
      final dates = unlockDates(prefs);
      for (final b in newlyUnlocked) {
        dates[b.id] = now;
      }
      await prefs.setString(
          _kDates, jsonEncode(dates.map((k, v) => MapEntry(k.name, v))));
    }

    return newlyUnlocked;
  }
}
