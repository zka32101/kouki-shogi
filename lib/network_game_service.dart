// lib/network_game_service.dart — Firebase Realtime DB を使ったネットワーク対局
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'piece.dart';
import 'logic.dart';
import 'services/board_sync_service.dart';

/// Firebase Realtime DB 構造:
/// /rooms/{6桁コード}/
///   status: 'waiting' | 'playing' | 'ended'
///   createdAt: timestamp
///   moves/
///     {pushKey}/
///       fr, fc, tr, tc: int  (-1 = 打ち駒)
///       promote: bool
///       drop: int? (PieceType.index)
///       isP1: bool
///       ts: timestamp
///   result: 'p1win' | 'p2win' | 'draw' | null
///   resignedBy: 'p1' | 'p2' | null
///
/// /matchmaking/{pushKey}/
///   status: 'waiting' | 'matched'
///   roomCode: null | string
///   userId: string
///   createdAt: timestamp
class NetworkGameService {
  NetworkGameService._();

  /// Firebase が正常に初期化されているか
  static bool _firebaseReady = false;
  static void setFirebaseReady() => _firebaseReady = true;
  static bool get firebaseReady => _firebaseReady;

  static String? _roomCode;
  static String? _matchId;
  static bool _isHost = false;
  static bool _isSpectator = false;
  static bool _hostIsP1 = true;
  static StreamSubscription? _moveSub;
  static StreamSubscription? _statusSub;
  static StreamSubscription? _reactionSub;
  static int _lastMoveCount = 0;

  // ストリーム（相手の指し手 / 状態変化 / 絵文字リアクション）
  static final _moveCtrl   = StreamController<AMove>.broadcast();
  static final _statusCtrl = StreamController<NetworkStatus>.broadcast();
  static final _emojiCtrl  = StreamController<ReceivedEmoji>.broadcast();

  static Stream<AMove>          get moveStream   => _moveCtrl.stream;
  static Stream<NetworkStatus>  get statusStream => _statusCtrl.stream;
  static Stream<ReceivedEmoji>  get emojiStream  => _emojiCtrl.stream;

  // マッチング用
  static StreamSubscription?     _matchWatchSub;
  static String?                 _myMatchKey;
  static Completer<MatchResult>? _activeCompleter; // キャンセル用
  static Timer?                  _rescanTimer; // ホスト待機中の再スキャン用

  static String? get roomCode     => _roomCode;
  static bool    get isHost       => _isHost;
  static bool    get isSpectator  => _isSpectator;
  static bool    get hostIsP1     => _hostIsP1;

  // ─── ランダムマッチング ──────────────────────────────────────────────────────
  /// 不特定多数との対戦マッチング
  /// [myRating] 自分の現在レーティング（強さフィルタに使用）
  /// [strengthPref] 'weak' | 'any' | 'strong'
  /// 戻り値: MatchResult（roomCode + isHost）
  /// 60秒以内にマッチしない場合 TimeoutException
  static Future<MatchResult> startMatchmaking({
    int myRating = 1000,
    String strengthPref = 'any',
    bool rated = true,
    int timeLimitSec = 600,
  }) async {
    if (!_firebaseReady) throw Exception('Firebase未設定');
    cancelMatchmaking();

    // Completer を先に登録（auth中でもキャンセル可能にするため）
    final completer = Completer<MatchResult>();
    _activeCompleter = completer;

    // 匿名認証（5秒タイムアウト付き、失敗してもランダムIDで続行）
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously()
            .timeout(const Duration(seconds: 5));
        print('[MATCH] 匿名認証完了: ${FirebaseAuth.instance.currentUser?.uid}');
      } on TimeoutException {
        print('[MATCH] 匿名認証タイムアウト（ランダムIDで続行）');
      } catch (e) {
        print('[MATCH] 匿名認証失敗（ランダムIDで続行）: $e');
      }
    }
    if (completer.isCompleted) return completer.future;

    final myId  = _generateUserId();
    final mqRef = FirebaseDatabase.instance.ref('matchmaking');

    // ── Step1: 自分のエントリを追加 ───────────────────────────────────────
    final myRef = mqRef.push();
    _myMatchKey = myRef.key!;
    print('[MATCH] 参加 myKey=$_myMatchKey uid=$myId');

    try {
      await myRef.set({
        'userId':       myId,
        'status':       'open',
        'rating':       myRating,
        'strengthPref': strengthPref,
        'timeLimitSec': timeLimitSec,
        'createdAt':    ServerValue.timestamp,
      });
      print('[MATCH] RTDBエントリ作成完了 key=$_myMatchKey');
    } catch (e) {
      print('[MATCH] RTDBエントリ作成失敗: $e');
      if (!completer.isCompleted) {
        completer.completeError(Exception('RTDB接続エラー: $e'));
      }
      return completer.future;
    }
    if (completer.isCompleted) return completer.future;

    // ── Step2: 少し待ってから全エントリを一度読む ─────────────────────────
    await Future.delayed(const Duration(milliseconds: 800));
    if (completer.isCompleted) return completer.future;

    // ホスト候補をスキャンする（[ignorePref]=true で強さフィルタを無視した緩和スキャン）
    Future<(String?, int?)> scanForHost({bool ignorePref = false}) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      String? foundKey;
      int? foundRating;
      try {
        final snap = await mqRef.get();
        if (!snap.exists) return (null, null);
        final myKey = _myMatchKey;
        if (myKey == null) return (null, null);
        final all = Map<String, dynamic>.from(snap.value as Map);
        for (final kv in all.entries) {
          final key = kv.key as String;
          if (key == myKey) continue;
          // 自分より先に来た人（キーが小さい = 先着）のみ対象
          if (key.compareTo(myKey) >= 0) continue;
          final d = Map<String, dynamic>.from(kv.value as Map);
          if (d['status'] != 'open') continue;
          // 古すぎるエントリは無視してクリーンアップ（120秒以上前）
          final createdAt = (d['createdAt'] as num?)?.toInt() ?? 0;
          if (createdAt > 0 && nowMs - createdAt > 120000) {
            mqRef.child(key).remove().catchError((_) {});
            print('[MATCH] 古いエントリ削除: $key');
            continue;
          }
          // 持ち時間が一致しないと対局が成立しないため、これは常に必須のフィルタ
          // （強さフィルタと違い、待機時間が延びても緩和しない）
          final hostTimeLimit = (d['timeLimitSec'] as num?)?.toInt() ?? 600;
          if (hostTimeLimit != timeLimitSec) continue;
          // 強さフィルタ（緩和スキャン時はスキップ）
          final r = (d['rating'] as num?)?.toInt() ?? 1000;
          if (!ignorePref) {
            if (strengthPref == 'weak'   && r > myRating + 50) continue;
            if (strengthPref == 'strong' && r < myRating - 50) continue;
          }
          // 最も古いホスト（最小キー）を選ぶ
          if (foundKey == null || key.compareTo(foundKey!) < 0) {
            foundKey = key;
            foundRating = r;
          }
        }
      } catch (e) {
        print('[MATCH] スキャンエラー: $e');
      }
      return (foundKey, foundRating);
    }

    // 見つかったホストのゲストとして参加する
    Future<void> becomeGuest(String hostKey, int? hostRating) async {
      print('[MATCH] GUEST → ホスト=$hostKey');
      _rescanTimer?.cancel();
      _rescanTimer = null;

      // 自分のエントリは不要なので削除
      myRef.remove().catchError((_) {});
      _myMatchKey = null;

      // ホストのエントリに「参加通知」
      await mqRef.child(hostKey).update({
        'status':      'matched',
        'guestId':     myId,
        'guestRating': myRating,
      });

      // ホストがマッチを作成してmatchId(=roomCode)を書くのを待つ
      _matchWatchSub?.cancel();
      _matchWatchSub = mqRef.child(hostKey).onValue.listen((event) async {
        if (completer.isCompleted) return;
        final data = event.snapshot.value as Map?;
        if (data == null) return;
        final matchId = data['roomCode'] as String?;
        if (matchId == null || matchId.isEmpty) return;

        print('[MATCH] GUEST完了: matchId=$matchId');
        _matchWatchSub?.cancel();
        _isHost   = false;
        _matchId  = matchId;
        _roomCode = matchId;

        // Firestoreのplayer2_idをゲストの実際のFirebase UIDで上書き
        try {
          await FirebaseFirestore.instance
              .collection('matches').doc(matchId)
              .update({'player2_id': myId});
        } catch (_) {}

        // ホストのエントリを削除
        mqRef.child(hostKey).remove().catchError((_) {});

        if (!completer.isCompleted) {
          completer.complete(MatchResult(
            matchId:        matchId,
            isPlayer1:      false,
            myPlayerId:     myId,
            opponentRating: hostRating,
          ));
        }
      });
    }

    final (foundHostKey, foundHostRating) = await scanForHost();
    if (completer.isCompleted) return completer.future;

    if (foundHostKey != null) {
      // ══ ゲストとして参加 ════════════════════════════════════════════════
      await becomeGuest(foundHostKey, foundHostRating);
    } else {
      // ══ ホストとして待機 ════════════════════════════════════════════════
      print('[MATCH] HOST 待機中 myKey=$_myMatchKey');
      _isHost = true;
      bool _roomCreating = false;

      // 待機中も定期的に再スキャンし、初回スキャン後に現れた／強さフィルタで
      // 見送っていたホストがいれば見つけ次第ゲストとして合流する。
      // 序盤は元の強さ設定を維持し、20秒経過後はフィルタを無視して緩和する
      // （将棋クエスト等の「見つからなければ徐々に範囲を広げる」挙動に近づける）。
      var rescanElapsedSec = 0;
      _rescanTimer = Timer.periodic(const Duration(seconds: 7), (timer) async {
        if (completer.isCompleted || _roomCreating) {
          timer.cancel();
          return;
        }
        rescanElapsedSec += 7;
        final (rescanKey, rescanRating) =
            await scanForHost(ignorePref: rescanElapsedSec >= 20);
        if (completer.isCompleted || _roomCreating) {
          timer.cancel();
          return;
        }
        if (rescanKey != null) {
          timer.cancel();
          _isHost = false;
          await becomeGuest(rescanKey, rescanRating);
        }
      });

      _matchWatchSub = myRef.onValue.listen((event) async {
        if (completer.isCompleted || _roomCreating) return;
        final data = event.snapshot.value as Map?;
        if (data == null) return;
        if (data['status'] != 'matched') return;

        _roomCreating = true;
        _matchWatchSub?.cancel();
        _rescanTimer?.cancel();
        _rescanTimer = null;
        print('[MATCH] HOST: ゲスト参加確認 → マッチ作成');

        try {
          final hostUid  = myId;
          final guestUid = data['guestId'] as String? ?? 'guest_${Random().nextInt(9999)}';
          final guestRating = (data['guestRating'] as num?)?.toInt();

          // RTDBにgames/{matchId}を作成（matchIdはRTDBのpushKeyで生成）
          final gamesRef = FirebaseDatabase.instance.ref('games');
          final gameEntry = gamesRef.push();
          final matchId   = gameEntry.key!;

          final boardSync = BoardSyncService();
          await boardSync.initMatchBoard(
            matchId,
            board:        GL.initialBoard(),
            player1Id:    hostUid,
            player2Id:    guestUid,
            timeLimitSec: timeLimitSec,
          );

          // Firestoreにmatches documentを作成（オプション: 認証エラー時はスキップ）
          try {
            await FirebaseFirestore.instance.collection('matches').doc(matchId).set({
              'id':           matchId,
              'player1_id':   hostUid,
              'player2_id':   guestUid,
              'player1_name': 'プレイヤー1',
              'player2_name': 'プレイヤー2',
              'player1_time': timeLimitSec,
              'player2_time': timeLimitSec,
              'status':       'playing',
              'result':       null,
              'winner_id':    null,
              'created_at':   FieldValue.serverTimestamp(),
            });
          } catch (fe) {
            print('[MATCH] HOST: Firestore作成スキップ（RTDBのみで続行）: $fe');
          }

          _matchId  = matchId;
          _roomCode = matchId;
          print('[MATCH] HOST: matchId=$matchId');

          // ゲストにmatchIdをroomCodeとして通知
          await myRef.update({'roomCode': matchId, 'status': 'playing'});

          // エントリ削除（ゲストが読んだ後）
          await Future.delayed(const Duration(seconds: 3));
          myRef.remove().catchError((_) {});

          if (!completer.isCompleted) {
            completer.complete(MatchResult(
              matchId:        matchId,
              isPlayer1:      true,
              myPlayerId:     hostUid,
              opponentRating: guestRating,
            ));
          }
        } catch (e) {
          print('[MATCH] HOST: マッチ作成失敗 $e');
          try {
            await myRef.update({
              'status':      'open',
              'guestId':     null,
              'guestRating': null,
            });
          } catch (_) {}
          _roomCreating = false;
          if (!completer.isCompleted) {
            completer.completeError(Exception('マッチ作成失敗: $e'));
          }
        }
      });
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        cancelMatchmaking();
        throw TimeoutException('マッチングタイムアウト', const Duration(seconds: 60));
      },
    );
  }

  /// マッチングをキャンセル（UIをブロックしない同期的キャンセル）
  static void cancelMatchmaking() {
    print('[CLEANUP] マッチングキャンセル');

    // Active completer を即時エラーで完了させる（startMatchmaking のawaitを解放）
    final c = _activeCompleter;
    _activeCompleter = null;
    if (c != null && !c.isCompleted) {
      c.completeError(const MatchCancelledException());
    }

    _matchWatchSub?.cancel();
    _matchWatchSub = null;
    _rescanTimer?.cancel();
    _rescanTimer = null;

    // Firebase削除はfire-and-forget（UIをブロックしない）
    final keyToDelete = _myMatchKey;
    _myMatchKey = null;
    if (keyToDelete != null) {
      FirebaseDatabase.instance
          .ref('matchmaking/$keyToDelete')
          .remove()
          .catchError((_) {});
    }
    if (_isHost && _roomCode != null) {
      FirebaseDatabase.instance
          .ref('rooms/$_roomCode')
          .remove()
          .catchError((_) {});
    }
    _roomCode = null;
  }

  // ルームだけを内部作成（dispose を呼ばない版）
  static Future<String> _createRoomInternal() async {
    _lastMoveCount = 0;
    final code = await _uniqueCode();
    await FirebaseDatabase.instance.ref('rooms/$code').set({
      'status':    'playing', // マッチング済みなので即 playing
      'createdAt': ServerValue.timestamp,
    });
    _roomCode = code;
    return code;
  }

  // Firebase Anonymous Auth UID（fallback: ランダム文字列）
  static String _generateUserId() {
    return FirebaseAuth.instance.currentUser?.uid ??
        List.generate(16, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  }

  // ─── ルーム作成（先後はランダム決定）────────────────────────────────────────
  static Future<String> createRoom() async {
    if (!_firebaseReady) {
      throw Exception('Firebase が設定されていません。\nfirebase_options.dart の設定を確認してください。');
    }
    dispose(); // 既存セッションをクリア
    _hostIsP1 = Random().nextBool(); // ランダムで先後決定
    _isHost = true;
    _lastMoveCount = 0;
    final code = await _uniqueCode();
    await FirebaseDatabase.instance.ref('rooms/$code').set({
      'status':    'waiting',
      'createdAt': ServerValue.timestamp,
      'hostIsP1':  _hostIsP1,
    });
    _roomCode = code;
    _subscribeRoom(code);
    return code;
  }

  // ─── ルーム参加（ゲスト）──────────────────────────────────────────────────
  static Future<JoinResult> joinRoom(String code) async {
    if (!_firebaseReady) return JoinResult.error;
    dispose();
    _isHost = false;
    _lastMoveCount = 0;
    final code6 = code.trim();
    final ref  = FirebaseDatabase.instance.ref('rooms/$code6');
    try {
      final snap = await ref.get();
      if (!snap.exists) return JoinResult.notFound;
      final data = snap.value as Map?;
      if (data == null) return JoinResult.notFound;
      final status = data['status'] as String?;
      if (status == 'playing' || status == 'ended') return JoinResult.full;
      // ホストの先後を取得して、ゲストは逆
      _hostIsP1 = (data['hostIsP1'] as bool?) ?? true;
    } catch (_) {
      return JoinResult.error;
    }
    try {
      await ref.update({'status': 'playing'});
    } catch (_) {
      return JoinResult.error;
    }
    _roomCode = code6;
    _subscribeRoom(code6);
    return JoinResult.ok;
  }

  // ─── 観戦参加 ──────────────────────────────────────────────────────────────
  static Future<JoinResult> joinAsSpectator(String code) async {
    if (!_firebaseReady) return JoinResult.error;
    dispose();
    _isHost = false;
    _isSpectator = true;
    _lastMoveCount = 0;
    final code6 = code.trim();
    final ref = FirebaseDatabase.instance.ref('rooms/$code6');
    try {
      final snap = await ref.get();
      if (!snap.exists) return JoinResult.notFound;
      final data = snap.value as Map?;
      if (data == null) return JoinResult.notFound;
      final status = data['status'] as String?;
      if (status == 'ended') return JoinResult.full; // ended = 終了済み
    } catch (_) {
      return JoinResult.error;
    }
    _roomCode = code6;
    _subscribeRoom(code6);
    return JoinResult.ok;
  }

  // ─── 絵文字リアクション送信 ────────────────────────────────────────────────
  static Future<void> sendEmoji(String emoji, {required bool isP1}) async {
    if (!_firebaseReady || _roomCode == null) return;
    await FirebaseDatabase.instance
        .ref('rooms/$_roomCode/reactions')
        .push()
        .set({'emoji': emoji, 'isP1': isP1, 'ts': ServerValue.timestamp});
  }

  // ─── 指し手送信 ─────────────────────────────────────────────────────────────
  static Future<void> sendMove(AMove mv, {required bool isP1}) async {
    if (_roomCode == null) return;
    await FirebaseDatabase.instance
        .ref('rooms/$_roomCode/moves')
        .push()
        .set(_encodeMove(mv, isP1: isP1));
  }

  // ─── 投了 ─────────────────────────────────────────────────────────────────
  static Future<void> resign({required bool isP1}) async {
    if (_roomCode == null) return;
    await FirebaseDatabase.instance.ref('rooms/$_roomCode').update({
      'status':     'ended',
      'result':     isP1 ? 'p2win' : 'p1win',
      'resignedBy': isP1 ? 'p1' : 'p2',
    });
  }

  // ─── アクティブな対局一覧取得 ─────────────────────────────────────────────
  /// 現在プレイ中のルーム一覧を取得（最大20件）
  static Future<List<Map<String, dynamic>>> getActiveRooms() async {
    if (!_firebaseReady) return [];
    try {
      final snap = await FirebaseDatabase.instance
          .ref('rooms')
          .limitToLast(20)
          .get();
      if (!snap.exists) return [];
      final data = snap.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      final rooms = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        final v = value as Map<dynamic, dynamic>?;
        if (v != null && v['status'] == 'playing') {
          final moveCount = (v['moves'] as Map?)?.length ?? 0;
          rooms.add({
            'code': key as String,
            'moveCount': moveCount,
            'createdAt': v['createdAt'] ?? 0,
          });
        }
      });
      // 作成日時降順でソート
      rooms.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
      return rooms;
    } catch (_) {
      return [];
    }
  }

  // ─── 解放 ─────────────────────────────────────────────────────────────────
  static void dispose() {
    _moveSub?.cancel();
    _statusSub?.cancel();
    _reactionSub?.cancel();
    _matchWatchSub?.cancel();
    _moveSub = null;
    _statusSub = null;
    _reactionSub = null;
    _matchWatchSub = null;
    // ルームを削除（ホストのみ）
    if (_isHost && _roomCode != null) {
      FirebaseDatabase.instance.ref('rooms/$_roomCode').remove().catchError((_) {});
      print('[CLEANUP] dispose: ルーム削除 $_roomCode');
    }
    _myMatchKey = null;
    _roomCode = null;
    _lastMoveCount = 0;
    _isSpectator = false;
    _hostIsP1 = true;
    _isHost = false;
  }

  // ─── 内部: ルーム購読 ────────────────────────────────────────────────────
  static void _subscribeRoom(String code) {
    final ref = FirebaseDatabase.instance.ref('rooms/$code');

    // ステータス変化
    _statusSub = ref.onValue.listen((event) {
      if (!event.snapshot.exists) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final status = data['status'] as String?;
      switch (status) {
        case 'playing':
          _statusCtrl.add(NetworkStatus.playing);
        case 'ended':
          final resignedBy = data['resignedBy'] as String?;
          final result     = data['result'] as String?;
          if (resignedBy != null) {
            // 相手が投了
            final opponentResigned =
                (_isHost && resignedBy == 'p2') ||
                (!_isHost && resignedBy == 'p1');
            if (opponentResigned) {
              _statusCtrl.add(NetworkStatus.opponentResigned);
            }
          } else if (result != null) {
            _statusCtrl.add(NetworkStatus.ended);
          }
          // 対局終了後、ルームを削除（ホストのみ）
          Future.delayed(const Duration(seconds: 2), () async {
            if (_isHost && _roomCode != null) {
              try {
                await FirebaseDatabase.instance.ref('rooms/$_roomCode').remove();
                print('[CLEANUP] 対局終了後、ルーム削除: $_roomCode');
              } catch (e) {
                print('[CLEANUP] ルーム削除失敗: $e');
              }
            }
          });
        case 'waiting':
          break;
      }
    });

    // 絵文字リアクション（onChildAdded で新着のみ受信）
    _reactionSub = ref.child('reactions').onChildAdded.listen((event) {
      if (!event.snapshot.exists) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final emoji = data['emoji'] as String?;
      final isP1  = data['isP1'] as bool? ?? true;
      if (emoji == null) return;
      // 対局モード: 自分が送ったリアクションはスキップ
      if (!_isSpectator) {
        final isMine = (_isHost && isP1) || (!_isHost && !isP1);
        if (isMine) return;
      }
      _emojiCtrl.add(ReceivedEmoji(emoji: emoji, isP1: isP1));
    });

    // 指し手リスト
    _moveSub = ref.child('moves').onValue.listen((event) {
      if (!event.snapshot.exists) return;
      final raw = event.snapshot.value;
      final moves = _extractMoves(raw);
      for (int i = _lastMoveCount; i < moves.length; i++) {
        final m      = moves[i];
        final isP1   = m['isP1'] as bool? ?? true;
        // 観戦モード: すべての手を転送。対局モード: 自分の手はスキップ
        if (!_isSpectator) {
          final isMine = (_isHost && isP1) || (!_isHost && !isP1);
          if (isMine) continue;
        }
        final mv = _decodeMove(m);
        if (mv != null) _moveCtrl.add(mv);
      }
      _lastMoveCount = moves.length;
    });
  }

  // ─── 内部: moves を List<Map> に正規化 ──────────────────────────────────
  static List<Map> _extractMoves(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.whereType<Map>().toList();
    }
    if (raw is Map) {
      final keys = raw.keys.toList()
        ..sort((a, b) {
          // Firebase push key は時系列順
          return a.toString().compareTo(b.toString());
        });
      return keys.map((k) => raw[k]).whereType<Map>().toList();
    }
    return [];
  }

  // ─── 内部: AMove ↔ Map ──────────────────────────────────────────────────
  static Map<String, dynamic> _encodeMove(AMove mv, {required bool isP1}) => {
    'fr':      mv.fr,
    'fc':      mv.fc,
    'tr':      mv.tr,
    'tc':      mv.tc,
    'promote': mv.promote,
    'drop':    mv.drop?.index,
    'isP1':    isP1,
    'ts':      ServerValue.timestamp,
  };

  static AMove? _decodeMove(Map m) {
    try {
      final fr      = (m['fr'] as num).toInt();
      final fc      = (m['fc'] as num).toInt();
      final tr      = (m['tr'] as num).toInt();
      final tc      = (m['tc'] as num).toInt();
      final promote = m['promote'] as bool? ?? false;
      final dropIdx = m['drop'];
      final drop    = dropIdx != null
          ? PieceType.values[(dropIdx as num).toInt()]
          : null;
      return AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: promote, drop: drop);
    } catch (_) {
      return null;
    }
  }

  // ─── 内部: 重複しないコード生成 ──────────────────────────────────────────
  static Future<String> _uniqueCode() async {
    final rng = Random.secure();
    for (int i = 0; i < 5; i++) {
      final code = List.generate(6, (_) => rng.nextInt(10).toString()).join();
      final snap = await FirebaseDatabase.instance.ref('rooms/$code').get();
      if (!snap.exists) return code;
    }
    return List.generate(6, (_) => rng.nextInt(10).toString()).join();
  }
}

enum NetworkStatus { playing, opponentResigned, ended }

enum JoinResult { ok, notFound, full, error }

class MatchResult {
  final String matchId;
  final bool   isPlayer1;  // true=先手  false=後手
  final String myPlayerId; // 自分のプレイヤーID（勝敗判定用）
  final int?   opponentRating; // マッチング時点の相手レーティング（対局後のレーティング計算用）
  const MatchResult({
    required this.matchId,
    required this.isPlayer1,
    required this.myPlayerId,
    this.opponentRating,
  });
}

class ReceivedEmoji {
  final String emoji;
  final bool   isP1;
  const ReceivedEmoji({required this.emoji, required this.isP1});
}

class MatchCancelledException implements Exception {
  const MatchCancelledException();
}
