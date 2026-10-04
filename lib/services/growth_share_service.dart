import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game_analysis.dart';

class GrowthShareService {
  /// 成長ストーリーを画像として共有
  static Future<void> shareGrowthStory({
    required Uint8List imageBytes,
    required List<GameAnalysis> allGames,
    required int daysAgo,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/growth_story_$daysAgo.png');
      await file.writeAsBytes(imageBytes);

      final stats = _calculateStats(allGames, daysAgo);
      final pastWinRate = stats['pastWinRate'] as double;
      final recentWinRate = stats['recentWinRate'] as double;
      final rateChange = recentWinRate - pastWinRate;

      final message = _buildShareMessage(
        daysAgo: daysAgo,
        pastWinRate: pastWinRate,
        recentWinRate: recentWinRate,
        rateChange: rateChange,
        allGames: allGames.length,
      );

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: message,
        subject: '将棋アプリで成長中 📈',
      );

      // シェア後に一時ファイルを削除
      await Future.delayed(const Duration(seconds: 2));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('❌ シェアエラー: $e');
    }
  }

  static Map<String, dynamic> _calculateStats(
    List<GameAnalysis> allGames,
    int daysAgo,
  ) {
    final targetDate =
        DateTime.now().subtract(Duration(days: daysAgo));
    final pastGames = allGames
        .where((g) => g.playedAt.isBefore(targetDate))
        .toList();
    final recentGames = allGames
        .where((g) => g.playedAt.isAfter(targetDate))
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
      'rateChange': recentWinRate - pastWinRate,
    };
  }

  static String _buildShareMessage({
    required int daysAgo,
    required double pastWinRate,
    required double recentWinRate,
    required double rateChange,
    required int allGames,
  }) {
    final dateLabel = _getDateLabel(daysAgo);
    final emoji = rateChange > 0 ? '📈' : '📉';

    return '''
将棋アプリで成長中 $emoji

$dateLabel のあなたと比較:
勝率: ${pastWinRate.toStringAsFixed(0)}% → ${recentWinRate.toStringAsFixed(0)}%
${rateChange > 0 ? '+${rateChange.toStringAsFixed(1)}% 向上！🎉' : '${rateChange.toStringAsFixed(1)}% (調整中)'}

対局数: $allGames局

#将棋アプリ #成長記録 #棋力向上
''';
  }

  static String _getDateLabel(int daysAgo) {
    if (daysAgo == 90) return '3ヶ月前';
    if (daysAgo == 30) return '1ヶ月前';
    if (daysAgo == 14) return '2週間前';
    if (daysAgo == 7) return '1週間前';
    return '${daysAgo}日前';
  }
}
