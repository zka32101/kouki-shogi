import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../models/game_analysis.dart';
import '../theme/app_theme.dart';

class GrowthStoryCard extends StatelessWidget {
  final List<GameAnalysis> allGames;
  final int daysAgo;

  const GrowthStoryCard({
    required this.allGames,
    required this.daysAgo,
  });

  String _getDateLabel(int daysAgo) {
    if (daysAgo == 90) return '3ヶ月前';
    if (daysAgo == 30) return '1ヶ月前';
    if (daysAgo == 14) return '2週間前';
    if (daysAgo == 7) return '1週間前';
    return '${daysAgo}日前';
  }

  Map<String, dynamic> _calculateStats(DateTime targetDate) {
    final pastGames = allGames
        .where((g) => g.playedAt.isBefore(
            DateTime.now().subtract(Duration(days: daysAgo))))
        .toList();
    final recentGames = allGames
        .where((g) => g.playedAt
            .isAfter(DateTime.now().subtract(Duration(days: daysAgo))))
        .toList();

    final pastWins =
        pastGames.where((g) => g.playerWon).length;
    final recentWins =
        recentGames.where((g) => g.playerWon).length;

    final pastWinRate = pastGames.isEmpty
        ? 0.0
        : pastWins / pastGames.length * 100;
    final recentWinRate = recentGames.isEmpty
        ? 0.0
        : recentWins / recentGames.length * 100;

    return {
      'pastWinRate': pastWinRate,
      'recentWinRate': recentWinRate,
      'pastGames': pastGames.length,
      'recentGames': recentGames.length,
      'rateChange': recentWinRate - pastWinRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats(
        DateTime.now().subtract(Duration(days: daysAgo)));
    final dateLabel = _getDateLabel(daysAgo);
    final rateChange = stats['rateChange'] as double;
    final isImproved = rateChange > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.bg,
            const Color(0xFF0F3460),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isImproved
              ? Colors.green.withAlpha(100)
              : Colors.orange.withAlpha(100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isImproved
                ? Colors.green.withAlpha(40)
                : Colors.orange.withAlpha(40),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Row(
            children: [
              const Icon(Icons.trending_up, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              Text(
                'あなたの成長',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 日付
          Text(
            '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),

          // 過去 → 現在
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: dateLabel,
                  winRate:
                      stats['pastWinRate'].toStringAsFixed(0),
                  games: stats['pastGames'] as int,
                  isPast: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  isImproved ? Icons.arrow_forward : Icons.trending_down,
                  color: isImproved
                      ? Colors.green.shade400
                      : Colors.orange.shade400,
                  size: 28,
                ),
              ),
              Expanded(
                child: _buildStatBox(
                  label: '現在',
                  winRate:
                      stats['recentWinRate'].toStringAsFixed(0),
                  games: stats['recentGames'] as int,
                  isPast: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 成長指標
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isImproved
                  ? Colors.green.withAlpha(30)
                  : Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isImproved
                      ? '勝率向上'
                      : '勝率低下',
                  style: TextStyle(
                    color: isImproved
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${isImproved ? '+' : ''}${rateChange.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isImproved
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // メッセージ
          Text(
            isImproved
                ? '${daysAgo}日前のあなたより強くなりました！'
                : '${daysAgo}日前に比べて調整中です。練習を続けましょう！',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String winRate,
    required int games,
    required bool isPast,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$winRate%',
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${games}対局',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// 成長ストーリーカードを画像で出力（Phase 4）
class GrowthStoryImageGenerator {
  /// 成長ストーリーを画像で生成（Canvas描画）
  static Future<Uint8List?> generateImage({
    required List<GameAnalysis> allGames,
    required int daysAgo,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const width = 800.0;
      const height = 600.0;

      // 背景
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF0F3460),
      );

      // 統計情報
      final stats = _calculateStats(allGames, daysAgo);
      final pastWinRate = (stats['pastWinRate'] as double).toStringAsFixed(0);
      final recentWinRate = (stats['recentWinRate'] as double).toStringAsFixed(0);
      final rateChange = stats['rateChange'] as double;

      // タイトル
      _drawText(
        canvas,
        '成長記録',
        const Offset(40, 40),
        40,
        AppTheme.accent,
      );

      // 日付
      final dateLabel = _getDateLabel(daysAgo);
      _drawText(
        canvas,
        '$dateLabel のあなたと比較',
        const Offset(40, 100),
        24,
        Colors.white70,
      );

      // 勝率比較
      _drawText(
        canvas,
        '勝率: $pastWinRate% → $recentWinRate%',
        const Offset(40, 180),
        28,
        Colors.white,
      );

      // 成長指標
      final growthText = rateChange > 0
          ? '+${rateChange.toStringAsFixed(1)}% 向上！'
          : '${rateChange.toStringAsFixed(1)}%';
      final growthColor = rateChange > 0 ? Colors.green : Colors.orange;
      _drawText(
        canvas,
        growthText,
        const Offset(40, 240),
        32,
        growthColor,
        fontWeight: true,
      );

      // 対局数
      _drawText(
        canvas,
        '対局数: ${allGames.length}',
        const Offset(40, 320),
        20,
        Colors.white54,
      );

      // ハッシュタグ
      _drawText(
        canvas,
        '#将棋アプリ #成長記録 #棋力向上',
        const Offset(40, 480),
        18,
        AppTheme.accent,
      );

      final image = await recorder
          .endRecording()
          .toImage(width.toInt(), height.toInt());
      final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return pngBytes?.buffer.asUint8List();
    } catch (e) {
      print('❌ 画像生成エラー: $e');
      return null;
    }
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color, {
    bool fontWeight = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  static Map<String, dynamic> _calculateStats(
    List<GameAnalysis> allGames,
    int daysAgo,
  ) {
    final targetDate = DateTime.now().subtract(Duration(days: daysAgo));
    final pastGames =
        allGames.where((g) => g.playedAt.isBefore(targetDate)).toList();
    final recentGames =
        allGames.where((g) => g.playedAt.isAfter(targetDate)).toList();

    final pastWins = pastGames.where((g) => g.playerWon).length;
    final recentWins = recentGames.where((g) => g.playerWon).length;

    final pastWinRate =
        pastGames.isEmpty ? 0.0 : pastWins / pastGames.length * 100;
    final recentWinRate =
        recentGames.isEmpty ? 0.0 : recentWins / recentGames.length * 100;

    return {
      'pastWinRate': pastWinRate,
      'recentWinRate': recentWinRate,
      'rateChange': recentWinRate - pastWinRate,
    };
  }

  static String _getDateLabel(int daysAgo) {
    if (daysAgo == 90) return '3ヶ月前';
    if (daysAgo == 30) return '1ヶ月前';
    if (daysAgo == 14) return '2週間前';
    if (daysAgo == 7) return '1週間前';
    return '${daysAgo}日前';
  }
}
