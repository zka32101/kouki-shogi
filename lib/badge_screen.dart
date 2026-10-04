// lib/badge_screen.dart — バッジ一覧画面

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'badge_service.dart';
import 'theme/app_theme.dart';

class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  Set<BadgeId> _unlocked = {};
  Map<BadgeId, String> _dates = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = await BadgeService.unlockedIds(prefs);
    final dates    = BadgeService.unlockDates(prefs);
    if (mounted) {
      setState(() {
        _unlocked = unlocked;
        _dates    = dates;
        _loading  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _unlocked.length;
    final total         = allBadges.length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('バッジ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$unlockedCount / $total',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
              children: [
                // 進捗バー
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '解除済み: $unlockedCount / $total',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            '${(unlockedCount / total * 100).round()}%',
                            style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: total > 0 ? unlockedCount / total : 0,
                        backgroundColor: const Color(0xFF2A2A4A),
                        color: Colors.amber,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                // バッジグリッド
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: allBadges.length,
                    itemBuilder: (ctx, i) {
                      final badge   = allBadges[i];
                      final isUnlocked = _unlocked.contains(badge.id);
                      final date    = _dates[badge.id];
                      return _BadgeCell(
                        badge:      badge,
                        isUnlocked: isUnlocked,
                        unlockDate: date,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── バッジセル ────────────────────────────────────────────────
class _BadgeCell extends StatelessWidget {
  final BadgeDef badge;
  final bool isUnlocked;
  final String? unlockDate;

  const _BadgeCell({
    required this.badge,
    required this.isUnlocked,
    this.unlockDate,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? badge.color : Colors.white24;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isUnlocked
              ? badge.color.withAlpha(20)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked ? badge.color.withAlpha(150) : Colors.white12,
            width: isUnlocked ? 1.5 : 1,
          ),
          boxShadow: isUnlocked
              ? [BoxShadow(color: badge.color.withAlpha(40), blurRadius: 6)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アイコン
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked ? badge.color.withAlpha(30) : Colors.white12,
                border: Border.all(
                  color: isUnlocked ? badge.color.withAlpha(150) : Colors.white12,
                ),
              ),
              child: Icon(
                badge.icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            // タイトル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                badge.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isUnlocked && unlockDate != null) ...[
              const SizedBox(height: 3),
              Text(
                unlockDate!,
                style: TextStyle(
                  color: badge.color.withAlpha(180),
                  fontSize: 9,
                ),
              ),
            ],
            if (!isUnlocked) ...[
              const SizedBox(height: 3),
              const Icon(Icons.lock, color: Colors.white24, size: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked ? badge.color.withAlpha(30) : Colors.white12,
                border: Border.all(
                  color: isUnlocked ? badge.color : Colors.white24,
                  width: 2,
                ),
              ),
              child: Icon(
                badge.icon,
                color: isUnlocked ? badge.color : Colors.white38,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: TextStyle(
                color: isUnlocked ? badge.color : Colors.white54,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            if (isUnlocked && unlockDate != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '解除日: $unlockDate',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (!isUnlocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'まだ解除されていません',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
