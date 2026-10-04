// lib/screens/season_screen.dart
// シーズン制ランキング画面

import 'package:flutter/material.dart';
import '../services/season_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  final SeasonService _seasonService = SeasonService();
  final NetworkService _networkService = NetworkService();

  List<SeasonRankEntry> _rankings = [];
  int? _myRank;
  bool _loading = true;
  late SeasonInfo _season;

  @override
  void initState() {
    super.initState();
    _season = _seasonService.getCurrentSeason();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _seasonService.initSeasonRating();
    final results = await Future.wait([
      _seasonService.getTopRankings(limit: 30),
      _seasonService.getMyRank(),
    ]);
    if (mounted) {
      setState(() {
        _rankings = results[0] as List<SeasonRankEntry>;
        _myRank = results[1] as int?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _networkService.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('シーズン', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildTile(_rankings[i], myUid),
                        childCount: _rankings.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final daysLeft = _season.endAt.difference(now).inDays + 1;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade900, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              _season.label,
              style: const TextStyle(
                color: AppTheme.textHigh,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _infoChip('残り ${daysLeft}日', AppTheme.accent),
            const SizedBox(width: 8),
            if (_myRank != null)
              _infoChip('自分: ${_myRank}位', Colors.amber),
          ]),
          const SizedBox(height: 12),
          const Text(
            '上位プレイヤーにはシーズン終了時に特別称号が付与されます',
            style: TextStyle(color: AppTheme.textLow, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _rewardRow(1, '👑 シーズン王者', Colors.amber),
          const SizedBox(height: 4),
          _rewardRow(3, '🥈 上位3名', Colors.blueGrey.shade300),
          const SizedBox(height: 4),
          _rewardRow(10, '🏅 上位10名', Colors.brown.shade300),
        ],
      ),
    );
  }

  Widget _rewardRow(int rank, String label, Color color) {
    return Row(children: [
      Container(
        width: 36,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(
          'TOP $rank',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppTheme.textMid, fontSize: 12)),
    ]);
  }

  Widget _infoChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
  );

  Widget _buildTile(SeasonRankEntry entry, String? myUid) {
    final isMe = entry.userId == myUid;
    final total = entry.wins + entry.losses;
    final winRate = total > 0 ? (entry.wins / total * 100).toStringAsFixed(0) : '-';

    Color rankColor;
    Widget rankWidget;
    if (entry.rank == 1) {
      rankColor = Colors.amber;
      rankWidget = const Text('👑', style: TextStyle(fontSize: 20));
    } else if (entry.rank == 2) {
      rankColor = Colors.blueGrey.shade300;
      rankWidget = const Text('🥈', style: TextStyle(fontSize: 20));
    } else if (entry.rank == 3) {
      rankColor = Colors.brown.shade300;
      rankWidget = const Text('🥉', style: TextStyle(fontSize: 20));
    } else {
      rankColor = AppTheme.textLow;
      rankWidget = Text(
        '${entry.rank}',
        style: TextStyle(color: rankColor, fontSize: 16, fontWeight: FontWeight.bold),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.amber.withAlpha(20)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMe ? Colors.amber.withAlpha(80) : Colors.white12,
        ),
      ),
      child: Row(children: [
        SizedBox(width: 40, child: Center(child: rankWidget)),
        const SizedBox(width: 8),
        // アバター
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.brown.shade700,
          child: Text(
            entry.username.isNotEmpty ? entry.username[0].toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.textHigh, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              entry.username,
              style: TextStyle(
                color: isMe ? Colors.amber : AppTheme.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '${entry.wins}勝${entry.losses}敗  勝率${winRate}%',
              style: const TextStyle(color: AppTheme.textLow, fontSize: 11),
            ),
          ]),
        ),
        Text(
          '${entry.rating}',
          style: TextStyle(
            color: rankColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }
}
