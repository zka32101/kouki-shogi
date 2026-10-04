import 'package:flutter/material.dart';
import '../services/kifu_analytics_service.dart';
import '../services/growth_share_service.dart';
import '../models/game_analysis.dart';
import '../widgets/growth_story_card.dart';
import 'past_self_battle_game_screen.dart';
import '../theme/app_theme.dart';

class PastSelfBattleScreen extends StatefulWidget {
  const PastSelfBattleScreen();

  @override
  State<PastSelfBattleScreen> createState() => _PastSelfBattleScreenState();
}

class _PastSelfBattleScreenState extends State<PastSelfBattleScreen> {
  List<GameAnalysis>? _allGames;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllGames();
  }

  Future<void> _loadAllGames() async {
    try {
      final games = await KifuAnalyticsService().getAllAnalyses();
      setState(() {
        _allGames = games;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ ゲーム読み込みエラー: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startBattle(int daysAgo) {
    if (_allGames == null || _allGames!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対局履歴が見つかりません')),
      );
      return;
    }

    final targetDate = DateTime.now().subtract(Duration(days: daysAgo));
    final pastGames = _allGames!
        .where((g) => g.playedAt.isBefore(targetDate))
        .toList();

    if (pastGames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('指定した期間の対局が見つかりません')),
      );
      return;
    }

    // 成長ストーリーダイアログを表示
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GrowthStoryCard(
                allGames: _allGames!,
                daysAgo: daysAgo,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _shareGrowthStory(daysAgo);
            },
            child: const Text(
              'シェア',
              style: TextStyle(color: AppTheme.accent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PastSelfBattleGameScreen(
                    daysAgo: daysAgo,
                    dateLabel: _getDateLabel(daysAgo),
                  ),
                ),
              );
            },
            child: const Text(
              '対戦開始',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  String _getDateLabel(int daysAgo) {
    if (daysAgo == 90) return '3ヶ月前';
    if (daysAgo == 30) return '1ヶ月前';
    if (daysAgo == 14) return '2週間前';
    if (daysAgo == 7) return '1週間前';
    return '${daysAgo}日前';
  }

  Future<void> _shareGrowthStory(int daysAgo) async {
    if (_allGames == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対局データがありません')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('成長ストーリーを作成中...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // 画像生成
      final imageBytes = await GrowthStoryImageGenerator.generateImage(
        allGames: _allGames!,
        daysAgo: daysAgo,
      );

      if (imageBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像生成に失敗しました')),
        );
        return;
      }

      // シェア処理
      await GrowthShareService.shareGrowthStory(
        imageBytes: imageBytes,
        allGames: _allGames!,
        daysAgo: daysAgo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 成長ストーリーをシェアしました'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('シェアエラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('成長を確認'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _allGames == null || _allGames!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '対局履歴がありません',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '最初に何局かAIと対局してください',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accent.withAlpha(60)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up, color: AppTheme.accent),
                                SizedBox(width: 8),
                                Text(
                                  'あなたの成長',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildStatRow(
                              label: '対局数',
                              value: _allGames!.length.toString(),
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              label: '勝率',
                              value:
                                  '${(_allGames!.where((g) => g.playerWon).length / _allGames!.length * 100).toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              label: '平均手数',
                              value: _allGames!
                                  .fold<double>(
                                    0,
                                    (sum, g) => sum + g.movesCount,
                                  )
                                  .toStringAsFixed(1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '過去のあなたと対戦',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBattleButton(
                        context: context,
                        label: '3ヶ月前のあなた',
                        subtitle: '90日前の実力',
                        daysAgo: 90,
                      ),
                      const SizedBox(height: 8),
                      _buildBattleButton(
                        context: context,
                        label: '1ヶ月前のあなた',
                        subtitle: '30日前の実力',
                        daysAgo: 30,
                      ),
                      const SizedBox(height: 8),
                      _buildBattleButton(
                        context: context,
                        label: '2週間前のあなた',
                        subtitle: '14日前の実力',
                        daysAgo: 14,
                      ),
                      const SizedBox(height: 8),
                      _buildBattleButton(
                        context: context,
                        label: '1週間前のあなた',
                        subtitle: '7日前の実力',
                        daysAgo: 7,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBattleButton({
    required BuildContext context,
    required String label,
    required String subtitle,
    required int daysAgo,
  }) {
    final games = _allGames!;
    final targetDate = DateTime.now().subtract(Duration(days: daysAgo));
    final pastGames = games.where((g) => g.playedAt.isBefore(targetDate)).toList();
    final pastWinRate = pastGames.isEmpty
        ? null
        : (pastGames.where((g) => g.playerWon).length / pastGames.length * 100);

    return GestureDetector(
      onTap: () => _startBattle(daysAgo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    if (pastWinRate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '勝率 ${pastWinRate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: pastWinRate >= 50
                              ? Colors.green.shade400
                              : Colors.orange.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Icon(Icons.sports_kabaddi, color: Colors.amber, size: 20),
          ],
        ),
      ),
    );
  }
}

