// lib/services/character_bond_service.dart
// キャラクター絆管理システム

import 'package:shared_preferences/shared_preferences.dart';

class CharacterBondService {
  static const String _winsKeyPrefix = 'character_wins_';

  /// キャラクターの勝利数を取得
  static Future<int> getWins(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_winsKeyPrefix$characterId') ?? 0;
  }

  /// キャラクターの勝利数を追加
  static Future<void> addWin(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentWins = await getWins(characterId);
    await prefs.setInt('$_winsKeyPrefix$characterId', currentWins + 1);
  }

  /// 絆レベルを計算（3段階）
  /// Lv0: 0勝（未解放）
  /// Lv1: 1勝（解放済み）
  /// Lv2: 3勝以上（絆完成）
  static Future<BondLevel> getBondLevel(String characterId) async {
    final wins = await getWins(characterId);

    if (wins == 0) {
      return BondLevel.unlocked;
    } else if (wins >= 3) {
      return BondLevel.complete;
    } else {
      return BondLevel.released;
    }
  }

  /// 初勝利かどうかを判定
  static Future<bool> isFirstWin(String characterId) async {
    final wins = await getWins(characterId);
    return wins == 0;
  }

  /// 全キャラの絆情報をリセット（テスト用）
  static Future<void> resetAllBonds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_winsKeyPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// 絆統計を取得（ボーナス計算用）
  static Future<BondStatistics> getBondStatistics() async {
    final characterIds = [
      'speed',
      'guard',
      'balance',
      'ryuou',
      'tengu',
      'shogun',
      'sennin',
      'oni',
      'doshim',
    ];

    int totalWins = 0;
    int completedBonds = 0;
    int releasedBonds = 0;

    for (final id in characterIds) {
      final wins = await getWins(id);
      totalWins += wins;

      if (wins >= 3) {
        completedBonds++;
      } else if (wins >= 1) {
        releasedBonds++;
      }
    }

    return BondStatistics(
      totalWins: totalWins,
      completedBonds: completedBonds,
      releasedBonds: releasedBonds,
      unlockedBonds: characterIds.length - releasedBonds - completedBonds,
    );
  }
}

enum BondLevel {
  unlocked,   // 未解放（0勝）
  released,   // 解放済み（1-2勝）
  complete,   // 絆完成（3勝以上）
}

class BondStatistics {
  final int totalWins;          // 総勝数
  final int completedBonds;     // 絆完成数
  final int releasedBonds;      // 解放済み数
  final int unlockedBonds;      // 未解放数

  BondStatistics({
    required this.totalWins,
    required this.completedBonds,
    required this.releasedBonds,
    required this.unlockedBonds,
  });

  /// エンディング条件：全棋霊の絆レベル3以上
  bool get canUnlockCoexistenceEnding => completedBonds == 9;
}
