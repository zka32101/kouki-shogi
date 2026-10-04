// lib/opening_stats_screen.dart — 自分の棋譜からの定跡統計（lishogiの開局データベース風）
//
// 保存済み棋譜（kifu_records）を戦型別に集計し、対局数・勝率を表示する。
// opening フィールドは game_screen.dart の _detectOpening() が
// 「▲三間飛車」のようにプレイヤー視点で先頭に▲/△を付けて保存しているため、
// その接頭辞から「このプレイヤーがどちらの手番だったか」を復元して
// 勝敗判定（result は "先手の勝ち"/"後手の勝ち" 形式）に使う。
// 接頭辞のない古い記録・空文字の記録は集計対象から除外する。
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'theme/app_theme.dart';

class _OpeningStat {
  final String name;
  int games = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;

  _OpeningStat(this.name);

  double get winRate => games == 0 ? 0 : wins / games;
}

class OpeningStatsScreen extends StatefulWidget {
  const OpeningStatsScreen({super.key});

  @override
  State<OpeningStatsScreen> createState() => _OpeningStatsScreenState();
}

class _OpeningStatsScreenState extends State<OpeningStatsScreen> {
  bool _loading = true;
  List<_OpeningStat> _stats = [];
  int _totalGames = 0;
  int _uncategorized = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kifu_records') ?? '[]';
    List<dynamic> list;
    try {
      list = jsonDecode(raw);
    } catch (_) {
      list = [];
    }

    final byName = <String, _OpeningStat>{};
    int uncategorized = 0;

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final opening = item['opening'] as String? ?? '';
      final result = item['result'] as String? ?? '';
      if (opening.isEmpty || opening.length < 2) {
        uncategorized++;
        continue;
      }
      final prefix = opening.substring(0, 1);
      final playerIsP1 = prefix == '▲' ? true : (prefix == '△' ? false : null);
      if (playerIsP1 == null) {
        // 接頭辞のない旧形式レコードは手番が復元できないため除外
        uncategorized++;
        continue;
      }
      final strategyName = opening.substring(1);

      final stat = byName.putIfAbsent(strategyName, () => _OpeningStat(strategyName));
      stat.games++;

      final playerWon = playerIsP1
          ? result.startsWith('先手の勝ち')
          : result.startsWith('後手の勝ち');
      final oppWon = playerIsP1
          ? result.startsWith('後手の勝ち')
          : result.startsWith('先手の勝ち');
      if (playerWon) {
        stat.wins++;
      } else if (oppWon) {
        stat.losses++;
      } else {
        stat.draws++;
      }
    }

    final stats = byName.values.toList()
      ..sort((a, b) => b.games.compareTo(a.games));

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _totalGames = list.length;
      _uncategorized = uncategorized;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('定跡統計', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            const Text(
              'まだ戦型データがありません',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '10手以上進んだ対局を保存すると、\nここに戦型別の対局数・勝率が集計されます。',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.rCard),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _summaryItem('保存済み対局', '$_totalGames局'),
              ),
              Expanded(
                child: _summaryItem('集計対象戦型', '${_stats.length}種'),
              ),
            ],
          ),
        ),
        if (_uncategorized > 0) ...[
          const SizedBox(height: 8),
          Text(
            '※ $_uncategorized局は戦型未判定のため集計対象外です（10手未満の対局・旧バージョンの記録など）',
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          '戦型別 対局数・勝率',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._stats.map(_buildStatCard),
      ],
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatCard(_OpeningStat stat) {
    final winRatePct = (stat.winRate * 100).round();
    final winColor = stat.winRate >= 0.55
        ? AppTheme.success
        : stat.winRate <= 0.45
            ? AppTheme.danger
            : Colors.white54;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$winRatePct%',
                style: TextStyle(
                  color: winColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.winRate,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(winColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${stat.games}局（${stat.wins}勝${stat.losses}敗${stat.draws > 0 ? '${stat.draws}分' : ''}）',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
