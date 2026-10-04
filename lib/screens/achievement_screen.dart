// lib/screens/achievement_screen.dart
// 実績表示画面

import 'package:flutter/material.dart';
import '../services/network_achievement_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('実績', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const _AchievementBody(),
    );
  }
}

class _AchievementBody extends StatelessWidget {
  const _AchievementBody();

  @override
  Widget build(BuildContext context) {
    final networkService = NetworkService();
    final achievementService = NetworkAchievementService();
    final uid = networkService.currentUser?.uid;

    if (uid == null) {
      return const Center(
          child:
              Text('ログインが必要です', style: TextStyle(color: Colors.white54)));
    }

    return StreamBuilder<List<String>>(
      stream: achievementService.watchUnlockedAchievements(uid),
      builder: (context, snap) {
        final unlocked = snap.data ?? [];
        final total = kAchievements.length;
        final unlockedCount = unlocked.length;

        return Column(
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount / $total 解除',
                        style: const TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? unlockedCount / total : 0,
                            backgroundColor: AppTheme.surfaceHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.amber),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 実績リスト
            Expanded(
              child: _buildAchievementList(unlocked),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementList(List<String> unlocked) {
    // カテゴリごとにグループ化
    final categories = [
      {
        'title': '対局実績',
        'ids': [
          AchievementId.netFirst,
          AchievementId.netWin1,
          AchievementId.netWin10,
          AchievementId.netWin50,
          AchievementId.netWin100,
          AchievementId.netWin500,
          AchievementId.play100,
          AchievementId.play500,
        ],
      },
      {
        'title': 'レーティング',
        'ids': [
          AchievementId.rating1600,
          AchievementId.rating1800,
          AchievementId.rating2000,
          AchievementId.rating2200,
          AchievementId.rating2500,
        ],
      },
      {
        'title': '連勝',
        'ids': [
          AchievementId.streak3,
          AchievementId.streak5,
          AchievementId.streak10,
        ],
      },
      {
        'title': '特殊勝利',
        'ids': [
          AchievementId.win5Checkmate,
          AchievementId.win5Resign,
        ],
      },
      {
        'title': 'コミュニティ',
        'ids': [
          AchievementId.spectate10,
          AchievementId.friend5,
          AchievementId.tournamentWin,
        ],
      },
      {
        'title': 'デイリー',
        'ids': [
          AchievementId.streak7Daily,
          AchievementId.streak30Daily,
          AchievementId.challenge100pt,
        ],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: categories.length,
      itemBuilder: (_, catIdx) {
        final cat = categories[catIdx];
        final title = cat['title'] as String;
        final ids = cat['ids'] as List<String>;

        final catUnlocked = ids.where((id) => unlocked.contains(id)).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$catUnlocked/${ids.length}',
                    style: const TextStyle(
                        color: AppTheme.textLow, fontSize: 12),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: ids.length,
              itemBuilder: (_, i) {
                final id = ids[i];
                final def = kAchievements[id]!;
                final isUnlocked = unlocked.contains(id);
                return _AchievementCard(
                  def: def,
                  isUnlocked: isUnlocked,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementDef def;
  final bool isUnlocked;

  const _AchievementCard({required this.def, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked
              ? AppTheme.surface
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnlocked
                ? Colors.amber.withAlpha(120)
                : Colors.grey.shade800,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isUnlocked ? def.emoji : '🔒',
              style: TextStyle(
                  fontSize: 28,
                  color: isUnlocked ? null : Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                def.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked ? AppTheme.textHigh : Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Text(isUnlocked ? def.emoji : '🔒',
                style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                def.title,
                style: TextStyle(
                  color: isUnlocked ? AppTheme.textHigh : AppTheme.textLow,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          def.description,
          style: const TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          if (isUnlocked)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text('解除済み',
                      style:
                          TextStyle(color: Colors.green, fontSize: 12)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる',
                  style: TextStyle(color: Colors.white54)),
            ),
        ],
      ),
    );
  }
}
