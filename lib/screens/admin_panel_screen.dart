// lib/screens/admin_panel_screen.dart
// 管理者向け管理画面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/network_service.dart';
import '../services/cheat_detection_service.dart';
import '../theme/app_theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final NetworkService _networkService = NetworkService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CheatDetectionService _cheatService = CheatDetectionService();

  int _tabIndex = 0; // 0: 報告一覧、1: BAN済みユーザー、2: チート疑い、3: 統計

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('管理パネル', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: AppTheme.textHigh),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // タブ
            Container(
              color: AppTheme.surface,
              child: Row(
                children: [
                  Expanded(child: _buildTabButton('報告一覧', 0)),
                  Expanded(child: _buildTabButton('BAN済み', 1)),
                  Expanded(child: _buildTabButton('チート疑い', 2)),
                  Expanded(child: _buildTabButton('統計', 3)),
                ],
              ),
            ),
            // コンテンツ
            Expanded(
              child: _tabIndex == 0
                  ? _buildReportsList()
                  : _tabIndex == 1
                      ? _buildBannedUsersList()
                      : _tabIndex == 2
                          ? _buildCheatSuspectsList()
                          : _buildStatsDashboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AppTheme.accent : AppTheme.textMid,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ① 報告一覧
  Widget _buildReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        if (reports.isEmpty) {
          return const Center(
            child: Text('待機中の報告はありません',
                style: TextStyle(color: AppTheme.textMid)),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '報告ID: ${report.id.substring(0, 8)}',
                        style: const TextStyle(
                          color: AppTheme.textMid,
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(100),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['reason'] == 'soft_play'
                              ? 'ソフト指し'
                              : data['reason'] == 'time_cheat'
                                  ? 'タイムチート'
                                  : 'その他',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '報告対象: ${data['reported_user_id'].substring(0, 8)}...',
                    style: const TextStyle(color: AppTheme.textHigh),
                  ),
                  Text(
                    '報告者: ${data['reporter_id'].substring(0, 8)}...',
                    style: const TextStyle(color: AppTheme.textMid, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _approveReport(report.id, data['reported_user_id']),
                        icon: const Icon(Icons.check),
                        label: const Text('承認'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _dismissReport(report.id),
                        icon: const Icon(Icons.close),
                        label: const Text('却下'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ② BAN済みユーザー一覧
  Widget _buildBannedUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('is_banned', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(
            child: Text('BAN済みユーザーはいません',
                style: TextStyle(color: AppTheme.textMid)),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;

            final bannedAt = data['banned_at'] != null
                ? DateTime.parse(data['banned_at'].toString())
                : null;
            final reason = data['ban_reason'] ?? 'unknown';
            final reasonLabel = reason == 'too_many_reports'
                ? '報告多数'
                : reason == 'spam_reporting'
                    ? '報告スパム'
                    : 'その他';

            return Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['username'] ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textHigh,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'UID: ${user.id.substring(0, 8)}...',
                              style: const TextStyle(
                                color: AppTheme.textMid,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          reasonLabel,
                          style: const TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (bannedAt != null)
                    Text(
                      'BAN日時: ${bannedAt.toString().substring(0, 16)}',
                      style: const TextStyle(
                        color: AppTheme.textMid,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _unbanUser(user.id),
                    icon: const Icon(Icons.restore),
                    label: const Text('BAN解除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 報告を承認（ユーザーをBAN）
  Future<void> _approveReport(String reportId, String reportedUid) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'reviewed',
      });

      await _firestore.collection('users').doc(reportedUid).update({
        'is_banned': true,
        'banned_at': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を承認しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // 報告を却下
  Future<void> _dismissReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'dismissed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を却下しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // BANを解除
  Future<void> _unbanUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'is_banned': false,
        'banned_at': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BAN を解除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // ③ チート疑いユーザー一覧
  Widget _buildCheatSuspectsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cheatService.watchFlaggedUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, color: AppTheme.success, size: 48),
                SizedBox(height: 12),
                Text('フラグ付きユーザーはいません',
                    style: TextStyle(color: AppTheme.textMid)),
              ],
            ),
          );
        }

        return Column(
          children: [
            // バッチ分析ボタン
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: _runBatchAnalysis,
                icon: const Icon(Icons.analytics),
                label: const Text('全ユーザーを再分析'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: AppTheme.textHigh,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;
                  final score =
                      (data['cheat_score'] as num?)?.toDouble() ?? 0;
                  final flags =
                      (data['cheat_flags'] as List?)?.cast<String>() ?? [];
                  final username =
                      data['username'] as String? ?? 'Unknown';
                  final scoreColor = score >= 85
                      ? AppTheme.danger
                      : score >= 70
                          ? Colors.orange
                          : Colors.yellow;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: scoreColor, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textHigh,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: scoreColor.withAlpha(50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'スコア: ${score.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // フラグ一覧
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: flags
                              .map((f) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger.withAlpha(150),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      f,
                                      style: const TextStyle(
                                        color: AppTheme.textMid,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _banCheatUser(user.id, username),
                                icon: const Icon(Icons.block, size: 16),
                                label: const Text('BAN'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.danger,
                                  foregroundColor: AppTheme.textHigh,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _clearCheatFlag(user.id),
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 16),
                                label: const Text('誤検知'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: AppTheme.textHigh,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runBatchAnalysis() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('バックグラウンドで分析中...')),
    );
    final results = await _cheatService.batchAnalyze(limit: 50);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '分析完了: ${results.length}件のフラグを検出しました')),
      );
    }
  }

  Future<void> _banCheatUser(String uid, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('BAN確認'),
        content: Text('$username をチート行為でBANしますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('BAN')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'is_banned': true,
        'banned_at': DateTime.now(),
        'ban_reason': 'cheat_detected',
        'flagged_for_review': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('BANしました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  Future<void> _clearCheatFlag(String uid) async {
    await _cheatService.clearFlag(uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フラグをクリアしました')),
      );
    }
  }

  // ④ 統計ダッシュボード
  Widget _buildStatsDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatCard(
            title: '総ユーザー数',
            icon: Icons.people,
            color: AppTheme.primary,
            stream: _firestore
                .collection('users')
                .snapshots()
                .map((s) => s.docs.length.toString()),
          ),
          const SizedBox(height: 10),
          _StatCard(
            title: 'BAN済みユーザー',
            icon: Icons.block,
            color: AppTheme.danger,
            stream: _firestore
                .collection('users')
                .where('is_banned', isEqualTo: true)
                .snapshots()
                .map((s) => s.docs.length.toString()),
          ),
          const SizedBox(height: 10),
          _StatCard(
            title: '未処理報告数',
            icon: Icons.flag,
            color: Colors.orange,
            stream: _firestore
                .collection('reports')
                .where('status', isEqualTo: 'pending')
                .snapshots()
                .map((s) => s.docs.length.toString()),
          ),
          const SizedBox(height: 10),
          _StatCard(
            title: '総対局数',
            icon: Icons.sports_esports,
            color: AppTheme.success,
            stream: _firestore
                .collection('matches')
                .where('status', isEqualTo: 'finished')
                .snapshots()
                .map((s) => s.docs.length.toString()),
          ),
          const SizedBox(height: 10),
          _StatCard(
            title: 'チート疑いユーザー',
            icon: Icons.warning,
            color: Colors.yellow,
            stream: _firestore
                .collection('users')
                .where('flagged_for_review', isEqualTo: true)
                .snapshots()
                .map((s) => s.docs.length.toString()),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<String> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: AppTheme.textMid, fontSize: 14),
          ),
        ),
        StreamBuilder<String>(
          stream: stream,
          builder: (ctx, snap) => Text(
            snap.data ?? '...',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ]),
    );
  }
}
