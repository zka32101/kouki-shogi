// lib/ghost_service.dart
// ゴースト棋士サービス - プレイヤーの棋風ゴーストをアップロード・シミュレーション対戦

import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logic.dart';
import 'ai_personality.dart';
import 'piece.dart';

class GhostPersonalityData {
  final double attackBias;
  final double defenceBias;
  final double greedBias;
  final int depthBonus;
  final String typeName;
  final String description;

  const GhostPersonalityData({
    required this.attackBias,
    required this.defenceBias,
    required this.greedBias,
    required this.depthBonus,
    required this.typeName,
    required this.description,
  });

  factory GhostPersonalityData.fromPlaystyleStats({
    required double attackRatio,
    required double retreatRatio,
    required double dropRatio,
  }) {
    if (attackRatio > 0.45) {
      return const GhostPersonalityData(
        attackBias: 2.0, defenceBias: 0.3, greedBias: 0.8, depthBonus: -1,
        typeName: '超攻撃型',
        description: '守りを顧みない超攻撃的な棋風',
      );
    } else if (attackRatio > 0.38) {
      return const GhostPersonalityData(
        attackBias: 1.5, defenceBias: 0.7, greedBias: 1.0, depthBonus: 0,
        typeName: '攻撃型',
        description: '積極的に攻める攻撃的な棋風',
      );
    } else if (retreatRatio > 0.32) {
      return const GhostPersonalityData(
        attackBias: 0.7, defenceBias: 1.8, greedBias: 1.1, depthBonus: 1,
        typeName: '守備型',
        description: '堅陣を築く守備的な棋風',
      );
    } else if (dropRatio > 0.22) {
      return const GhostPersonalityData(
        attackBias: 1.1, defenceBias: 1.0, greedBias: 1.4, depthBonus: 0,
        typeName: '駒活用型',
        description: '持ち駒を巧みに活用する棋風',
      );
    } else {
      return const GhostPersonalityData(
        attackBias: 1.0, defenceBias: 1.0, greedBias: 1.0, depthBonus: 0,
        typeName: 'バランス型',
        description: '攻守バランスの取れた棋風',
      );
    }
  }

  AiPersonality toAiPersonality() => AiPersonality(
    attackBias: attackBias,
    defenceBias: defenceBias,
    greedBias: greedBias,
    depthBonus: depthBonus,
    dialogues: const <DialogueTrigger, List<String>>{},
  );

  Map<String, dynamic> toMap() => {
    'attackBias': attackBias,
    'defenceBias': defenceBias,
    'greedBias': greedBias,
    'depthBonus': depthBonus,
    'typeName': typeName,
    'description': description,
  };

  static GhostPersonalityData fromMap(Map<String, dynamic> map) =>
      GhostPersonalityData(
        attackBias: (map['attackBias'] as num?)?.toDouble() ?? 1.0,
        defenceBias: (map['defenceBias'] as num?)?.toDouble() ?? 1.0,
        greedBias: (map['greedBias'] as num?)?.toDouble() ?? 1.0,
        depthBonus: (map['depthBonus'] as int?) ?? 0,
        typeName: map['typeName'] as String? ?? 'バランス型',
        description: map['description'] as String? ?? '',
      );
}

class GhostOpponent {
  final String uid;
  final String displayName;
  final GhostPersonalityData personality;
  final int wins;
  final int losses;

  GhostOpponent({
    required this.uid,
    required this.displayName,
    required this.personality,
    required this.wins,
    required this.losses,
  });

  static GhostOpponent? fromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return GhostOpponent(
        uid: doc.id,
        displayName: data['displayName'] as String? ?? '名無し棋士',
        personality: GhostPersonalityData.fromMap(
          (data['personality'] as Map<String, dynamic>?) ?? {},
        ),
        wins: data['wins'] as int? ?? 0,
        losses: data['losses'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class GhostService {
  static const _col = 'ghosts';
  static const _todayWinsKey = 'ghost_today_wins';
  static const _todayLossesKey = 'ghost_today_losses';
  static const _todayDateKey = 'ghost_today_date';
  static const _lastBattleKey = 'ghost_last_battle';

  /// プレイヤーのゴーストをFirestoreにアップロード（対局後に呼ぶ）
  /// 返り値: 成功時true、失敗時false
  static Future<bool> updateMyGhost() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getInt('playstyle_games') ?? 0;
      if (games < 5) return false;

      final total = (prefs.getInt('playstyle_total') ?? 0);
      if (total == 0) return false;
      final attack = prefs.getInt('playstyle_attack') ?? 0;
      final retreat = prefs.getInt('playstyle_retreat') ?? 0;
      final drop = prefs.getInt('playstyle_drop') ?? 0;

      final pers = GhostPersonalityData.fromPlaystyleStats(
        attackRatio: attack / total,
        retreatRatio: retreat / total,
        dropRatio: drop / total,
      );

      String displayName = 'ゴースト棋士';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          displayName =
              userDoc.data()?['username'] as String? ?? 'ゴースト棋士';
        }
      } catch (_) {}

      await FirebaseFirestore.instance.collection(_col).doc(uid).set({
        'uid': uid,
        'displayName': displayName,
        'personality': pers.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ランダムな対戦相手を取得（自分以外、最大3件）
  /// 返り値: null = ネットワークエラー、[] = 対戦相手不在、[opponents...] = 成功
  static Future<List<GhostOpponent>?> fetchOpponents() async {
    try {
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final snap = await FirebaseFirestore.instance
          .collection(_col)
          .limit(20)
          .get();

      final others = snap.docs
          .where((d) => d.id != myUid)
          .map(GhostOpponent.fromDoc)
          .whereType<GhostOpponent>()
          .toList();

      others.shuffle(Random());
      return others.take(3).toList();
    } catch (_) {
      return null;
    }
  }

  /// AI vs AI バトルシミュレーション（depth=1、max 120手）
  /// 返り値: true = myGhost(P1) 勝利
  static Future<bool> simulateBattle(
    GhostPersonalityData myPers,
    GhostPersonalityData oppPers,
  ) async {
    return Future(() {
      var board = GL.initialBoard();
      var p1h = <PieceType, int>{};
      var p2h = <PieceType, int>{};
      bool p1Turn = true;
      const maxMoves = 120;

      for (int i = 0; i < maxMoves; i++) {
        final pers = p1Turn ? myPers : oppPers;
        AI.setPersonality(pers.toAiPersonality(), aiIsP1: p1Turn);
        final mv = AI.bestMove(board, p1h, p2h, p1Turn, 1);
        if (mv == null) {
          // 合法手なし → 手番側が負け
          AI.setPersonality(null);
          return !p1Turn; // 相手が負け = 自分(P1)の勝ち
        }
        final next = AI.apply(board, p1h, p2h, mv, p1Turn);
        board = next.b;
        p1h = next.p1h;
        p2h = next.p2h;
        p1Turn = !p1Turn;
      }

      // 最大手数に達した場合はランダムに決定
      AI.setPersonality(null);
      return Random().nextBool();
    });
  }

  /// バトル結果を SharedPrefs + Firestore に記録
  /// 返り値: 成功時true、失敗時false（SharedPrefsは常に記録、Firestoreのみ失敗可能）
  static Future<bool> recordResult({
    required String oppUid,
    required String oppName,
    required bool myWon,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      if ((prefs.getString(_todayDateKey) ?? '') != todayStr) {
        await prefs.setString(_todayDateKey, todayStr);
        await prefs.setInt(_todayWinsKey, 0);
        await prefs.setInt(_todayLossesKey, 0);
      }

      if (myWon) {
        await prefs.setInt(
            _todayWinsKey, (prefs.getInt(_todayWinsKey) ?? 0) + 1);
      } else {
        await prefs.setInt(
            _todayLossesKey, (prefs.getInt(_todayLossesKey) ?? 0) + 1);
      }
      await prefs.setString(
          _lastBattleKey, '$oppName:${myWon ? 'win' : 'loss'}');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection(_col).doc(uid).update({
          myWon ? 'wins' : 'losses': FieldValue.increment(1),
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 今日の戦績を取得
  static Future<({int wins, int losses, String lastBattle})>
      getTodayRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      if ((prefs.getString(_todayDateKey) ?? '') != todayStr) {
        return (wins: 0, losses: 0, lastBattle: '');
      }
      return (
        wins: prefs.getInt(_todayWinsKey) ?? 0,
        losses: prefs.getInt(_todayLossesKey) ?? 0,
        lastBattle: prefs.getString(_lastBattleKey) ?? '',
      );
    } catch (_) {
      return (wins: 0, losses: 0, lastBattle: '');
    }
  }
}
