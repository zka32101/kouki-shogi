// lib/screens/network_game_home.dart
// ネットワーク対局ホーム画面

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/network_service.dart';
import '../services/matching_service.dart';
import '../services/fcm_service.dart';
import 'match_screen.dart';
import 'ranking_screen.dart';
import 'spectator_screen.dart';
import 'tournament_screen.dart';
import 'player_profile_screen.dart';
import 'friend_screen.dart';
import 'daily_challenge_screen.dart';
import 'achievement_screen.dart';
import 'season_screen.dart';
import 'premium_screen.dart';
import 'customize_screen.dart';
import 'club_screen.dart';
import 'lishogi_puzzle_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_tile.dart';

class NetworkGameHome extends StatefulWidget {
  const NetworkGameHome({super.key});

  @override
  State<NetworkGameHome> createState() => _NetworkGameHomeState();
}

class _NetworkGameHomeState extends State<NetworkGameHome> {
  final NetworkService _networkService = NetworkService();
  final MatchingService _matchingService = MatchingService();
  final FcmService _fcmService = FcmService();
  bool _isLoading = false;
  String? _queueId;
  // 持ち時間: 600=10分, 300=5分 のみ有効
  int _timeLimitSec = 600;

  // 中断対局の復帰情報
  String? _resumeMatchId;
  bool _resumeIsP1 = true;
  String _resumePlayerId = '';
  int _resumeTimeLimitSec = 600;

  @override
  void initState() {
    super.initState();
    _fcmService.initialize();
    _checkResumeMatch();
  }

  // ── 中断対局の確認 ──────────────────────────────────────────

  Future<void> _checkResumeMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final matchId = prefs.getString('net_active_match_id');
      if (matchId == null) return;

      // RTDBでまだアクティブか確認
      final snap = await FirebaseDatabase.instance.ref('games/$matchId').get();
      if (!snap.exists) {
        await _clearResumePrefs(prefs);
        return;
      }
      final data = Map<String, dynamic>.from(snap.value as Map);
      if (data['status'] != 'active') {
        await _clearResumePrefs(prefs);
        return;
      }

      if (mounted) {
        setState(() {
          _resumeMatchId = matchId;
          _resumeIsP1 = prefs.getBool('net_active_match_is_p1') ?? true;
          _resumePlayerId = prefs.getString('net_active_match_player_id') ?? '';
          _resumeTimeLimitSec = prefs.getInt('net_active_match_time_limit') ?? 600;
        });
      }
    } catch (_) {}
  }

  Future<void> _clearResumePrefs(SharedPreferences prefs) async {
    await prefs.remove('net_active_match_id');
    await prefs.remove('net_active_match_is_p1');
    await prefs.remove('net_active_match_player_id');
    await prefs.remove('net_active_match_time_limit');
  }

  void _resumeGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchScreen(
          matchId: _resumeMatchId!,
          isPlayer1: _resumeIsP1,
          myPlayerId: _resumePlayerId,
          timeLimitSec: _resumeTimeLimitSec,
        ),
      ),
    ).then((_) {
      // 戻ってきたときに再チェック（ゲームが終了していれば非表示）
      setState(() => _resumeMatchId = null);
      _checkResumeMatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ネットワーク対局', style: TextStyle(color: AppTheme.textHigh)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.s2),

              // 中断対局の再開カード
              if (_resumeMatchId != null)
                Card(
                  color: Colors.green.shade900,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_filled,
                        color: Colors.greenAccent, size: 32),
                    title: const Text('対局が中断されています',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${_resumeTimeLimitSec == 600 ? "10分" : "5分"}局 • ${_resumeIsP1 ? "先手" : "後手"}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _resumeGame(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black),
                      child: const Text('再開'),
                    ),
                  ),
                ),

              // 持ち時間選択 + 対局ボタン
              Row(
                children: [
                  // 持ち時間切り替え（10分/5分のみ）
                  _TimeLimitToggle(
                    value: _timeLimitSec,
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() => _timeLimitSec = v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _startNetworkGame(context),
                      icon: const Icon(Icons.public),
                      label: const Text('対局を探す',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppTheme.primary.withAlpha(120),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.rBtn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const SizedBox(height: AppTheme.s5),

              // ── 対局系 ──
              _sectionLabel('対局'),
              _menuGrid([
                MenuTile(
                  icon: Icons.military_tech,
                  label: 'ランク対戦',
                  categoryColor: AppTheme.catPlay,
                  onTap: _isLoading ? null : () => _startRankMatch(context),
                ),
                MenuTile(
                  icon: Icons.groups,
                  label: 'クラブ対戦',
                  categoryColor: AppTheme.catPlay,
                  onTap: _isLoading ? null : () => _startClubMatch(context),
                ),
                MenuTile(
                  icon: Icons.today,
                  label: 'デイリー',
                  categoryColor: AppTheme.catPlay,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const DailyChallengeScreen())),
                ),
                MenuTile(
                  icon: Icons.emoji_events,
                  label: 'トーナメント',
                  categoryColor: AppTheme.catPlay,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const TournamentListScreen())),
                ),
                MenuTile(
                  icon: Icons.live_tv,
                  label: 'ライブ観戦',
                  categoryColor: AppTheme.catPlay,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SpectatorListScreen())),
                ),
              ]),

              const SizedBox(height: AppTheme.s4),

              // ── 育成・実績系 ──
              _sectionLabel('育成・記録'),
              _menuGrid([
                MenuTile(
                  icon: Icons.leaderboard,
                  label: 'ランキング',
                  categoryColor: AppTheme.catGrow,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const RankingScreen())),
                ),
                MenuTile(
                  icon: Icons.military_tech,
                  label: '実績',
                  categoryColor: AppTheme.catGrow,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AchievementScreen())),
                ),
                MenuTile(
                  icon: Icons.calendar_month,
                  label: 'シーズン',
                  categoryColor: AppTheme.catGrow,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SeasonScreen())),
                ),
                MenuTile(
                  icon: Icons.extension,
                  label: 'パズル',
                  categoryColor: AppTheme.catGrow,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LishogiPuzzleScreen())),
                ),
              ]),

              const SizedBox(height: AppTheme.s4),

              // ── 交流系 ──
              _sectionLabel('交流'),
              _menuGrid([
                MenuTile(
                  icon: Icons.person,
                  label: 'プロフィール',
                  categoryColor: AppTheme.catSocial,
                  onTap: () {
                    final uid = _networkService.currentUser?.uid;
                    if (uid != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(
                            userId: uid, isCurrentUser: true),
                      ));
                    }
                  },
                ),
                MenuTile(
                  icon: Icons.group,
                  label: 'フレンド',
                  categoryColor: AppTheme.catSocial,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const FriendScreen())),
                ),
                MenuTile(
                  icon: Icons.groups_2,
                  label: 'クラブ',
                  categoryColor: AppTheme.catSocial,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ClubScreen())),
                ),
              ]),

              const SizedBox(height: AppTheme.s4),

              // ── 設定・課金系 ──
              _sectionLabel('設定'),
              _menuGrid([
                MenuTile(
                  icon: Icons.palette,
                  label: 'カスタマイズ',
                  categoryColor: AppTheme.catConfig,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CustomizeScreen())),
                ),
                MenuTile(
                  icon: Icons.workspace_premium,
                  label: 'プレミアム',
                  categoryColor: AppTheme.accent,
                  badge: 'PRO',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PremiumScreen())),
                ),
              ]),
              const SizedBox(height: AppTheme.s3),

              // マッチング中の表示
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // 説明
              Container(
                padding: const EdgeInsets.all(AppTheme.s4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.rCard),
                  border: Border.all(color: AppTheme.surfaceHigh, width: 1),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppTheme.textMid, size: 18),
                        SizedBox(width: AppTheme.s2),
                        Text(
                          '対局時のルール',
                          style: TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.s3),
                    Text(
                      '• ソフト指し（AI支援）は禁止です\n'
                      '• 不正な行動を検出した場合は報告できます\n'
                      '• 一定数の報告でアカウントが停止されます\n'
                      '• 健全なコミュニティを保ちましょう',
                      style: TextStyle(color: AppTheme.textMid, height: 1.6, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── メニューUI ヘルパー ──────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppTheme.s2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMid,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// 2列のメニューグリッド（高さ自動・スクロール無効）。
  Widget _menuGrid(List<Widget> tiles) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.s2,
      crossAxisSpacing: AppTheme.s2,
      childAspectRatio: 3.0,
      children: tiles,
    );
  }

  Future<void> _startNetworkGame(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = _networkService.currentUser;
      if (currentUser == null) {
        throw Exception('ログインが必要です');
      }

      // ✅ 対局前 BAN チェック
      final isBanned = await _networkService.isUserBanned(currentUser.uid);
      if (isBanned) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('アカウント停止'),
              content: const Text(
                'このアカウントは不正行為のため停止されています。\n\n'
                '詳細は support@kouki.jp までお問い合わせください。',
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
        return;
      }

      // ② ユーザー情報を取得
      final userProfile =
          await _networkService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        throw Exception('ユーザー情報が見つかりません');
      }

      // ③ マッチング待機キューに参加
      final queueId = await _matchingService.joinMatchingQueue(
        currentUser.uid,
        userProfile,
        100, // ±100のレーティング範囲
      );

      setState(() => _queueId = queueId);

      // ④ マッチング結果を待機
      if (mounted) {
        _showMatchingWaitDialog(context, queueId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// ランク対戦（同じ段級位の相手とのみマッチング）
  Future<void> _startRankMatch(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final currentUser = _networkService.currentUser;
      if (currentUser == null) throw Exception('ログインが必要です');

      final isBanned = await _networkService.isUserBanned(currentUser.uid);
      if (isBanned) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('アカウント停止'),
              content: const Text('このアカウントは停止されています。'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
              ],
            ),
          );
        }
        return;
      }

      final userProfile = await _networkService.getUserProfile(currentUser.uid);
      if (userProfile == null) throw Exception('ユーザー情報が見つかりません');

      // ランク帯限定マッチング（同じ段級位の相手のみ）
      final queueId = await _matchingService.joinMatchingQueue(
        currentUser.uid,
        userProfile,
        0, // rankTierOnly=true の場合は無視される
        rankTierOnly: true,
      );

      setState(() => _queueId = queueId);
      if (mounted) {
        _showMatchingWaitDialog(context, queueId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// クラブ対戦（同クラブ優先マッチング）
  Future<void> _startClubMatch(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final currentUser = _networkService.currentUser;
      if (currentUser == null) throw Exception('ログインが必要です');

      final isBanned = await _networkService.isUserBanned(currentUser.uid);
      if (isBanned) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('アカウント停止'),
              content: const Text('このアカウントは停止されています。'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
              ],
            ),
          );
        }
        return;
      }

      final userProfile = await _networkService.getUserProfile(currentUser.uid);
      if (userProfile == null) throw Exception('ユーザー情報が見つかりません');

      // クラブ限定マッチング（ratingRange広め: ±300）
      final queueId = await _matchingService.joinMatchingQueue(
        currentUser.uid,
        userProfile,
        300,
        clubMatchOnly: true,
      );

      setState(() => _queueId = queueId);
      if (mounted) {
        _showClubMatchingWaitDialog(context, queueId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// クラブマッチング待機ダイアログ
  void _showClubMatchingWaitDialog(BuildContext context, String queueId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('クラブメンバーを探索中...', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
            ),
            const SizedBox(height: 16),
            const Text(
              '同クラブのメンバーを待っています\n（最大5分）',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            StreamBuilder<dynamic>(
              stream: _matchingService.watchMatchingQueue(queueId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final queue = snapshot.data;
                  if (queue.isMatched && queue.matchId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MatchScreen(
                          matchId: queue.matchId,
                          isPlayer1: true,
                          timeLimitSec: _timeLimitSec,
                        ),
                      ));
                    });
                  }
                  if (queue.isCancelled) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('クラブメンバーが見つかりませんでした')),
                      );
                      if (mounted) setState(() => _isLoading = false);
                    });
                  }
                }
                return ElevatedButton(
                  onPressed: () async {
                    await _matchingService.cancelMatchingQueue(queueId);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  child: const Text('キャンセル'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// マッチング待機ダイアログ
  void _showMatchingWaitDialog(BuildContext context, String queueId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '対戦相手を探索中...',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
            const SizedBox(height: 16),
            const Text(
              '相手が見つかるまでお待ちください\n（最大5分）',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            StreamBuilder<dynamic>(
              stream: _matchingService.watchMatchingQueue(queueId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final queue = snapshot.data;

                  // マッチング成功
                  if (queue.isMatched && queue.matchId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context); // ダイアログを閉じる
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchScreen(
                            matchId: queue.matchId,
                            isPlayer1: true,
                            timeLimitSec: _timeLimitSec,
                          ),
                        ),
                      );
                    });
                  }

                  // マッチング失敗（タイムアウト）
                  if (queue.isCancelled) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('相手が見つかりませんでした'),
                        ),
                      );
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    });
                  }
                }

                return ElevatedButton(
                  onPressed: () async {
                    await _matchingService.cancelMatchingQueue(queueId);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  child: const Text('キャンセル'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 持ち時間トグル（10分 / 5分）─────────────────────────────────

class _TimeLimitToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const _TimeLimitToggle({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('持ち時間', style: TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Row(
          children: [
            _Chip(label: '10分', selected: value == 600,
                onTap: onChanged != null ? () => onChanged!(600) : null),
            const SizedBox(width: 4),
            _Chip(label: '5分', selected: value == 300,
                onTap: onChanged != null ? () => onChanged!(300) : null),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Chip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.brown.shade600 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.amber : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
