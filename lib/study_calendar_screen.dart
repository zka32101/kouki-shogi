import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';

class StudyCalendarScreen extends StatefulWidget {
  const StudyCalendarScreen({super.key});

  @override
  State<StudyCalendarScreen> createState() => _StudyCalendarScreenState();

  static Future<void> recordActivity(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey = today.toIso8601String().substring(0, 10);
    final logKey = 'study_log_$dateKey';
    final count = (prefs.getInt(logKey) ?? 0) + 1;
    await prefs.setInt(logKey, count);

    // Update type-specific counter
    final typeTotal = (prefs.getInt('study_total_$type') ?? 0) + 1;
    await prefs.setInt('study_total_$type', typeTotal);

    // Update streak
    final lastDateStr = prefs.getString('study_last_date') ?? '';
    final todayStr = dateKey;
    final yesterday = DateTime(today.year, today.month, today.day - 1)
        .toIso8601String()
        .substring(0, 10);

    int streak = prefs.getInt('study_streak') ?? 0;
    if (lastDateStr == todayStr) {
      // Already recorded today, no streak change
    } else if (lastDateStr == yesterday) {
      streak += 1;
    } else {
      streak = 1;
    }
    await prefs.setInt('study_streak', streak);
    await prefs.setString('study_last_date', todayStr);

    final maxStreak = prefs.getInt('study_streak_max') ?? 0;
    if (streak > maxStreak) {
      await prefs.setInt('study_streak_max', streak);
    }
  }
}

class _StudyCalendarScreenState extends State<StudyCalendarScreen> {
  Map<String, int> _studyLog = {};
  int _streak = 0;
  int _maxStreak = 0;
  int _totalDays = 0;
  int _thisMonthDays = 0;
  int _tsumeTotal = 0;
  int _tesujiTotal = 0;
  int _taikyokuTotal = 0;
  String? _tooltipDate;
  int? _tooltipCount;
  bool _loading = true;

  static const int _weeks = 12;
  static const int _days = 84;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, int> log = {};
    int totalDays = 0;
    int thisMonthDays = 0;

    for (int i = 0; i < _days; i++) {
      final date = today.subtract(Duration(days: _days - 1 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = prefs.getInt('study_log_$key') ?? 0;
      log[key] = count;
      if (count > 0) {
        totalDays++;
        if (date.year == now.year && date.month == now.month) {
          thisMonthDays++;
        }
      }
    }

    setState(() {
      _studyLog = log;
      _streak = prefs.getInt('study_streak') ?? 0;
      _maxStreak = prefs.getInt('study_streak_max') ?? 0;
      _totalDays = totalDays;
      _thisMonthDays = thisMonthDays;
      _tsumeTotal = prefs.getInt('study_total_tsume') ?? 0;
      _tesujiTotal = prefs.getInt('study_total_tesuji') ?? 0;
      _taikyokuTotal = prefs.getInt('study_total_taikyoku') ?? 0;
      _loading = false;
    });
  }

  Color _colorForCount(int count) {
    if (count == 0) return const Color(0xFF2D2D2D);
    if (count == 1) return const Color(0xFF196127);
    if (count == 2) return const Color(0xFF239A3B);
    return const Color(0xFF3AC45F);
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            value: '$_streak',
            label: '連続学習',
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.emoji_events,
            iconColor: Colors.amber,
            value: '$_maxStreak',
            label: '最長連続',
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.calendar_today,
            iconColor: const Color(0xFF3AC45F),
            value: '$_totalDays',
            label: '総学習日',
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.date_range,
            iconColor: Colors.blueAccent,
            value: '$_thisMonthDays',
            label: '今月',
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: const Color(0xFF3A3A3A),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmap() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: _days - 1));
    final startWeekday = startDate.weekday;
    final gridStart = startDate.subtract(Duration(days: startWeekday - 1));

    const double squareSize = 13.0;
    const double gap = 3.0;
    const double leftLabelWidth = 28.0;
    const double topLabelHeight = 20.0;

    final List<String> dayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学習ヒートマップ（直近12週）',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels column
              Column(
                children: [
                  SizedBox(height: topLabelHeight),
                  ...List.generate(7, (i) {
                    return SizedBox(
                      height: squareSize + gap,
                      width: leftLabelWidth,
                      child: Center(
                        child: Text(
                          dayLabels[i],
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              // Weeks grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Week labels row
                      Row(
                        children: List.generate(_weeks, (weekIndex) {
                          final weeksAgo = _weeks - 1 - weekIndex;
                          String label;
                          if (weeksAgo == 0) {
                            label = '今週';
                          } else if (weeksAgo <= 4) {
                            label = '${weeksAgo}週前';
                          } else {
                            final weekStart =
                                gridStart.add(Duration(days: weekIndex * 7));
                            label =
                                '${weekStart.month}/${weekStart.day}';
                          }
                          return SizedBox(
                            width: squareSize + gap,
                            height: topLabelHeight,
                            child: Text(
                              weekIndex % 3 == 0 ? label : '',
                              style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 9,
                              ),
                              overflow: TextOverflow.visible,
                            ),
                          );
                        }),
                      ),
                      // Grid rows
                      ...List.generate(7, (dayOfWeek) {
                        return Row(
                          children: List.generate(_weeks, (weekIndex) {
                            final cellIndex = weekIndex * 7 + dayOfWeek;
                            final cellDate =
                                gridStart.add(Duration(days: cellIndex));
                            final isFuture = cellDate.isAfter(today);
                            final isBeforeStart =
                                cellDate.isBefore(startDate);

                            String dateStr = '';
                            int count = 0;
                            if (!isFuture && !isBeforeStart) {
                              dateStr =
                                  '${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';
                              count = _studyLog[dateStr] ?? 0;
                            }

                            final color = (isFuture || isBeforeStart)
                                ? Colors.transparent
                                : _colorForCount(count);

                            final isTooltipActive =
                                _tooltipDate == dateStr && dateStr.isNotEmpty;

                            return GestureDetector(
                              onTap: () {
                                if (!isFuture && !isBeforeStart) {
                                  setState(() {
                                    if (_tooltipDate == dateStr) {
                                      _tooltipDate = null;
                                      _tooltipCount = null;
                                    } else {
                                      _tooltipDate = dateStr;
                                      _tooltipCount = count;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                width: squareSize,
                                height: squareSize,
                                margin:
                                    const EdgeInsets.only(right: gap, bottom: gap),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                  border: isTooltipActive
                                      ? Border.all(
                                          color: Colors.white, width: 1.5)
                                      : null,
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_tooltipDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF3AC45F)),
              ),
              child: Text(
                '$_tooltipDate: ${_tooltipCount ?? 0}件の学習',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '少ない',
                style:
                    TextStyle(color: Color(0xFF888888), fontSize: 10),
              ),
              const SizedBox(width: 4),
              ...[0, 1, 2, 3].map((c) => Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: _colorForCount(c),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
              const Text(
                '多い',
                style:
                    TextStyle(color: Color(0xFF888888), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLast7DaysBar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '直近7日間の学習',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final date = today.subtract(Duration(days: 6 - i));
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final count = _studyLog[dateStr] ?? 0;
              const double maxHeight = 60.0;
              final double barHeight =
                  count == 0 ? 4.0 : (count * 20.0).clamp(10.0, maxHeight);
              final List<String> dayNames = [
                '月', '火', '水', '木', '金', '土', '日'
              ];
              final String dayLabel = dayNames[date.weekday - 1];
              final bool isToday = date == today;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count > 0 ? '$count' : '',
                    style: const TextStyle(
                      color: Color(0xFF3AC45F),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 28,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: count == 0
                          ? const Color(0xFF2D2D2D)
                          : count >= 3
                              ? const Color(0xFF3AC45F)
                              : const Color(0xFF239A3B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF3AC45F)
                          : const Color(0xFF888888),
                      fontSize: 11,
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3AC45F),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTypeTotal('詰将棋', _tsumeTotal, Colors.redAccent),
              _buildTypeTotal('手筋', _tesujiTotal, Colors.blueAccent),
              _buildTypeTotal('対局', _taikyokuTotal, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTotal(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievements() {
    final badges = [
      _AchievementBadge(
        icon: Icons.local_fire_department,
        label: '7日連続',
        achieved: _streak >= 7 || _maxStreak >= 7,
        color: Colors.orange,
      ),
      _AchievementBadge(
        icon: Icons.whatshot,
        label: '30日連続',
        achieved: _streak >= 30 || _maxStreak >= 30,
        color: Colors.deepOrange,
      ),
      _AchievementBadge(
        icon: Icons.star,
        label: '50日達成',
        achieved: _totalDays >= 50,
        color: Colors.amber,
      ),
      _AchievementBadge(
        icon: Icons.workspace_premium,
        label: '100日達成',
        achieved: _totalDays >= 100,
        color: Colors.purple,
      ),
      _AchievementBadge(
        icon: Icons.emoji_events,
        label: '詰将棋100問',
        achieved: _tsumeTotal >= 100,
        color: Colors.red,
      ),
      _AchievementBadge(
        icon: Icons.military_tech,
        label: '対局50局',
        achieved: _taikyokuTotal >= 50,
        color: Colors.blue,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '実績バッジ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: badges.map((badge) => _buildBadge(badge)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(_AchievementBadge badge) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: badge.achieved
                ? badge.color.withOpacity(0.2)
                : const Color(0xFF2D2D2D),
            border: Border.all(
              color: badge.achieved
                  ? badge.color
                  : const Color(0xFF444444),
              width: 2,
            ),
          ),
          child: Icon(
            badge.icon,
            color: badge.achieved
                ? badge.color
                : const Color(0xFF555555),
            size: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          badge.label,
          style: TextStyle(
            color: badge.achieved ? Colors.white : const Color(0xFF555555),
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        foregroundColor: Colors.white,
        title: const Text(
          '学習カレンダー',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3AC45F),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF3AC45F),
              backgroundColor: const Color(0xFF1E1E1E),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 8),
                  _buildStatsRow(),
                  const SizedBox(height: 4),
                  _buildHeatmap(),
                  const SizedBox(height: 4),
                  _buildLast7DaysBar(),
                  const SizedBox(height: 4),
                  _buildAchievements(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _AchievementBadge {
  final IconData icon;
  final String label;
  final bool achieved;
  final Color color;

  const _AchievementBadge({
    required this.icon,
    required this.label,
    required this.achieved,
    required this.color,
  });
}
