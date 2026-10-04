import 'package:flutter/material.dart';
import '../services/learning_content_generator.dart';
import '../theme/app_theme.dart';

class PersonalizedLessonScreen extends StatefulWidget {
  const PersonalizedLessonScreen({super.key});

  @override
  State<PersonalizedLessonScreen> createState() => _PersonalizedLessonScreenState();
}

class _PersonalizedLessonScreenState extends State<PersonalizedLessonScreen> {
  List<GeneratedLesson>? _lessons;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    final lessons = await LearningContentGenerator.generatePersonalizedLessons();
    if (mounted) {
      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('パーソナライズ学習プラン'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_lessons == null || _lessons!.isEmpty)
              ? _buildEmptyState()
              : _buildLessonList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(
              'まだ十分な対局データがありません',
              style: TextStyle(color: AppTheme.textMid, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '対局を重ねると、あなたの悪手パターンを分析して\n個別の学習アドバイスを自動生成します。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textLow, fontSize: 12, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent.withAlpha(35), AppTheme.accent.withAlpha(8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.accent.withAlpha(90)),
              borderRadius: BorderRadius.circular(AppTheme.rCard),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'あなた専用の学習プラン',
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '直近の対局から悪手パターンを分析し、優先度順に${_lessons!.length}件のレッスンを生成しました',
                        style: TextStyle(color: AppTheme.textLow, fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._lessons!.asMap().entries.map((e) => _buildLessonCard(e.key, e.value)),
        ],
      ),
    );
  }

  Color _severityColor(double avgDelta) {
    if (avgDelta <= -200) return AppTheme.danger;
    if (avgDelta <= -100) return Color.lerp(AppTheme.danger, AppTheme.accent, 0.5)!;
    return AppTheme.accent;
  }

  Widget _buildLessonCard(int idx, GeneratedLesson lesson) {
    final severityColor = _severityColor(lesson.avgDelta);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: severityColor.withAlpha(80)),
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: severityColor.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: severityColor, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lesson.title,
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lesson.severityLabel,
                  style: TextStyle(color: severityColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lesson.summary,
            style: TextStyle(color: AppTheme.textMid, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'アドバイス',
                      style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.adviceText,
                  style: TextStyle(color: AppTheme.textMid, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              border: Border.all(color: AppTheme.primary.withAlpha(70)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: AppTheme.primary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lesson.drillSuggestion,
                    style: TextStyle(color: AppTheme.primary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
