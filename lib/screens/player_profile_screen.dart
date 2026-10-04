// lib/screens/player_profile_screen.dart
// プレイヤープロフィール画面（自分 or 対戦相手）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/rating_service.dart';
import '../services/network_service.dart';
import 'match_history_screen.dart';
import 'notification_settings_screen.dart';
import 'customize_screen.dart';
import '../theme/app_theme.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const PlayerProfileScreen({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RatingService _ratingService = RatingService();
  final NetworkService _networkService = NetworkService();

  UserProfile? _profile;
  bool _isLoading = true;
  int? _globalRank;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc =
          await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        final profile = UserProfile.fromJson(doc.data()!);

        // グローバルランクを計算
        final allUsers = await _firestore.collection('users').get();
        final allRatings = allUsers.docs
            .map((d) => d['rating'] as int? ?? 1500)
            .toList();
        final rank =
            _ratingService.calculateRank(profile.rating, allRatings);

        if (mounted) {
          setState(() {
            _profile = profile;
            _globalRank = rank;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.isCurrentUser ? 'マイプロフィール' : 'プロフィール',
          style: const TextStyle(color: AppTheme.textHigh),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: widget.isCurrentUser
            ? [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white70),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NotificationSettingsScreen(),
                    ),
                  ),
                  tooltip: '通知設定',
                ),
                IconButton(
                  icon: const Icon(Icons.palette, color: Colors.white70),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CustomizeScreen())),
                  tooltip: 'カスタマイズ',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  onPressed: _editProfile,
                  tooltip: '編集',
                ),
              ]
            : [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(
                  child: Text('プロフィールが見つかりません',
                      style: TextStyle(color: AppTheme.textMid)))
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final p = _profile!;
    final total = (p.wins ?? 0) + (p.losses ?? 0);
    final winRate =
        total > 0 ? ((p.wins ?? 0) / total * 100).toStringAsFixed(1) : '0.0';
    final rankLabel = _ratingService.getRankLabel(p.rating);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── ヘッダー ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.brown.shade800,
                  AppTheme.bg,
                ],
              ),
            ),
            child: Column(
              children: [
                // アバター
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      p.username.isNotEmpty
                          ? p.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  p.username,
                  style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rankLabel,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                  ),
                ),
                if (_globalRank != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '世界 #$_globalRank 位',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 統計カード ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _statCard('レート', '${p.rating}', Colors.amber),
                const SizedBox(width: 8),
                _statCard('勝率', '$winRate%', Colors.green),
                const SizedBox(width: 8),
                _statCard('試合数', '$total', Colors.blue),
              ],
            ),
          ),

          // ── 勝敗内訳 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildWinLossBar(p.wins ?? 0, p.losses ?? 0),
          ),
          const SizedBox(height: 16),

          // ── 対局履歴ボタン ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchHistoryScreen(userId: widget.userId),
                ),
              ),
              icon: const Icon(Icons.history),
              label: const Text('対局履歴'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.catPlay,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── BAN バッジ（停止中の場合） ──
          if (p.isBanned)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'このアカウントは現在停止中です',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinLossBar(int wins, int losses) {
    final total = wins + losses;
    final winRatio = total > 0 ? wins / total : 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '勝敗',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Flexible(
                flex: (winRatio * 100).round(),
                child: Container(
                  height: 18,
                  color: Colors.green.shade700,
                  child: Center(
                    child: Text(
                      '$wins勝',
                      style:
                          const TextStyle(color: AppTheme.textHigh, fontSize: 11),
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: ((1 - winRatio) * 100).round(),
                child: Container(
                  height: 18,
                  color: Colors.red.shade800,
                  child: Center(
                    child: Text(
                      '$losses敗',
                      style:
                          const TextStyle(color: AppTheme.textHigh, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile() async {
    final controller =
        TextEditingController(text: _profile?.username ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('ユーザー名を変更',
            style: TextStyle(color: AppTheme.textHigh)),
        content: TextField(
          controller: controller,
          maxLength: 16,
          style: const TextStyle(color: AppTheme.textHigh),
          decoration: const InputDecoration(
            hintText: '新しいユーザー名',
            hintStyle: TextStyle(color: AppTheme.textLow),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.textLow),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _networkService.updateUserProfile(
          widget.userId, {'username': result.trim()});
      await _loadProfile();
    }
  }
}
