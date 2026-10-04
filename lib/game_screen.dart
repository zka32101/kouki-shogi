// lib/game_screen.dart — メインゲーム画面（全機能）

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'piece.dart';
import 'logic.dart';
import 'services/ai_isolate.dart';
import 'study_calendar_screen.dart';
import 'cloud_sync_service.dart';
import 'character_icons.dart';
import 'exceptions/app_exception.dart';
import 'ai_personality.dart';
import 'sound_service.dart';
import 'coach_report_screen.dart';
import 'feedback_screen.dart';
import 'ai_data_service.dart';
import 'stats_screen.dart' show ratingToRank, ratingToColor;
import 'rank_badge_widget.dart' show showRankUpDialog;
import 'ghost_service.dart';
import 'widgets/koma_painter.dart';
import 'widgets/board_painter.dart';
import 'purchase_service.dart';
import 'services/character_bond_service.dart';
import 'screens/premium_screen.dart';
import 'weakness_analysis_screen.dart';
import 'tsume_screen.dart';
import 'joseki_screen.dart';
import 'tesuji_screen.dart';
import 'shodan_roadmap_screen.dart';
import 'kifu_history_screen.dart';
import 'kifu_replay_screen.dart';
import 'screens/personal_blunder_quiz_screen.dart';
import 'kansousen_screen.dart';

import 'services/firebase_logging_service.dart';
import 'services/kifu_analytics_service.dart';
import 'models/game_analysis.dart';
import 'defeat_experience_widget.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'defeat_screen.dart';
import 'practice_points_system.dart';
import 'theme/app_theme.dart';
import 'badge_service.dart';
import 'castle_guide_service.dart';

// AppBarオーバーフローメニュー用の行（const で使えるよう独立ウィジェット化）
class _StaticMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StaticMenuRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

// ── コーチモード補助関数 ──────────────────────────────
int _pEvalChange(int before, int after, bool wasP1Turn) =>
    wasP1Turn ? after - before : before - after;

String _coachLabel(int change) {
  if (change >= 150) return '★ 好手！';
  if (change >= 30) return '✓ 良手';
  if (change >= -80) return '';
  if (change >= -200) return '? 疑問手';
  return '✗ 悪手！';
}

Color _coachColor(int change) {
  if (change >= 150) return const Color(0xFF5C9DFF);
  if (change >= 30) return const Color(0xFF64B5F6);
  if (change >= -80) return Colors.white38;
  if (change >= -200) return const Color(0xFFFF9800);
  return const Color(0xFFEF5350);
}

IconData _coachIcon(int change) {
  if (change >= 150) return Icons.star;
  if (change >= 30) return Icons.check_circle_outline;
  if (change >= -80) return Icons.remove;
  if (change >= -200) return Icons.warning_amber_outlined;
  return Icons.cancel_outlined;
}

// ===== 設定 =====
enum GameMode {
  pvp, // ローカル対人対局
  vsAI, // AI対局
  network, // オンライン対局
  spectator, // 観戦
  localNetwork, // ローカルネットワーク対局
}

enum AILevel {
  random,
  easy,
  medium,
  hard,
  beginner,
  elementary,
  upperMedium,
  expert,
}

extension AILevelLabel on AILevel {
  String get rankLabel {
    switch (this) {
      case AILevel.random:
        return 'ランダム';
      case AILevel.beginner:
        return '入門';
      case AILevel.easy:
        return '初級';
      case AILevel.elementary:
        return '初中級';
      case AILevel.medium:
        return '中級';
      case AILevel.upperMedium:
        return '中上級';
      case AILevel.hard:
        return '上級';
      case AILevel.expert:
        return '達人';
    }
  }

  String get rankDesc {
    switch (this) {
      case AILevel.random:
        return 'ランダムな手を指します';
      case AILevel.beginner:
        return '将棋を覚えたての方向け';
      case AILevel.easy:
        return '初心者向けのレベルです';
      case AILevel.elementary:
        return '基本を身につけた方向け';
      case AILevel.medium:
        return '中級者向けのレベルです';
      case AILevel.upperMedium:
        return '段位取得を目指す方向け';
      case AILevel.hard:
        return '上級者向けの高いレベルです';
      case AILevel.expert:
        return '将棋ウォーズ初段以上向け';
    }
  }

  // UIに表示する難度数字（0〜8）
  int get stars {
    switch (this) {
      case AILevel.random:
        return 0;
      case AILevel.beginner:
        return 1;
      case AILevel.easy:
        return 2;
      case AILevel.elementary:
        return 3;
      case AILevel.medium:
        return 4;
      case AILevel.upperMedium:
        return 5;
      case AILevel.hard:
        return 6;
      case AILevel.expert:
        return 8;
    }
  }
}

/// レーティングからAIレベルを自動決定する
AILevel autoAiLevelFromRating(int rating) {
  if (rating >= 1600) return AILevel.expert;
  if (rating >= 1300) return AILevel.hard;
  if (rating >= 1050) return AILevel.upperMedium;
  if (rating >= 820)  return AILevel.medium;
  if (rating >= 650)  return AILevel.elementary;
  if (rating >= 450)  return AILevel.easy;
  if (rating >= 200)  return AILevel.beginner;
  return AILevel.random;
}

enum VariantType {
  normal, // 標準的な将棋
  captureForced, // 取る一手（駒を取れば取らなければならない）
  checkForced, // 王手将棋（王手できれば王手しなければならない）
  hiddenPieces, // かくし将棋（相手の駒が見えない）
  kagemusha, // 影武者（相手の王が見えない）
  invader, // インベーダー将棋
}

extension VariantTypeLabel on VariantType {
  String get label {
    switch (this) {
      case VariantType.normal:
        return '標準';
      case VariantType.captureForced:
        return '取る一手';
      case VariantType.checkForced:
        return '王手将棋';
      case VariantType.hiddenPieces:
        return 'かくし将棋';
      case VariantType.kagemusha:
        return '影武者';
      case VariantType.invader:
        return 'インベーダー';
    }
  }
}

enum PieceTheme {
  standard, // 標準
  dark, // ダーク
  textured, // 質感（プレミアム）
  emerald, // エメラルド（プレミアム）
  cherry, // 桜（プレミアム）
}

enum PieceLabelStyle {
  kanji, // 漢字（標準）
  english, // 英字 (K/G/S/N/L/B/R/P)
}

String pieceLabelEn(PieceType t, bool isP1) {
  switch (t) {
    case PieceType.king:
      return isP1 ? 'K' : 'k';
    case PieceType.rook:
      return 'R';
    case PieceType.bishop:
      return 'B';
    case PieceType.gold:
      return 'G';
    case PieceType.silver:
      return 'S';
    case PieceType.knight:
      return 'N';
    case PieceType.lance:
      return 'L';
    case PieceType.pawn:
      return 'P';
    case PieceType.promotedRook:
      return '+R';
    case PieceType.promotedBishop:
      return '+B';
    case PieceType.promotedSilver:
      return '+S';
    case PieceType.promotedKnight:
      return '+N';
    case PieceType.promotedLance:
      return '+L';
    case PieceType.promotedPawn:
      return '+P';
  }
}

/// 駒落ちハンデ（後手 = 上手 の駒を減らす）
enum Handicap {
  none, // 平手
  lance, // 香落ち（左香）
  bishop, // 角落ち
  rook, // 飛車落ち
  rookBishop, // 飛角落ち
  four, // 四枚落ち（飛・角・両香）
  six, // 六枚落ち（飛・角・両香・両桂）
  eight, // 八枚落ち（飛・角・両香・両桂・両銀）
}

extension HandicapLabel on Handicap {
  String get label {
    switch (this) {
      case Handicap.none:
        return '平手';
      case Handicap.lance:
        return '香落ち';
      case Handicap.bishop:
        return '角落ち';
      case Handicap.rook:
        return '飛車落ち';
      case Handicap.rookBishop:
        return '飛角落ち';
      case Handicap.four:
        return '四枚落ち';
      case Handicap.six:
        return '六枚落ち';
      case Handicap.eight:
        return '八枚落ち';
    }
  }
}

class GameSettings {
  final GameMode mode;
  final AILevel aiLevel;
  final bool aiIsP2; // AI が後手か
  final int? timeLimitSec; // null=制限なし
  final int? byoyomiSec; // 秒読み（null=なし）
  final int fischerIncrementSec; // フィッシャー加算（0=なし）
  final PieceTheme theme;
  final PieceLabelStyle labelStyle;
  final Handicap handicap;
  final VariantType variant;
  final bool aiRated;
  final bool castleGuideEnabled;
  final String castleGuideName;
  final int castleGuideMaxPly;
  final bool networkIsHost; // ネットワーク対局でホストか
  final bool networkRated; // ネットワーク対局でレーティング戦か
  final bool coachMode; // コーチモード（指導対局）
  final String? opponentCharacterId; // AIの棋風キャラID（null=デフォルト）

  const GameSettings({
    this.mode = GameMode.pvp,
    this.aiLevel = AILevel.easy,
    this.aiIsP2 = true,
    this.timeLimitSec,
    this.byoyomiSec,
    this.fischerIncrementSec = 0,
    this.theme = PieceTheme.standard,
    this.labelStyle = PieceLabelStyle.kanji,
    this.handicap = Handicap.none,
    this.variant = VariantType.normal,
    this.aiRated = true,
    this.castleGuideEnabled = false,
    this.castleGuideName = 'mino',
    this.castleGuideMaxPly = 30,
    this.networkIsHost = false,
    this.networkRated = true,
    this.coachMode = false,
    this.opponentCharacterId,
  });

  int get aiDepth {
    switch (aiLevel) {
      case AILevel.random:
        return 0;
      case AILevel.beginner:
        return 1;
      case AILevel.easy:
        return 2;
      case AILevel.elementary:
        return 3;
      case AILevel.medium:
        return 4;
      case AILevel.upperMedium:
        return 5;
      case AILevel.hard:
        return 6;
      case AILevel.expert:
        return 8;
    }
  }
}

// ===== 棋譜表記補助 =====
const _rowKanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
String _sq(int r, int c) => '${9 - c}${_rowKanji[r]}';

// ===== ミッション定義 =====
class _MissionDef {
  final String id;
  final String label;
  final String icon;
  bool completed;
  _MissionDef({required this.id, required this.label, required this.icon})
    : completed = false;
}

// ===== GameScreen =====
class GameScreen extends StatefulWidget {
  final GameSettings settings;
  // カスタム初期配置（局面エディタから渡す場合に使用）
  final List<List<Piece?>>? initialBoard;
  final Map<PieceType, int>? initialP1Hand;
  final Map<PieceType, int>? initialP2Hand;
  final bool initialP1Turn;

  const GameScreen({
    super.key,
    required this.settings,
    this.initialBoard,
    this.initialP1Hand,
    this.initialP2Hand,
    this.initialP1Turn = true,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // --- 盤面状態 ---
  late List<List<Piece?>> board;
  Map<PieceType, int> p1Hand = {}, p2Hand = {};
  bool p1Turn = true;
  String? result;

  // --- 選択 ---
  int? selR, selC;
  PieceType? selHand;
  var hl = _eHL();

  // --- 棋譜 ---
  List<KifuMove> kifu = [];

  // --- タイマー ---
  Timer? _timer;
  // 終局ダイアログで一定時間操作がなければ棋譜振り返り画面へ自動遷移
  Timer? _postGameAutoNavTimer;
  int p1Time = 0, p2Time = 0;
  // 秒読み（byoyomi）
  bool _p1InByoyomi = false;
  bool _p2InByoyomi = false;
  int _p1ByoyomiRemaining = 0;
  int _p2ByoyomiRemaining = 0;

  // --- UI ---
  bool showKifu = false;
  bool _aiThinking = false;
  int _aiElapsedSec = 0;
  Timer? _aiElapsedTimer;

  final _boardRepaintKey = GlobalKey();
  bool showAttackMap = false;
  List<List<int>>? _p1AtkMap, _p2AtkMap; // 効きマップキャッシュ（絶対：先手/後手）
  bool _analysisMode = false; // 局面分析モード
  AMove? _hintMove; // ヒント手
  int? lastFR, lastFC, lastTR, lastTC;

  // --- 評価値バー ---
  int _evalScore = 0; // 正=先手有利 負=後手有利
  final List<int> _evalHistory = []; // 手ごとの評価値履歴

  // --- 戦型 ---
  String _openingLabel = ''; // 戦型ラベル

  // --- コーチモード ---
  final List<List<List<Piece?>>> _boardSnaps = [];
  final List<Map<PieceType, int>> _p1HandSnaps = [];
  final List<Map<PieceType, int>> _p2HandSnaps = [];
  final List<bool> _p1TurnSnaps = [];
  List<List<Piece?>>? _coachInitialBoard; // 対局開始時盤面（講評用）
  String? _coachBadgeText;
  Color _coachBadgeColor = Colors.white38;
  IconData _coachBadgeIcon = Icons.remove;
  Timer? _coachBadgeTimer;

  // --- キャラクターアイコン ---
  String? _charIconId; // 自分（先手 or 人間側）のアイコンID

  // --- AIキャラセリフ ---
  String? _aiDialogue; // 表示中のセリフ（null=非表示）
  bool _dialogueVisible = false;

  // --- 局面メモ ---
  final Map<int, String> _memos = {}; // moveIndex → memo text

  // --- アニメーション ---
  late AnimationController _anim;
  late Animation<double> _animVal;
  bool _lastWasPromotion = false; // 直前の手が成りだったか（成り演出用）

  // ===== ゲーム性向上: 追加アニメーション・状態 =====

  // 王手フラッシュ
  AnimationController? _checkFlashAnim;
  bool _inCheckFlash = false;

  // 詰み紙吹雪
  AnimationController? _confettiAnim;
  bool _showConfetti = false;
  final List<_ConfettiParticle> _particles = [];

  // 駒を取った瞬間の小さな弾けエフェクト
  AnimationController? _captureBurstAnim;
  bool _showCaptureBurst = false;
  int? _captureBurstRow;
  int? _captureBurstCol;
  final List<_ConfettiParticle> _captureParticles = [];

  // 連勝カウンター
  int _winStreak = 0;
  int _lossStreak = 0;
  int _playerRating = 700;

  // 棋譜保存済みフラグ（詰み/投了/時間切れ重複防止）
  bool _kifuSaved = false;

  // アニメーション実行中フラグ（PvP で手番間の誤タップを防止）
  bool _animating = false;

  // 千日手判定（RepetitionChecker は logic.dart に定義）
  final _repChecker = RepetitionChecker();

  // 局面ブックマーク
  int _bookmarkCount = 0;

  // 囲い・戦法バナー
  AnimationController? _castleBannerAnim;
  String? _castleBannerText;
  String _detectedCastleP1 = '';
  String _detectedCastleP2 = '';
  String _detectedStrategyP1 = '';
  String _detectedStrategyP2 = '';
  final Map<int, String> _castleTags = {}; // 手番 → 囲い/戦法タグ文字列

  // 対局ミッション
  final List<_MissionDef> _missions = [];
  bool _showMissionPanel = false;

  // 対局後振り返り: 最善手
  AMove? _bestMoveAfterGame;

  // 持ち時間警告点滅
  AnimationController? _timerBlinkAnim;

  GameSettings get s => widget.settings;
  bool get vsAI => s.mode == GameMode.vsAI;
  bool get isAITurn => vsAI && ((s.aiIsP2 && !p1Turn) || (!s.aiIsP2 && p1Turn));
  // ユーザーは常に下（後手）に表示
  bool get _userIsP2 => vsAI ? !s.aiIsP2 : false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animVal = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);

    // 王手フラッシュアニメーション
    _checkFlashAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addStatusListener((st) {
          if (st == AnimationStatus.completed) {
            _checkFlashAnim?.reverse();
          }
        });

    // 詰みエフェクト
    _confettiAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 駒を取った瞬間の弾けエフェクト（短時間）
    _captureBurstAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // 囲い完成バナー（フェードイン＋ホールド＋フェードアウト 計3秒）
    _castleBannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // 持ち時間点滅
    _timerBlinkAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        )..repeat(
          reverse: true,
        ); // hand-piece pulse always runs; timer blink checked separately

    // 通常初期配置 or エディタからのカスタム配置
    board = widget.initialBoard != null
        ? GL.copy(widget.initialBoard!)
        : _initBoard(s.handicap);
    if (widget.initialP1Hand != null) p1Hand = Map.from(widget.initialP1Hand!);
    if (widget.initialP2Hand != null) p2Hand = Map.from(widget.initialP2Hand!);
    p1Turn = widget.initialP1Turn;

    if (s.timeLimitSec != null) {
      p1Time = s.timeLimitSec!;
      p2Time = s.timeLimitSec!;
      _p1InByoyomi = false;
      _p2InByoyomi = false;
      _p1ByoyomiRemaining = 0;
      _p2ByoyomiRemaining = 0;
      _startTimer();
    }
    _updateAtkMap();
    // コーチモード: 初期盤面を保存
    if (s.coachMode) {
      _coachInitialBoard = GL.copy(board);
    }
    _loadCharacterIcon();
    _loadWinStreak();
    _loadPlayerRating();
    _initMissions();
    _loadBookmarkCount();
    // AIパーソナリティを設定
    if (vsAI) {
      final pers = getPersonality(s.opponentCharacterId);
      AI.setPersonality(pers, aiIsP1: !s.aiIsP2);
      // 対局開始セリフ
      if (s.opponentCharacterId != null) {
        _showDialogue(DialogueTrigger.gameStart);
      }
    }
    // クラッシュからの復旧チェック
    Future.microtask(_checkAndRestoreGameSnapshot);

    // ゲーム開始ログを記録
    FirebaseLoggingService.logGameStart(
      gameMode: vsAI ? 'vsAI' : 'network',
      opponentId: null,
      aiCharacterId: s.opponentCharacterId ?? 'unknown',
      handicap: s.handicap.index,
    );

    // AI が先手の場合は最初の手番を AI に渡す
    if (vsAI && !s.aiIsP2) {
      Future.delayed(const Duration(milliseconds: 600), _runAI);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _checkFlashAnim?.dispose();
    _confettiAnim?.dispose();
    _captureBurstAnim?.dispose();
    _timerBlinkAnim?.dispose();
    _timer?.cancel();
    _aiElapsedTimer?.cancel();
    _postGameAutoNavTimer?.cancel();

    _coachBadgeTimer?.cancel();
    _castleBannerAnim?.dispose();
    AI.setPersonality(null); // パーソナリティをリセット
    super.dispose();
  }

  // ===== コーチモード: スナップショット保存 =====
  void _saveSnap() {
    _boardSnaps.add(GL.copy(board));
    _p1HandSnaps.add(Map.from(p1Hand));
    _p2HandSnaps.add(Map.from(p2Hand));
    _p1TurnSnaps.add(p1Turn);
  }

  // ===== コーチモード: 待った =====
  Future<void> _takata() async {
    if (!s.coachMode) return;
    final undoCount = vsAI ? 2 : 1;
    if (kifu.length < undoCount || _boardSnaps.length < undoCount) return;

    final targetIdx = kifu.length - undoCount;
    if (targetIdx < 0 ||
        targetIdx >= _boardSnaps.length ||
        targetIdx >= _p1HandSnaps.length ||
        targetIdx >= _p2HandSnaps.length ||
        targetIdx >= _p1TurnSnaps.length) return;

    setState(() {
      board = GL.copy(_boardSnaps[targetIdx]);
      p1Hand = Map.from(_p1HandSnaps[targetIdx]);
      p2Hand = Map.from(_p2HandSnaps[targetIdx]);
      p1Turn = _p1TurnSnaps[targetIdx];

      kifu = List.from(kifu.sublist(0, targetIdx));
      _boardSnaps.removeRange(targetIdx, _boardSnaps.length);
      _p1HandSnaps.removeRange(targetIdx, _p1HandSnaps.length);
      _p2HandSnaps.removeRange(targetIdx, _p2HandSnaps.length);
      _p1TurnSnaps.removeRange(targetIdx, _p1TurnSnaps.length);

      lastFR = null;
      lastFC = null;
      lastTR = null;
      lastTC = null;
      _coachBadgeText = null;
      _hintMove = null;
      result = null;
      _repChecker.reset(); // 待った後は千日手カウントをリセット
      _clearSel();
      _evalScore = AI.eval(board, p1Hand, p2Hand, ignorePersonality: true);
      _updateAtkMap();
    });

    // ベスト手をヒントとして表示
    final mv = await Future(
      () => AI.bestMove(board, p1Hand, p2Hand, p1Turn, 2),
    );
    if (mounted) setState(() => _hintMove = mv);
  }

  // ===== コーチモード: バッジ表示 =====
  void _showCoachBadge(int evalChange) {
    final label = _coachLabel(evalChange);
    if (label.isEmpty) return;
    _coachBadgeTimer?.cancel();
    setState(() {
      _coachBadgeText = label;
      _coachBadgeColor = _coachColor(evalChange);
      _coachBadgeIcon = _coachIcon(evalChange);
    });
    _coachBadgeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _coachBadgeText = null);
    });
  }

  // ===== コーチモード: 1局講評画面へ =====
  void _openCoachReport() {
    if (_coachInitialBoard == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachReportScreen(
          kifu: List.from(kifu),
          initialBoard: _coachInitialBoard!,
          result: result ?? '未終了',
          playerIsP1: s.aiIsP2, // AI が後手なら player は先手
        ),
      ),
    );
  }

  // ===== 効きマップ更新（setState 内から呼ぶ）=====
  void _updateAtkMap() {
    if (showAttackMap) {
      // 絶対座標で先手/後手を固定計算（手番に依存しない）
      _p1AtkMap = GL.attackMap(board, true); // 先手の利き
      _p2AtkMap = GL.attackMap(board, false); // 後手の利き
    } else {
      _p1AtkMap = null;
      _p2AtkMap = null;
    }
  }

  // ===== 局面分析ヒント計算 =====
  Future<void> _computeHint() async {
    if (result != null || isAITurn) return;
    // depth 2 で AI の最善手を非同期計算
    final mv = await Future(
      () => AI.bestMove(board, p1Hand, p2Hand, p1Turn, 2),
    );
    if (mounted) setState(() => _hintMove = mv);
  }

  // ===== タイマー =====
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || result != null) return;
      setState(() {
        if (p1Turn) {
          if (_p1InByoyomi) {
            // 秒読み中：カウントダウン
            _p1ByoyomiRemaining--;
            if (_p1ByoyomiRemaining <= 0) {
              _p1ByoyomiRemaining = 0;
              result = '後手の勝ち！（時間切れ）';
              _timer?.cancel();
              if (vsAI) Future.microtask(() => _updateWinStreak(!s.aiIsP2));
              Future.microtask(() => _showGameEndDialog());
            }
          } else {
            p1Time--;
            if (p1Time <= 0) {
              p1Time = 0;
              if (s.byoyomiSec != null) {
                // 秒読みモードへ移行
                _p1InByoyomi = true;
                _p1ByoyomiRemaining = s.byoyomiSec!;
              } else {
                result = '後手の勝ち！（時間切れ）';
                _timer?.cancel();
                if (vsAI) Future.microtask(() => _updateWinStreak(!s.aiIsP2));
                Future.microtask(() => _showGameEndDialog());
              }
            }
          }
        } else {
          if (_p2InByoyomi) {
            _p2ByoyomiRemaining--;
            if (_p2ByoyomiRemaining <= 0) {
              _p2ByoyomiRemaining = 0;
              result = '先手の勝ち！（時間切れ）';
              _timer?.cancel();
              if (vsAI) Future.microtask(() => _updateWinStreak(s.aiIsP2));
              Future.microtask(() => _showGameEndDialog());
            }
          } else {
            p2Time--;
            if (p2Time <= 0) {
              p2Time = 0;
              if (s.byoyomiSec != null) {
                _p2InByoyomi = true;
                _p2ByoyomiRemaining = s.byoyomiSec!;
              } else {
                result = '先手の勝ち！（時間切れ）';
                _timer?.cancel();
                if (vsAI) Future.microtask(() => _updateWinStreak(s.aiIsP2));
                Future.microtask(() => _showGameEndDialog());
              }
            }
          }
        }
      });
    });
  }

  String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  // ===== 選択解除 =====
  void _clearSel() {
    selR = null;
    selC = null;
    selHand = null;
    hl = _eHL();
  }

  bool get _showAds => !PurchaseService.isPremium;
  static List<List<bool>> _eHL() =>
      List.generate(9, (_) => List.filled(9, false));

  // ===== サブスクリプション =====
  // ===== AIセリフ表示 =====
  void _showDialogue(DialogueTrigger trigger) {
    final line = getRandomDialogue(s.opponentCharacterId, trigger);
    if (line == null || !mounted) return;
    setState(() {
      _aiDialogue = line;
      _dialogueVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _dialogueVisible = false);
    });
  }

  void _loadCharacterIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final charIconId = prefs.getString('character_icon_id');
      if (mounted) {
        setState(() {
          _charIconId = charIconId;
        });
      }
    } catch (_) {
      // アイコン読み込み失敗時は無視（オプション機能）
    }
  }

  // ===== 連勝/連敗カウンター読み込み =====
  Future<void> _loadWinStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streak = prefs.getInt('win_streak_ai') ?? 0;
      final loss = prefs.getInt('loss_streak_ai') ?? 0;
      if (mounted)
        setState(() {
          _winStreak = streak;
          _lossStreak = loss;
        });
    } catch (_) {}
  }

  // ===== プレイヤーレーティング読み込み =====
  Future<void> _loadPlayerRating() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rating = prefs.getInt('rating_ai_current') ?? 700;
      if (mounted) setState(() => _playerRating = rating);
    } catch (_) {}
  }

  // ===== 王手フラッシュ =====
  void _triggerCheckFlash() {
    if (!mounted) return;
    setState(() => _inCheckFlash = true);
    HapticFeedback.heavyImpact();
    _checkFlashAnim?.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _inCheckFlash = false);
    });
  }

  // ===== 詰みエフェクト（紙吹雪）=====
  void _triggerConfetti(bool playerWon) {
    if (!mounted) return;
    _particles.clear();
    final colors = playerWon
        ? [Colors.amber, Colors.yellow, Colors.orange, Colors.white]
        : [Colors.grey, Colors.white24, Colors.blueGrey];
    for (int i = 0; i < 60; i++) {
      _particles.add(
        _ConfettiParticle(
          x: (i % 9) / 9.0,
          color: colors[i % colors.length],
          size: 4.0 + (i % 4) * 2.0,
          speed: 0.3 + (i % 5) * 0.15,
          angle: (i % 360) * 3.14159 / 180,
        ),
      );
    }
    setState(() => _showConfetti = true);
    _confettiAnim?.forward(from: 0).then((_) {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  // ===== 駒を取った瞬間の弾けエフェクト =====
  void _triggerCaptureBurst(int row, int col) {
    if (!mounted) return;
    _captureParticles.clear();
    const colors = [Colors.white, Color(0xFFF0E9DC), Color(0xFFC8A45A)];
    for (int i = 0; i < 10; i++) {
      _captureParticles.add(
        _ConfettiParticle(
          x: 0.5,
          color: colors[i % colors.length],
          size: 3.0 + (i % 3) * 1.5,
          speed: 0.5 + (i % 4) * 0.12,
          angle: (i * 36) * 3.14159 / 180, // 放射状に均等配置
        ),
      );
    }
    setState(() {
      _captureBurstRow = row;
      _captureBurstCol = col;
      _showCaptureBurst = true;
    });
    _captureBurstAnim?.forward(from: 0).then((_) {
      if (mounted) setState(() => _showCaptureBurst = false);
    });
  }

  // ===== 対局後振り返り: 最善手計算 =====
  Future<void> _computeBestMoveAfterGame() async {
    try {
      if (kifu.length < 3) return;
      if (_boardSnaps.isEmpty) return;
      final snapBoard = GL.copy(_boardSnaps.last);
      final snapP1 = Map<PieceType, int>.from(_p1HandSnaps.last);
      final snapP2 = Map<PieceType, int>.from(_p2HandSnaps.last);
      final best = await Future(
        () => AI.bestMove(snapBoard, snapP1, snapP2, !p1Turn, 3),
      );
      if (mounted) setState(() => _bestMoveAfterGame = best);
    } catch (_) {}
  }

  void _goToPremium() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  // ===== 駒説明ポップアップ =====
  void _showPieceGuide(Piece piece) {
    final desc = _pieceGuide[piece.type] ?? '特殊な動きをします';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Text(
              piece.label,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              piece.type.name.contains('promoted')
                  ? '（成り駒）'
                  : '（${piece.isPlayer1 ? "先手" : "後手"}）',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        content: Text(
          desc,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // ===== 段位認定チェック =====
  Future<void> _checkDanPromotion(bool playerWon) async {
    if (!playerWon || !vsAI) return;
    final prefs = await SharedPreferences.getInstance();
    final wins = (prefs.getInt('win_count_vs_ai') ?? 0) + 1;
    await prefs.setInt('win_count_vs_ai', wins);
    // 10勝ごとに段位昇格イベント
    if (wins % 10 != 0) return;
    final dan = wins ~/ 10;
    final labels = ['初段', '二段', '三段', '四段', '五段'];
    if (dan < 1 || dan > labels.length) return;
    final label = labels[dan - 1];
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '段位認定',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'おめでとうございます！',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AI対局 $wins 勝達成！\n$label に認定されました。',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('受け取る', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  // ===== 対局結果シェア =====
  Future<void> _shareResult() async {
    try {
      final mode = vsAI ? 'AI対局' : '対人対局';
      final dan = _openingLabel.isNotEmpty ? '戦型: $_openingLabel / ' : '';
      final text = '【効棋】$mode ${dan}${kifu.length}手 $result\n将棋アプリ「効棋」で対局中！';
      await Share.share(text);
    } catch (_) {}
  }

  // ===== 盤面スナップショット =====
  Future<void> _captureBoard() async {
    try {
      final boundary =
          _boardRepaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final file = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'shogi_board.png',
      );
      await Share.shareXFiles([
        file,
      ], text: '将棋の局面 ${kifu.length}手目\n将棋アプリ「効棋」');
    } catch (_) {}
  }

  // ===== 局面メモ =====
  void _openMemoDialog() {
    final moveIdx = kifu.length; // 現在の手数でメモ
    final existing = _memos[moveIdx] ?? '';
    final ctrl = TextEditingController(text: existing);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          '手数${moveIdx}のメモ',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 200,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'この局面についてメモ...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.grey.shade900,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          if (existing.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _memos.remove(moveIdx));
                Navigator.pop(context);
              },
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              setState(() {
                if (text.isEmpty) {
                  _memos.remove(moveIdx);
                } else {
                  _memos[moveIdx] = text;
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
            ),
            child: const Text('保存', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ===== 成りダイアログ =====
  Future<bool?> _askPromo() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('成りますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('成らない'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('成る'),
        ),
      ],
    ),
  );

  // ===== 戦型自動判定 =====
  // 以前は先手の飛車位置だけを見る簡易ロジックで、「三間飛車」のように
  // ▲/△の接頭辞なしのラベルを返していた。一方で _detectStrategyFor は
  // 同じ戦型でも「△三間飛車」のように接頭辞付きで検出するため、
  // 同一の戦型が棋譜上で表記違いの別物として重複して見えるバグがあった。
  // _detectStrategyFor に一本化し、指し手数の多い側（=戦型が明確な側）を
  // 優先して同じ接頭辞付き表記で返すことで表記を統一する。
  String _detectOpening() {
    if (kifu.length < 10) return '';
    final humanIsP1 = !_userIsP2;
    final humanStrat = _detectStrategyFor(humanIsP1);
    if (humanStrat.isNotEmpty) return (humanIsP1 ? '▲' : '△') + humanStrat;
    final oppStrat = _detectStrategyFor(!humanIsP1);
    if (oppStrat.isNotEmpty) return (humanIsP1 ? '△' : '▲') + oppStrat;
    return '居飛車';
  }

  // ===== 囲い自動検出（P1/P2汎用）=====
  // 囲い検出（両コーナー対応: 居飛車=std側, 振り飛車=alt側）
  // 囲い検出（30種対応）
  // 座標: ec=コーナーからの距離, er=自陣後段からの距離
  // stdCorner: P1→col=0(9筋/居飛車), P2→col=8(1筋)
  // altCorner: P1→col=8(1筋/振り飛車), P2→col=0
  // chk(dr_n, dc_n, type): dr_n>0=敵方向, dc_n>0=コーナーから離れる方向
  String _detectCastleFor(bool isP1) {
    int kr = -1, kc = -1;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p != null && p.isPlayer1 == isP1 && p.type == PieceType.king) {
          kr = r; kc = c;
        }
      }
    }
    if (kr < 0) return '';
    final er = isP1 ? (8 - kr) : kr;

    String detect(bool std) {
      final ec = std ? (isP1 ? kc : (8 - kc)) : (isP1 ? (8 - kc) : kc);
      final dir = std ? (isP1 ? 1 : -1) : (isP1 ? -1 : 1);

      bool chk(int dr_n, int dc_n, PieceType t) {
        final r2 = isP1 ? kr - dr_n : kr + dr_n;
        final c2 = kc + dc_n * dir;
        if (r2 < 0 || r2 > 8 || c2 < 0 || c2 > 8) return false;
        final pc = board[r2][c2];
        return pc != null && pc.isPlayer1 == isP1 &&
            (pc.type == t || pc.baseType == t);
      }

      // ── ec=0, er=0: 穴熊ファミリー（4種） ──
      if (ec == 0 && er == 0) {
        final s0 = chk(1, 0, PieceType.silver);
        final s1 = chk(1, 1, PieceType.silver);
        final s2 = chk(1, 2, PieceType.silver);
        // 銀冠穴熊: 穴熊の上に銀冠（銀が二段）
        if (s1 && (chk(2, 1, PieceType.silver) || chk(2, 2, PieceType.silver))) return '銀冠穴熊';
        // ビッグ4: 銀2枚が内側（コーナー側に銀なし）
        if (s1 && s2 && !s0) return 'ビッグ4';
        // 穴熊: 銀2枚外側 or 銀1枚 or 金蓋
        if (s0 && s1) return '穴熊';
        if (chk(1, 0, PieceType.lance)) return '居飛車穴熊';
        if (s0 || s1) return '穴熊';
        if (chk(0, 1, PieceType.gold)) return '穴熊';
        return '';
      }

      // ── ec=0, er≥1: コーナー列上段（端囲い/右矢倉） ──
      if (ec == 0 && er >= 1) {
        // 端囲い: 玉が端筋の上段、金で内側を守る
        if (chk(0, 1, PieceType.gold) &&
            (chk(1, 1, PieceType.silver) || chk(1, 2, PieceType.silver))) return '右矢倉';
        if (chk(0, 1, PieceType.gold)) return '端囲い';
        return '';
      }

      // ── ec=1, er=0: 後段コーナー隣（早囲い） ──
      if (ec == 1 && er == 0) {
        if (chk(0, 1, PieceType.gold)) return '早囲い';
        return '';
      }

      // ── ec=1, er=1: 美濃・矢倉ファミリー（10種） ──
      if (ec == 1 && er == 1) {
        final gR  = chk(0, 1, PieceType.gold);
        final gR2 = chk(0, 2, PieceType.gold);
        final gR3 = chk(0, 3, PieceType.gold);
        final gL  = chk(0, -1, PieceType.gold);
        final sF  = chk(1, 0, PieceType.silver);
        final sFR = chk(1, 1, PieceType.silver);
        final sFL = chk(1, -1, PieceType.silver);
        final gFR = chk(1, 1, PieceType.gold);
        final gDR = chk(1, 2, PieceType.gold);
        final sDR = chk(1, 2, PieceType.silver);

        if (gR && gR2) return '金無双';
        if (sF && gR && gDR) return '銀冠';
        // 二枚銀矢倉: 銀前+銀斜め+金（矢倉より厚い形）
        if (gR && sF && sFR) return '二枚銀矢倉';
        if (gR && (sFR || gFR)) return '矢倉';
        if (gR && sF && gL) return '左美濃';
        if (gR && gR3 && sDR) return '木村美濃';
        if (gR && sFR && gDR) return '高美濃';
        // 菱矢倉: 銀が両斜め（金と銀の菱形）
        if (gR && sFR && sFL) return '菱矢倉';
        // 金美濃: 銀なし、金が前/斜めを守る
        if (gR && (gFR || chk(1, 0, PieceType.gold))) return '金美濃';
        if (gR && (sF || sFR || sFL)) return '美濃';
        return '';
      }

      // ── ec=1, er≥2: 天守閣美濃（玉が高い位置） ──
      if (ec == 1 && er >= 2) {
        if (chk(0, 1, PieceType.gold) || chk(0, -1, PieceType.gold)) return '天守閣美濃';
        return '';
      }

      // ── ec=2, er=0: 急戦囲い（3筋・7筋の後段） ──
      if (ec == 2 && er == 0) {
        if (chk(0, 1, PieceType.gold)) return '急戦囲い';
        return '';
      }

      // ── ec=2, er=1: ミレニアム・ダイアモンド等 ──
      if (ec == 2 && er == 1) {
        final gR  = chk(0, 1, PieceType.gold);
        final gL  = chk(0, -1, PieceType.gold);
        final sFR = chk(1, 1, PieceType.silver);
        final sFL = chk(1, -1, PieceType.silver);
        final sF  = chk(1, 0, PieceType.silver);

        // ミレニアム: 金両側+銀展開（現代振り飛車の堅陣）
        if (gR && gL && (sFR || sFL)) return 'ミレニアム';
        // ダイアモンド美濃: 銀が両斜め（菱形の銀）
        if (sFR && sFL) return 'ダイアモンド美濃';
        // 二段囲い: 金+銀前（縦の守り）
        if ((gR || gL) && sF) return '二段囲い';
        // 片矢倉: 金片側+銀斜め
        if (gR && sFR) return '片矢倉';
        return '';
      }

      // ── ec=2, er≥2: 銀矢倉（高い位置の銀両翼） ──
      if (ec == 2 && er >= 2) {
        if (chk(1, 1, PieceType.silver) && chk(1, -1, PieceType.silver)) return '銀矢倉';
        return '';
      }

      // ── ec≥3, er=0: カニ囲い ──
      if (ec >= 3 && er == 0) {
        if (chk(0, 1, PieceType.gold) && chk(0, -1, PieceType.gold)) {
          if (chk(1, 0, PieceType.silver)) return 'カニ囲い';
        }
        return '';
      }

      // ── ec≥3, er≥1: 中央系（舟囲い・雁木等） ──
      if (ec >= 3 && er >= 1) {
        final gR = chk(0, 1, PieceType.gold);
        final gL = chk(0, -1, PieceType.gold);
        if (gR && gL) {
          final sFR = chk(1, 1, PieceType.silver);
          final sFL = chk(1, -1, PieceType.silver);
          // 二枚銀: 金両側+銀両斜め（中央の厚み）
          if (sFR && sFL) return '二枚銀';
          if (chk(0, 2, PieceType.silver) || chk(0, -2, PieceType.silver) ||
              chk(1, 2, PieceType.silver) || chk(1, -2, PieceType.silver)) return '中住まい';
          return '舟囲い';
        }
        if (chk(1, 1, PieceType.silver) && chk(1, -1, PieceType.silver)) return '雁木';
        // 流れ矢倉: 金片側+銀斜め（中央からの矢倉志向）
        if ((gR && chk(1, 1, PieceType.silver)) ||
            (gL && chk(1, -1, PieceType.silver))) return '流れ矢倉';
        return '';
      }

      return '';
    }

    final ecStd = isP1 ? kc : (8 - kc);
    final ecAlt = isP1 ? (8 - kc) : kc;
    if (ecStd <= ecAlt) {
      final r = detect(true);
      return r.isNotEmpty ? r : detect(false);
    } else {
      final r = detect(false);
      return r.isNotEmpty ? r : detect(true);
    }
  }

  // 戦法検出（飛車・銀・角の配置と手駒から判定）
  // 盤座標: col=0=9筋, col=8=1筋 / P1後段=row=8, P2後段=row=0
  String _detectStrategyFor(bool isP1) {
    if (kifu.length < 8) return '';

    // 飛車位置を探索
    int rookR = -1, rookC = -1;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p != null && p.isPlayer1 == isP1 && p.type == PieceType.rook) {
          rookR = r; rookC = c;
        }
      }
    }

    if (rookR >= 0) {
      if (isP1) {
        // P1飛車スタート: 2八(col=7). 振り飛車 = col減少
        switch (rookC) {
          case 0: return '端飛車';
          case 1: return '向かい飛車';
          case 2:
            // 石田流: 7筋に飛車 + 7六歩(board[5][2])または飛車が7五以上
            final pawn76 = board[5][2];
            final pawnOk = pawn76 != null && pawn76.isPlayer1 &&
                (pawn76.type == PieceType.pawn || pawn76.baseType == PieceType.pawn);
            if (rookR <= 4 || pawnOk) return '石田流三間飛車';
            return '三間飛車';
          case 3: return '四間飛車';
          case 4: return 'ゴキゲン中飛車';
          case 5: return '右四間飛車';
          case 6: return '右三間飛車';
        }
      } else {
        // P2飛車スタート: 8二(col=1). 振り飛車 = col増加
        switch (rookC) {
          case 8: return '端飛車';
          case 7: return '向かい飛車';
          case 6:
            final pawn76 = board[3][6];
            final pawnOk = pawn76 != null && !pawn76.isPlayer1 &&
                (pawn76.type == PieceType.pawn || pawn76.baseType == PieceType.pawn);
            if (rookR >= 4 || pawnOk) return '石田流三間飛車';
            return '三間飛車';
          case 5: return '四間飛車';
          case 4: return 'ゴキゲン中飛車';
          case 3: return '右四間飛車';
          case 2: return '右三間飛車';
        }
      }

      // 飛車が自陣にある場合の居飛車系戦法検出
      final homeFile = isP1 ? 7 : 1;
      if (rookC == homeFile && kifu.length >= 20) {
        // 角換わり: 両者の角が交換済み（それぞれ相手の角を持駒に持つ）
        final p1HasBishop = (p1Hand[PieceType.bishop] ?? 0) > 0;
        final p2HasBishop = (p2Hand[PieceType.bishop] ?? 0) > 0;
        if (p1HasBishop && p2HasBishop) return '角換わり';

        // 棒銀: 銀が前線(敵陣方向)に進出 + 飛車が本筋
        for (int r = 0; r < 9; r++) {
          for (int c = 0; c < 9; c++) {
            final p = board[r][c];
            if (p == null || p.isPlayer1 != isP1 || p.type != PieceType.silver) continue;
            final advancedRank = isP1 ? (8 - r) : r; // 自陣からの前進段数
            final silverFile = isP1 ? (8 - c) : c;   // 1-9筋
            if (advancedRank >= 4 && silverFile <= 3) return '棒銀';
          }
        }

        // 相掛かり: 飛車が前進している(2筋のまま進出)
        final advancedRow = isP1 ? (8 - rookR) : rookR;
        if (advancedRow >= 3) return '相掛かり';
      }
    }

    return '';
  }

  // 「○○囲い」のように既に「囲い」で終わる名称に、さらに「囲い」を
  // 重複させて表示しないようにする（例: 「カニ囲い囲い」を防ぐ）
  String _castleCompletionTag(String mark, String castleName) {
    final suffix = castleName.endsWith('囲い') ? '完成' : '囲い完成';
    return '$mark$castleName$suffix';
  }

  // ===== 囲い完成チェック（_endTurn 末尾から呼ぶ）=====
  void _checkCastleCompletion() {
    final p1Castle = _detectCastleFor(true);
    final p2Castle = _detectCastleFor(false);
    if (p1Castle.isNotEmpty && p1Castle != _detectedCastleP1) {
      _detectedCastleP1 = p1Castle;
      final tag = _castleCompletionTag('▲', p1Castle);
      _castleTags[kifu.length] = tag;
      _showCastleBanner(tag);
      return;
    }
    if (p2Castle.isNotEmpty && p2Castle != _detectedCastleP2) {
      _detectedCastleP2 = p2Castle;
      final tag = _castleCompletionTag('△', p2Castle);
      _castleTags[kifu.length] = tag;
      _showCastleBanner(tag);
      return;
    }
    // 戦法（振り飛車）検出 — 囲いバナーと同一チャンネルで表示
    final p1Strat = _detectStrategyFor(true);
    final p2Strat = _detectStrategyFor(false);
    if (p1Strat.isNotEmpty && p1Strat != _detectedStrategyP1) {
      _detectedStrategyP1 = p1Strat;
      final tag = '▲$p1Strat';
      _castleTags[kifu.length] = tag;
      _showCastleBanner(tag);
    } else if (p2Strat.isNotEmpty && p2Strat != _detectedStrategyP2) {
      _detectedStrategyP2 = p2Strat;
      final tag = '△$p2Strat';
      _castleTags[kifu.length] = tag;
      _showCastleBanner(tag);
    }
  }

  void _showCastleBanner(String text) {
    _castleBannerText = text; // _endTurn は setState 内から呼ばれるので追加setState不要
    _castleBannerAnim!.forward(from: 0).then((_) {
      if (mounted) setState(() => _castleBannerText = null);
    });
  }

  // ===== 囲い自動検出（P1専用・後方互換）=====
  String _detectCastle() {
    // P1の玉の位置を探す
    int kr = -1, kc = -1;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p != null && p.isPlayer1 && p.type == PieceType.king) {
          kr = r;
          kc = c;
        }
      }
    }
    if (kr < 0) return '';
    if (kc == 0) return '穴熊';
    if (kc == 1) {
      // 銀が隣にあれば矢倉、なければ美濃
      bool hasSilver = false;
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 2; dc++) {
          final r2 = kr + dr;
          final c2 = kc + dc;
          if (r2 < 0 || r2 > 8 || c2 < 0 || c2 > 8) continue;
          final p = board[r2][c2];
          if (p != null && p.isPlayer1 && p.type == PieceType.silver)
            hasSilver = true;
        }
      }
      return hasSilver ? '矢倉' : '美濃';
    }
    if (kc == 2) return '舟囲い';
    return '';
  }

  // ===== 手番終了処理（責任分離版） =====
  void _endTurn() {
    try {
      final prevEval = _evalScore;
      _evalScore = AI.eval(board, p1Hand, p2Hand, ignorePersonality: true);
      _evalHistory.add(_evalScore);
      if (kifu.length >= 15 && kifu.length % 5 == 0 && _openingLabel.isEmpty) {
        _openingLabel = _detectOpening();
      }

      _updateGameState();
      _applyPostMoveEffects(prevEval);
      _decideAIMove();
    } catch (e, st) {
      FirebaseLoggingService.logError(
        errorType: 'end_turn_crash',
        message: '$e',
        context: 'game_screen_endTurn',
      );
      if (mounted) {
        setState(() => _aiThinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('エラーが発生しました。対局を継続できます。'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 結果文字列は「{勝者}の勝ち！...」の形式で必ず勝者側のマーカーから始まる
  // （投了・持将棋などは敗者側の呼称も括弧内に含むため、contains() では
  //   誤判定する。必ず startsWith() で判定すること）
  bool _resultWonBy(String marker) =>
      result != null && result!.startsWith('${marker}の勝ち');

  // ゲーム状態を更新（千日手・詰み判定・ゲーム終了判定）
  void _updateGameState() {
    final next = !p1Turn; // 次に指す手番

    // ── 千日手チェック（合法手チェックより先に行う）──
    if (_repChecker.record(board, p1Hand, p2Hand, next)) {
      if (_repChecker.isConsecutiveCheck(board, p1Hand, p2Hand, next)) {
        // 連続王手の千日手: next プレイヤーが常に王手されている
        // → 王手をかけ続けた p1Turn 側（直前に指した側）が負け
        result = p1Turn
            ? '後手の勝ち！（連続王手の千日手）'
            : '先手の勝ち！（連続王手の千日手）';
      } else {
        result = '引き分け（千日手）';
      }
      _timer?.cancel();
      SoundService.playGameEnd();
      final playerMarker = s.aiIsP2 ? '先手' : '後手';
      final playerWon = vsAI && _resultWonBy(playerMarker);
      _triggerConfetti(playerWon);
      if (vsAI && !result!.contains('引き分け')) _updateWinStreak(playerWon);
      _computeBestMoveAfterGame();
      if (mounted) Future.microtask(() => _showGameEndDialog());
      return;
    }

    // ── 持将棋チェック（両玉入玉後の点数判定）──
    {
      final p1In = NyugyokuChecker.isNyugyoku(board, true);
      final p2In = NyugyokuChecker.isNyugyoku(board, false);
      if (p1In && p2In) {
        final (p1Pts, p2Pts) =
            NyugyokuChecker.calcScores(board, p1Hand, p2Hand);
        final p1Win = p1Pts >= 24;
        final p2Win = p2Pts >= 24;
        if (p1Win || p2Win) {
          if (p1Win && p2Win) {
            result = '引き分け（持将棋・先手${p1Pts}点 後手${p2Pts}点）';
          } else if (p1Win) {
            result = '先手の勝ち！（持将棋・${p1Pts}点）';
          } else {
            result = '後手の勝ち！（持将棋・${p2Pts}点）';
          }
          _timer?.cancel();
          SoundService.playGameEnd();
          final playerMarker = s.aiIsP2 ? '先手' : '後手';
          final playerWon = vsAI && _resultWonBy(playerMarker);
          _triggerConfetti(playerWon);
          if (vsAI && !result!.contains('引き分け')) _updateWinStreak(playerWon);
          _computeBestMoveAfterGame();
          if (mounted) Future.microtask(() => _showGameEndDialog());
          return;
        }
      }
    }

    final hand = next ? p1Hand : p2Hand;
    final oppHand = next ? p2Hand : p1Hand;
    if (!GL.hasLegalMove(board, next, hand, oppHand)) {
      result = GL.inCheck(board, next)
          ? (p1Turn ? '先手の勝ち！🎉' : '後手の勝ち！🎉')
          : '引き分け（行き詰まり）'; // 千日手ではなく行き詰まり（将棋では非常に稀）
      _timer?.cancel();
      SoundService.playGameEnd();
      final playerMarker = s.aiIsP2 ? '先手' : '後手';
      final playerWon = vsAI ? _resultWonBy(playerMarker) : _resultWonBy('先手');
      final isDraw = result!.contains('引き分け');
      _triggerConfetti(playerWon);
      if (vsAI && !isDraw) _updateWinStreak(playerWon);
      _computeBestMoveAfterGame();
      if (mounted) {
        Future.microtask(() => _showGameEndDialog());
      }
    } else if (GL.inCheck(board, next)) {
      SoundService.playCheck();
      _triggerCheckFlash();
    }
  }

  // ポストムーブエフェクト（バッジ・セリフ・時間管理）
  void _applyPostMoveEffects(int prevEval) {
    if (s.coachMode && kifu.isNotEmpty && result == null) {
      final humanJustMoved = !vsAI || !isAITurn;
      if (humanJustMoved) {
        final change = _pEvalChange(prevEval, _evalScore, kifu.last.p1);
        _showCoachBadge(change);
      }
    } else {
      if (vsAI && kifu.isNotEmpty && s.opponentCharacterId != null && result == null) {
        final humanJustMoved = isAITurn;
        if (humanJustMoved) {
          final change = _pEvalChange(prevEval, _evalScore, kifu.last.p1);
          if (change >= 150) {
            _showDialogue(DialogueTrigger.opponentGoodMove);
          } else if (change <= -200) {
            _showDialogue(DialogueTrigger.opponentBadMove);
          }
        }
      }
    }

    if (s.fischerIncrementSec > 0 && s.timeLimitSec != null && result == null) {
      // 秒読み突入後はp1Time/p2Timeが使われなくなるため、
      // 死に変数への加算を避け秒読み中の側には加算しない
      if (p1Turn && !_p1InByoyomi) {
        p1Time = (p1Time + s.fischerIncrementSec).clamp(0, 3600);
      } else if (!p1Turn && !_p2InByoyomi) {
        p2Time = (p2Time + s.fischerIncrementSec).clamp(0, 3600);
      }
    }

    if (s.byoyomiSec != null && result == null) {
      if (p1Turn && _p1InByoyomi) {
        _p1ByoyomiRemaining = s.byoyomiSec!;
      } else if (!p1Turn && _p2InByoyomi) {
        _p2ByoyomiRemaining = s.byoyomiSec!;
      }
    }

    _checkMissions();
    _checkCastleCompletion();
  }

  // AI実行判定・ターン切替
  void _decideAIMove() {
    // _endTurn は AI の駒アニメ完了コールバックからも呼ばれ、setState の外に
    // なるため、手番表示が更新されないのを防ぐ。
    if (mounted) {
      setState(() {
        p1Turn = !p1Turn;
        _updateAtkMap();
      });
    } else {
      p1Turn = !p1Turn;
      _updateAtkMap();
    }
    if (_analysisMode && result == null && !isAITurn) _computeHint();
    if (result == null && isAITurn) {
      _saveGameSnapshot();
      Future.delayed(const Duration(milliseconds: 100), _runAI);
    }
  }

  // 感想戦画面へ遷移（終局後の既定の振り返り先）
  void _openKansousenScreen(BuildContext ctx) {
    final initialBoard =
        _boardSnaps.isNotEmpty ? _boardSnaps.first : _initBoard(s.handicap);
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => KansousenScreen(
          moves: List.from(kifu),
          initialBoard: initialBoard,
          title: '${kifu.length}手の対局',
          pieceTheme: s.theme,
        ),
      ),
    );
  }

  // ゲーム終了ダイアログ
  Future<void> _showGameEndDialog() async {
    if (!mounted || result == null) return;

    GameAnalysis? analysis;

    // 棋譜保存（詰み・時間切れ・その他の終局を一括カバー）
    if (!_kifuSaved) {
      _kifuSaved = true;
      _saveKifu(recordStats: true);
      StudyCalendarScreen.recordActivity('taikyoku');
      // ゲーム終了ログを記録
      FirebaseLoggingService.logGameEnd(
        gameMode: vsAI ? 'vsAI' : 'network',
        opponentId: null,
        result: result ?? '中断',
        moveCount: kifu.length,
        elapsedSeconds: (DateTime.now().millisecondsSinceEpoch ~/ 1000).toInt(),
      );
      // クラッシュからの復旧フラグをクリア（正常終了）
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('has_game_snapshot', false);
      });

      // 棋譜を分析・保存（Phase 1）
      try {
        analysis = await KifuAnalyticsService().analyzeAndSaveGame(
          evalHistory: _evalHistory,
          moveNotations: kifu.map((m) => m.note).toList(),
          playerWon: _resultWonBy(_userIsP2 ? '後手' : '先手'),
          openingName: _openingLabel.isNotEmpty ? _openingLabel : null,
          playerIsP1: !_userIsP2,
        );
        print('✅ 棋譜分析完了: 悪手${analysis.blunders.length}個, 好手${analysis.goodMoves.length}個');
      } catch (e) {
        print('❌ 棋譜分析エラー: $e');
      }
    }
    if (vsAI && s.opponentCharacterId != null) {
      final aiWon = _resultWonBy(s.aiIsP2 ? '後手' : '先手');
      _showDialogue(aiWon ? DialogueTrigger.aiWins : DialogueTrigger.aiLoses);
    }

    final playerWon = vsAI ? _resultWonBy(_userIsP2 ? '後手' : '先手') : false;
    final loss = _lossStreak;

    // 敗北時の敗北体験ウィジェット表示
    if (!playerWon && vsAI && mounted) {
      _showDefeatExperienceSheet();
      return; // ここで従来のダイアログは表示しない
    }

    // 段位認定チェック（非同期）
    if (playerWon)
      Future.delayed(
        const Duration(milliseconds: 1200),
        () => _checkDanPromotion(true),
      );

    // 一定時間メニューを選ばなければ、感想戦画面へ自動的に移動する
    _postGameAutoNavTimer?.cancel();
    _postGameAutoNavTimer = Timer(const Duration(seconds: 25), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst || !route.isCurrent);
      Navigator.of(context).pop(); // 終局ダイアログを閉じる
      if (kifu.isNotEmpty) {
        _openKansousenScreen(context);
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
              ),
              child: Text(
                result!,
                style: TextStyle(
                  color: playerWon ? Colors.amber : Colors.redAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${kifu.length}手で終局',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Listener(
          onPointerDown: (_) => _postGameAutoNavTimer?.cancel(),
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 連敗ケアメッセージ ──
              if (!playerWon && loss >= 2) ...[
                _LossStreakCard(lossStreak: loss),
                const SizedBox(height: 12),
              ],

              // ── 振り返りサマリー ──
              if (_evalHistory.length >= 4) ...[
                const Divider(color: Colors.white12),
                _buildGameReviewSummary(),
              ],

              // ── コーチモード: AI講評 ──
              if (s.coachMode && kifu.isNotEmpty) ...[
                _postGameBtn(
                  icon: Icons.psychology,
                  label: 'AI講評を見る',
                  color: Colors.deepPurple.shade600,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCoachReport();
                  },
                ),
                const SizedBox(height: 8),
              ],

              // ── 学習アクション ──
              const Divider(color: Colors.white12, height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '次のアクション',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),

              // 感想戦（振り返り）
              if (kifu.isNotEmpty)
                _postGameBtn(
                  icon: Icons.history,
                  label: '感想戦で振り返る',
                  color: Colors.teal.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openKansousenScreen(context);
                  },
                ),
              const SizedBox(height: 6),

              // 悪手クイズ（Phase 2）
              if (analysis != null && analysis!.blunders.isNotEmpty)
                _postGameBtn(
                  icon: Icons.quiz,
                  label: '悪手を復習（${analysis!.blunders.length}問）',
                  color: Colors.red.shade700,
                  onTap: () async {
                    Navigator.pop(ctx);
                    // 過去の悪手パターンを取得
                    final historicalBlunders = <BlunderInfo>[];
                    try {
                      final allGames = await KifuAnalyticsService().getAllAnalyses();
                      for (final blunder in analysis!.blunders) {
                        final matching = allGames
                            .expand((g) => g.blunders)
                            .where((b) =>
                                b.toSquare == blunder.toSquare &&
                                b.pieceMoved == blunder.pieceMoved)
                            .toList();
                        historicalBlunders.addAll(matching);
                      }
                    } catch (e) {
                      print('⚠️ 過去の悪手取得エラー: $e');
                    }
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonalBlunderQuizScreen(
                            blunders: analysis!.blunders,
                            historicalBlunders: historicalBlunders,
                          ),
                        ),
                      );
                    }
                  },
                ),
              if (analysis != null && analysis!.blunders.isNotEmpty)
                const SizedBox(height: 6),

              // 悪手・好手フィルター振り返り
              if (_evalHistory.length >= 4) ...[
                Builder(builder: (context) {
                  final blunders = _filterMoveIndices(blunder: true);
                  final goods = _filterMoveIndices(blunder: false);
                  return Column(
                    children: [
                      if (blunders.isNotEmpty)
                        _postGameBtn(
                          icon: Icons.warning_amber_outlined,
                          label: '悪手を振り返る（${blunders.length}手）',
                          color: Colors.orange.shade800,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KifuReplayScreen(
                                  moves: kifu,
                                  title: '悪手の振り返り',
                                  filterIndices: blunders,
                                  filterLabel: '悪手',
                                  initialStep: blunders.first,
                                ),
                              ),
                            );
                          },
                        ),
                      if (blunders.isNotEmpty) const SizedBox(height: 6),
                      if (goods.isNotEmpty)
                        _postGameBtn(
                          icon: Icons.star_outline,
                          label: '好手を振り返る（${goods.length}手）',
                          color: Colors.lightBlue.shade800,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KifuReplayScreen(
                                  moves: kifu,
                                  title: '好手の振り返り',
                                  filterIndices: goods,
                                  filterLabel: '好手',
                                  initialStep: goods.first,
                                ),
                              ),
                            );
                          },
                        ),
                      if (goods.isNotEmpty) const SizedBox(height: 6),
                    ],
                  );
                }),
              ],

              // 弱点を分析・練習
              _postGameBtn(
                icon: Icons.analytics,
                label: '弱点を分析して練習',
                color: Colors.purple.shade700,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WeaknessAnalysisScreen(
                        onGoToTsume: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TsumeScreen(),
                          ),
                        ),
                        onGoToJoseki: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JosekiScreen(),
                          ),
                        ),
                        onGoToTesuji: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TesujiScreen(),
                          ),
                        ),
                        onGoToAiGame: () => Navigator.pop(context),
                        onGoToKifu: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KifuHistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),

              // 詰将棋1問で気分転換
              _postGameBtn(
                icon: Icons.extension,
                label: '詰将棋1問やってみる',
                color: Colors.orange.shade800,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TsumeScreen()),
                  );
                },
              ),
              const SizedBox(height: 6),

              // 初段ロードマップ
              _postGameBtn(
                icon: Icons.map,
                label: '初段への道を確認',
                color: Colors.brown.shade600,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShodanRoadmapScreen(),
                    ),
                  );
                },
              ),

              const Divider(color: Colors.white12, height: 20),

              // ── 通常ボタン ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (kifu.length >= 2)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.repeat, size: 16),
                      label: const Text('リベンジ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadDefeatAndReplay();
                      },
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('新局'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        board = _initBoard(s.handicap);
                        p1Hand = {};
                        p2Hand = {};
                        p1Turn = true;
                        result = null;
                        kifu = [];
                        _coachInitialBoard = s.coachMode
                            ? GL.copy(board)
                            : null;
                        _boardSnaps.clear();
                        _p1HandSnaps.clear();
                        _p2HandSnaps.clear();
                        _p1TurnSnaps.clear();
                        _clearSel();
                        lastFR = null;
                        lastFC = null;
                        lastTR = null;
                        lastTC = null;
                        _hintMove = null;
                        _updateAtkMap();
                        if (s.timeLimitSec != null) {
                          p1Time = s.timeLimitSec!;
                          p2Time = s.timeLimitSec!;
                          _p1InByoyomi = false;
                          _p2InByoyomi = false;
                          _p1ByoyomiRemaining = 0;
                          _p2ByoyomiRemaining = 0;
                          _startTimer();
                        }
                        if (vsAI && !s.aiIsP2)
                          Future.delayed(
                            const Duration(milliseconds: 600),
                            _runAI,
                          );
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.home, size: 16),
                    label: const Text('ホーム'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('シェア'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _shareResult,
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ===== 対局振り返りサマリー =====
  Widget _buildGameReviewSummary() {
    if (_evalHistory.length < 2) return const SizedBox.shrink();

    int maxBlunderMove = -1;
    int maxBlunderDelta = 0;
    int bestMoveMove = -1;
    int bestMoveDelta = 0;

    for (int i = 1; i < _evalHistory.length; i++) {
      final delta = _evalHistory[i] - _evalHistory[i - 1];
      final playerDelta = (i - 1 < kifu.length && kifu[i - 1].p1)
          ? delta
          : -delta;
      if (playerDelta < maxBlunderDelta) {
        maxBlunderDelta = playerDelta;
        maxBlunderMove = i;
      }
      if (playerDelta > bestMoveDelta) {
        bestMoveDelta = playerDelta;
        bestMoveMove = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '振り返り',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        if (maxBlunderMove > 0)
          _reviewRow(
            Icons.warning_amber_outlined,
            Colors.orange,
            '${maxBlunderMove}手目',
            '最大の疑問手 (${maxBlunderDelta}点)',
          ),
        if (bestMoveMove > 0)
          _reviewRow(
            Icons.star_outline,
            Colors.lightBlueAccent,
            '${bestMoveMove}手目',
            '最大の好手 (+${bestMoveDelta}点)',
          ),
      ],
    );
  }

  Widget _reviewRow(IconData icon, Color color, String move, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            move,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 悪手・好手フィルター手番計算 =====
  // 戻り値: 1-based step インデックスのリスト（KifuReplayScreen._step に対応）
  List<int> _filterMoveIndices({required bool blunder}) {
    final result = <int>[];
    if (_evalHistory.length < 2) return result;
    for (int i = 1; i < _evalHistory.length && i <= kifu.length; i++) {
      final delta = _evalHistory[i] - _evalHistory[i - 1];
      final isP1 = kifu[i - 1].p1;
      final playerDelta = isP1 ? delta : -delta;
      if (blunder && playerDelta <= -80) result.add(i);
      if (!blunder && playerDelta >= 150) result.add(i);
    }
    return result;
  }

  // 対局後アクションボタン共通Widget
  Widget _postGameBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  // ===== AI 実行 =====
  Future<void> _runAI() async {
    if (result != null || !mounted) return;
    setState(() {
      _aiThinking = true;
      _aiElapsedSec = 0;
    });
    _aiElapsedTimer?.cancel();
    _aiElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _aiThinking) setState(() => _aiElapsedSec++);
    });
    try {
      await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
      if (!mounted || result != null) return;

      // ── オープニングブック参照（序盤20手以内・中級以上・50%確率で使用）──
      AMove? mv;
      if (kifu.length < 20 && s.aiDepth >= 2 && Random().nextDouble() > 0.5) {
        mv = AiDataService.lookupOpeningBook(board, kifu.length);
      }

      // ── ブックにない場合は探索（棋風による深さ補正を適用）──
      final pers = getPersonality(s.opponentCharacterId);
      final depthBonus = pers?.depthBonus ?? 0;
      final effectiveDepth = (s.aiDepth + depthBonus).clamp(1, 6);
      // 時間予算テーブル（depth 1..6 に対応）
      const budgetTable = [150, 250, 350, 600, 1100, 1800];
      final budgetMs = budgetTable[(effectiveDepth - 1).clamp(0, 5)];
      final aiIsP1 = !s.aiIsP2;
      if (mv == null) {
        // 浅い読み（depth<=3）では上位3手からランダム選択して多様性を確保
        // Isolate で実行することで UIスレッドをブロックしない
        if (effectiveDepth <= 3) {
          final tops = await AiIsolate.topMovesTimed(
            board, p1Hand, p2Hand, aiIsP1,
            n: 3,
            budget: Duration(milliseconds: budgetMs),
            personality: pers,
            persAiIsP1: aiIsP1,
          );
          if (tops.isNotEmpty) {
            // 60%: 1位、30%: 2位、10%: 3位
            final r = Random().nextDouble();
            final idx = r < 0.6 ? 0 : r < 0.9 ? 1 : 2;
            mv = tops[idx.clamp(0, tops.length - 1)].$1;
          }
        } else {
          mv = await AiIsolate.bestMoveTimed(
            board, p1Hand, p2Hand, aiIsP1,
            budget: Duration(milliseconds: budgetMs),
            personality: pers,
            persAiIsP1: aiIsP1,
          );
        }
      }

      if (mv == null) {
        _aiElapsedTimer?.cancel();
        if (mounted) setState(() => _aiThinking = false);
        return;
      }
      // AIが空マスからの手を生成していないか事前確認（AI バグ防止）
      if (mv.drop == null && board[mv.fr][mv.fc] == null) {
        _aiElapsedTimer?.cancel();
        if (mounted) setState(() => _aiThinking = false);
        return;
      }
      _aiElapsedTimer?.cancel();
      if (mounted) {
        setState(() {
          _applyAIMove(mv!);
          _aiThinking = false;
        });
      }
    } catch (e) {
      _aiElapsedTimer?.cancel();
      // エラーログを記録
      FirebaseLoggingService.logError(
        errorType: 'ai_crash',
        message: e.toString(),
        context: 'game_screen_runAI',
      );
      if (mounted) {
        setState(() => _aiThinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI思考中にエラーが発生しました。棋譜は自動保存されています。'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _applyAIMove(AMove mv) {
    if (s.coachMode) _saveSnap(); // スナップショット保存（AI指手前）
    final aiP1 = !s.aiIsP2;
    final srcPiece = mv.drop == null ? board[mv.fr][mv.fc] : null;
    final note = mv.drop != null
        ? '${_sq(mv.tr, mv.tc)}${pieceLabel(mv.drop!)}打'
        : '${_sq(mv.tr, mv.tc)}${srcPiece?.label ?? "?"}${mv.promote ? "成" : ""}';

    if (mv.drop != null) {
      SoundService.playDrop();
      board[mv.tr][mv.tc] = Piece(mv.drop!, aiP1);
      final h = aiP1 ? p1Hand : p2Hand;
      h[mv.drop!] = (h[mv.drop!] ?? 1) - 1;
      if (h[mv.drop!] == 0) h.remove(mv.drop!);
    } else {
      final piece = srcPiece;
      if (piece == null) return; // _runAI 側でガード済みだが防御的チェック
      final cap = board[mv.tr][mv.tc];
      if (cap != null) {
        SoundService.playCapture();
        _triggerCaptureBurst(mv.tr, mv.tc);
        final h = aiP1 ? p1Hand : p2Hand;
        final bt = cap.baseType;
        h[bt] = (h[bt] ?? 0) + 1;
      } else {
        SoundService.playMove();
      }
      board[mv.tr][mv.tc] = mv.promote
          ? Piece(piece.promotedType, piece.isPlayer1)
          : piece;
      board[mv.fr][mv.fc] = null;
    }
    lastFR = mv.fr;
    lastFC = mv.fc;
    lastTR = mv.tr;
    lastTC = mv.tc;
    _lastWasPromotion = mv.promote;
    kifu.add(
      KifuMove(
        kifu.length + 1,
        aiP1,
        note,
        fr: mv.fr,
        fc: mv.fc,
        tr: mv.tr,
        tc: mv.tc,
        drop: mv.drop,
        promote: mv.promote,
      ),
    );
    _hintMove = null;
    // アニメーション完了後に _endTurn() を実行（駒が動ききるまで次の処理を待つ）
    _animating = true;
    _anim.forward(from: 0).then((_) {
      _animating = false;
      if (mounted) _endTurn();
    });
  }

  // ===== 投了 =====
  Future<void> _resign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('投了しますか？'),
        content: Text('${p1Turn ? "▲先手" : "△後手"}が投了します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('投了する', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      SoundService.playResign();
      setState(() {
        result = p1Turn ? '後手の勝ち！（先手投了）' : '先手の勝ち！（後手投了）';
        _timer?.cancel();
      });
      // 投了確定の視覚的な締め（灰色トーンの散り演出。詰み等と違って
      // 勝利側がいないため、常に「負け」トーンで表示する）
      _triggerConfetti(false);
      if (vsAI) _updateWinStreak(false);
      if (mounted) Future.microtask(() => _showGameEndDialog());
    }
  }

  // ===== KIF エクスポート =====
  void _showKifExport() {
    final buf = StringBuffer();
    buf.writeln('# 将棋アプリ 棋譜');
    buf.writeln('# ${DateTime.now().toString().substring(0, 16)}');
    buf.writeln('手数----指手----------');
    for (final m in kifu) {
      buf.writeln(m.text);
    }
    final text = buf.toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('棋譜エクスポート', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2A40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('コピー'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('クリップボードにコピーしました'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('シェア'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await Share.share(text, subject: '将棋棋譜');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ===== AI考慮前の中間棋譜を保存（クラッシュ対策）=====
  Future<void> _saveGameSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = {
        'timestamp': DateTime.now().toString(),
        'moves': kifu.map((m) => m.toJson()).toList(),
        'p1Turn': p1Turn,
        'result': result,
      };
      await prefs.setString('game_snapshot_backup', jsonEncode(snapshot));
      await prefs.setBool('has_game_snapshot', true);
    } catch (e) {
      // 無視（スナップショット失敗がゲーム進行を止めないように）
    }
  }

  // ===== クラッシュからの自動復旧 =====
  Future<void> _checkAndRestoreGameSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSnapshot = prefs.getBool('has_game_snapshot') ?? false;
      if (!hasSnapshot || !mounted) return;

      final raw = prefs.getString('game_snapshot_backup');
      if (raw == null) {
        await prefs.setBool('has_game_snapshot', false);
        return;
      }

      final snapshot = jsonDecode(raw) as Map<String, dynamic>;
      final response = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('対局を復旧しますか？', style: TextStyle(color: Colors.white)),
          content: Text(
            'AI思考中にエラーが発生した可能性があります。\n'
            '前回の対局状態から再開しますか？\n'
            '※キャンセルすると新しく開始します。',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('新しく開始'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('復旧する', style: TextStyle(color: Colors.lightBlue)),
            ),
          ],
        ),
      );

      if (response == true) {
        _restoreGameSnapshot(snapshot);
      } else {
        await prefs.setBool('has_game_snapshot', false);
      }
    } catch (e) {
      // 復旧失敗時は無視して新規開始
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_game_snapshot', false);
    }
  }

  // ===== スナップショットから復旧（棋譜から盤面を再生）=====
  void _restoreGameSnapshot(Map<String, dynamic> snapshot) {
    try {
      final movesData = snapshot['moves'] as List<dynamic>;
      final moves = movesData.map((m) => KifuMove.fromJson(m as Map<String, dynamic>)).toList();

      // 初期盤面にリセット
      board = _initBoard(s.handicap);
      p1Hand.clear();
      p2Hand.clear();
      p1Turn = true;
      kifu.clear();
      _repChecker.reset(); // 復旧時に千日手カウントをリセット

      // 棋譜を再生して盤面を復旧
      for (final move in moves) {
        if (move.drop != null) {
          if (!GL.ok(move.tr, move.tc)) continue; // 破損データ guard
          board[move.tr][move.tc] = Piece(move.drop!, move.p1);
          final h = move.p1 ? p1Hand : p2Hand;
          final cnt = h[move.drop!] ?? 0;
          if (cnt <= 1) h.remove(move.drop!); else h[move.drop!] = cnt - 1;
        } else {
          if (!GL.ok(move.fr, move.fc) || !GL.ok(move.tr, move.tc)) continue; // 破損データ guard
          final piece = board[move.fr][move.fc];
          if (piece != null) {
            final cap = board[move.tr][move.tc];
            if (cap != null) {
              final h = move.p1 ? p1Hand : p2Hand;
              h[cap.baseType] = (h[cap.baseType] ?? 0) + 1;
            }
            board[move.tr][move.tc] = move.promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
            board[move.fr][move.fc] = null;
          }
        }
        kifu.add(move);
        p1Turn = !p1Turn;
      }

      // スナップショットから保存されたターン状態を復旧
      if (snapshot['p1Turn'] != null) {
        p1Turn = snapshot['p1Turn'] as bool;
      }

      result = snapshot['result'];
      _updateAtkMap();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('対局を復旧しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('復旧に失敗しました。新しく開始します。'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ===== 棋譜を保存（JSON 複数対応）=====
  // recordStats: 対局統計・修練値・ストリークを加算するか。
  // 1局につき1回（対局終了時の自動保存）のみtrueにすること。オーバーフロー
  // メニューからの手動保存で何度も呼ばれても統計が水増しされないよう分離している。
  Future<void> _saveKifu({bool recordStats = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 既存リストを読み込み
      final raw = prefs.getString('kifu_records') ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      // 新しいレコードを先頭に追加（最大20件）
      final castle = _detectCastle();
      final tags = <String>[
        if (_openingLabel.isNotEmpty) _openingLabel,
        if (castle.isNotEmpty) castle,
        ..._castleTags.values,
      ];
      final record = {
        'date': DateTime.now().toString().substring(0, 16),
        'result': result ?? '未完了',
        'mode': s.mode == GameMode.vsAI ? 'AI対局' : '二人対局',
        'handicap': s.handicap.label,
        'moveCount': kifu.length,
        'opening': _openingLabel,
        'castle': castle,
        'tags': tags,
        'castleTags': _castleTags.map((k, v) => MapEntry(k.toString(), v)),
        'autoComment': _genAutoComment(),
        'moves': kifu.map((m) => m.toJson()).toList(),
      };
      list.insert(0, record);
      // 定跡統計（opening_stats_screen.dart）が意味のあるサンプル数を
      // 確保できるよう、以前の20件から拡大している
      if (list.length > 100) list.removeLast();
      await prefs.setString('kifu_records', jsonEncode(list));
      if (recordStats) {
        // 対局統計を更新
        await _updateStats();
        // ゴーストデータをバックグラウンドでアップロード（fire-and-forget）
        GhostService.updateMyGhost();
        // ストリーク更新（週次・月次）
        await _updateStreaks();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('棋譜を保存しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final ex = SaveException.kifuSaveFailed(cause: e is Exception ? e : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ex.userMessage),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ===== 棋譜コメント自動生成 =====
  String _genAutoComment() {
    if (_evalHistory.length < 3 || kifu.length < 3) return '';
    final evals = [0, ..._evalHistory];
    int blunderIdx = -1, blunderDelta = 0;
    int goodIdx = -1, goodDelta = 0;
    final limit = kifu.length < evals.length - 1
        ? kifu.length
        : evals.length - 1;
    for (int i = 0; i < limit; i++) {
      final delta = evals[i + 1] - evals[i];
      final wasP1 = kifu[i].p1;
      final moverDelta = wasP1 ? delta : -delta;
      if (-moverDelta > blunderDelta) {
        blunderDelta = -moverDelta;
        blunderIdx = i;
      }
      if (moverDelta > goodDelta) {
        goodDelta = moverDelta;
        goodIdx = i;
      }
    }
    final parts = <String>[];
    if (blunderIdx >= 0 && blunderIdx < kifu.length && blunderDelta >= 200) {
      final m = kifu[blunderIdx];
      final who = m.p1 ? '▲' : '△';
      parts.add('${m.num}手目${who}${m.note}は疑問手(-${blunderDelta}点)');
    }
    if (goodIdx >= 0 && goodIdx < kifu.length && goodDelta >= 150) {
      final m = kifu[goodIdx];
      final who = m.p1 ? '▲' : '△';
      parts.add('${m.num}手目${who}${m.note}が好手(+${goodDelta}点)');
    }
    if (parts.isEmpty) return '${kifu.length}手の熱戦。';
    return parts.join('。') + '。';
  }

  // ===== 局面ブックマーク: 件数ロード =====
  Future<void> _loadBookmarkCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('board_bookmarks') ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      if (mounted) setState(() => _bookmarkCount = list.length);
    } catch (_) {}
  }

  // ===== 局面ブックマーク: 保存 =====
  Future<void> _bookmarkPosition() async {
    try {
      final boardEnc = board
          .map(
            (row) => row.map((p) {
              if (p == null) return null;
              return {'t': p.type.index, 'p1': p.isPlayer1};
            }).toList(),
          )
          .toList();
      final p1HandEnc = p1Hand.map((k, v) => MapEntry(k.index.toString(), v));
      final p2HandEnc = p2Hand.map((k, v) => MapEntry(k.index.toString(), v));
      final entry = {
        'date': DateTime.now().toString().substring(0, 16),
        'moveNum': kifu.length,
        'p1Turn': p1Turn,
        'board': boardEnc,
        'p1Hand': p1HandEnc,
        'p2Hand': p2HandEnc,
      };
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('board_bookmarks') ?? '[]';
      final list = jsonDecode(raw) as List;
      list.insert(0, entry);
      if (list.length > 10) list.removeLast();
      await prefs.setString('board_bookmarks', jsonEncode(list));
      if (mounted) {
        setState(() => _bookmarkCount = list.length);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('局面をブックマークしました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  // ===== 局面ブックマーク: 一覧表示 =====
  Future<void> _showBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('board_bookmarks') ?? '[]';
    List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      list = [];
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('局面ブックマーク', style: TextStyle(color: Colors.white)),
        content: list.isEmpty
            ? const Text('ブックマークなし', style: TextStyle(color: Colors.white54))
            : SizedBox(
                width: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final bm = list[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.bookmark, color: Colors.amber),
                      title: Text(
                        '${bm['moveNum']}手目  ${bm['date']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _loadBookmark(bm);
                        },
                        child: const Text(
                          '再現',
                          style: TextStyle(color: Colors.amber),
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ===== 局面ブックマーク: 再現ロード =====
  void _loadBookmark(Map<String, dynamic> bm) {
    try {
      final boardDecoded = (bm['board'] as List)
          .map(
            (row) => (row as List).map<Piece?>((cell) {
              if (cell == null) return null;
              final c = cell as Map<String, dynamic>;
              final typeIdx = c['t'] as int? ?? 0;
              if (typeIdx < 0 || typeIdx >= PieceType.values.length)
                return null;
              return Piece(
                PieceType.values[typeIdx],
                (c['p1'] as bool?) ?? true,
              );
            }).toList(),
          )
          .toList();
      final p1HandDecoded = <PieceType, int>{};
      final p2HandDecoded = <PieceType, int>{};
      (bm['p1Hand'] as Map<String, dynamic>).forEach((k, v) {
        final idx = int.tryParse(k) ?? -1;
        if (idx >= 0 && idx < PieceType.values.length) {
          p1HandDecoded[PieceType.values[idx]] = v as int;
        }
      });
      (bm['p2Hand'] as Map<String, dynamic>).forEach((k, v) {
        final idx = int.tryParse(k) ?? -1;
        if (idx >= 0 && idx < PieceType.values.length) {
          p2HandDecoded[PieceType.values[idx]] = v as int;
        }
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            settings: widget.settings,
            initialBoard: boardDecoded,
            initialP1Hand: p1HandDecoded,
            initialP2Hand: p2HandDecoded,
            initialP1Turn: bm['p1Turn'] as bool? ?? true,
          ),
        ),
      );
    } catch (_) {}
  }

  // ===== 対局ミッション: 初期化 =====
  void _initMissions() {
    final all = [
      _MissionDef(id: 'capture_rook', label: '飛車を取る', icon: '🏰'),
      _MissionDef(id: 'capture_bishop', label: '角を取る', icon: '🔮'),
      _MissionDef(id: 'capture_2silver', label: '銀を2枚取る', icon: '🥈'),
      _MissionDef(id: 'promote_bishop', label: '馬を作る', icon: '🐴'),
      _MissionDef(id: 'promote_rook', label: '龍を作る', icon: '🐉'),
      _MissionDef(id: 'check_once', label: '王手をかける', icon: '⚡'),
    ];
    all.shuffle();
    _missions.clear();
    _missions.addAll(all.take(3));
  }

  // ===== 対局ミッション: チェック =====
  void _checkMissions() {
    if (_missions.isEmpty || result != null) return;
    final humanIsP1 = !vsAI || s.aiIsP2;
    final humanHand = humanIsP1 ? p1Hand : p2Hand;
    // check_once: did we put opponent in check? (next player = !p1Turn at call time before switch)
    final opponentInCheck = GL.inCheck(board, !p1Turn);
    for (final m in _missions) {
      if (m.completed) continue;
      bool done = false;
      switch (m.id) {
        case 'capture_rook':
          done = (humanHand[PieceType.rook] ?? 0) > 0;
          break;
        case 'capture_bishop':
          done = (humanHand[PieceType.bishop] ?? 0) > 0;
          break;
        case 'capture_2silver':
          done = (humanHand[PieceType.silver] ?? 0) >= 2;
          break;
        case 'promote_bishop':
          done = board.any(
            (row) => row.any(
              (p) =>
                  p != null &&
                  p.isPlayer1 == humanIsP1 &&
                  p.type == PieceType.promotedBishop,
            ),
          );
          break;
        case 'promote_rook':
          done = board.any(
            (row) => row.any(
              (p) =>
                  p != null &&
                  p.isPlayer1 == humanIsP1 &&
                  p.type == PieceType.promotedRook,
            ),
          );
          break;
        case 'check_once':
          // human just moved and opponent is in check
          final humanJustMoved = p1Turn == humanIsP1;
          done = humanJustMoved && opponentInCheck;
          break;
      }
      if (done) {
        m.completed = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎯 ミッション達成！ ${m.icon} ${m.label}'),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // ===== 対局ミッション: UIパネル =====
  Widget _missionPanel() {
    if (!_showMissionPanel || _missions.isEmpty) return const SizedBox.shrink();
    final done = _missions.where((m) => m.completed).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        border: Border.all(color: Colors.deepPurple.shade800, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.deepPurpleAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                'ミッション $done/${_missions.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _missions
                .map(
                  (m) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: m.completed
                          ? Colors.green.withAlpha(40)
                          : Colors.white.withAlpha(8),
                      border: Border.all(
                        color: m.completed
                            ? Colors.green.shade700
                            : Colors.white24,
                        width: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.icon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          m.label,
                          style: TextStyle(
                            color: m.completed
                                ? Colors.green.shade300
                                : Colors.white54,
                            fontSize: 11,
                            decoration: m.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ===== この局面をフィードバック報告 =====
  void _reportPosition() {
    // 直近20手の棋譜テキストを作成
    final recent = kifu.length > 20 ? kifu.sublist(kifu.length - 20) : kifu;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          board: board,
          p1Hand: Map.from(p1Hand),
          p2Hand: Map.from(p2Hand),
          recentKifu: recent.map((m) => m.text).toList(),
          moveCount: kifu.length,
        ),
      ),
    );
  }

  // ===== 対局統計を更新 =====
  Future<void> _updateStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final total = (prefs.getInt('stats_total') ?? 0) + 1;
      await prefs.setInt('stats_total', total);
      await prefs.setInt(
        'stats_moves_sum',
        (prefs.getInt('stats_moves_sum') ?? 0) + kifu.length,
      );
      // AI対局の総数（勝敗に関わらず加算。弱点分析系画面の勝率計算に使用）
      if (vsAI) {
        await prefs.setInt(
          'stats_total_ai',
          (prefs.getInt('stats_total_ai') ?? 0) + 1,
        );
      } else {
        await prefs.setInt(
          'stats_total_pvp',
          (prefs.getInt('stats_total_pvp') ?? 0) + 1,
        );
      }

      // 勝敗判定（_resultWonBy: startsWith ベースで判定。理由は同メソッド参照）
      bool? playerWon;
      final p1Won = _resultWonBy('先手');
      final p2Won = _resultWonBy('後手');
      if (result != null) {
        if (vsAI) {
          // AI が後手(aiIsP2=true)なら player は先手(P1)。
          // 以前は !s.aiIsP2 としており符号が逆で、
          // 既定設定（AIが後手）で勝っても敗北判定されレーティングが
          // 下がるバグの原因になっていた。
          final playerIsP1 = s.aiIsP2;
          playerWon = (p1Won && playerIsP1) || (p2Won && !playerIsP1);
        }
        if (p1Won) {
          await prefs.setInt(
            'stats_p1_wins',
            (prefs.getInt('stats_p1_wins') ?? 0) + 1,
          );
          await prefs.setInt(
            vsAI ? 'stats_p1_wins_ai' : 'stats_p1_wins_pvp',
            (prefs.getInt(vsAI ? 'stats_p1_wins_ai' : 'stats_p1_wins_pvp') ??
                    0) +
                1,
          );
        } else if (p2Won) {
          await prefs.setInt(
            'stats_p2_wins',
            (prefs.getInt('stats_p2_wins') ?? 0) + 1,
          );
          await prefs.setInt(
            vsAI ? 'stats_p2_wins_ai' : 'stats_p2_wins_pvp',
            (prefs.getInt(vsAI ? 'stats_p2_wins_ai' : 'stats_p2_wins_pvp') ??
                    0) +
                1,
          );
        }
      }

      // バッジ判定用の集計キー（プレイヤー視点の通算勝利）
      if (playerWon == true) {
        await prefs.setInt(
          'stats_total_wins',
          (prefs.getInt('stats_total_wins') ?? 0) + 1,
        );
        // キャラクター絆レベル（選択中のアバターでのAI対局勝利数）
        if (_charIconId != null) {
          await CharacterBondService.addWin(_charIconId!);
        }
      }
      if (s.variant != VariantType.normal) {
        await prefs.setBool('stats_variant_${s.variant.name}', true);
      }

      // 修練値の追加（対局するだけで貯まる）
      await PracticePointsSystem.addPointsForGame(
        moveCount: kifu.length,
        playerWon: playerWon ?? false,
        viewedAnalysis: false,
      );

      // ストリーク更新ロジック（敗北時も感想戦ストリークを追加）
      await _updatePracticeStreak();

      // 棋風診断用統計（先手視点）
      final playerMoves = vsAI
          ? kifu.where((m) => m.p1 != s.aiIsP2).toList()
          : kifu.where((m) => m.p1).toList();
      final totalPM = playerMoves.length;
      if (totalPM > 0) {
        final attackMvs = playerMoves
            .where((m) => m.drop == null && m.tr < m.fr)
            .length;
        final retreatMvs = playerMoves
            .where((m) => m.drop == null && m.tr > m.fr)
            .length;
        final dropMvs = playerMoves.where((m) => m.drop != null).length;
        await prefs.setInt(
          'playstyle_attack',
          (prefs.getInt('playstyle_attack') ?? 0) + attackMvs,
        );
        await prefs.setInt(
          'playstyle_retreat',
          (prefs.getInt('playstyle_retreat') ?? 0) + retreatMvs,
        );
        await prefs.setInt(
          'playstyle_drop',
          (prefs.getInt('playstyle_drop') ?? 0) + dropMvs,
        );
        await prefs.setInt(
          'playstyle_total',
          (prefs.getInt('playstyle_total') ?? 0) + totalPM,
        );
        await prefs.setInt(
          'playstyle_games',
          (prefs.getInt('playstyle_games') ?? 0) + 1,
        );
      }

      // リベンジ用：敗着検出（プレイヤーが負けた場合）
      if (playerWon == false && kifu.length >= 2) {
        _detectDefeatMove();
      }

      // レーティング更新（AI対局・レーティング戦のみ。駒落ちは対象外）
      if (vsAI && s.aiRated && s.handicap == Handicap.none && playerWon != null) {
        final prevRating = prefs.getInt('rating_ai_current') ?? 700;
        final prevRankStr = ratingToRank(prevRating);

        // Elo 変動量（難度別: random,easy,medium,hard,beginner,elementary,upperMedium,expert）
        final delta = playerWon
            ? [5, 10, 20, 35, 7, 15, 28, 50][s.aiLevel.index]
            : [-3, -7, -15, -20, -4, -10, -18, -30][s.aiLevel.index];
        final newRating = (prevRating + delta).clamp(0, 9999);

        await prefs.setInt('rating_ai_current', newRating);
        // rating_current はバッジ判定・棋力診断・マッチングなど多数の画面が
        // 参照する統一レーティング値。AI対局・ネット対局どちらのモードで
        // 上がったレーティングも失われないよう、両モードの高い方を採用する
        // （直近プレイしたモードで単純上書きすると、片方のモードで築いた
        // 実力が別モードの1敗で瞬時に下がって見えてしまうため）。
        final netRating = prefs.getInt('rating_net_current') ?? 0;
        await prefs.setInt('rating_current', newRating > netRating ? newRating : netRating);
        // ローカルの進捗（レーティング・バッジ・対局数）をサーバーへも反映する
        // （pushUserData()自体は定義済みだったがどこからも呼ばれておらず、
        // 端末を変えるとローカルのみの進捗が失われる状態だった）。
        CloudSyncService.pushUserData();

        // 昇段チェック
        final newRankStr = ratingToRank(newRating);
        if (newRankStr != prevRankStr && delta > 0 && mounted) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            await showRankUpDialog(
              context,
              newRankStr,
              ratingToColor(newRating),
            );
          }
        }
      }

      // ── バッジ（実績）判定 ─────────────────────────────────
      const aiLevelBadgeMap = {
        AILevel.medium: 'medium',
        AILevel.hard: 'hard',
        AILevel.expert: 'super_hard',
      };
      final newBadges = await BadgeService.check(
        prefs,
        isWin: playerWon ?? false,
        isVariant: s.variant != VariantType.normal,
        isAiGame: vsAI,
        aiLevel: vsAI ? (aiLevelBadgeMap[s.aiLevel] ?? '') : '',
        moveCount: kifu.length,
      );
      if (newBadges.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) await _showBadgeUnlockDialog(newBadges);
      }
    } catch (e) {
      final ex = SaveException.statisticsUpdateFailed(cause: e is Exception ? e : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ex.userMessage),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ===== バッジ解除ダイアログ =====
  Future<void> _showBadgeUnlockDialog(List<BadgeDef> badges) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          side: BorderSide(color: AppTheme.accent.withAlpha(100)),
        ),
        title: Text(
          badges.length > 1 ? '実績解除！' : '実績解除',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: badges.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: b.color.withAlpha(40),
                    shape: BoxShape.circle,
                    border: Border.all(color: b.color.withAlpha(150)),
                  ),
                  child: Icon(b.icon, color: b.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.description,
                        style: TextStyle(color: AppTheme.textMid, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('閉じる', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  // ===== ストリーク更新（週次・月次） =====
  Future<void> _updateStreaks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final weekKey = '${now.year}-W${(now.day / 7).ceil()}';
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // vsAI では「プレイヤー自身」が勝った場合のみカウント（相手＝AIの勝ちで
      // 誤加算しないよう startsWith ベースの _resultWonBy で判定）
      final playerWonThisGame = vsAI
          ? _resultWonBy(_userIsP2 ? '後手' : '先手')
          : (result != null && result!.contains('勝'));
      if (playerWonThisGame) {
        // 勝利時のみストリーク更新
        final weekStreak = (prefs.getInt('weekly_streak_$weekKey') ?? 0) + 1;
        final monthStreak = (prefs.getInt('monthly_streak_$monthKey') ?? 0) + 1;
        await prefs.setInt('weekly_streak_$weekKey', weekStreak);
        await prefs.setInt('monthly_streak_$monthKey', monthStreak);
      } else if (result != null) {
        // 敗北時はストリークリセット
        await prefs.remove('weekly_streak_$weekKey');
        await prefs.remove('monthly_streak_$monthKey');
      }
    } catch (_) {}
  }

  // ===== 連勝/連敗カウンター更新 =====
  Future<void> _updateWinStreak(bool playerWon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (playerWon) {
        final streak = (prefs.getInt('win_streak_ai') ?? 0) + 1;
        await prefs.setInt('win_streak_ai', streak);
        await prefs.setInt('loss_streak_ai', 0);
        if (mounted)
          setState(() {
            _winStreak = streak;
            _lossStreak = 0;
          });
      } else {
        final loss = (prefs.getInt('loss_streak_ai') ?? 0) + 1;
        await prefs.setInt('loss_streak_ai', loss);
        await prefs.setInt('win_streak_ai', 0);
        if (mounted)
          setState(() {
            _winStreak = 0;
            _lossStreak = loss;
          });
      }
    } catch (_) {}
  }

  // ===== 感想戦ストリーク更新（敗北時も日数カウント） =====
  Future<void> _updatePracticeStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastStreakDate = prefs.getString('practice_streak_date') ?? '';

      if (lastStreakDate != todayStr) {
        // 新しい日付 → ストリークを +1
        final streak = (prefs.getInt('practice_streak_days') ?? 0) + 1;
        await prefs.setInt('practice_streak_days', streak);
        await prefs.setString('practice_streak_date', todayStr);
      }
      // 同じ日付なら何もしない（1日1回のみカウント）
    } catch (_) {}
  }

  // ===== 敗北体験シート表示 =====
  Future<void> _showDefeatExperienceSheet() async {
    if (!mounted) return;

    try {
      // 基本チェック
      if (result == null || result!.isEmpty) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final streakDays = prefs.getInt('practice_streak_days') ?? 0;
      final isPremium = PurchaseService.isPremium;

      // 今回の対局で獲得した修練値を計算
      final todayPoints = await _calculateTodayPracticePoints();

      // プレミアム分析情報を計算（例外をキャッチ）
      late final (String?, String?) analysisData;
      try {
        analysisData = _analyzeDefeatMove();
      } catch (e) {
        analysisData = (null, null);
      }

      if (!mounted) return;

      // マウント確認
      if (!mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      showModalBottomSheet(
        context: context,
        isDismissible: true,
        isScrollControlled: true,
        builder: (_) => DefeatScreen(
          analysis: DefeatAnalysis(
            moveCount: kifu.length,
            evaluations: _evalHistory.isNotEmpty ? _evalHistory : [],
            bestMoveAtKey: analysisData.$2,
            actualMove: analysisData.$1,
            playerWon: false,
          ),
          opponentCharacterId: s.opponentCharacterId ?? 'samurai',
          opponentCharacterName: _getCharacterName(),
          isPremium: isPremium,
          practicePoints: todayPoints,
          streakDays: streakDays,
          evaluationHistory: _evalHistory.isNotEmpty ? _evalHistory : null,
          suggestedBestMove: analysisData.$2,
          failedMove: analysisData.$1,
          onViewAnalysis: () {
            Navigator.pop(context);
            final initialBoard = _boardSnaps.isNotEmpty
                ? _boardSnaps.first
                : _initBoard(s.handicap);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KansousenScreen(
                  moves: List.from(kifu),
                  initialBoard: initialBoard,
                  title: '${kifu.length}手の対局',
                  pieceTheme: s.theme,
                ),
              ),
            );
          },
          onPlayAgain: () {
            Navigator.pop(context);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          onClose: () {
            try {
              Navigator.pop(context);
              // 敗北後はホーム画面に戻す
              Navigator.of(context).popUntil((route) => route.isFirst);
            } catch (_) {
              // Navigator エラーを無視
            }
          },
        ),
      );
    } catch (e) {
      // エラーログを出力（本番では Firebase Crashlytics に送信）
      print('DefeatExperienceSheet error: $e');

      // エラー時でもホーム画面に戻す
      try {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (_) {}
    }
  }

  // ===== 本日の修練値を計算 =====
  Future<int> _calculateTodayPracticePoints() async {
    int points = PracticePointsSystem.pointsPerGame;

    // 勝利ボーナス（敗北時は 0）
    // points += 0;

    // 長手数ボーナス
    if (kifu.length >= 30) {
      points += PracticePointsSystem.bonusPointsForLongGame;
    }

    return points;
  }

  // ===== 敗着分析（敗北後の AI分析用） =====
  (String?, String?) _analyzeDefeatMove() {
    try {
      if (kifu.isEmpty) return (null, null);

      // 最後の数手の中で最大の評価値ロスを検出
      String? worstMove;
      String? suggestedMove;

      try {
        // シンプル実装：最後の手を「敗着」と見なす
        final lastMove = kifu.last;
        worstMove = _formatMove(lastMove);
        suggestedMove = '△${lastMove.tr}${lastMove.fc}'; // 簡易版
      } catch (_) {
        return (null, null);
      }

      return (worstMove, suggestedMove);
    } catch (e) {
      print('AnalyzeDefeatMove error: $e');
      return (null, null);
    }
  }

  String _formatMove(dynamic move) {
    // 棋譜表記を生成（簡易版）
    try {
      if (move == null) return '???';

      // move オブジェクトが持つメンバーにアクセス
      if (move is Map) {
        final fr = move['fr'] as int?;
        final fc = move['fc'] as int?;
        final tr = move['tr'] as int?;
        final tc = move['tc'] as int?;
        if (fr != null && fc != null && tr != null && tc != null) {
          // 範囲チェック（0-8 の有効な座標か確認）
          if (fr >= 0 && fr < 9 && fc >= 0 && fc < 9 &&
              tr >= 0 && tr < 9 && tc >= 0 && tc < 9) {
            return '${9 - fc}${9 - fr}${9 - tc}${9 - tr}';
          }
        }
      } else {
        // move が Map でない場合、その他のアクセス方法を試す
        final fr = (move as dynamic).fr as int?;
        final fc = (move as dynamic).fc as int?;
        final tr = (move as dynamic).tr as int?;
        final tc = (move as dynamic).tc as int?;
        if (fr != null && fc != null && tr != null && tc != null) {
          // 範囲チェック
          if (fr >= 0 && fr < 9 && fc >= 0 && fc < 9 &&
              tr >= 0 && tr < 9 && tc >= 0 && tc < 9) {
            return '${9 - fc}${9 - fr}${9 - tc}${9 - tr}';
          }
        }
      }
    } catch (e) {
      print('FormatMove error: $e');
      // エラーが発生した場合
    }
    return '???';
  }

  // ===== キャラクター名取得 =====
  String _getCharacterName() {
    try {
      if (s.opponentCharacterId == null || s.opponentCharacterId!.isEmpty) {
        return '謎の棋士';
      }

      // キャラクター ID から名前を取得（簡易版）
      const characterNames = {
        'brave': '勇者',
        'scholar': '学者',
        'wanderer': '放浪者',
        'elder': '老仙人',
      };

      return characterNames[s.opponentCharacterId] ?? '謎の棋士';
    } catch (_) {
      return '謎の棋士';
    }
  }

  // ===== リベンジ: 敗着から再開 =====
  Future<void> _loadDefeatAndReplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kifuJson = prefs.getString('last_defeat_kifu');
      if (kifuJson == null) return;

      final List<dynamic> moves = jsonDecode(kifuJson);
      final playerIsP1 = s.aiIsP2; // AI が後手なら player は先手

      // 初期盤面に戻す
      if (!mounted) return;
      setState(() {
        board = _initBoard(s.handicap);
        p1Hand = {};
        p2Hand = {};
        p1Turn = true;
        result = null;
        kifu = [];
        _coachInitialBoard = s.coachMode ? GL.copy(board) : null;
        _boardSnaps.clear();
        _p1HandSnaps.clear();
        _p2HandSnaps.clear();
        _p1TurnSnaps.clear();
        _clearSel();
        lastFR = null;
        lastFC = null;
        lastTR = null;
        lastTC = null;
        _hintMove = null;
      });

      // 敗着までの棋譜を再生
      for (final moveJson in moves) {
        if (moveJson is! Map<String, dynamic>) continue;
        final km = KifuMove.fromJson(moveJson);
        GL.applyKifuMove(board, p1Hand, p2Hand, km);
        kifu.add(km);
        p1Turn = !km.p1;
      }

      setState(() {
        _updateAtkMap();
        if (s.timeLimitSec != null) {
          p1Time = s.timeLimitSec!;
          p2Time = s.timeLimitSec!;
          _p1InByoyomi = false;
          _p2InByoyomi = false;
          _p1ByoyomiRemaining = 0;
          _p2ByoyomiRemaining = 0;
          _startTimer();
        }
      });

      // AIが後手の場合は思考開始
      if (vsAI && !s.aiIsP2 && p1Turn) {
        Future.delayed(const Duration(milliseconds: 600), _runAI);
      }
    } catch (_) {}
  }

  // ===== リベンジ: 敗着検出 =====
  Future<void> _detectDefeatMove() async {
    try {
      final playerIsP1 = s.aiIsP2; // AI が後手なら player は先手
      var testBoard = List.generate(9, (_) => List<Piece?>.filled(9, null));
      var testP1Hand = <PieceType, int>{};
      var testP2Hand = <PieceType, int>{};

      // 初期盤面をコピー
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          testBoard[i][j] = board[i][j];
        }
      }
      testP1Hand = Map.from(p1Hand);
      testP2Hand = Map.from(p2Hand);

      int defeatIdx = -1;
      int worstEval = 0;

      // 棋譜を再生しながら敗着を検出
      for (int i = 0; i < kifu.length; i++) {
        final move = kifu[i];
        final isPlayerMove = move.p1 == playerIsP1;

        if (isPlayerMove) {
          // 駒数ベースの簡易評価（少ないほど不利）
          int piecesOnBoard = 0;
          for (int r = 0; r < 9; r++)
            for (int c = 0; c < 9; c++)
              if (testBoard[r][c] != null &&
                  testBoard[r][c]!.isPlayer1 == playerIsP1)
                piecesOnBoard++;
          final handPieces = (playerIsP1 ? testP1Hand : testP2Hand).values.fold(
            0,
            (a, b) => a + b,
          );
          final eval = piecesOnBoard + handPieces;
          if (eval < worstEval || worstEval == 0) {
            worstEval = eval;
            defeatIdx = i;
          }
        }

        // 手を適用
        if (move.drop != null) {
          testBoard[move.tr][move.tc] = Piece(move.drop!, move.p1);
          final hand = move.p1 ? testP1Hand : testP2Hand;
          hand[move.drop!] = (hand[move.drop!] ?? 1) - 1;
          if (hand[move.drop!] == 0) hand.remove(move.drop!);
        } else {
          final piece = testBoard[move.fr][move.fc]!;
          final cap = testBoard[move.tr][move.tc];
          if (cap != null) {
            final hand = move.p1 ? testP1Hand : testP2Hand;
            hand[cap.baseType] = (hand[cap.baseType] ?? 0) + 1;
          }
          testBoard[move.tr][move.tc] = move.promote
              ? Piece(piece.promotedType, piece.isPlayer1)
              : piece;
          testBoard[move.fr][move.fc] = null;
        }
      }

      if (defeatIdx >= 0) {
        // 敗着までの棋譜を保存
        final defeatKifu = kifu.sublist(0, defeatIdx + 1);
        final kifuJson = defeatKifu.map((m) => m.toJson()).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_defeat_kifu', jsonEncode(kifuJson));
      }
    } catch (_) {}
  }

  // ===== セルタップ =====
  Future<void> _onCell(int row, int col) async {
    if (result != null || _aiThinking || _animating) return;
    if (vsAI && isAITurn) return;

    // 持ち駒を打つ
    if (selHand != null) {
      if (hl[row][col]) {
        final type = selHand!;
        final note = '${_sq(row, col)}${pieceLabel(type)}打';
        SoundService.playDrop();
        if (s.coachMode) _saveSnap(); // スナップショット保存
        setState(() {
          board[row][col] = Piece(type, p1Turn);
          final hand = p1Turn ? p1Hand : p2Hand;
          hand[type] = (hand[type] ?? 0) - 1;
          if ((hand[type] ?? 0) <= 0) hand.remove(type);
          lastFR = -1;
          lastFC = -1;
          lastTR = row;
          lastTC = col;
          _lastWasPromotion = false;
          kifu.add(
            KifuMove(
              kifu.length + 1,
              p1Turn,
              note,
              tr: row,
              tc: col,
              drop: type,
            ),
          );
          _hintMove = null;
          _clearSel();
          // アニメーション完了後に _endTurn() を実行
          _animating = true;
          _anim.forward(from: 0).then((_) {
            _animating = false;
            if (mounted) _endTurn();
          });
        });
      } else {
        setState(_clearSel);
      }
      return;
    }

    final piece = board[row][col];

    if (selR == null) {
      if (piece != null && piece.isPlayer1 == p1Turn) {
        final moves = GL.legal(board, row, col);
        setState(() {
          selR = row;
          selC = col;
          hl = _eHL();
          for (final m in moves) hl[m.$1][m.$2] = true;
        });
      }
      return;
    }

    if (selR == row && selC == col) {
      setState(_clearSel);
      return;
    }

    if (piece != null && piece.isPlayer1 == p1Turn) {
      final moves = GL.legal(board, row, col);
      setState(() {
        selR = row;
        selC = col;
        hl = _eHL();
        for (final m in moves) hl[m.$1][m.$2] = true;
      });
      return;
    }

    if (!hl[row][col]) {
      setState(_clearSel);
      return;
    }

    // 移動実行
    final moving = board[selR!][selC!]!;
    bool promote = false;
    bool inZone(bool p1, int r) => p1 ? r <= 2 : r >= 6;

    if (moving.canPromote) {
      if (moving.mustPromote(row)) {
        promote = true;
      } else if (inZone(moving.isPlayer1, selR!) ||
          inZone(moving.isPlayer1, row)) {
        promote = (await _askPromo()) ?? false;
      }
    }

    if (s.coachMode) _saveSnap(); // スナップショット保存（移動前）
    final cap = board[row][col];
    final note =
        '${_sq(row, col)}${moving.label}${promote ? "成" : ""}${cap != null ? "(取)" : ""}';
    final fr = selR!, fc = selC!;

    // 効果音（setState 前に呼ぶ）
    if (cap != null) {
      SoundService.playCapture();
      _triggerCaptureBurst(row, col);
    } else {
      SoundService.playMove();
    }

    setState(() {
      if (cap != null) {
        final bt = cap.baseType;
        final hand = p1Turn ? p1Hand : p2Hand;
        hand[bt] = (hand[bt] ?? 0) + 1;
      }
      board[row][col] = promote
          ? Piece(moving.promotedType, moving.isPlayer1)
          : moving;
      board[fr][fc] = null;
      lastFR = fr;
      lastFC = fc;
      lastTR = row;
      lastTC = col;
      _lastWasPromotion = promote;
      kifu.add(
        KifuMove(
          kifu.length + 1,
          p1Turn,
          note,
          fr: fr,
          fc: fc,
          tr: row,
          tc: col,
          promote: promote,
        ),
      );
      _hintMove = null;
      _clearSel();
      // アニメーション完了後に _endTurn() を実行
      _animating = true;
      _anim.forward(from: 0).then((_) {
        _animating = false;
        if (mounted) _endTurn();
      });
    });
  }

  // ===== 持ち駒タップ =====
  void _onHand(PieceType type, bool isP1) {
    if (result != null || _aiThinking) return;
    if (isP1 != p1Turn) return;
    if (vsAI && isAITurn) return;
    setState(() {
      if (selHand == type) {
        _clearSel();
        return;
      }
      _clearSel();
      selHand = type;
      // isP1 は現在の手番と同一（1468行でガード）
      // 正しい持ち駒と相手の持ち駒を渡す
      final hand = isP1 ? p1Hand : p2Hand;
      final oppHand = isP1 ? p2Hand : p1Hand;
      final drops = GL.dropSquares(board, type, isP1, hand, oppHand);
      hl = _eHL();
      for (final d in drops) hl[d.$1][d.$2] = true;
    });
  }

  // ===== 有利度計算（駒数ベース） =====
  double _advantageRatio() {
    int p1Score = 0, p2Score = 0;
    const values = {
      PieceType.king: 0,
      PieceType.rook: 5,
      PieceType.bishop: 3,
      PieceType.gold: 1,
      PieceType.silver: 1,
      PieceType.knight: 1,
      PieceType.lance: 1,
      PieceType.pawn: 1,
      PieceType.promotedRook: 6,
      PieceType.promotedBishop: 4,
    };
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null) {
          final val = values[piece.type] ?? 0;
          if (piece.isPlayer1)
            p1Score += val;
          else
            p2Score += val;
        }
      }
    }
    p1Hand.forEach((type, cnt) {
      final val = values[type] ?? 0;
      p1Score += val * cnt;
    });
    p2Hand.forEach((type, cnt) {
      final val = values[type] ?? 0;
      p2Score += val * cnt;
    });
    final total = p1Score + p2Score;
    return total == 0 ? 0.5 : p1Score / total;
  }

  // ===== テーマ =====
  Color get _cellColor {
    switch (s.theme) {
      case PieceTheme.dark:
        return const Color(0xFF6B5310);
      case PieceTheme.textured:
        return const Color(0xFFD4AF87); // 上品な金茶色
      case PieceTheme.standard:
      case PieceTheme.emerald:
      case PieceTheme.cherry:
        return const Color(0xFFDEB887);
    }
  }

  Color get _cellBorder {
    switch (s.theme) {
      case PieceTheme.dark:
        return const Color(0xFF3D2F0A);
      case PieceTheme.textured:
        return const Color(0xFF8D6E63); // 質感用ボーダー
      case PieceTheme.standard:
      case PieceTheme.emerald:
      case PieceTheme.cherry:
        return Colors.brown.shade600;
    }
  }

  Color? get _gradientTop {
    if (s.theme == PieceTheme.textured) {
      return const Color(0xFF3E2723); // グラデーション上部（濃い茶）
    }
    return null;
  }

  Color? get _gradientBottom {
    if (s.theme == PieceTheme.textured) {
      return const Color(0xFF5D4037); // グラデーション下部
    }
    return null;
  }

  Color pieceTextColor(Piece p) {
    // ユーザーの駒は青、相手の駒は赤系
    final isUserPiece = _userIsP2 ? !p.isPlayer1 : p.isPlayer1;

    if (isUserPiece) {
      // ユーザーの駒は青
      return p.isPromoted ? Colors.blue.shade200 : Colors.blue.shade600;
    } else {
      // 相手の駒は赤系
      if (s.theme == PieceTheme.dark)
        return p.isPromoted ? Colors.red.shade200 : Colors.red.shade300;
      return p.isPromoted ? Colors.red.shade600 : Colors.red.shade800;
    }
  }

  // 相手の駒がこの位置を取れるかチェック
  bool _canBeCaptured(int r, int c) {
    final piece = board[r][c];
    if (piece == null) return false;
    // 相手の全駒をチェック
    for (int pr = 0; pr < 9; pr++) {
      for (int pc = 0; pc < 9; pc++) {
        final p = board[pr][pc];
        if (p == null || p.isPlayer1 == piece.isPlayer1) continue;
        final moves = GL.pseudo(board, pr, pc);
        if (moves.any((m) => m.$1 == r && m.$2 == c)) {
          return true;
        }
      }
    }
    return false;
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    final inCheck = result == null && GL.inCheck(board, p1Turn);
    final gameInProgress = result == null && kifu.isNotEmpty;
    return PopScope(
      canPop: !gameInProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !gameInProgress) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('対局中です'),
            content: const Text('画面を離れると対局内容は保存されません。よろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('離れる', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          result != null
              ? result!
              : inCheck
              ? '${p1Turn ? "▲先手" : "△後手"} 王手！  ${kifu.length}手目'
              : '${kifu.length > 0 ? "${kifu.length}手目  " : ""}${p1Turn ? "▲ 先手の番" : "△ 後手の番"}',
          style: TextStyle(
            color: result != null
                ? Colors.amber
                : inCheck
                ? Colors.red.shade300
                : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (result == null && kifu.isNotEmpty)
            IconButton(
              icon: Icon(Icons.flag, color: Colors.red.shade300),
              tooltip: '投了',
              onPressed: _resign,
            ),
          // 棋譜/盤面切替（頻繁に使うため直接表示）
          IconButton(
            icon: Icon(
              showKifu ? Icons.grid_on : Icons.list_alt,
              color: Colors.white,
            ),
            tooltip: showKifu ? '盤面' : '棋譜',
            onPressed: () => setState(() => showKifu = !showKifu),
          ),
          _buildOverflowMenu(),
        ],
      ),
      body: showKifu ? _kifuView() : _gameView(),
      ),
    );
  }

  // ボタン過多でAppBarから溢れないよう、使用頻度の低い操作をここにまとめる
  Widget _buildOverflowMenu() {
    void newGame() => setState(() {
      board = _initBoard(s.handicap);
      p1Hand = {};
      p2Hand = {};
      p1Turn = true;
      result = null;
      kifu = [];
      _clearSel();
      lastFR = null;
      lastFC = null;
      lastTR = null;
      lastTC = null;
      _hintMove = null;
      _updateAtkMap();
      if (s.timeLimitSec != null) {
        p1Time = s.timeLimitSec!;
        p2Time = s.timeLimitSec!;
        _p1InByoyomi = false;
        _p2InByoyomi = false;
        _p1ByoyomiRemaining = 0;
        _p2ByoyomiRemaining = 0;
        _startTimer();
      }
      if (vsAI && !s.aiIsP2) {
        Future.delayed(const Duration(milliseconds: 600), _runAI);
      }
    });

    void openBookmarkMenu() {
      if (result != null) {
        _showBookmarks();
        return;
      }
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_add, color: Colors.amber),
                title: const Text('この局面をブックマーク',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _bookmarkPosition();
                },
              ),
              ListTile(
                leading: Icon(Icons.bookmarks, color: Colors.amber.shade300),
                title: Text('ブックマーク一覧 ($_bookmarkCount件)',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showBookmarks();
                },
              ),
            ],
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: AppTheme.surface,
      onSelected: (value) {
        switch (value) {
          case 'takata':
            _takata();
            break;
          case 'coach_report':
            _openCoachReport();
            break;
          case 'memo':
            _openMemoDialog();
            break;
          case 'analysis':
            setState(() {
              _analysisMode = !_analysisMode;
              if (_analysisMode) {
                _computeHint();
              } else {
                _hintMove = null;
              }
            });
            break;
          case 'sound':
            setState(() => SoundService.enabled = !SoundService.enabled);
            break;
          case 'attack_map':
            setState(() {
              showAttackMap = !showAttackMap;
              _updateAtkMap();
            });
            break;
          case 'screenshot':
            _captureBoard();
            break;
          case 'bookmark':
            openBookmarkMenu();
            break;
          case 'mission':
            setState(() => _showMissionPanel = !_showMissionPanel);
            break;
          case 'kif_export':
            _showKifExport();
            break;
          case 'save':
            _saveKifu();
            break;
          case 'report':
            _reportPosition();
            break;
          case 'new_game':
            if (result == null && kifu.isNotEmpty) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('新しく対局を始めますか？'),
                  content: const Text('現在の対局内容は破棄されます（保存していない場合、棋譜は失われます）。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        newGame();
                      },
                      child: const Text('新しく始める', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            } else {
              newGame();
            }
            break;
        }
      },
      itemBuilder: (context) => [
        if (s.coachMode && result == null && kifu.length >= (vsAI ? 2 : 1))
          PopupMenuItem(
            value: 'takata',
            child: _menuRow(Icons.undo, '待った（やり直し）',
                color: AppTheme.accent),
          ),
        if (s.coachMode && kifu.isNotEmpty)
          PopupMenuItem(
            value: 'coach_report',
            child: _menuRow(Icons.psychology_outlined, 'AI講評',
                color: Colors.deepPurpleAccent),
          ),
        PopupMenuItem(
          value: 'memo',
          child: _menuRow(
            _memos.containsKey(kifu.length)
                ? Icons.note
                : Icons.note_add_outlined,
            'メモ',
            color: _memos.containsKey(kifu.length) ? Colors.amber : null,
          ),
        ),
        PopupMenuItem(
          value: 'analysis',
          child: _menuRow(Icons.lightbulb_outline,
              _analysisMode ? '分析オフ' : '局面分析（ヒント）',
              color: _analysisMode ? Colors.yellow : null),
        ),
        PopupMenuItem(
          value: 'sound',
          child: _menuRow(
              SoundService.enabled ? Icons.volume_up : Icons.volume_off,
              SoundService.enabled ? '音をオフ' : '音をオン'),
        ),
        PopupMenuItem(
          value: 'attack_map',
          child: _menuRow(Icons.visibility,
              showAttackMap ? '利き非表示' : '利きを表示',
              color: showAttackMap ? Colors.orangeAccent : null),
        ),
        const PopupMenuItem(
          value: 'screenshot',
          child: _StaticMenuRow(Icons.camera_alt_outlined, '盤面を画像で共有'),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: _menuRow(Icons.bookmark_add_outlined,
              'ブックマーク ($_bookmarkCount件)',
              color: _bookmarkCount > 0 ? Colors.amber.shade300 : null),
        ),
        PopupMenuItem(
          value: 'mission',
          child: _menuRow(Icons.flag, 'ミッション',
              color: _showMissionPanel ? Colors.deepPurpleAccent : null),
        ),
        if (kifu.isNotEmpty)
          const PopupMenuItem(
            value: 'kif_export',
            child: _StaticMenuRow(Icons.file_download, '棋譜エクスポート'),
          ),
        if (kifu.isNotEmpty)
          const PopupMenuItem(
            value: 'save',
            child: _StaticMenuRow(Icons.save, '棋譜保存'),
          ),
        const PopupMenuItem(
          value: 'report',
          child: _StaticMenuRow(Icons.bug_report_outlined, 'バグ報告・改善要望'),
        ),
        const PopupMenuItem(
          value: 'new_game',
          child: _StaticMenuRow(Icons.refresh, '新局'),
        ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  // ===== 形勢に応じた臨場感のある背景 =====
  // 評価値(_evalScore: 正=先手有利/負=後手有利)に応じて、
  // 有利な側の色(先手=青系/後手=赤系)へ背景を染め、その陣側を濃くする。
  BoxDecoration _advantageDecoration() {
    const base = AppTheme.bg;      // 中立のベース
    const senteColor = Color(0xFF2A5CC4); // 先手＝青系（鮮やかに）
    const goteColor = Color(0xFFB0243F);  // 後手＝赤系（鮮やかに）
    const maxScore = 3000.0;
    final t = (_evalScore.clamp(-3000, 3000)) / maxScore; // -1..1
    final strength = t.abs();
    final lead = t >= 0 ? senteColor : goteColor;
    // 終局後は決着側の色をしっかり出す
    final boost = result != null ? 0.22 : 0.0;
    final strong = Color.lerp(base, lead, (strength * 0.85 + boost).clamp(0.0, 0.95))!;
    final mid = Color.lerp(base, lead, (strength * 0.45 + boost * 0.6).clamp(0.0, 0.55))!;
    final weak = Color.lerp(base, lead, (strength * 0.15).clamp(0.0, 0.2))!;
    // 有利側が画面の上下どちらにいるか（ユーザーは常に下＝!_userIsP2が先手側）
    final senteAdvant = _evalScore >= 0;
    final senteAtBottom = !_userIsP2;
    final strongAtBottom = senteAdvant == senteAtBottom;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: strongAtBottom ? [weak, mid, strong] : [strong, mid, weak],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  Widget _gameView() {
    // ユーザーは常に下に表示
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      decoration: _advantageDecoration(),
      child: SafeArea(
      child: Stack(
        children: [
          // メインレイアウト
          Column(
            children: [
              _playerBar(_userIsP2), // 相手は上
              _handBar(_userIsP2),
              _evalBar(), // 評価値バー
              // コーチバッジ
              if (s.coachMode && _coachBadgeText != null) _coachBadgeWidget(),
              // 連勝カウンター
              if (_winStreak >= 2 && result == null) _winStreakBanner(),
              _missionPanel(),
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _boardRepaintKey,
                    child: _boardWidget(),
                  ),
                ),
              ),
              // 対局後振り返り
              if (result != null && _bestMoveAfterGame != null) _bestMoveBar(),
              _handBar(!_userIsP2), // ユーザーは下
              _playerBar(!_userIsP2),
              if (_analysisMode || (s.coachMode && _hintMove != null))
                _hintBar(),
              // ゲーム終了時に広告を表示
              if (result != null) _adWidget(),
            ],
          ),
          // 王手フラッシュオーバーレイ
          if (_inCheckFlash)
            AnimatedBuilder(
              animation: _checkFlashAnim!,
              builder: (_, __) => IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red.withAlpha(
                        (_checkFlashAnim!.value * 180).toInt(),
                      ),
                      width: 6,
                    ),
                  ),
                ),
              ),
            ),
          // 紙吹雪オーバーレイ
          if (_showConfetti)
            AnimatedBuilder(
              animation: _confettiAnim!,
              builder: (_, __) => IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiAnim!.value,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          // 囲い完成バナー（盤面下・持ち駒エリア上に重ねる）
          if (_castleBannerText != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: _castleBannerWidget(),
            ),
        ],
      ),
      ),
    );
  }

  // ===== 囲い完成バナー（上品スタイル：書道風、派手さなし）=====
  Widget _castleBannerWidget() {
    return AnimatedBuilder(
      animation: _castleBannerAnim!,
      builder: (_, __) {
        final t = _castleBannerAnim!.value;
        // フェーズ: 0→0.2 フェードイン, 0.2→0.75 ホールド, 0.75→1.0 フェードアウト
        final opacity = t < 0.2
            ? t / 0.2
            : t > 0.75
                ? (1.0 - t) / 0.25
                : 1.0;
        // 右からスライドイン（フェードイン中のみ）
        final slide = t < 0.2 ? (1.0 - t / 0.2) * 24.0 : 0.0;
        return Transform.translate(
          offset: Offset(slide, 0),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xEC150B00),
                borderRadius: BorderRadius.circular(4),
                border: const Border(
                  left: BorderSide(color: Color(0xFFC8A45A), width: 3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28C8A45A),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.castle_outlined, color: Color(0xFFC8A45A), size: 15),
                  const SizedBox(width: 8),
                  Text(
                    _castleBannerText ?? '',
                    style: const TextStyle(
                      color: Color(0xFFF0DFBA),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===== 連勝バナー =====
  Widget _winStreakBanner() {
    final colors = _winStreak >= 5
        ? [Colors.amber.shade700, Colors.orange.shade600]
        : [Colors.green.shade800, Colors.teal.shade700];
    return TweenAnimationBuilder<double>(
      // keyでなくvalueKeyでウィジェットを作り直すことで、連勝数が更新される
      // たびにポップインアニメーションを再生する
      key: ValueKey(_winStreak),
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        height: 28,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
        child: Center(
          child: Text(
            '🔥 $_winStreak連勝中！',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ===== 対局後最善手バー =====
  Widget _bestMoveBar() {
    final mv = _bestMoveAfterGame!;
    final fromSq = mv.drop != null ? '持ち駒' : _sqLabel(mv.fr, mv.fc);
    final toSq = _sqLabel(mv.tr, mv.tc);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.deepPurple.shade900.withAlpha(220),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.psychology,
            color: Colors.deepPurpleAccent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '最善手: $fromSq → $toSq',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _sqLabel(int r, int c) {
    const cols = ['9', '8', '7', '6', '5', '4', '3', '2', '1'];
    const rows = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (r < 0 || r > 8 || c < 0 || c > 8) return '?';
    return '${cols[c]}${rows[r]}';
  }

  // ===== コーチバッジ =====
  Widget _coachBadgeWidget() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _coachBadgeColor.withAlpha(40),
        border: Border.all(color: _coachBadgeColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_coachBadgeIcon, color: _coachBadgeColor, size: 16),
          const SizedBox(width: 6),
          Text(
            _coachBadgeText!,
            style: TextStyle(
              color: _coachBadgeColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 評価値バー =====
  Widget _evalBar() {
    if (kifu.isEmpty) return const SizedBox(height: 6);
    const maxScore = 3000;
    final clamped = _evalScore.clamp(-maxScore, maxScore);
    final ratio = (clamped + maxScore) / (maxScore * 2);
    final p1Width = ratio;
    final label = _evalScore.abs() < 50
        ? '均衡'
        : (_evalScore > 0 ? '先手有利 +$_evalScore' : '後手有利 ${_evalScore}');
    return GestureDetector(
      onTap: _evalHistory.length >= 3 ? _showEvalGraph : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '▲先手',
                  style: TextStyle(color: Colors.blue.shade300, fontSize: 10),
                ),
                Flexible(
                  child: Row(
                  children: [
                    Flexible(
                      child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textLow,
                        fontSize: 10,
                      ),
                    )),
                    if (_openingLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withAlpha(40),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _openingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                    if (_evalHistory.length >= 3) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.show_chart, color: Colors.white30, size: 12),
                    ],
                  ],
                )),
                Text(
                  '△後手',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 10),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 9,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    return Stack(
                      children: [
                        // 後手側（赤）
                        Container(
                          width: totalWidth,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade900, Colors.red.shade500],
                            ),
                          ),
                        ),
                        // 先手側（青）— 評価値に応じて伸びる
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          width: totalWidth * p1Width,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade500, Colors.blue.shade900],
                            ),
                          ),
                        ),
                        // 中央の基準線
                        Positioned(
                          left: totalWidth / 2 - 0.5,
                          child: Container(
                            width: 1,
                            height: 9,
                            color: Colors.white38,
                          ),
                        ),
                        // 形勢の境目マーカー（白い縦線）
                        Positioned(
                          left: (totalWidth * p1Width - 1).clamp(
                            0.0,
                            totalWidth - 2,
                          ),
                          child: Container(width: 2, height: 9, color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ===== 評価グラフダイアログ =====
  void _showEvalGraph() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          '評価値グラフ',
          style: TextStyle(color: AppTheme.textHigh, fontSize: 16),
        ),
        content: SizedBox(
          width: 320,
          height: 200,
          child: CustomPaint(painter: _EvalGraphPainter(_evalHistory)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる', style: TextStyle(color: AppTheme.textMid)),
          ),
        ],
      ),
    );
  }

  // ===== ヒントバー =====
  Widget _hintBar() {
    if (_hintMove == null) {
      return Container(
        color: const Color(0xFF0A2040),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 16),
            const SizedBox(width: 8),
            const Text(
              '分析中...',
              style: TextStyle(color: Colors.yellow, fontSize: 13),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.yellow,
              ),
            ),
          ],
        ),
      );
    }
    final mv = _hintMove!;
    final from = mv.drop != null
        ? '持ち駒（${pieceLabel(mv.drop!)}）'
        : _sq(mv.fr, mv.fc);
    final to = _sq(mv.tr, mv.tc);
    return Container(
      color: const Color(0xFF0A3060),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.yellow, size: 16),
          const SizedBox(width: 8),
          Text(
            'ヒント: $from → $to',
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '(AIのおすすめ)',
            style: TextStyle(color: Colors.yellow.shade200, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ===== 広告ウィジェット（試合終了時） =====
  Widget _adWidget() {
    if (!_showAds) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '広告',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textLow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppTheme.rChip),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        'スポンサー広告',
                        textAlign: TextAlign.center,
                        style: AppTheme.body.copyWith(color: AppTheme.textMid, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _goToPremium,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          minimumSize: const Size(double.infinity, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.rBtn),
                          ),
                        ),
                        child: Text(
                          'プレミアムで広告を非表示',
                          style: AppTheme.label.copyWith(color: AppTheme.bg),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== プレイヤーバー（名前+タイマー）=====
  Widget _playerBar(bool isP1) {
    final active = (p1Turn == isP1) && result == null;
    final timeStr = s.timeLimitSec != null
        ? '  ⏱ ${_fmt(isP1 ? p1Time : p2Time)}'
        : '';
    final isAI = vsAI && (isP1 != s.aiIsP2);
    final isHumanPlayer = !isAI;

    // アイコン決定: 人間→自分のアイコン、AI→対戦相手キャラ
    CharacterIcon? charIcon;
    if (isHumanPlayer && _charIconId != null) {
      charIcon = findCharacterById(_charIconId!);
    } else if (isAI && s.opponentCharacterId != null) {
      charIcon = findCharacterById(s.opponentCharacterId!);
    }

    // AI名: キャラ名があれば使用
    final aiLabel = isAI && s.opponentCharacterId != null
        ? ' ${findCharacterById(s.opponentCharacterId!)?.name ?? "CPU"}'
        : isAI
        ? ' (CPU)'
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セリフバブル（AIの場合のみ）
        if (isAI && _dialogueVisible && _aiDialogue != null)
          AnimatedOpacity(
            opacity: _dialogueVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: charIcon != null
                    ? charIcon.bgColor.withAlpha(200)
                    : AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _aiDialogue!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: active ? AppTheme.surfaceHigh : AppTheme.surface,
            border: Border(
              left: BorderSide(
                color: active ? AppTheme.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              if (charIcon != null)
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: charIcon.bgColor,
                    shape: BoxShape.circle,
                    border: isAI
                        ? Border.all(
                            color: AppTheme.accent.withAlpha(180),
                            width: 2,
                          )
                        : Border.all(color: Colors.white30, width: 1),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppTheme.accent.withAlpha(70),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      charIcon.imagePath,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          charIcon!.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Icon(
                  isAI ? Icons.computer : Icons.person,
                  color: active ? AppTheme.textHigh : AppTheme.textLow,
                  size: 18,
                ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isP1 ? "▲ 先手" : "△ 後手"}$aiLabel',
                    style: TextStyle(
                      color: active ? AppTheme.textHigh : AppTheme.textLow,
                      fontSize: 13,
                    ),
                  ),
                  // AI難度表示（AI側のみ）
                  if (isAI && vsAI)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        4,
                        (i) => Icon(
                          i * 2 < s.aiLevel.stars
                              ? Icons.star
                              : Icons.star_border,
                          color: AppTheme.accent.withAlpha(
                            i * 2 < s.aiLevel.stars ? 200 : 80,
                          ),
                          size: 10,
                        ),
                      ),
                    ),
                  // プレイヤー段位表示（人間側のみ）
                  if (!isAI)
                    Text(
                      ratingToRank(_playerRating),
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              if (active) ...[
                const SizedBox(width: 8),
                Text(
                  isP1 ? '先手の番' : '後手の番',
                  style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
              const Spacer(),
              if (s.timeLimitSec != null)
                AnimatedBuilder(
                  animation: _timerBlinkAnim!,
                  builder: (_, __) {
                    final inByoyomi = isP1 ? _p1InByoyomi : _p2InByoyomi;
                    final byoyomiRemaining = isP1
                        ? _p1ByoyomiRemaining
                        : _p2ByoyomiRemaining;
                    final remaining = isP1 ? p1Time : p2Time;
                    final isWarning = active && (inByoyomi || remaining < 30);
                    final blinkAlpha = (_timerBlinkAnim!.value * 180).toInt();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isWarning
                            ? AppTheme.danger.withAlpha(blinkAlpha)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: inByoyomi
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '秒読み',
                                  style: TextStyle(
                                    color: Color.lerp(AppTheme.danger, Colors.white, 0.3),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${byoyomiRemaining}秒',
                                  style: TextStyle(
                                    color: Color.lerp(AppTheme.danger, Colors.white, 0.5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _fmt(remaining),
                              style: TextStyle(
                                color: isWarning
                                    ? Color.lerp(AppTheme.danger, Colors.white, 0.5)
                                    : AppTheme.textMid,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                    );
                  },
                ),
              const Spacer(),
            ],
          ),
        ), // Container (playerBar inner)
      ], // Column children
    ); // Column
  }

  // ===== 持ち駒バー =====
  Widget _handBar(bool isP1) {
    final hand = isP1 ? p1Hand : p2Hand;
    final active = (p1Turn == isP1) && result == null && !_aiThinking;
    final isAI = vsAI && (isP1 != s.aiIsP2);
    final canSelectPieces = p1Turn == isP1 && !_aiThinking && result == null;
    final droppableTypes = canSelectPieces
        ? Set<PieceType>.from(
            hand.keys.where(
              (type) => GL
                  .dropSquares(board, type, isP1, hand, isP1 ? p2Hand : p1Hand)
                  .isNotEmpty,
            ),
          )
        : <PieceType>{};
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? [AppTheme.surfaceHigh, AppTheme.surface]
              : [AppTheme.surface, AppTheme.bg],
        ),
        border: Border(
          top: BorderSide(
            color: active ? AppTheme.accent.withAlpha(60) : Colors.white.withAlpha(15),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: active ? AppTheme.accent.withAlpha(60) : Colors.white.withAlpha(15),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Text(
            '持駒',
            style: TextStyle(
              color: active ? AppTheme.textMid : AppTheme.textLow,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: hand.isEmpty
                ? Text(
                    'なし',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 11),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: hand.entries.map((e) {
                        final sel = selHand == e.key && p1Turn == isP1 && !isAI;
                        final hasDropSquares =
                            canSelectPieces &&
                            !sel &&
                            droppableTypes.contains(e.key);
                        Widget buildPiece(double v) => AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.accent.withAlpha(70)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: sel
                                ? Border.all(
                                    color: AppTheme.accent,
                                    width: 2,
                                  )
                                : hasDropSquares
                                ? Border.all(
                                    color: AppTheme.primary.withAlpha(
                                      (100 + v * 100).toInt(),
                                    ),
                                    width: 1.5,
                                  )
                                : null,
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accent.withAlpha(180),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : hasDropSquares
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primary.withAlpha(
                                        (v * 90).toInt(),
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 23,
                                height: 27,
                                child: CustomPaint(
                                  painter: const KomaPainter(
                                    pointsUp: true, // 持ち駒は常に上向き（読みやすさ優先）
                                    fill: Color(0xFFF4DDA6),
                                    border: Color(0xFFC49A4E),
                                  ),
                                  child: Center(
                                    child: Text(
                                      pieceLabel(e.key),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3A2A18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (e.value > 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    '×${e.value}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                        return GestureDetector(
                          onTap: () => _onHand(e.key, isP1),
                          child: Opacity(
                            opacity: canSelectPieces ? 1.0 : 0.5,
                            child: hasDropSquares && _timerBlinkAnim != null
                                ? AnimatedBuilder(
                                    animation: _timerBlinkAnim!,
                                    builder: (_, __) =>
                                        buildPiece(_timerBlinkAnim!.value),
                                  )
                                : buildPiece(0),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ===== 駒タイル（五角形コマ＋漢字、成りフリップ対応） =====
  Widget _komaTile(
    Piece piece,
    double cellW,
    double cellH,
    bool flipBoard, {
    double flipScaleY = 1.0,
  }) {
    final pointsUp = flipBoard ? !piece.isPlayer1 : piece.isPlayer1;
    final quarter = flipBoard
        ? (piece.isPlayer1 ? 2 : 0)
        : (piece.isPlayer1 ? 0 : 2);
    return SizedBox(
      width: cellW * 0.88,
      height: cellH * 0.88,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1.0, flipScaleY, 1.0),
        child: CustomPaint(
          painter: KomaPainter(
            pointsUp: pointsUp,
            fill: const Color(0xFFF4DDA6),
            border: const Color(0xFFC49A4E),
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: quarter,
              child: Text(
                s.labelStyle == PieceLabelStyle.english
                    ? pieceLabelEn(piece.type, piece.isPlayer1)
                    : piece.label,
                style: komaLabelStyle(
                  isPromoted: piece.isPromoted,
                  fontSize: s.labelStyle == PieceLabelStyle.english
                      ? cellW * .42
                      : cellW * .52,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== 将棋盤 =====
  Widget _boardWidget() {
    // 後手プレイヤー時は盤面を反転（プレイヤーが常に下になるように）
    final flipBoard = vsAI && !s.aiIsP2;
    return AspectRatio(
      aspectRatio: 9 / 11,
      child: LayoutBuilder(
        builder: (_, cs) {
          final boardSize = cs.maxWidth * 0.9;
          final labelSize = cs.maxWidth * 0.05;
          final cellW = boardSize / 9;
          final cellH = cellW * 1.1; // 将棋盤は縦が少し長い
          final boardH = cellH * 9;

          return Column(
            children: [
              // 筋ラベル（反転時は1→9、通常は9→1）
              Row(
                children: [
                  SizedBox(width: labelSize),
                  ...List.generate(
                    9,
                    (i) => SizedBox(
                      width: cellW,
                      child: Text(
                        flipBoard ? '${i + 1}' : '${9 - i}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: labelSize * 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 段ラベル（反転時は九→一、通常は一→九）
                  Column(
                    children: List.generate(
                      9,
                      (i) => SizedBox(
                        width: labelSize,
                        height: cellH,
                        child: Center(
                          child: Text(
                            flipBoard ? _rowKanji[8 - i] : _rowKanji[i],
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: labelSize * 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 盤面本体（ダブルボーダー＋影で本物感）
                  Container(
                    // 外枠：濃い焦茶
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xFF2E1A0E),
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(140),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                        BoxShadow(
                          color: Colors.black.withAlpha(55),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Container(
                    // 内枠：明るい縁（立体感）
                    width: boardSize,
                    height: boardH,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      // 外枠線は GridOverlayPainter が盤面と同じ座標系で描く
                      // （Container の border は decoration.padding により
                      //   内側コンテンツを縮めてしまい、グリッド線・駒とズレる）
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(_cellColor, Colors.white, 0.12)!,
                          _cellColor,
                          Color.lerp(_cellColor, Colors.black, 0.16)!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // グリッドと星を描画
                        CustomPaint(
                          painter: BoardPainter(
                            cellColor: _cellColor,
                            borderColor: _cellBorder,
                            starColor: s.theme == PieceTheme.dark
                                ? Colors.white70
                                : Colors.black87,
                            textured: s.theme == PieceTheme.textured,
                            advantageRatio: _advantageRatio(),
                            gradientTop: _gradientTop,
                            gradientBottom: _gradientBottom,
                          ),
                          size: Size(boardSize, boardH),
                        ),
                        // 駒とハイライト
                        AnimatedBuilder(
                          animation: _animVal,
                          builder: (_, __) {
                            final av = _animVal.value;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                9,
                                (displayRow) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(9, (displayCol) {
                                    // 後手プレイヤー時は座標を反転
                                    final r = flipBoard
                                        ? 8 - displayRow
                                        : displayRow;
                                    final c = flipBoard
                                        ? 8 - displayCol
                                        : displayCol;

                                    final piece = board[r][c];
                                    final isSel = selR == r && selC == c;
                                    final isHL = hl[r][c];
                                    final isLastTo = lastTR == r && lastTC == c;
                                    final isLastFr = lastFR == r && lastFC == c;
                                    // 先手/後手の利き数（絶対座標）
                                    final p1V = _p1AtkMap?[r][c] ?? 0; // 先手の利き
                                    final p2V = _p2AtkMap?[r][c] ?? 0; // 後手の利き
                                    // 旧変数名との互換（他の場所で使用中）
                                    final myV = p1Turn ? p1V : p2V;
                                    final oppV = p1Turn ? p2V : p1V;
                                    final isHintFr =
                                        _analysisMode &&
                                        _hintMove != null &&
                                        _hintMove!.drop == null &&
                                        _hintMove!.fr == r &&
                                        _hintMove!.fc == c;
                                    final isHintTo =
                                        _analysisMode &&
                                        _hintMove != null &&
                                        _hintMove!.tr == r &&
                                        _hintMove!.tc == c;
                                    // ただどり判定：相手に取られうるかつ自分も守っていない
                                    final canCapture =
                                        piece != null && _canBeCaptured(r, c);
                                    // より深刻なただどり（守りがない）
                                    final isTadaDori =
                                        canCapture &&
                                        (() {
                                          // 駒の持ち主が先手ならp1V=0(守りなし)かつp2V>0
                                          // 後手ならp2V=0かつp1V>0
                                          if (piece!.isPlayer1)
                                            return p1V == 0 && p2V > 0;
                                          return p2V == 0 && p1V > 0;
                                        })();

                                    // ── セル背景色 ──
                                    Color bg = _cellColor;
                                    // 利きマップ（駒のないマスのみ強め、駒ありは薄め）
                                    if (showAttackMap) {
                                      final hasPiece = piece != null;
                                      // 先手優勢＝青、後手優勢＝赤、拮抗＝紫（薄）
                                      final baseIntensity = hasPiece
                                          ? 0.18
                                          : 0.40;
                                      if (p1V > 0 && p2V == 0) {
                                        final t =
                                            (baseIntensity + (p1V - 1) * 0.08)
                                                .clamp(
                                                  0.0,
                                                  hasPiece ? 0.25 : 0.55,
                                                );
                                        bg = Color.lerp(
                                          _cellColor,
                                          Colors.blue.shade300,
                                          t,
                                        )!;
                                      } else if (p2V > 0 && p1V == 0) {
                                        final t =
                                            (baseIntensity + (p2V - 1) * 0.08)
                                                .clamp(
                                                  0.0,
                                                  hasPiece ? 0.25 : 0.55,
                                                );
                                        bg = Color.lerp(
                                          _cellColor,
                                          Colors.red.shade300,
                                          t,
                                        )!;
                                      } else if (p1V > 0 && p2V > 0) {
                                        final t = hasPiece ? 0.12 : 0.28;
                                        bg = Color.lerp(
                                          _cellColor,
                                          Colors.purple.shade300,
                                          t,
                                        )!;
                                      }
                                    }
                                    // ヒント手
                                    if (isHintFr)
                                      bg = AppTheme.accent;
                                    else if (isHintTo)
                                      bg = AppTheme.accent;
                                    // 直前移動ハイライト（琥珀色で統一・控えめ）
                                    if (isLastTo) {
                                      if (av < 1.0) {
                                        bg = Color.lerp(
                                          Colors.amber.shade200,
                                          bg,
                                          av,
                                        )!;
                                      } else {
                                        bg = Color.lerp(
                                          bg,
                                          Colors.amber.shade300,
                                          0.32,
                                        )!;
                                      }
                                    } else if (isLastFr) {
                                      if (av < 1.0) {
                                        bg = Color.lerp(
                                          Colors.amber.shade100,
                                          bg,
                                          min(1.0, av * 2),
                                        )!;
                                      } else {
                                        bg = Color.lerp(
                                          bg,
                                          Colors.amber.shade200,
                                          0.18,
                                        )!;
                                      }
                                    }
                                    // 選択（合法手はドット/リングで示すのでマス塗りはしない）
                                    if (isSel) bg = Colors.amber.shade200.withAlpha(200);

                                    final net =
                                        p1V - p2V; // 利き合計値（+は先手有利、-は後手有利）
                                    return GestureDetector(
                                      onTap: () => _onCell(r, c),
                                      onLongPress: () {
                                        if (piece != null)
                                          _showPieceGuide(piece);
                                      },
                                      child: Container(
                                        width: cellW,
                                        height: cellH,
                                        decoration: BoxDecoration(
                                          color: bg,
                                          border: isSel
                                              ? Border.all(
                                                  color: Colors.amber.shade600,
                                                  width: 2.2,
                                                )
                                              : isTadaDori
                                              ? Border.all(
                                                  color: Colors.red.shade400,
                                                  width: 2.0,
                                                )
                                              : canCapture
                                              ? Border.all(
                                                  color: Colors.orange.shade300,
                                                  width: 1.0,
                                                )
                                              : null, // グリッドはBoardPainterが描く
                                        ),
                                        child: Stack(
                                          children: [
                                            // 駒（五角形のコマ形）。移動中の駒はオーバーレイで描くのでここでは隠す
                                            if (piece != null &&
                                                !(isLastTo &&
                                                    lastFR != null &&
                                                    lastFR! >= 0 &&
                                                    _anim.value < 0.999))
                                              Center(
                                                child: Transform.scale(
                                                  scale: (isLastTo && av < 1.0)
                                                      ? 1.0 + 0.22 * (1.0 - av)
                                                      : 1.0,
                                                  child: _komaTile(
                                                    piece,
                                                    cellW,
                                                    cellH,
                                                    flipBoard,
                                                  ),
                                                ),
                                              )
                                            // 合法手マーカー（空マス＝ドット）
                                            else if (isHL)
                                              Center(
                                                child: Container(
                                                  width: cellW * .28,
                                                  height: cellW * .28,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1B6B46).withAlpha(210),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF2E7D5B).withAlpha(120),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            // 取れる駒（合法手の移動先に敵駒）＝リング
                                            if (isHL && piece != null)
                                              Center(
                                                child: Container(
                                                  width: cellW * 0.92,
                                                  height: cellH * 0.92,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: const Color(0xFF1B6B46),
                                                      width: 2.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF2E7D5B).withAlpha(80),
                                                        blurRadius: 5,
                                                        spreadRadius: 0,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            // 利き数表示：合計値のみ（+先手/青、-後手/赤）
                                            if (showAttackMap && net != 0)
                                              Positioned(
                                                right: 1,
                                                bottom: 1,
                                                child: Text(
                                                  net > 0 ? '+$net' : '$net',
                                                  style: TextStyle(
                                                    fontSize: cellW * 0.26,
                                                    fontWeight: FontWeight.bold,
                                                    color: net > 0
                                                        ? Colors.blue.shade400
                                                        : Colors.red.shade400,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withAlpha(160),
                                                        blurRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            );
                          },
                        ),
                        // 移動アニメーション（スライド＋成りフリップ）オーバーレイ
                        AnimatedBuilder(
                          animation: _animVal,
                          builder: (_, __) {
                            final t = _anim.value;
                            final isBoardMove =
                                lastFR != null && lastFR! >= 0;
                            final mp = (lastTR != null && lastTC != null)
                                ? board[lastTR!][lastTC!]
                                : null;
                            if (mp == null || !isBoardMove || t >= 0.999) {
                              return const SizedBox.shrink();
                            }
                            final slide = Curves.easeOutCubic.transform(t);
                            final sdr = (flipBoard ? 8 - lastFR! : lastFR!)
                                .toDouble();
                            final sdc = (flipBoard ? 8 - lastFC! : lastFC!)
                                .toDouble();
                            final ddr = (flipBoard ? 8 - lastTR! : lastTR!)
                                .toDouble();
                            final ddc = (flipBoard ? 8 - lastTC! : lastTC!)
                                .toDouble();
                            final x = (sdc + (ddc - sdc) * slide) * cellW;
                            final y = (sdr + (ddr - sdr) * slide) * cellH;
                            double flipY = 1.0;
                            // 成り演出: 前半は元の駒→つぶれて→後半に成駒(赤)を出す
                            Piece showPiece = mp;
                            if (_lastWasPromotion) {
                              flipY = (t < 0.5) ? (1 - t * 2) : (t - 0.5) * 2;
                              flipY = flipY.clamp(0.06, 1.0);
                              if (t < 0.5) {
                                showPiece = Piece(mp.baseType, mp.isPlayer1);
                              }
                            }
                            return Positioned(
                              left: x,
                              top: y,
                              width: cellW,
                              height: cellH,
                              child: Center(
                                child: _komaTile(
                                  showPiece,
                                  cellW,
                                  cellH,
                                  flipBoard,
                                  flipScaleY: flipY,
                                ),
                              ),
                            );
                          },
                        ),
                        // 駒を取った瞬間の弾けエフェクト
                        if (_showCaptureBurst &&
                            _captureBurstRow != null &&
                            _captureBurstCol != null)
                          AnimatedBuilder(
                            animation: _captureBurstAnim!,
                            builder: (_, __) {
                              final br = (flipBoard
                                      ? 8 - _captureBurstRow!
                                      : _captureBurstRow!)
                                  .toDouble();
                              final bc = (flipBoard
                                      ? 8 - _captureBurstCol!
                                      : _captureBurstCol!)
                                  .toDouble();
                              return Positioned(
                                left: bc * cellW,
                                top: br * cellH,
                                width: cellW,
                                height: cellH,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _CaptureBurstPainter(
                                      particles: _captureParticles,
                                      progress: _captureBurstAnim!.value,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        // 囲いガイド矢印
                        if (s.castleGuideEnabled && result == null && kifu.length <= s.castleGuideMaxPly)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CastleGuideArrowPainter(
                                arrows: CastleGuideService.getGuideArrows(board, s.castleGuideName, s.aiIsP2),
                                cellW: cellW,
                                cellH: cellH,
                                flipBoard: flipBoard,
                              ),
                              size: Size(boardSize, boardH),
                            ),
                          ),
                        // グリッド線・星は最前面に重ねる（マスの不透明背景に隠れないように）
                        IgnorePointer(
                          child: CustomPaint(
                            painter: GridOverlayPainter(
                              borderColor: _cellBorder,
                              outerBorderColor: const Color(0xFF8D6E4A), // 明るい木縁
                              outerBorderWidth: 2.4,
                              starColor: s.theme == PieceTheme.dark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                            size: Size(boardSize, boardH),
                          ),
                        ),
                      ],
                    ),
                    ), // 内枠 Container
                  ), // 外枠 Container
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== 棋譜ビュー =====
  Widget _kifuView() => Container(
    color: AppTheme.surface,
    child: kifu.isEmpty
        ? const Center(
            child: Text('まだ手がありません', style: TextStyle(color: Colors.white54)),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '棋譜 (${kifu.length}手)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('エクスポート'),
                          onPressed: _showKifExport,
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('保存'),
                          onPressed: _saveKifu,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: kifu.length,
                  itemBuilder: (_, i) {
                    final m = kifu[kifu.length - 1 - i];
                    final memo = _memos[m.num];
                    return GestureDetector(
                      onTap: () {
                        final moveIdx = m.num;
                        final existing = _memos[moveIdx] ?? '';
                        final ctrl = TextEditingController(text: existing);
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.surface,
                            title: Text(
                              '${moveIdx}手目のメモ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            content: TextField(
                              controller: ctrl,
                              maxLines: 3,
                              maxLength: 200,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'この手についてメモ...',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade900,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('キャンセル'),
                              ),
                              if (existing.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() => _memos.remove(moveIdx));
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    '削除',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ElevatedButton(
                                onPressed: () {
                                  final t = ctrl.text.trim();
                                  setState(() {
                                    if (t.isEmpty)
                                      _memos.remove(moveIdx);
                                    else
                                      _memos[moveIdx] = t;
                                  });
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                ),
                                child: const Text(
                                  '保存',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.text,
                                  style: TextStyle(
                                    color: m.p1
                                        ? Colors.white
                                        : Colors.lightBlue.shade200,
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (memo != null)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.note,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                            if (_castleTags.containsKey(m.num))
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 1, bottom: 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1100),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFFC8A45A),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    _castleTags[m.num]!,
                                    style: const TextStyle(
                                      color: Color(0xFFC8A45A),
                                      fontSize: 10,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            if (memo != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  bottom: 2,
                                ),
                                child: Text(
                                  memo,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}

// ===== 初期盤面 =====
List<List<Piece?>> _initBoard([Handicap handicap = Handicap.none]) {
  final b = List<List<Piece?>>.generate(
    9,
    (_) => List<Piece?>.filled(9, null, growable: false),
  );
  void s(int r, int c, PieceType t, bool p1) => b[r][c] = Piece(t, p1);

  // ---- 後手（上手 / P2）の配置 ----
  // 各駒の除外条件
  final rmLeftLance = {
    Handicap.lance,
    Handicap.four,
    Handicap.six,
    Handicap.eight,
  };
  final rmRightLance = {Handicap.four, Handicap.six, Handicap.eight};
  final rmKnight = {Handicap.six, Handicap.eight};
  final rmSilver = {Handicap.eight};
  final rmRook = {
    Handicap.rook,
    Handicap.rookBishop,
    Handicap.four,
    Handicap.six,
    Handicap.eight,
  };
  final rmBishop = {
    Handicap.bishop,
    Handicap.rookBishop,
    Handicap.four,
    Handicap.six,
    Handicap.eight,
  };

  if (!rmLeftLance.contains(handicap)) s(0, 0, PieceType.lance, false);
  if (!rmKnight.contains(handicap)) s(0, 1, PieceType.knight, false);
  if (!rmSilver.contains(handicap)) s(0, 2, PieceType.silver, false);
  s(0, 3, PieceType.gold, false);
  s(0, 4, PieceType.king, false);
  s(0, 5, PieceType.gold, false);
  if (!rmSilver.contains(handicap)) s(0, 6, PieceType.silver, false);
  if (!rmKnight.contains(handicap)) s(0, 7, PieceType.knight, false);
  if (!rmRightLance.contains(handicap)) s(0, 8, PieceType.lance, false);
  if (!rmRook.contains(handicap)) s(1, 1, PieceType.rook, false);
  if (!rmBishop.contains(handicap)) s(1, 7, PieceType.bishop, false);

  for (int c = 0; c < 9; c++) s(2, c, PieceType.pawn, false);
  s(8, 0, PieceType.lance, true);
  s(8, 1, PieceType.knight, true);
  s(8, 2, PieceType.silver, true);
  s(8, 3, PieceType.gold, true);
  s(8, 4, PieceType.king, true);
  s(8, 5, PieceType.gold, true);
  s(8, 6, PieceType.silver, true);
  s(8, 7, PieceType.knight, true);
  s(8, 8, PieceType.lance, true);
  s(7, 7, PieceType.rook, true);
  s(7, 1, PieceType.bishop, true);
  for (int c = 0; c < 9; c++) s(6, c, PieceType.pawn, true);
  return b;
}

// ===== Export alias =====
/// 初期盤面を生成（initShogiBoard は _initBoard へのエクスポート）
List<List<Piece?>> initShogiBoard([Handicap handicap = Handicap.none]) =>
    _initBoard(handicap);

// ===== 紙吹雪パーティクル =====
class _ConfettiParticle {
  final double x; // 初期X位置（0〜1）
  final Color color;
  final double size;
  final double speed;
  final double angle; // 初期角度（ラジアン）

  _ConfettiParticle({
    required this.x,
    required this.color,
    required this.size,
    required this.speed,
    required this.angle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress; // 0.0 〜 1.0

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final x = (p.x + sin(p.angle + progress * 6) * 0.08) * size.width;
      final y = progress * size.height * p.speed * 1.5;
      final opacity = (1.0 - progress * 0.8).clamp(0.0, 1.0);
      paint.color = p.color.withAlpha((opacity * 220).toInt());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.angle * 4);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ── 駒を取った瞬間の弾けエフェクト（マス中央から放射状に飛散）─────
class _CaptureBurstPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress; // 0.0 〜 1.0

  _CaptureBurstPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.6;
    final paint = Paint()..style = PaintingStyle.fill;
    final eased = Curves.easeOut.transform(progress);
    for (final p in particles) {
      final r = maxRadius * eased * p.speed;
      final dx = center.dx + cos(p.angle) * r;
      final dy = center.dy + sin(p.angle) * r;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = p.color.withAlpha((opacity * 230).toInt());
      canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptureBurstPainter old) => old.progress != progress;
}

// ── 連敗ケアカード ─────────────────────────────────────────────────────────
class _LossStreakCard extends StatelessWidget {
  final int lossStreak;
  const _LossStreakCard({required this.lossStreak});

  @override
  Widget build(BuildContext context) {
    final (emoji, title, message, tip) = _content(lossStreak);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.purple.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$lossStreak連敗中',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (tip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 $tip',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static (String, String, String, String) _content(int n) {
    if (n >= 10)
      return (
        '🏯',
        '鉄の意志',
        '10連敗以上でも諦めない姿勢こそが強さの根源です。伝説の棋士たちも無数の敗局を乗り越えてきました。',
        '一度 AI難易度を2段階下げて、勝ちの感覚を取り戻してみましょう。',
      );
    if (n >= 7)
      return (
        '⚔️',
        '修行の壁',
        '7連敗は大きな壁ですが、この時期に最も成長します。棋譜を振り返ると必ず共通の弱点が見つかります。',
        '詰将棋を5問解いて頭をリセットすると突破口が開けます。',
      );
    if (n >= 5)
      return (
        '🌊',
        '波に飲まれ中',
        '誰でも5連敗する時期があります。今は結果より「1手ごとの意味」を意識して指しましょう。',
        '弱点分析を確認してみると、今の課題が見えてきます。',
      );
    if (n >= 3)
      return (
        '😤',
        'ここが踏ん張りどころ',
        '3連敗は珍しくありません。焦らず、1局1局を丁寧に。詰将棋で基本を確認するのが近道です。',
        '難易度を1段階下げて連勝体験を積むのも有効です。',
      );
    return ('💪', '続けよう', '2連敗もよくあること。次の1局に集中しましょう。', '');
  }
}

// ===== 評価値グラフ CustomPainter =====
class _EvalGraphPainter extends CustomPainter {
  final List<int> history;
  const _EvalGraphPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    const maxScore = 3000;
    final midY = size.height / 2;

    // 背景グリッド
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);
    for (final v in [1000, -1000]) {
      final y = midY - (v / maxScore) * midY;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.white.withAlpha(20)
          ..strokeWidth = 0.5,
      );
    }

    // グラフライン
    final n = history.length;
    final stepX = size.width / (n > 1 ? n - 1 : 1);

    final p1Paint = Paint()
      ..color = Colors.blue.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i * stepX;
      final clamped = history[i].clamp(-maxScore, maxScore);
      final y = midY - (clamped / maxScore) * midY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, p1Paint);

    // 最後の点
    final lastX = (n - 1) * stepX;
    final lastClamped = history.last.clamp(-maxScore, maxScore);
    final lastY = midY - (lastClamped / maxScore) * midY;
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = Colors.amber);
  }

  @override
  bool shouldRepaint(_EvalGraphPainter old) => old.history != history;
}

// ===== 駒の動き説明 =====
const _pieceGuide = <PieceType, String>{
  PieceType.king: '全方向に1マス動けます',
  PieceType.rook: '縦・横に何マスでも動けます',
  PieceType.bishop: '斜め4方向に何マスでも動けます',
  PieceType.gold: '前・横・斜め前・後ろに1マス（斜め後ろ不可）',
  PieceType.silver: '斜め4方向＋前方向に1マス',
  PieceType.knight: '前2マス＋横1マスのL字（飛び越し可）',
  PieceType.lance: '前方向のみ何マスでも',
  PieceType.pawn: '前方向に1マスのみ',
  PieceType.promotedRook: '龍王：縦横何マスでも＋斜め1マス',
  PieceType.promotedBishop: '龍馬：斜め何マスでも＋縦横1マス',
  PieceType.promotedSilver: '成銀：金と同じ動き',
  PieceType.promotedKnight: '成桂：金と同じ動き',
  PieceType.promotedLance: '成香：金と同じ動き',
  PieceType.promotedPawn: 'と金：金と同じ動き',
};

// ===== 囲いガイド矢印描画 =====
class _CastleGuideArrowPainter extends CustomPainter {
  final List<(int, int, int, int)> arrows;
  final double cellW;
  final double cellH;
  final bool flipBoard;

  const _CastleGuideArrowPainter({
    required this.arrows,
    required this.cellW,
    required this.cellH,
    required this.flipBoard,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (arrows.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xCC1AAA55)
      ..strokeWidth = cellW * 0.1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = const Color(0xCC1AAA55)
      ..style = PaintingStyle.fill;

    for (final (fr, fc, tr, tc) in arrows) {
      final dfr = (flipBoard ? 8 - fr : fr).toDouble();
      final dfc = (flipBoard ? 8 - fc : fc).toDouble();
      final dtr = (flipBoard ? 8 - tr : tr).toDouble();
      final dtc = (flipBoard ? 8 - tc : tc).toDouble();

      final from = Offset((dfc + 0.5) * cellW, (dfr + 0.5) * cellH);
      final to   = Offset((dtc + 0.5) * cellW, (dtr + 0.5) * cellH);
      final d    = to - from;
      final len  = d.distance;
      if (len < 1) continue;

      final arrowSize = cellW * 0.27;
      final ux = d.dx / len;
      final uy = d.dy / len;
      // Shorten line so it doesn't overlap the arrowhead
      final tip  = to;
      final tail = from + Offset(ux * arrowSize * 0.5, uy * arrowSize * 0.5);
      final lineEnd = tip - Offset(ux * arrowSize * 0.85, uy * arrowSize * 0.85);
      canvas.drawLine(tail, lineEnd, linePaint);

      // Arrowhead triangle
      final p1 = tip - Offset(ux * arrowSize - uy * arrowSize * 0.5, uy * arrowSize + ux * arrowSize * 0.5);
      final p2 = tip - Offset(ux * arrowSize + uy * arrowSize * 0.5, uy * arrowSize - ux * arrowSize * 0.5);
      canvas.drawPath(
        Path()..moveTo(tip.dx, tip.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CastleGuideArrowPainter old) =>
      old.arrows.length != arrows.length ||
      old.flipBoard != flipBoard ||
      old.cellW != cellW;
}
