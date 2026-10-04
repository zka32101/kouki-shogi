// lib/main.dart — アプリエントリ + BottomNavigation ホーム画面

import 'dart:convert';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/koma_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'theme_config.dart';
import 'game_setup_screen.dart';
import 'editor_screen.dart';
import 'rules_screen.dart';
import 'guide_screen.dart';
import 'kifu_history_screen.dart';
import 'castle_patterns_screen.dart';
import 'strategies_screen.dart';
import 'screens/strategies_screen_v2.dart';
import 'stats_screen.dart';
import 'opening_stats_screen.dart';
import 'tutorial_screen.dart';
import 'strength_test_screen.dart';
import 'speech_service.dart';
import 'sound_service.dart';
import 'joseki_screen.dart';
import 'tsume_screen.dart';
import 'tesuji_screen.dart';
import 'strategy_map_screen.dart';
import 'proverbs_screen.dart';
import 'ad_service.dart';
import 'purchase_service.dart';
import 'network_lobby_screen.dart';
import 'network_game_service.dart';
import 'screens/ranking_screen.dart';
import 'badge_screen.dart';
import 'cloud_sync_service.dart';
import 'ai_data_service.dart';
import 'weekly_review_screen.dart';
import 'feedback_screen.dart';
import 'screens/premium_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/network_service.dart';
import 'screens/match_screen.dart';
import 'screens/friend_screen.dart';
import 'screens/achievement_screen.dart';
import 'screens/match_history_screen.dart';
import 'screens/daily_challenge_screen.dart';
import 'services/daily_challenge_service.dart';
import 'services/network_achievement_service.dart';
import 'shodan_roadmap_screen.dart';
import 'learning_guide_screen.dart';
import 'next_move_screen.dart';
import 'castle_break_screen.dart';
import 'pro_kifu_screen.dart';
import 'study_calendar_screen.dart';
import 'weakness_analysis_screen.dart';
import 'screens/tournament_screen.dart';
import 'puzzle_generator_screen.dart';
import 'l10n.dart';
import 'weakness_mining_screen.dart';
import 'micro_training_screen.dart';
import 'friend_challenge_screen.dart';
import 'async_training_duel_screen.dart';
import 'voice_io_screen.dart';
import 'spaced_repetition_screen.dart';
import 'coach_personality_screen.dart';
import 'adaptive_difficulty_screen.dart';
import 'playstyle_diagnosis_screen.dart';
import 'ghost_service.dart';
import 'screens/ghost_screen.dart';
import 'services/fcm_service.dart';

import 'screens/network_game_home.dart';
import 'screens/customize_screen.dart';
import 'screens/past_self_battle_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/custom_period_analysis_screen.dart';
import 'screens/personalized_lesson_screen.dart';
import 'services/kifu_analytics_service.dart';
import 'models/game_analysis.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 起動を体感的に高速化するため、初期化系(広告SDK/課金/Firebase/FCM)を
  // runApp() より後ろのバックグラウンドへ回す。各サービスは準備完了まで
  // 内部で ready フラグ/nullチェックを行う設計のため、初回フレーム表示を
  // これらの完了を待たずに行っても安全。
  try {
    await _initializeBackgroundServices();
  } catch (e) {
    debugPrint('Background initialization error: $e');
  }
  runApp(const ShogiApp());
}

Future<void> _initializeBackgroundServices() async {
  await AdService.initialize();
  await PurchaseService.initialize();
  // Firebase 初期化（設定済みの場合のみ有効）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics: uncaught Flutter エラーを自動報告
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // ネットワークサービス初期化
    await NetworkService().initFirebase();
    // 連続ログインストリーク更新 + 実績判定（1日1回・冪等）
    final uid = NetworkService().currentUser?.uid;
    if (uid != null) {
      DailyChallengeService().updateLoginStreak(uid).then((streak) {
        if (streak > 0) {
          NetworkAchievementService().checkLoginStreak(uid, streak);
        }
      });
    }
    NetworkGameService.setFirebaseReady();
    CloudSyncService.setReady();
    AiDataService.setReady();
    // 起動時: サーバーデータ取得 + オープニングブック DL（バックグラウンド）
    CloudSyncService.pullAndMerge();
    AiDataService.downloadOpeningBook();
    // G1: プッシュ通知初期化（バックグラウンドハンドラはFirebase.initializeApp後に登録必須）
    await FcmService().initialize();
    // 通知タップ時の画面遷移コールバックも Firebase 初期化後に登録
    FcmService().onNotificationTap = _handleNotificationTap;
    // アプリが完全終了状態から通知タップで起動された場合（cold start）の
    // 遷移も処理する（onMessageOpenedAppだけではこのケースを捕捉できない）
    FcmService().checkInitialMessage();
  } catch (_) {
    // Firebase 未設定の場合はスキップ（ネットワーク対局機能は無効）
  }
}

// プッシュ通知タップ時に BuildContext なしで画面遷移するためのキー
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// ── プッシュ通知タップ時の画面遷移 ─────────────────────────
// Firebase 初期化後にのみ登録されるトップレベル関数（_initializeBackgroundServices 参照）
void _handleNotificationTap(Map<String, dynamic> data) {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  final screen = data['screen'] as String?;
  switch (screen) {
    case 'match':
      final matchId = data['match_id'] as String?;
      if (matchId != null) _openMatch(nav, matchId);
      break;
    case 'friends':
    case 'challenge':
      nav.push(MaterialPageRoute(builder: (_) => const FriendScreen()));
      break;
    case 'achievements':
      nav.push(MaterialPageRoute(builder: (_) => const AchievementScreen()));
      break;
    case 'match_history':
      final uid = NetworkService().currentUser?.uid;
      if (uid != null) {
        nav.push(MaterialPageRoute(
            builder: (_) => MatchHistoryScreen(userId: uid)));
      }
      break;
    case 'daily_challenge':
      nav.push(MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));
      break;
  }
}

Future<void> _openMatch(NavigatorState nav, String matchId) async {
  try {
    final uid = NetworkService().currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final isPlayer1 = data['player1_id'] == uid;
    final timeLimitSec = (data['player1_time'] as int?) ?? 600;
    nav.push(MaterialPageRoute(
      builder: (_) => MatchScreen(
        matchId: matchId,
        isPlayer1: isPlayer1,
        myPlayerId: uid,
        timeLimitSec: timeLimitSec,
      ),
    ));
  } catch (_) {}
}

class ShogiApp extends StatefulWidget {
  const ShogiApp({super.key});

  @override
  State<ShogiApp> createState() => _ShogiAppState();
}

class _ShogiAppState extends State<ShogiApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    // Load theme asynchronously - Fire and forget with error handling
    _loadThemePreference().catchError((e) {
      debugPrint('Theme load error: $e');
    });
    // 注意: FcmService().onNotificationTap の登録は Firebase 初期化後
    // （_initializeBackgroundServices 内）で行うこと。ここで FcmService() に
    // 触れると、その場で FirebaseMessaging.instance が生成され、
    // まだ Firebase.initializeApp() が完了していない場合に
    // 「No Firebase App '[DEFAULT]' has been created」で即クラッシュし、
    // 起動直後にグレー画面になる（実機で確認済みの不具合）。
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isDarkMode = prefs.getBool('theme_dark_mode') ?? true;
        });
      }
    } catch (e) {
      debugPrint('SharedPreferences error: $e');
    }
  }

  void _onThemeChanged(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
    SharedPreferences.getInstance().then((p) => p.setBool('theme_dark_mode', isDark));
  }

  ThemeData _buildTheme(bool isDark) {
    if (isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.accent,
          secondary: AppTheme.primary,
          surface: AppTheme.surface,
          onSurface: AppTheme.textHigh,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.bg,
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamilyFallback: const ['Noto Serif', 'Noto Sans', 'serif'],
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppTheme.surface,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: AppTheme.textHigh);
            }
            return TextStyle(color: AppTheme.textMid);
          }),
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: Colors.blue.shade600,
          secondary: Colors.orange.shade600,
          surface: Colors.grey.shade100,
          onSurface: Colors.black87,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey.shade50,
        textTheme: ThemeData.light().textTheme.apply(
          fontFamilyFallback: const ['Noto Serif', 'Noto Sans', 'serif'],
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: Colors.blue.shade600);
            }
            return const TextStyle(color: Colors.black54);
          }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: rootNavigatorKey,
    title: '効棋',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja', 'JP'),
    theme: _buildTheme(_isDarkMode),
    home: HomeScreen(onThemeChanged: _onThemeChanged),
  );
}

// ===== ホーム画面（BottomNavigation 4タブ） =====
class HomeScreen extends StatefulWidget {
  final void Function(bool)? onThemeChanged;

  const HomeScreen({super.key, this.onThemeChanged});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // 設定状態（設定タブから対局タブへ共有）
  int? _timeLimitSec;
  int? _byoyomiSec;
  int _fischerIncrementSec = 0;
  PieceTheme _theme = PieceTheme.standard;
  PieceLabelStyle _labelStyle = PieceLabelStyle.kanji;
  bool _speechEnabled = false;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final launched = prefs.getBool('has_launched') ?? false;
      if (!launched) {
        await prefs.setBool('has_launched', true);
        if (mounted) {
          // 初回起動: チュートリアル画面へ
          // ストーリー演出は無効化中（キャラID不整合のため要再設計）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TutorialScreen()),
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(
        index: _tab,
        children: [
          _PlayTab(
            timeLimitSec: _timeLimitSec,
            byoyomiSec: _byoyomiSec,
            fischerIncrementSec: _fischerIncrementSec,
            theme: _theme,
            labelStyle: _labelStyle,
          ),
          const _KifuTab(),
          const _StudyTab(),
          _SettingsTab(
            timeLimitSec: _timeLimitSec,
            byoyomiSec: _byoyomiSec,
            fischerIncrementSec: _fischerIncrementSec,
            theme: _theme,
            labelStyle: _labelStyle,
            speechEnabled: _speechEnabled,
            soundEnabled: _soundEnabled,
            onTime: (v) => setState(() => _timeLimitSec = v),
            onByoyomi: (v) => setState(() => _byoyomiSec = v),
            onFischer: (v) => setState(() => _fischerIncrementSec = v),
            onTheme: (v) {
              setState(() => _theme = v);
              SharedPreferences.getInstance().then((p) => p.setInt('piece_theme_idx', v.index));
            },
            onLabelStyle: (v) => setState(() => _labelStyle = v),
            onSpeech: (v) {
              setState(() => _speechEnabled = v);
              SpeechService.setEnabled(v);
            },
            onSound: (v) {
              setState(() => _soundEnabled = v);
              SoundService.enabled = v;
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        indicatorColor: Colors.transparent,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(
              _tab == 0 ? Icons.sports_esports : Icons.sports_esports_outlined,
              color: _tab == 0 ? AppTheme.accent : AppTheme.textLow,
              size: 24,
            ),
            label: '対局',
          ),
          NavigationDestination(
            icon: Icon(
              _tab == 1 ? Icons.history : Icons.history_outlined,
              color: _tab == 1 ? AppTheme.accent : AppTheme.textLow,
              size: 24,
            ),
            label: '棋譜',
          ),
          NavigationDestination(
            icon: Icon(
              _tab == 2 ? Icons.school : Icons.school_outlined,
              color: _tab == 2 ? AppTheme.accent : AppTheme.textLow,
              size: 24,
            ),
            label: '学習',
          ),
          NavigationDestination(
            icon: Icon(
              _tab == 3 ? Icons.tune : Icons.tune_outlined,
              color: _tab == 3 ? AppTheme.accent : AppTheme.textLow,
              size: 24,
            ),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

// ===== タブ 0: 対局 =====
class _PlayTab extends StatefulWidget {
  final int? timeLimitSec;
  final int? byoyomiSec;
  final int fischerIncrementSec;
  final PieceTheme theme;
  final PieceLabelStyle labelStyle;
  const _PlayTab({
    required this.timeLimitSec,
    required this.byoyomiSec,
    required this.fischerIncrementSec,
    required this.theme,
    required this.labelStyle,
  });
  @override
  State<_PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<_PlayTab> {
  int _rating = 700;
  List<int> _ratingHistory = [];
  String _rank = '10級';
  Color _rankColor = Colors.white54;
  int _ghostWins = 0;
  int _ghostLosses = 0;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  @override
  void didUpdateWidget(_PlayTab old) {
    super.didUpdateWidget(old);
    _loadRating();
  }

  Future<void> _loadRating() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = prefs.getInt('rating_current') ?? 700;
      final record = await GhostService.getTodayRecord();
      if (mounted) {
        setState(() {
          _rating = r;
          _rank = ratingToRank(r);
          _rankColor = ratingToColor(r);
          _ghostWins = record.wins;
          _ghostLosses = record.losses;
        });
      }
      try {
        final raw = prefs.getString('rating_history') ?? '[]';
        final hist = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final ratings = hist.map((e) => e['rating'] as int? ?? 700).toList();
        if (mounted)
          setState(
            () => _ratingHistory = ratings.reversed
                .take(20)
                .toList()
                .reversed
                .toList(),
          );
      } catch (_) {}
    } catch (_) {}
  }

  void _go(BuildContext ctx, Widget screen) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _loadRating()); // 対局後に戻ったら更新
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // タイトル
            Text(
              '効棋',
              textAlign: TextAlign.center,
              style: AppTheme.display.copyWith(
                color: AppTheme.textHigh,
                fontSize: 40,
                letterSpacing: 6,
              ),
            ),
            Text(
              'KOUKI  ·  Learn the Kiki',
              textAlign: TextAlign.center,
              style: AppTheme.overline.copyWith(
                color: AppTheme.textMid,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '好機を見つける将棋の効きを学ぶ',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(
                color: AppTheme.textLow,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),

            // ── レーティング表示 ──
            GestureDetector(
              onTap: () => _go(context, const StatsScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.surface, _rankColor.withAlpha(30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _rankColor.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech, color: _rankColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _rank,
                      style: TextStyle(
                        color: _rankColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_rating',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'pts',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── レーティング推移ミニグラフ ──
            if (_ratingHistory.length >= 3)
              GestureDetector(
                onTap: () => _go(context, const StatsScreen()),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '推移',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomPaint(
                          painter: _RatingMiniGraphPainter(
                            history: _ratingHistory,
                            currentRating: _rating,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.open_in_new,
                        color: Colors.white24,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),

            // ── 全ランク一覧（横スクロール） ──
            GestureDetector(
              onTap: () => _go(context, const StatsScreen()),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: rankTable.length,
                  itemBuilder: (ctx, i) {
                    final rr = rankTable[rankTable.length - 1 - i]; // 低級から高段へ
                    final isCurrent = _rank == rr.rank;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? rr.color.withAlpha(40)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCurrent ? rr.color : Colors.white12,
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        rr.rank,
                        style: TextStyle(
                          color: isCurrent ? rr.color : Colors.white38,
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 現在の対局設定サマリー ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.brown.shade900.withAlpha(100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // 持ち時間行
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: Colors.lightBlue.shade300,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '持ち時間: ',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      _settingChip(
                        widget.timeLimitSec == null
                            ? 'なし'
                            : '${widget.timeLimitSec! ~/ 60}分',
                        widget.timeLimitSec == null
                            ? Colors.white24
                            : Colors.green.shade700,
                      ),
                      if (widget.byoyomiSec != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.timer,
                          size: 13,
                          color: Colors.lightBlue.shade300,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '秒読み: ',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        _settingChip(
                          '${widget.byoyomiSec}秒',
                          AppTheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: const Text(
                      '設定タブで変更できます',
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('対局モード'),
            const SizedBox(height: 10),
            // PvP + AI
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    context,
                    'ローカル対局',
                    Icons.people,
                    Colors.brown.shade700,
                    () =>
                        _go(context, const GameSetupScreen(mode: GameMode.pvp)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _bigButton(
              context,
              'AI対局',
              Icons.computer,
              Colors.blueGrey.shade700,
              () => _go(context, const GameSetupScreen(mode: GameMode.vsAI)),
            ),
            const SizedBox(height: 8),
            _bigButton(
              context,
              'ネットワーク対局',
              Icons.wifi,
              const Color(0xFF1A5276),
              () => _go(context, const NetworkLobbyScreen()),
            ),
            const SizedBox(height: 8),
            // クラブ対戦・トーナメント・シーズン制ランキング・観戦は
            // NetworkService/MatchingService 側の別マッチングシステム
            // （NetworkGameHomeから遷移）にまとまっている
            _bigButton(
              context,
              'クラブ・大会・シーズン',
              Icons.emoji_events,
              const Color(0xFF6C3483),
              () => _go(context, const NetworkGameHome()),
            ),
            const SizedBox(height: 20),

            _sectionLabel('統計・ツール'),
            const SizedBox(height: 10),
            _bigButton(
              context,
              '統計',
              Icons.bar_chart,
              Colors.indigo.shade600,
              () => _go(context, const StatsScreen()),
            ),
            const SizedBox(height: 8),
            _bigButton(
              context,
              '定跡統計',
              Icons.insights,
              Colors.teal.shade600,
              () => _go(context, const OpeningStatsScreen()),
            ),
            const SizedBox(height: 8),
            // ゴースト棋士カード
            GestureDetector(
              onTap: () {
                if (!PurchaseService.isPremium) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                  return;
                }
                _go(context, const GhostScreen());
              },
              child: Stack(
                children: [
                  Opacity(
                    opacity: PurchaseService.isPremium ? 1.0 : 0.65,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A237E),
                            Colors.deepPurple.shade900,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Text('👻', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ゴースト棋士',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  PurchaseService.isPremium
                                      ? ((_ghostWins + _ghostLosses) == 0
                                          ? '棋風ゴーストで自動対戦'
                                          : '今日 $_ghostWins勝 $_ghostLosses敗')
                                      : 'プレミアム限定機能',
                                  style: TextStyle(
                                    color: PurchaseService.isPremium
                                        ? ((_ghostWins + _ghostLosses) == 0 ? Colors.white38 : Colors.white70)
                                        : AppTheme.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            PurchaseService.isPremium ? Icons.arrow_forward_ios : Icons.lock,
                            color: PurchaseService.isPremium ? Colors.white54 : AppTheme.accent,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('局面エディタ'),
            const SizedBox(height: 10),
            _bigButton(
              context,
              '局面エディタ',
              Icons.edit_note,
              Colors.teal.shade700,
              () => _go(
                context,
                EditorScreen(
                  gameSettings: GameSettings(
                    mode: GameMode.pvp,
                    timeLimitSec: widget.timeLimitSec,
                    fischerIncrementSec: widget.fischerIncrementSec,
                    theme: widget.theme,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== タブ 1: 棋譜 =====
class _KifuTab extends StatelessWidget {
  const _KifuTab();
  @override
  Widget build(BuildContext context) {
    // タブに埋め込み（戻るボタン非表示）
    return const KifuHistoryScreen(showBackButton: false);
  }
}

// ===== タブ 2: 学習 =====
class _StudyTab extends StatelessWidget {
  const _StudyTab();

  void _go(BuildContext ctx, Widget screen) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
  }

  // 分析済み対局データ（GameAnalysis）を読み込んでから遷移する画面用。
  // KifuAnalyticsService.getAllAnalyses() は既存の対局分析保存機能
  // （_showGameEndDialog → analyzeAndSaveGame）が書き込んだデータを読む。
  Future<void> _goWithAnalyses(
    BuildContext ctx,
    Widget Function(List<GameAnalysis> games) builder,
  ) async {
    final games = await KifuAnalyticsService().getAllAnalyses();
    if (!ctx.mounted) return;
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => builder(games)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              '学習',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '目的から選んで効率よく上達しましょう',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _heroGuide(context),
            const SizedBox(height: 22),
            // 成長を確認ボタン（Phase 3）
            GestureDetector(
              onTap: () => _go(context, const PastSelfBattleScreen()),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF00796B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.rCard),
                  border: Border.all(color: AppTheme.success.withAlpha(120), width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.trending_up, color: AppTheme.success, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '成長を確認',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '過去のあなたと対戦して成長度を確認',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: AppTheme.success, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            ..._buildSections(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===== 学習ガイドのヒーローカード =====
  Widget _heroGuide(BuildContext context) {
    return GestureDetector(
      onTap: () => _go(context, const LearningGuideScreen()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.surfaceHigh, AppTheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          border: Border.all(color: AppTheme.accent.withAlpha(120), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.explore, color: Colors.amber, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '学習ガイド',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '今の悩みから最適なメニューを提案',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  // ===== 目的別カテゴリ =====
  List<Widget> _buildSections(BuildContext context) {
    final sections = <_StudySection>[
      _StudySection('問題で鍛える', Icons.fitness_center, const Color(0xFF42A5F5), [
        _StudyItem('詰将棋', Icons.extension, () => _go(context, const TsumeScreen())),
        _StudyItem('デイリー詰将棋', Icons.today, () => _go(context, const DailyTsumeScreen())),
        _StudyItem('ローグライト', Icons.casino, () => _go(context, const TsumeRogueliteScreen())),
        _StudyItem('タイムアタック', Icons.timer, () => _go(context, const TsumeTimeAttackScreen())),
        _StudyItem('次の一手', Icons.lightbulb, () => _go(context, const NextMoveScreen())),
        _StudyItem('手筋トレーニング', Icons.psychology, () => _go(context, const TesujiScreen())),
        _StudyItem('囲い崩し道場', Icons.shield_outlined, () => _go(context, const CastleBreakScreen())),
        _StudyItem('自動生成パズル', Icons.auto_fix_high, () => _go(context, const PuzzleGeneratorScreen()), requiresPremium: true),
      ]),
      _StudySection('定跡・囲い・基礎', Icons.menu_book, const Color(0xFF5C6BC0), [
        _StudyItem('定跡ガイド', Icons.route, () => _go(context, const JosekiScreen())),
        _StudyItem('囲いパターン', Icons.security, () => _go(context, const CastlePatternsScreen())),
        _StudyItem('戦法', Icons.trending_up, () => _go(context, const StrategiesScreen())),
        _StudyItem('対策マップ', Icons.alt_route, () => _go(context, const StrategyMapScreen())),
        _StudyItem('戦法（AI評価版）', Icons.smart_toy, () => _go(context, const StrategiesScreenV2()), requiresPremium: true),
        _StudyItem('将棋の格言', Icons.format_quote, () => _go(context, const ProverbsScreen())),
        _StudyItem('駒の動き', Icons.book, () => _go(context, const RulesScreen())),
        _StudyItem('チュートリアル', Icons.school, () => _go(context, const TutorialScreen())),
        _StudyItem('使い方', Icons.help_outline, () => _go(context, const GuideScreen())),
      ]),
      _StudySection('診断・分析', Icons.analytics, const Color(0xFFAB47BC), [
        _StudyItem('棋力診断', Icons.assessment, () => _go(context, const StrengthTestScreen())),
        _StudyItem('棋風診断', Icons.face, () => _go(context, const PlaystyleDiagnosisScreen()), requiresPremium: true),
        _StudyItem('弱点分析（総合スコア）', Icons.radar, () => _go(context, const WeaknessAnalysisScreen()), requiresPremium: true),
        _StudyItem('弱点採掘（改善アクション）', Icons.travel_explore, () => _go(context, const WeaknessMiningScreen()), requiresPremium: true),
        _StudyItem('学習カレンダー', Icons.calendar_month, () => _go(context, const StudyCalendarScreen())),
        _StudyItem('プロ棋譜', Icons.video_library, () => _go(context, const ProKifuScreen())),
      ]),
      _StudySection('実戦・対戦で練習', Icons.sports_kabaddi, const Color(0xFFFFA726), [
        // 旧 MonthlyTournamentScreen は対戦表・結果が全てハードコードされた
        // モックデータで実体がなかったため、NetworkGameHome側と同じ
        // 実装済み・Firestore連携済みの TournamentListScreen に統合した。
        _StudyItem('トーナメント', Icons.emoji_events, () => _go(context, const TournamentListScreen())),
        _StudyItem('友達対戦', Icons.people, () => _go(context, const FriendChallengeScreen())),
        _StudyItem('レース対戦', Icons.speed, () => _go(context, const AsyncTrainingDuelScreen())),
        _StudyItem('3分筋トレ', Icons.bolt, () => _go(context, const MicroTrainingScreen())),
      ]),
      _StudySection('AIコーチ・ツール', Icons.auto_awesome, const Color(0xFF7E57C2), [
        _StudyItem('週次AI振り返り', Icons.insights, () => _go(context, const WeeklyReviewScreen()), requiresPremium: true),
        _StudyItem('忘却曲線AI', Icons.calendar_today, () => _go(context, const SpacedRepetitionScreen()), requiresPremium: true),
        _StudyItem('AI棋風コーチ', Icons.person, () => _go(context, const CoachPersonalityScreen()), requiresPremium: true),
        _StudyItem('難易度自動調整', Icons.tune, () => _go(context, AdaptiveDifficultyScreen(userId: 'user_default', isPremium: PurchaseService.isPremium)), requiresPremium: true),
        // カメラOCR盤読取は実装が存在しない完全なモック（撮影せずランダムな駒配置を
        // 表示するだけ）だったため、実装するまで課金メニューから外す。
        // 画面自体（camera_ocr_screen.dart）は将来の実装に備えて残してある。
        _StudyItem('音声入出力', Icons.mic, () => _go(context, const VoiceIOScreen()), requiresPremium: true),
        _StudyItem('パーソナライズ学習', Icons.menu_book, () => _go(context, const PersonalizedLessonScreen()), requiresPremium: true),
      ]),
      _StudySection('記録・実績', Icons.leaderboard, const Color(0xFF78909C), [
        _StudyItem('ランキング', Icons.leaderboard, () => _go(context, const RankingScreen())),
        _StudyItem('バッジ', Icons.military_tech, () => _go(context, const BadgeScreen())),
        _StudyItem('総合統計', Icons.public, () => _go(context, const StatisticsScreen())),
        _StudyItem('スコアボード', Icons.emoji_events_outlined,
            () => _goWithAnalyses(context, (games) => LeaderboardScreen(games: games))),
        _StudyItem('期間別分析', Icons.date_range,
            () => _goWithAnalyses(context, (games) => CustomPeriodAnalysisScreen(games: games))),
      ]),
    ];
    final widgets = <Widget>[];
    for (final s in sections) {
      widgets.add(_sectionHeaderTile(s));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_tileGrid(s));
      widgets.add(const SizedBox(height: 22));
    }
    return widgets;
  }

  Widget _sectionHeaderTile(_StudySection s) {
    return Row(
      children: [
        Icon(s.icon, color: s.color, size: 18),
        const SizedBox(width: 8),
        Text(
          s.title,
          style: TextStyle(
            color: s.color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _tileGrid(_StudySection s) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: s.items
          .map((it) => _LearnTile(item: it, color: s.color))
          .toList(),
    );
  }

}

// ===== 学習タブ: カテゴリ／タイルのデータ =====
class _StudySection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_StudyItem> items;
  _StudySection(this.title, this.icon, this.color, this.items);
}

class _StudyItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool requiresPremium;
  _StudyItem(this.label, this.icon, this.onTap, {this.requiresPremium = false});
}

class _LearnTile extends StatelessWidget {
  final _StudyItem item;
  final Color color;
  const _LearnTile({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    final locked = item.requiresPremium && !PurchaseService.isPremium;
    return GestureDetector(
      onTap: locked
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()))
          : item.onTap,
      child: Stack(
        children: [
          // Stack 内の非 Positioned 子は中身サイズに縮むため、タイル幅を揃えるには fill が必要
          Positioned.fill(
            child: Opacity(
            opacity: locked ? 0.55 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(60)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )),
          if (locked)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.lock, color: Colors.amber, size: 14),
            ),
        ],
      ),
    );
  }
}


// ===== タブ 3: 設定 =====
class _SettingsTab extends StatelessWidget {
  final int? timeLimitSec;
  final int? byoyomiSec;
  final int fischerIncrementSec;
  final PieceTheme theme;
  final PieceLabelStyle labelStyle;
  final bool speechEnabled;
  final bool soundEnabled;
  final ValueChanged<int?> onTime;
  final ValueChanged<int?> onByoyomi;
  final ValueChanged<int> onFischer;
  final ValueChanged<PieceTheme> onTheme;
  final ValueChanged<PieceLabelStyle> onLabelStyle;
  final ValueChanged<bool> onSpeech;
  final ValueChanged<bool> onSound;

  static const _timeOptions = [null, 180, 300, 600, 900, 1800];
  static const _timeLabels = ['なし', '3分', '5分', '10分', '15分', '30分'];
  static const _fischerOptions = [0, 5, 10, 15, 30];
  static const _fischerLabels = ['なし', '+5秒', '+10秒', '+15秒', '+30秒'];

  const _SettingsTab({
    required this.timeLimitSec,
    required this.byoyomiSec,
    required this.fischerIncrementSec,
    required this.theme,
    required this.labelStyle,
    required this.speechEnabled,
    required this.soundEnabled,
    required this.onTime,
    required this.onByoyomi,
    required this.onFischer,
    required this.onTheme,
    required this.onLabelStyle,
    required this.onSpeech,
    required this.onSound,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              '設定',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ── プレミアム ──
            _sectionLabel('プレミアム'),
            const SizedBox(height: 8),
            _buildPremiumCard(context),
            const SizedBox(height: 20),

            // ── 持ち時間プリセット ──
            _sectionLabel('持ち時間プリセット'),
            const SizedBox(height: 8),
            _buildTimePresets(context),
            const SizedBox(height: 12),

            _settingCard([
              // ── 持ち時間 ──
              _settingRow(
                '持ち時間',
                DropdownButton<int?>(
                  value: timeLimitSec,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: List.generate(
                    _timeOptions.length,
                    (i) => DropdownMenuItem(
                      value: _timeOptions[i],
                      child: Text(
                        _timeLabels[i],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  onChanged: onTime,
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              // ── 秒読み ──
              _settingRow(
                '秒読み',
                DropdownButton<int?>(
                  value: byoyomiSec,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('なし', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text('30秒', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 60,
                      child: Text('60秒', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 120,
                      child: Text('2分', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: onByoyomi,
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              // ── フィッシャー加算 ──
              _settingRow(
                'フィッシャー加算',
                DropdownButton<int>(
                  value: fischerIncrementSec,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: List.generate(
                    _fischerOptions.length,
                    (i) => DropdownMenuItem(
                      value: _fischerOptions[i],
                      child: Text(
                        _fischerLabels[i],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) onFischer(v);
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 24),

              // ── 盤面テーマ ──
              _sectionLabel('盤面テーマ'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PieceTheme.values.map((t) {
                  final cfg = boardThemeConfig(t);
                  final sel = theme == t;
                  return GestureDetector(
                    onTap: () => onTheme(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      decoration: BoxDecoration(
                        color: cfg.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? Colors.amber : Colors.white24,
                          width: sel ? 2.5 : 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withAlpha(80),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              width: double.infinity,
                              height: 66,
                              decoration: BoxDecoration(
                                color: cfg.cell,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: cfg.boardBorder,
                                  width: 2,
                                ),
                              ),
                              child: CustomPaint(
                                painter: _ThemePreviewPainter(cfg: cfg),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              cfg.label,
                              style: TextStyle(
                                color: sel ? Colors.amber : Colors.white70,
                                fontSize: 11,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white12, height: 24),

              // ── 駒ラベルスタイル ──
              _sectionLabel('駒ラベルスタイル'),
              const SizedBox(height: 10),
              Row(
                children: PieceLabelStyle.values.map((style) {
                  final sel = labelStyle == style;
                  final label = style == PieceLabelStyle.kanji
                      ? '漢字'
                      : '英字 (K/B/R...)';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onLabelStyle(style),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? Colors.amber.withAlpha(40)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? Colors.amber : Colors.white24,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: sel ? Colors.amber : Colors.white70,
                            fontSize: 13,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white12, height: 24),

              // ── 音声読み上げ ──
              _settingRow(
                '音声読み上げ',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      speechEnabled ? Icons.volume_up : Icons.volume_off,
                      color: speechEnabled
                          ? Colors.greenAccent
                          : Colors.white38,
                      size: 18,
                    ),
                    Switch(
                      value: speechEnabled,
                      activeColor: Colors.greenAccent,
                      onChanged: onSpeech,
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              // ── 駒の音 ──
              _settingRow(
                '駒の音',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      soundEnabled ? Icons.music_note : Icons.music_off,
                      color: soundEnabled
                          ? Colors.orangeAccent
                          : Colors.white38,
                      size: 18,
                    ),
                    Switch(
                      value: soundEnabled,
                      activeColor: Colors.orangeAccent,
                      onChanged: onSound,
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── アイコン設定 ──
            _sectionLabel('アイコン設定'),
            const SizedBox(height: 8),
            _settingCard([
              Builder(
                builder: (ctx) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.face, color: Colors.amber),
                  title: const Text('キャラクターアイコン', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('対局中に表示されるアイコンを変更', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CustomizeScreen())),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── 感想戦・再生表示 ──
            _sectionLabel('感想戦・再生表示'),
            const SizedBox(height: 8),
            _settingCard([const _AttackMapToggleRow()]),
            const SizedBox(height: 20),

            // ── 言語設定 ──
            _sectionLabel('言語 / Language'),
            const SizedBox(height: 8),
            _settingCard([
              Builder(
                builder: (ctx) => LanguageSettingsWidget(onChanged: () {}),
              ),
            ]),
            const SizedBox(height: 20),

            // ── フィードバック ──
            _sectionLabel('フィードバック'),
            const SizedBox(height: 8),
            _settingCard([
              _feedbackTile(
                context,
                icon: Icons.bug_report_outlined,
                color: Colors.redAccent,
                title: 'バグを報告する',
                subtitle: '不具合・おかしな動作を教えてください',
                type: FeedbackType.bug,
              ),
              const Divider(color: Colors.white12, height: 16),
              _feedbackTile(
                context,
                icon: Icons.lightbulb_outline,
                color: Colors.amber,
                title: '改善要望を送る',
                subtitle: 'こんな機能が欲しい！をお聞かせください',
                type: FeedbackType.request,
              ),
              const Divider(color: Colors.white12, height: 16),
              _feedbackTile(
                context,
                icon: Icons.chat_bubble_outline,
                color: Colors.blueAccent,
                title: 'その他のご意見',
                subtitle: 'ご感想・お問い合わせ',
                type: FeedbackType.other,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePresets(BuildContext context) {
    // (label, timeLimitSec, byoyomiSec)
    const presets = [
      ('⚡ 早指し', 180, 30),
      ('⏱ 標準', 600, 60),
      ('🕐 長考', 1800, 120),
    ];
    return Row(
      children: presets.map((p) {
        final active = timeLimitSec == p.$2 && byoyomiSec == p.$3;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                onTime(p.$2);
                onByoyomi(p.$3);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.brown.shade700 : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? Colors.amber : Colors.white24,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  p.$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.amber : Colors.white70,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===== 共通ウィジェット =====

// 感想戦・棋譜再生画面での「効き（利き）」可視化のON/OFF設定。
// kansousen_screen.dart / kifu_replay_screen.dart と同じキーを共有し、
// 画面側のトグルボタンとこの設定を相互に同期させる。
class _AttackMapToggleRow extends StatefulWidget {
  const _AttackMapToggleRow();

  @override
  State<_AttackMapToggleRow> createState() => _AttackMapToggleRowState();
}

class _AttackMapToggleRowState extends State<_AttackMapToggleRow> {
  static const _kShowAttackMapPref = 'review_show_attack_map';
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _enabled = prefs.getBool(_kShowAttackMapPref) ?? false);
  }

  Future<void> _toggle(bool next) async {
    setState(() => _enabled = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowAttackMapPref, next);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.visibility, color: Colors.orangeAccent),
      title: const Text('駒の効きを可視化',
          style: TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: const Text('感想戦・棋譜再生画面で先手/後手の利きを色分け表示',
          style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Switch(
        value: _enabled,
        activeColor: Colors.orangeAccent,
        onChanged: _toggle,
      ),
    );
  }
}

Widget _sectionLabel(String text) => Text(
  text,
  style: AppTheme.overline.copyWith(
    color: AppTheme.textMid,
    letterSpacing: 2,
    fontWeight: FontWeight.w500,
  ),
);

// レベルバッジ: 学習機能の対象レベルを示す小さなチップ
Widget _bigButton(
  BuildContext context,
  String label,
  IconData icon,
  Color color,
  VoidCallback onTap,
) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    ),
    onPressed: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

Widget _settingCard(List<Widget> children) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white12),
  ),
  // ListTile のインク効果が DecoratedBox に隠れないよう透明 Material で包む
  child: Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  ),
);

Widget _settingChip(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: color.withAlpha(50),
    border: Border.all(color: color, width: 0.8),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
  ),
);

Widget _settingRow(String label, Widget control) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const Spacer(),
      control,
    ],
  ),
);

Widget _buildPremiumCard(BuildContext context) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: PurchaseService.isPremium ? AppTheme.accent : Colors.white12,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.diamond,
            color: PurchaseService.isPremium
                ? AppTheme.accent
                : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            PurchaseService.isPremium ? 'プレミアム購入済み' : 'プレミアムプラン',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (!PurchaseService.isPremium) ...[
        const Text(
          '300円・500円のプランから選択',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text(
              'プレミアムプランを購入',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ],
  ),
);

Widget _feedbackTile(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required FeedbackType type,
}) {
  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FeedbackScreen(initialType: type)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        ],
      ),
    ),
  );
}

// ===== テーマプレビュー CustomPainter =====
class _ThemePreviewPainter extends CustomPainter {
  final BoardThemeConfig cfg;
  const _ThemePreviewPainter({required this.cfg});

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 3;
    final ch = size.height / 3;
    // 3×3 グリッド（縦横それぞれの高さに合わせる）
    final gridP = Paint()
      ..color = cfg.cellBorder
      ..strokeWidth = 0.6;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), gridP);
      canvas.drawLine(Offset(0, i * ch), Offset(size.width, i * ch), gridP);
    }
    // 星目（中央マスの四隅）
    final dotP = Paint()..color = cfg.starPoint;
    for (final dx in [cw, cw * 2]) {
      for (final dy in [ch, ch * 2]) {
        canvas.drawCircle(Offset(dx, dy), 1.6, dotP);
      }
    }
    // 中央マスに王（実際の盤と同じ五角形の駒）
    final pw = cw * 0.92;
    final ph = ch * 0.98;
    canvas.save();
    canvas.translate(cw + (cw - pw) / 2, ch + (ch - ph) / 2);
    KomaPainter(
      pointsUp: true,
      fill: Color.lerp(cfg.cell, const Color(0xFFF4DDA6), 0.7)!,
      border: cfg.boardBorder,
    ).paint(canvas, Size(pw, ph));
    canvas.restore();
    final tp = TextPainter(
      text: TextSpan(
        text: '王',
        style: komaLabelStyle(isPromoted: false, fontSize: ph * 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cw * 1.5 - tp.width / 2, ch * 1.5 - tp.height / 2 + ph * 0.06),
    );
  }

  @override
  bool shouldRepaint(_ThemePreviewPainter old) => old.cfg != cfg;
}

class _RatingMiniGraphPainter extends CustomPainter {
  final List<int> history;
  final int currentRating;
  const _RatingMiniGraphPainter({
    required this.history,
    required this.currentRating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final mn = history.reduce((a, b) => a < b ? a : b) - 50;
    final mx = history.reduce((a, b) => a > b ? a : b) + 50;
    final range = (mx - mn).toDouble();
    if (range <= 0) return;

    final pts = <Offset>[];
    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final y = size.height - ((history[i] - mn) / range) * size.height;
      pts.add(Offset(x, y));
    }

    // Draw filled area
    final path = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) path.lineTo(p.dx, p.dy);
    path
      ..lineTo(pts.last.dx, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.lightBlueAccent.withAlpha(20)
        ..style = PaintingStyle.fill,
    );

    // Draw line
    final linePaint = Paint()
      ..color = Colors.lightBlueAccent.withAlpha(160)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) linePath.lineTo(pts[i].dx, pts[i].dy);
    canvas.drawPath(linePath, linePaint);

    // Last point dot
    canvas.drawCircle(pts.last, 3, Paint()..color = Colors.lightBlueAccent);
  }

  @override
  bool shouldRepaint(_RatingMiniGraphPainter old) =>
      old.history != history || old.currentRating != currentRating;
}
