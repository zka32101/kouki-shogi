// lib/screens/notification_settings_screen.dart
// 通知設定画面

import 'package:flutter/material.dart';
import '../services/fcm_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final FcmService _fcmService = FcmService();
  final NetworkService _networkService = NetworkService();

  bool _matchFound = true;
  bool _opponentMoved = true;
  bool _tournament = true;
  bool _friends = true;
  bool _dailyChallenge = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _networkService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final settings = await _fcmService.getNotificationSettings(uid);
    setState(() {
      _matchFound = settings['match_found'] ?? true;
      _opponentMoved = settings['opponent_moved'] ?? true;
      _tournament = settings['tournament'] ?? true;
      _friends = settings['friends'] ?? true;
      _dailyChallenge = settings['daily_challenge'] ?? false;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final uid = _networkService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _fcmService.updateNotificationSettings(
        userId: uid,
        matchFound: _matchFound,
        opponentMoved: _opponentMoved,
        tournament: _tournament,
        friends: _friends,
        dailyChallenge: _dailyChallenge,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知設定を保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました（ネットワークを確認してください）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('通知設定', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionHeader('対局通知'),
                _NotifTile(
                  title: '対戦相手マッチング',
                  subtitle: '対局相手が見つかったとき',
                  icon: Icons.person_search,
                  value: _matchFound,
                  onChanged: (v) => setState(() => _matchFound = v),
                ),
                _NotifTile(
                  title: '相手が指した',
                  subtitle: '対局中に相手が手を指したとき',
                  icon: Icons.sports_esports,
                  value: _opponentMoved,
                  onChanged: (v) => setState(() => _opponentMoved = v),
                ),
                const SizedBox(height: 16),
                const _SectionHeader('トーナメント'),
                _NotifTile(
                  title: 'トーナメント試合開始',
                  subtitle: 'トーナメントで試合が始まるとき',
                  icon: Icons.emoji_events,
                  value: _tournament,
                  onChanged: (v) => setState(() => _tournament = v),
                ),
                const SizedBox(height: 16),
                const _SectionHeader('フレンド'),
                _NotifTile(
                  title: 'フレンド申請・招待',
                  subtitle: 'フレンド申請や対局招待が届いたとき',
                  icon: Icons.group,
                  value: _friends,
                  onChanged: (v) => setState(() => _friends = v),
                ),
                const SizedBox(height: 16),
                const _SectionHeader('チャレンジ'),
                _NotifTile(
                  title: 'デイリーチャレンジ',
                  subtitle: '毎朝のチャレンジ更新通知（0時）',
                  icon: Icons.today,
                  value: _dailyChallenge,
                  onChanged: (v) => setState(() => _dailyChallenge = v),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: value ? Colors.amber : Colors.white38),
        title: Text(title,
            style: TextStyle(
                color: value ? Colors.white : Colors.white54,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.amber,
        inactiveThumbColor: Colors.grey.shade600,
        inactiveTrackColor: Colors.grey.shade800,
      ),
    );
  }
}
