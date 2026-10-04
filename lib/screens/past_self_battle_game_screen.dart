import 'package:flutter/material.dart';
import '../game_screen.dart';
import '../services/kifu_analytics_service.dart';
import '../theme/app_theme.dart';

class PastSelfBattleGameScreen extends StatefulWidget {
  final int daysAgo;
  final String dateLabel;

  const PastSelfBattleGameScreen({
    required this.daysAgo,
    required this.dateLabel,
  });

  @override
  State<PastSelfBattleGameScreen> createState() =>
      _PastSelfBattleGameScreenState();
}

class _PastSelfBattleGameScreenState extends State<PastSelfBattleGameScreen> {
  AILevel? _estimatedLevel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _computeLevel();
  }

  Future<void> _computeLevel() async {
    try {
      final allGames = await KifuAnalyticsService().getAllAnalyses();
      final targetDate =
          DateTime.now().subtract(Duration(days: widget.daysAgo));
      final pastGames =
          allGames.where((g) => g.playedAt.isBefore(targetDate)).toList();

      AILevel level;
      if (pastGames.isEmpty) {
        level = _fallbackLevel(widget.daysAgo);
      } else {
        final winRate =
            pastGames.where((g) => g.playerWon).length / pastGames.length;
        final avgMoves = pastGames.fold<double>(
              0,
              (s, g) => s + g.movesCount,
            ) /
            pastGames.length;

        // 勝率 + 平均手数でレベルを推定
        if (winRate >= 0.7 && avgMoves >= 80) {
          level = AILevel.hard;
        } else if (winRate >= 0.55) {
          level = AILevel.upperMedium;
        } else if (winRate >= 0.4) {
          level = AILevel.medium;
        } else if (winRate >= 0.25) {
          level = AILevel.elementary;
        } else {
          level = AILevel.easy;
        }
      }

      if (mounted) {
        setState(() {
          _estimatedLevel = level;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _estimatedLevel = _fallbackLevel(widget.daysAgo);
          _loading = false;
        });
      }
    }
  }

  AILevel _fallbackLevel(int daysAgo) {
    if (daysAgo >= 90) return AILevel.easy;
    if (daysAgo >= 30) return AILevel.elementary;
    if (daysAgo >= 14) return AILevel.medium;
    return AILevel.upperMedium;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.accent),
              SizedBox(height: 16),
              Text(
                '過去の棋力を分析中...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return GameScreen(
      settings: GameSettings(
        mode: GameMode.vsAI,
        aiLevel: _estimatedLevel!,
        aiIsP2: false,
        coachMode: false,
        opponentCharacterId: null,
      ),
    );
  }
}
