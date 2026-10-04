import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game_analysis.dart';
import '../models/game_statistics.dart';
import '../theme/app_theme.dart';

class CustomPeriodAnalysisScreen extends StatefulWidget {
  final List<GameAnalysis> games;

  const CustomPeriodAnalysisScreen({
    required this.games,
    super.key,
  });

  @override
  State<CustomPeriodAnalysisScreen> createState() => _CustomPeriodAnalysisScreenState();
}

class _CustomPeriodAnalysisScreenState extends State<CustomPeriodAnalysisScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late List<GameAnalysis> _filteredGames;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
    _updateFilteredGames();
  }

  void _updateFilteredGames() {
    _filteredGames = widget.games
        .where((g) => !g.playedAt.isBefore(_startDate) && !g.playedAt.isAfter(_endDate))
        .toList();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: widget.games.isEmpty ? DateTime.now() : widget.games.last.playedAt,
      lastDate: _endDate.subtract(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _updateFilteredGames();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _updateFilteredGames();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = StatisticsCalculator.calculateStats(_filteredGames, startDate: _startDate, endDate: _endDate);
    final hourlyStats = StatisticsCalculator.calculateHourlyStats(_filteredGames);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('カスタム期間分析'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付選択セクション
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.accent.withAlpha(60)),
                borderRadius: BorderRadius.circular(AppTheme.rCard),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.date_range, size: 15, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Text(
                        '分析期間',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectStartDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              border: Border.all(color: Colors.white.withAlpha(30)),
                              borderRadius: BorderRadius.circular(AppTheme.rChip),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '開始日',
                                  style: TextStyle(
                                    color: AppTheme.textLow,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('yyyy/MM/dd').format(_startDate),
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: AppTheme.textLow),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectEndDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              border: Border.all(color: Colors.white.withAlpha(30)),
                              borderRadius: BorderRadius.circular(AppTheme.rChip),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '終了日',
                                  style: TextStyle(
                                    color: AppTheme.textLow,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('yyyy/MM/dd').format(_endDate),
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_calculateDays()}日間 • ${_filteredGames.length}局',
                    style: TextStyle(
                      color: AppTheme.textLow,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_filteredGames.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '該当期間のデータがありません',
                    style: TextStyle(color: AppTheme.textLow),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 成績サマリー
                  _sectionHeader(Icons.bar_chart, '成績サマリー'),
                  const SizedBox(height: 12),
                  _buildStatCard(stats),
                  const SizedBox(height: 20),

                  // 統計詳細
                  _sectionHeader(Icons.analytics, '詳細統計'),
                  const SizedBox(height: 12),
                  _buildDetailStats(stats),
                  const SizedBox(height: 20),

                  // 時間帯別成績
                  _sectionHeader(Icons.schedule, '時間帯別成績'),
                  const SizedBox(height: 12),
                  ...hourlyStats
                      .where((h) => h.games > 0)
                      .map((h) => _buildHourlyCard(h))
                      .toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int _calculateDays() {
    return _endDate.difference(_startDate).inDays;
  }

  Widget _sectionHeader(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 15, color: AppTheme.accent),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }

  Widget _buildStatCard(GameStatistics stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent.withAlpha(30), AppTheme.accent.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.accent.withAlpha(70)),
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBadge('対局数', stats.totalGames.toString(), AppTheme.textHigh),
          _buildStatBadge('勝利', stats.wins.toString(), AppTheme.success),
          _buildStatBadge('敗北', stats.losses.toString(), AppTheme.danger),
          _buildStatBadge('勝率', '${stats.winRate.toStringAsFixed(1)}%', AppTheme.accent),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textLow,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailStats(GameStatistics stats) {
    final days = _calculateDays().clamp(1, 1 << 30);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: Colors.white.withAlpha(20)),
        borderRadius: BorderRadius.circular(AppTheme.rBtn),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildStatRow('総手数', '${stats.totalMoves}手'),
          const SizedBox(height: 10),
          _buildStatRow('平均手数', '${stats.avgMoves.toStringAsFixed(1)}手'),
          const SizedBox(height: 10),
          _buildStatRow('1日平均対局数', '${(_filteredGames.length / days).toStringAsFixed(2)}局'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMid,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.accent,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Color _winRateColor(double rate) {
    if (rate >= 60) return AppTheme.success;
    if (rate >= 40) return AppTheme.primary;
    return AppTheme.textLow;
  }

  Widget _buildHourlyCard(HourlyStats hourly) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: Colors.white.withAlpha(20)),
        borderRadius: BorderRadius.circular(AppTheme.rBtn),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hourly.hour.toString().padLeft(2, '0')}:00～${(hourly.hour + 1).toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hourly.wins}勝 / ${hourly.games}局',
                style: TextStyle(
                  color: AppTheme.textLow,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Text(
            '${hourly.winRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _winRateColor(hourly.winRate),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
