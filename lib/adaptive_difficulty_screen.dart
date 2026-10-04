import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart' show AILevelLabel;
import 'models/game_analysis.dart';
import 'services/adaptive_difficulty_service.dart';
import 'services/kifu_analytics_service.dart';

// ──────────────────────────────────────────────
// Main Screen: AdaptiveDifficultyScreen
//
// services/adaptive_difficulty_service.dart が計算する「直近の調子を加味した
// AIレベル調整」は、対局開始画面（game_setup_screen.dart）のバナーで既に
// 無料表示されている。このプレミアム画面は同じ実データを、調整理由・
// 直近の勝率/悪手率・直近対局の内訳とあわせて詳しく見られるダッシュボードにする
// （旧版はダミー問題150問を使った完全に無関係な正誤当てクイズだった）。
// ──────────────────────────────────────────────
class AdaptiveDifficultyScreen extends StatefulWidget {
  final String userId;
  final bool isPremium;

  const AdaptiveDifficultyScreen({
    super.key,
    required this.userId,
    this.isPremium = false,
  });

  @override
  State<AdaptiveDifficultyScreen> createState() =>
      _AdaptiveDifficultyScreenState();
}

class _AdaptiveDifficultyScreenState extends State<AdaptiveDifficultyScreen> {
  bool _isLoading = true;
  int _currentRating = 700;
  AdaptiveLevelResult? _result;
  List<GameAnalysis> _recentGames = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final rating = prefs.getInt('rating_current') ?? 700;
    final result = await AdaptiveDifficultyService.computeAdaptiveLevel(rating: rating);

    List<GameAnalysis> recent = [];
    try {
      recent = (await KifuAnalyticsService().getAllAnalyses()).take(5).toList();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _currentRating = rating;
      _result = result;
      _recentGames = recent;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPremium) {
      return Scaffold(
        appBar: AppBar(title: const Text('難易度自動調整 👑')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'プレミアム機能',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'この機能はプレミアム会員のみ利用可能です',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('難易度自動調整 👑'),
        elevation: 0,
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '最新の状態に更新',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildLevelCard(),
                  const SizedBox(height: 16),
                  _buildReasonCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  if (_recentGames.isNotEmpty) _buildRecentGamesCard(),
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildLevelCard() {
    final result = _result;
    final level = result?.level;
    final isAdjusted = result?.isAdjusted ?? false;
    final adjustedUp = (result?.adjustmentSteps ?? 0) > 0;

    final accentColor = isAdjusted
        ? (adjustedUp ? Colors.redAccent : Colors.lightBlueAccent)
        : Colors.deepPurple;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'あなたのレーティング $_currentRating に対する現在のAIレベル',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isAdjusted
                      ? (adjustedUp ? Icons.trending_up : Icons.trending_down)
                      : Icons.auto_awesome,
                  color: accentColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  level?.rankLabel ?? '—',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                if (isAdjusted && result?.baseLevel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '（標準: ${result!.baseLevel.rankLabel}）',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            if (level != null) ...[
              const SizedBox(height: 8),
              Text(
                level.rankDesc,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReasonCard() {
    final reason = _result?.reason ?? '対局データを読み込み中です。';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.deepPurple[300], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final result = _result;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              '直近の勝率',
              result != null && result.sampleSize > 0
                  ? '${result.recentWinRate.toStringAsFixed(0)}%'
                  : '—',
            ),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            _buildStatItem(
              '平均悪手/局',
              result != null && result.sampleSize > 0
                  ? result.recentBlunderRate.toStringAsFixed(1)
                  : '—',
            ),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            _buildStatItem(
              '分析対局数',
              '${result?.sampleSize ?? 0}局',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGamesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '直近の対局',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_recentGames.length, (i) {
              final g = _recentGames[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i == _recentGames.length - 1 ? 0 : 10),
                child: Row(
                  children: [
                    Icon(
                      g.playerWon ? Icons.check_circle : Icons.cancel,
                      color: g.playerWon ? Colors.green : Colors.red[300],
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      g.playerWon ? '勝ち' : '負け',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${g.movesCount}手・悪手${g.blunders.length}回',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Text(
                'プレミアム機能',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'レーティングだけでなく、直近5局の勝敗・悪手率も加味してAIの'
            '強さを自動調整します。対局開始画面のAI対局設定にそのまま反映されます。',
            style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }
}
