'use strict';
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

// YaneuraOu 将棋エンジン
const YaneuraOu = require('@mizarjp/yaneuraou.halfkp');
let engine = null;

// エンジン初期化（遅延ロード）
async function getEngine() {
  if (engine) return engine;
  engine = new YaneuraOu();
  await engine.isReady();
  return engine;
}

// ── ELO計算 ─────────────────────────────────────────────────────
function calcElo(winnerRating, loserRating, kFactor = 32) {
  const expected = 1 / (1 + Math.pow(10, (loserRating - winnerRating) / 400));
  const winnerDelta = Math.round(kFactor * (1 - expected));
  const loserDelta  = Math.round(kFactor * (0 - (1 - expected)));
  return { winnerDelta, loserDelta };
}

// ── 実績判定（対局終了時）─────────────────────────────────────
// lib/services/network_achievement_service.dart の AchievementId と一致させること
function achievementsForStats({ matches, wins, rating, streak, checkmateWins, resignWins, isWinner }) {
  const ids = [];
  if (matches === 1) ids.push('net_first');
  if (isWinner && wins === 1) ids.push('net_win_1');
  if (isWinner) {
    if (wins === 10)  ids.push('net_win_10');
    if (wins === 50)  ids.push('net_win_50');
    if (wins === 100) ids.push('net_win_100');
    if (wins === 500) ids.push('net_win_500');
  }
  if (matches === 100) ids.push('play_100');
  if (matches === 500) ids.push('play_500');
  if (rating >= 1600) ids.push('rating_1600');
  if (rating >= 1800) ids.push('rating_1800');
  if (rating >= 2000) ids.push('rating_2000');
  if (rating >= 2200) ids.push('rating_2200');
  if (rating >= 2500) ids.push('rating_2500');
  if (streak >= 3)  ids.push('streak_3');
  if (streak >= 5)  ids.push('streak_5');
  if (streak >= 10) ids.push('streak_10');
  if (isWinner && checkmateWins === 5) ids.push('win_5_checkmate');
  if (isWinner && resignWins === 5)    ids.push('win_5_resign');
  return ids;
}

// season_service.dart の getCurrentSeason().id と同じ形式（"YYYY-MM"）
function currentSeasonId() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

// ── Trigger 1: 対局終了時 → ELO更新（Firestoreトリガー）────────
exports.onMatchFinished = functions.firestore
  .document('matches/{matchId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // status が 'finished' に変わったときだけ処理
    if (before.status === 'finished' || after.status !== 'finished') return null;
    // 二重実行防止フラグ
    if (after.rating_updated === true) return null;

    const matchId  = context.params.matchId;
    const winnerId = after.winner_id;
    const result   = after.result;
    const p1Id     = after.player1_id;
    const p2Id     = after.player2_id;

    // 引き分けはレーティング変動なし
    if (!winnerId || result === 'draw') {
      await change.after.ref.update({ rating_updated: true });
      return null;
    }

    const loserId = winnerId === p1Id ? p2Id : p1Id;

    try {
      await db.runTransaction(async (tx) => {
        const winnerRef = db.collection('users').doc(winnerId);
        const loserRef  = db.collection('users').doc(loserId);
        const [winnerDoc, loserDoc] = await Promise.all([
          tx.get(winnerRef),
          tx.get(loserRef),
        ]);

        if (!winnerDoc.exists || !loserDoc.exists) return;

        const winnerData = winnerDoc.data();
        const loserData  = loserDoc.data();
        const winnerRating = winnerData.rating || 700;
        const loserRating  = loserData.rating  || 700;
        const { winnerDelta, loserDelta } = calcElo(winnerRating, loserRating);

        // 実績判定用: このトランザクションで確定する新しい値
        const winnerNewWins   = (winnerData.wins || 0) + 1;
        const winnerNewLosses = winnerData.losses || 0;
        const winnerNewStreak = (winnerData.win_streak || 0) + 1;
        const winnerNewCheckmateWins =
          (winnerData.checkmate_wins || 0) + (result === 'checkmate' ? 1 : 0);
        const winnerNewResignWins =
          (winnerData.resign_wins || 0) + (result === 'resignation' ? 1 : 0);

        const loserNewLosses = (loserData.losses || 0) + 1;
        const loserNewWins   = loserData.wins || 0;

        const winnerAchievements = achievementsForStats({
          matches: winnerNewWins + winnerNewLosses,
          wins: winnerNewWins,
          rating: winnerRating + winnerDelta,
          streak: winnerNewStreak,
          checkmateWins: winnerNewCheckmateWins,
          resignWins: winnerNewResignWins,
          isWinner: true,
        });
        const loserAchievements = achievementsForStats({
          matches: loserNewWins + loserNewLosses,
          wins: loserNewWins,
          rating: loserRating + loserDelta,
          streak: 0,
          checkmateWins: 0,
          resignWins: 0,
          isWinner: false,
        });

        // シーズン参加中（season_rating 初期化済み・今シーズン内）のみ
        // season_rating/season_wins/season_losses もあわせて更新する
        const seasonId = currentSeasonId();
        const winnerInSeason =
          winnerData.season_id === seasonId &&
          typeof winnerData.season_rating === 'number';
        const loserInSeason =
          loserData.season_id === seasonId &&
          typeof loserData.season_rating === 'number';

        tx.update(winnerRef, {
          rating: admin.firestore.FieldValue.increment(winnerDelta),
          wins:   admin.firestore.FieldValue.increment(1),
          win_streak: winnerNewStreak,
          ...(result === 'checkmate'   ? { checkmate_wins: admin.firestore.FieldValue.increment(1) } : {}),
          ...(result === 'resignation' ? { resign_wins: admin.firestore.FieldValue.increment(1) } : {}),
          ...(winnerAchievements.length
            ? { achievements: admin.firestore.FieldValue.arrayUnion(...winnerAchievements) }
            : {}),
          ...(winnerInSeason
            ? {
                season_rating: admin.firestore.FieldValue.increment(winnerDelta),
                season_wins:   admin.firestore.FieldValue.increment(1),
              }
            : {}),
        });
        tx.update(loserRef, {
          rating:  admin.firestore.FieldValue.increment(loserDelta),
          losses:  admin.firestore.FieldValue.increment(1),
          win_streak: 0,
          ...(loserAchievements.length
            ? { achievements: admin.firestore.FieldValue.arrayUnion(...loserAchievements) }
            : {}),
          ...(loserInSeason
            ? {
                season_rating: admin.firestore.FieldValue.increment(loserDelta),
                season_losses: admin.firestore.FieldValue.increment(1),
              }
            : {}),
        });
        tx.update(change.after.ref, {
          rating_updated:      true,
          winner_rating_delta: winnerDelta,
          loser_rating_delta:  loserDelta,
        });
      });
    } catch (e) {
      console.error(`ELO update failed for match ${matchId}:`, e);
    }

    // RTDB のゲームデータを削除（対局終了後は不要）
    try {
      await rtdb.ref(`games/${matchId}`).remove();
    } catch (_) {}

    return null;
  });

// ── HTTP API: ユーザー統計取得 ──────────────────────────────
exports.getUserStatistics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  try {
    const usersSnap = await db.collection('users').get();

    // レーティング帯別に集計
    const distribution = {
      '0-499': 0,      // 初心者
      '500-599': 0,    // 級位下
      '600-699': 0,    // 級位中
      '700-799': 0,    // 級位上
      '800-899': 0,    // 段位下
      '900-999': 0,    // 段位中
      '1000+': 0,      // 段位上
    };

    let totalRating = 0;
    let totalUsers = 0;
    let maxRating = 0;
    let minRating = 10000;

    usersSnap.forEach((doc) => {
      const user = doc.data();
      const rating = user.rating || 700;

      totalRating += rating;
      totalUsers += 1;
      maxRating = Math.max(maxRating, rating);
      minRating = Math.min(minRating, rating);

      // 分布に追加
      if (rating < 500) distribution['0-499']++;
      else if (rating < 600) distribution['500-599']++;
      else if (rating < 700) distribution['600-699']++;
      else if (rating < 800) distribution['700-799']++;
      else if (rating < 900) distribution['800-899']++;
      else if (rating < 1000) distribution['900-999']++;
      else distribution['1000+']++;
    });

    const avgRating = totalUsers > 0 ? Math.round(totalRating / totalUsers) : 0;

    return {
      success: true,
      distribution,
      totalUsers,
      avgRating,
      maxRating: maxRating === 10000 ? 700 : maxRating,
      minRating: minRating === 10000 ? 700 : minRating,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (e) {
    console.error('getUserStatistics failed:', e);
    throw new functions.https.HttpsError('internal', '統計取得に失敗しました');
  }
});

// ── HTTP API: 手筋評価（Yoneura/YaneuraOu） ──────────────────
exports.evaluateTesuji = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  const { sfen, depth = 20 } = data;
  if (!sfen) {
    throw new functions.https.HttpsError('invalid-argument', 'sfen が必要です');
  }

  try {
    const eng = await getEngine();

    // 盤面をセット
    eng.position(sfen);

    // 評価を実行（depth手先まで）
    const result = await new Promise((resolve, reject) => {
      const info = {};
      eng.go({ depth }, (line) => {
        // USI エンジンの info 行をパース
        if (line.startsWith('info')) {
          const match = line.match(/score cp (-?\d+)/);
          if (match) info.score = parseInt(match[1]);

          const moveMatch = line.match(/pv (.+?)(?:\s|$)/);
          if (moveMatch) info.bestMove = moveMatch[1];
        }
        // bestmove 行で終了
        if (line.startsWith('bestmove')) {
          const parts = line.split(' ');
          resolve({
            bestMove: parts[1],
            score: info.score || 0,
          });
        }
      });
    });

    // スコアから勝率を推定（ロジスティック関数）
    const winRate = Math.round(
      (1 / (1 + Math.exp(-result.score / 200))) * 100
    );

    return {
      success: true,
      bestMove: result.bestMove,
      score: result.score,
      winRate: winRate,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (e) {
    console.error('evaluateTesuji failed:', e);
    throw new functions.https.HttpsError('internal', '評価に失敗しました');
  }
});

// ── HTTP API: 敗北分析（対局全体の評価値推移 + 敗着特定） ──────
exports.analyzeDefeat = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  const { sfen, kifu, playerColor, depth = 15 } = data;

  // 入力検証
  if (!sfen || typeof sfen !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'sfen (string) が必要です');
  }
  if (!kifu || !Array.isArray(kifu)) {
    throw new functions.https.HttpsError('invalid-argument', 'kifu (array) が必要です');
  }
  if (kifu.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'kifu が空です');
  }
  if (!playerColor || !['p1', 'p2'].includes(playerColor)) {
    throw new functions.https.HttpsError('invalid-argument', 'playerColor は "p1" または "p2" である必要があります');
  }

  try {
    const eng = await getEngine();

    // 初期盤面から出発
    eng.position('startpos');
    const evaluations = [0]; // 初期盤面の評価値は 0

    // ===== フェーズ 1: 対局全体の評価値推移を復元 =====
    // playerColor の手番を判定（p1=偶数(0,2,4), p2=奇数(1,3,5)）
    const loserIsEven = playerColor === 'p1';

    for (let i = 0; i < kifu.length; i++) {
      const moveNotation = kifu[i];

      try {
        // 手を実行
        eng.move(moveNotation);

        // 現在の盤面を評価（軽量評価: depth=10で高速化）
        const evalResult = await evaluatePosition(eng, Math.min(depth, 10));

        // 評価値を保存
        // 評価値は常に先手(black)視点で表現
        // i=0,2,4... は先手の手、i=1,3,5... は後手の手
        // 後手の手後の評価値を記録する際は、後手視点から見た評価値に変換
        const eval_score = (i % 2 === 0) ? evalResult.score : -evalResult.score;
        evaluations.push(eval_score);
      } catch (moveErr) {
        console.warn(`Failed to process move ${i}: ${moveNotation}`, moveErr);
        throw new functions.https.HttpsError('invalid-argument', `棋譜の${i}手目が無効です: ${moveNotation}`);
      }
    }

    // ===== フェーズ 2: 敗着（キー手）の自動検出 =====
    let keyMoveIndex = -1;
    let maxEvalDrop = 0;

    // 敗者の手のインデックスを抽出
    for (let i = loserIsEven ? 0 : 1; i < kifu.length; i += 2) {
      if (i === 0) continue; // 初手前の評価値がないため

      // i が敗者の手である場合、その手による局面悪化を検出
      const prevEval = evaluations[i]; // 敗者の手の直前の評価値
      const postEval = evaluations[i + 1]; // 敗者の手直後の評価値

      if (prevEval === undefined || postEval === undefined) continue;

      // 敗者にとって悪化した度合い（敗者がp1なら負の方向、p2なら正の方向に注目）
      // 統一的に：敗者の視点から見て「prevEval → postEval で悪化」を計算
      const evalDrop = loserIsEven ? (prevEval - postEval) : (postEval - prevEval);

      if (evalDrop > maxEvalDrop) {
        maxEvalDrop = evalDrop;
        keyMoveIndex = i;
      }
    }

    // keyMoveIndex が見つからない場合は最後の敗者の手を使用
    if (keyMoveIndex === -1) {
      for (let i = loserIsEven ? 0 : 1; i < kifu.length; i += 2) {
        keyMoveIndex = i;
      }
    }

    // keyMoveIndex が still -1 の場合は安全な初期値
    if (keyMoveIndex === -1) {
      keyMoveIndex = Math.max(0, kifu.length - 2);
    }

    // ===== フェーズ 3: 敗着での詳細評価（最善手の提案） =====
    let bestMoveAtKey = null;
    let bestMoveEval = 0;
    let actualMoveAtKey = null;
    let actualMoveEval = 0;
    let evaluationDiff = 0;

    if (keyMoveIndex >= 0 && keyMoveIndex < kifu.length) {
      try {
        // キー手の直前までの局面を再構築
        eng.position('startpos');
        for (let i = 0; i < keyMoveIndex; i++) {
          eng.move(kifu[i]);
        }

        // 最善手を詳細評価（depth=20）
        const keyEvalResult = await evaluatePosition(eng, Math.min(20, depth + 5));
        bestMoveAtKey = keyEvalResult.bestMove;
        bestMoveEval = keyEvalResult.score;

        // 実際の手の評価値
        actualMoveAtKey = kifu[keyMoveIndex];

        // keyMoveIndex の直後の評価値を取得
        if (keyMoveIndex + 1 < evaluations.length) {
          actualMoveEval = evaluations[keyMoveIndex + 1];
        } else {
          // キー手が最後の手の場合
          actualMoveEval = evaluations[keyMoveIndex] || 0;
        }

        // 評価値差を計算（敗者の視点で統一）
        if (loserIsEven) {
          // 敗者がp1（先手視点）：最善手の評価値 - 実際の手の評価値
          evaluationDiff = bestMoveEval - actualMoveEval;
        } else {
          // 敗者がp2（後手視点）：評価値は反転しているので逆
          evaluationDiff = actualMoveEval - bestMoveEval;
        }
      } catch (keyErr) {
        console.warn(`Failed to analyze key move at index ${keyMoveIndex}`, keyErr);
      }
    }

    // ===== フェーズ 4: ターニングポイント検出 =====
    let turningPointMove = keyMoveIndex; // デフォルトは敗着
    let fromEqualAtMove = 0;

    // 互角の定義：評価値が [-50, 50] の範囲
    for (let i = 0; i < evaluations.length; i++) {
      if (Math.abs(evaluations[i]) <= 50) {
        fromEqualAtMove = i;
      }
    }

    // 敗勢への転換点を検出（評価値が一気に悪化）
    for (let i = fromEqualAtMove + 1; i < evaluations.length; i++) {
      if (Math.abs(evaluations[i]) > 200) {
        turningPointMove = i - 1;
        break;
      }
    }

    // ===== フェーズ 5: アドバイスメッセージ生成 =====
    let advice = '敗北の分析';
    if (bestMoveAtKey && actualMoveAtKey && bestMoveAtKey !== actualMoveAtKey && Math.abs(evaluationDiff) > 50) {
      const evalDiffAbs = Math.abs(evaluationDiff);
      const prefix = loserIsEven ? '▲' : '△';

      if (evalDiffAbs > 300) {
        advice = `${prefix}${bestMoveAtKey}なら大きく有利を保てました（評価値差: ${Math.abs(evaluationDiff)}）。`;
      } else if (evalDiffAbs > 150) {
        advice = `${prefix}${bestMoveAtKey}ならもっと有利を保てました。`;
      } else {
        advice = `${prefix}${bestMoveAtKey}なら互角を保てました。`;
      }
    } else if (bestMoveAtKey === actualMoveAtKey && bestMoveAtKey) {
      advice = 'この手は最善手でした。';
    } else if (fromEqualAtMove > 0) {
      advice = `${fromEqualAtMove}手目まで互角でしたが、その後の展開で敗れました。`;
    }

    return {
      success: true,
      moveCount: kifu.length,
      evaluations: evaluations,
      keyMoveIndex: keyMoveIndex >= 0 ? keyMoveIndex : 0,
      bestMoveAtKey: bestMoveAtKey,
      actualMoveAtKey: actualMoveAtKey,
      evaluationDiff: evaluationDiff,
      turning_point_move: turningPointMove,
      from_equal_at_move: fromEqualAtMove,
      advice: advice,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (e) {
    console.error('analyzeDefeat failed:', e);
    throw new functions.https.HttpsError('internal', '敗北分析に失敗しました');
  }
});

/**
 * 盤面を指定のdepthで評価する
 * @param {Object} eng - YaneuraOu エンジンインスタンス
 * @param {number} depth - 探索深さ
 * @returns {Promise<{score: number, bestMove: string}>}
 */
async function evaluatePosition(eng, depth) {
  return new Promise((resolve, reject) => {
    let resolved = false;
    const info = {};

    try {
      eng.go({ depth }, (line) => {
        // USI エンジンの info 行をパース
        if (line.startsWith('info')) {
          const match = line.match(/score cp (-?\d+)/);
          if (match) info.score = parseInt(match[1]);

          const moveMatch = line.match(/pv (.+?)(?:\s|$)/);
          if (moveMatch) info.bestMove = moveMatch[1];
        }
        // bestmove 行で終了
        if (line.startsWith('bestmove')) {
          if (resolved) return;
          resolved = true;

          const parts = line.split(' ');
          resolve({
            bestMove: parts[1] || info.bestMove || 'unknown',
            score: info.score || 0,
          });
        }
      });

      // タイムアウト対策（20秒で強制終了）
      const timeoutHandle = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          console.warn(`Evaluation timeout after 20s with depth ${depth}`);
          reject(new Error(`Evaluation timeout (depth=${depth})`));
        }
      }, 20000);

      // 既に resolve済みの場合はタイムアウトをキャンセル
      const originalResolve = resolve;
      resolve = (value) => {
        clearTimeout(timeoutHandle);
        originalResolve(value);
      };
    } catch (err) {
      reject(err);
    }
  });
}

// ── Schedule 1: マッチメイキング（毎3秒）──────────────────────
exports.matchmaking = functions.pubsub
  .schedule('every 3 seconds')
  .onRun(async (_ctx) => {
    try {
      const queueSnap = await db.collection('matching_queue')
        .where('status', '==', 'waiting')
        .orderBy('created_at', 'asc')
        .limit(100)
        .get();

      if (queueSnap.size < 2) return null;

      const players = queueSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      const matched = [];

      for (let i = 0; i < players.length - 1; i++) {
        if (matched.includes(players[i].id)) continue;
        const p1 = players[i];

        // 同じレーティング帯のプレイヤーを探索（±200範囲）
        for (let j = i + 1; j < players.length; j++) {
          if (matched.includes(players[j].id)) continue;
          const p2 = players[j];
          const ratingDiff = Math.abs((p1.rating || 700) - (p2.rating || 700));

          if (ratingDiff <= 200) {
            // マッチング成立 → matches に新規作成
            const matchRef = db.collection('matches').doc();
            await db.runTransaction(async (tx) => {
              tx.set(matchRef, {
                player1_id:  p1.id,
                player2_id:  p2.id,
                status:      'matched',
                created_at:  admin.firestore.FieldValue.serverTimestamp(),
                handicap:    null,
              });
              tx.update(db.collection('matching_queue').doc(p1.id), {
                status: 'matched',
                match_id: matchRef.id,
              });
              tx.update(db.collection('matching_queue').doc(p2.id), {
                status: 'matched',
                match_id: matchRef.id,
              });
            });
            matched.push(p1.id, p2.id);
            break;
          }
        }
      }

      console.log(`Matched ${matched.length / 2} pairs from ${players.length} waiting players`);
    } catch (e) {
      console.error('matchmaking failed:', e);
    }
    return null;
  });

// ── Schedule 2: タイムアウト検知（毎分）────────────────────────
exports.checkTimeouts = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (_ctx) => {
    const now = Date.now();

    let gamesSnap;
    try {
      gamesSnap = await rtdb.ref('games')
        .orderByChild('status')
        .equalTo('active')
        .once('value');
    } catch (e) {
      console.error('checkTimeouts: RTDB read failed', e);
      return null;
    }

    if (!gamesSnap.exists()) return null;

    const rtdbUpdates = {};
    const firestoreJobs = [];

    gamesSnap.forEach((child) => {
      const game    = child.val();
      const matchId = child.key;
      if (!game || !game.clock) return;

      const { p1_ms, p2_ms, last_tick_ms, last_turn } = game.clock;
      const elapsed = now - (last_tick_ms || now);

      let timedOutSide = null; // 'p1' | 'p2' (負けた側)
      if (last_turn === 1 && p1_ms - elapsed <= 0) timedOutSide = 'p1';
      else if (last_turn === 2 && p2_ms - elapsed <= 0) timedOutSide = 'p2';

      if (!timedOutSide) return;

      const winnerId = timedOutSide === 'p1'
        ? game.player2_id
        : game.player1_id;

      rtdbUpdates[`games/${matchId}/status`]   = 'finished';
      rtdbUpdates[`games/${matchId}/result`]   = 'timeout';
      rtdbUpdates[`games/${matchId}/winner_id`] = winnerId || null;

      firestoreJobs.push(
        db.collection('matches').doc(matchId).update({
          status:      'finished',
          result:      'timeout',
          winner_id:   winnerId || null,
          finished_at: admin.firestore.FieldValue.serverTimestamp(),
        }).catch((e) => console.error(`Firestore update failed for ${matchId}:`, e))
      );
    });

    if (Object.keys(rtdbUpdates).length > 0) {
      await rtdb.ref().update(rtdbUpdates).catch(console.error);
      await Promise.all(firestoreJobs);
    }

    return null;
  });

// ── Schedule 3: 古いエントリのクリーンアップ（毎5分）────────────
exports.cleanupStale = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (_ctx) => {
    const nowSec = Math.floor(Date.now() / 1000);
    const cutoff = new admin.firestore.Timestamp(nowSec - 600, 0); // 10分前

    // Firestore: 待機中のマッチングキューを期限切れに
    try {
      const staleSnap = await db.collection('matching_queue')
        .where('status', '==', 'waiting')
        .where('created_at', '<', cutoff)
        .limit(100)
        .get();

      if (!staleSnap.empty) {
        const batch = db.batch();
        staleSnap.docs.forEach((doc) => batch.update(doc.ref, { status: 'expired' }));
        await batch.commit();
        console.log(`Expired ${staleSnap.size} stale queue entries`);
      }
    } catch (e) {
      console.error('cleanupStale: queue cleanup failed', e);
    }

    // RTDB: 30分間動きのない active ゲームを abandoned に
    const rtdbCutoff = Date.now() - 30 * 60 * 1000;
    try {
      const abandonedSnap = await rtdb.ref('games')
        .orderByChild('status')
        .equalTo('active')
        .once('value');

      if (!abandonedSnap.exists()) return null;

      const updates = {};
      abandonedSnap.forEach((child) => {
        const game         = child.val();
        const lastActivity = game.last_activity_ms || 0;
        if (lastActivity < rtdbCutoff) {
          updates[`games/${child.key}/status`] = 'abandoned';
        }
      });

      if (Object.keys(updates).length > 0) {
        await rtdb.ref().update(updates);
        console.log(`Abandoned ${Object.keys(updates).length} stale games`);
      }
    } catch (e) {
      console.error('cleanupStale: RTDB cleanup failed', e);
    }

    return null;
  });

// ── Schedule 4: デイリー問題生成（毎日 20:00 JST）──────────────
exports.generateDailyProblems = functions.pubsub
  .schedule('0 11 * * *')  // 20:00 JST = 11:00 UTC
  .timeZone('UTC')
  .onRun(async (_ctx) => {
    try {
      const today = new Date().toISOString().split('T')[0];
      const bucket = admin.storage().bucket();

      // 既に今日の問題が生成済みの場合はスキップ
      const alreadyExists = await bucket.file(`problems/${today}.json`).exists();
      if (alreadyExists[0]) {
        console.log(`Problems already generated for ${today}`);
        return null;
      }

      // SFEN プールからランダムに 5個を選択（簡易版）
      const sfenPool = _getSfenPool();
      const problems = [];
      const usedIndices = new Set();

      // ランダムに 5問を生成
      for (let i = 0; i < 5; i++) {
        let randomIdx;
        do {
          randomIdx = Math.floor(Math.random() * sfenPool.length);
        } while (usedIndices.has(randomIdx));
        usedIndices.add(randomIdx);

        const sfen = sfenPool[randomIdx];
        const problem = _generateProblem(sfen, i + 1, today);
        if (problem) {
          problems.push(problem);
        }
      }

      if (problems.length === 0) {
        console.error('Failed to generate any problems');
        return null;
      }

      // Cloud Storage に JSON を保存
      const jsonStr = JSON.stringify(problems, null, 2);
      await bucket.file(`problems/${today}.json`).save(jsonStr, {
        contentType: 'application/json',
        metadata: {
          cacheControl: 'public, max-age=86400',
        },
      });

      // Firestore にメタデータを記録
      await db.collection('daily_problems').doc(today).set({
        problemIds: problems.map((p) => p.id),
        count: problems.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'auto-generated',
      });

      console.log(`Generated ${problems.length} problems for ${today}`);
      return null;
    } catch (e) {
      console.error('generateDailyProblems failed:', e);
      throw e;
    }
  });

/**
 * SFEN プール（手筋・詰将棋の基本的な 100+ 局面）
 * 実運用では bookminer や棋力検定からの抽出 SFEN を使用
 */
function _getSfenPool() {
  // 基本的な詰将棋・手筋 SFEN（簡易版）
  return [
    // 3手詰（初級）
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
    'ln1gkgsnl/1r6b/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b P 1',

    // 飛車取り
    '7k1/6r2/8p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL b - 1',
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/3P5/PPP1PPPPP/1B5R1/LNSGKGSNL w - 1',

    // 王手金取り
    'lnsgkgsnl/1r5b1/ppppppppp/9/2P6/9/PP1PPPPPP/1B5R1/LNSGKGSNL w - 1',
    '7k1/6r2/4g3p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',

    // 両取り
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/3B5/PPPPPPPPP/1R6R/LNSGKGSNL b - 1',
    '8k/6r2/4n3p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',

    // 駒が取れる
    '6nk1/6r2/4r3p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',
    'ln1gkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',

    // 詰将棋パターン
    '8k/7P1/8K/9/9/9/9/9/9 b - 1',
    '8k/6P1/8K/9/9/9/9/9/9 b - 1',
    '6n1k/6r2/8p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',

    // 基本詰め
    '6nk1/6r2/8p/5P1P/9/8K/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',
    '8k/6r2/9/5P1P/9/8K/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',
  ];
}

/**
 * SFEN から問題を生成（簡易版）
 * 本番では problem_generator.dart をポートした TypeScript 版を使用
 */
function _generateProblem(sfen, index, dateStr) {
  try {
    // 簡易的な難度判定（SFEN の長さで仮判定）
    const difficulty = sfen.length < 50 ? '初級' : sfen.length < 70 ? '中級' : '上級';

    return {
      id: `daily_${dateStr}_${index}`,
      title: `${difficulty} 詰将棋 ${index}`,
      category: '詰め',
      difficulty,
      board: sfen,
      p1_hand: {},
      p2_hand: {},
      p1_turn: true,
      answer: {
        fr: 0,
        fc: 0,
        tr: 1,
        tc: 1,
        drop: null,
        promote: false,
      },
      explanation: `詰将棋問題です。${difficulty}の難易度でお試しください。`,
      source_url: null,
      source_title: 'Auto-generated',
    };
  } catch (e) {
    console.error(`Failed to generate problem for SFEN: ${sfen}`, e);
    return null;
  }
}

// ── AI 解説 (Claude API) ──────────────────────────────────────────

async function callClaude(systemPrompt, userMessage) {
  const apiKey = functions.config().anthropic && functions.config().anthropic.key;
  if (!apiKey) {
    throw new Error('Anthropic API key not configured. Run: firebase functions:config:set anthropic.key=YOUR_KEY');
  }

  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 512,
      system: systemPrompt,
      messages: [{ role: 'user', content: userMessage }],
    });

    const req = https.request(
      {
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
          'x-api-key': apiKey,
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            if (parsed.error) {
              reject(new Error(parsed.error.message));
            } else {
              resolve(parsed.content[0].text);
            }
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

exports.explainPosition = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  const { boardJson, question } = data;
  if (!question || typeof question !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'question が必要です');
  }

  const system = `あなたは将棋の専門家AIコーチです。初心者から上級者まで分かりやすく、簡潔に日本語で回答してください。
回答は3〜5行以内にまとめ、具体的な手の候補がある場合は▲（先手）または△（後手）の符号で示してください。`;

  const userMsg = boardJson
    ? `現在の盤面（JSON）: ${boardJson}\n\n質問: ${question}`
    : `質問: ${question}`;

  try {
    const answer = await callClaude(system, userMsg);
    return { answer };
  } catch (e) {
    console.error('explainPosition error:', e);
    throw new functions.https.HttpsError('internal', `AI解説エラー: ${e.message}`);
  }
});

exports.generateCoachFeedback = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  const { gameResult, playStyle } = data;

  const system = `あなたは将棋の熱心なコーチです。対局後のプレイヤーへのフィードバックを、励ましと具体的な改善点を交えて日本語で伝えてください。
フィードバックは5〜8行程度にまとめてください。`;

  const userMsg = `対局結果: ${gameResult || '不明'}\n棋風: ${playStyle || '一般的'}`;

  try {
    const feedback = await callClaude(system, userMsg);
    return { feedback };
  } catch (e) {
    console.error('generateCoachFeedback error:', e);
    throw new functions.https.HttpsError('internal', `AIコーチエラー: ${e.message}`);
  }
});
