// lib/learning_guide_screen.dart — 学習ガイド（診断 → ルート分岐）
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shodan_roadmap_screen.dart';
import 'weakness_analysis_screen.dart';
import 'tsume_screen.dart';
import 'tesuji_screen.dart';
import 'joseki_screen.dart';
import 'joseki_drill_screen.dart';
import 'castle_patterns_screen.dart';
import 'castle_break_screen.dart';
import 'proverbs_screen.dart';
import 'next_move_screen.dart';
import 'strategies_screen.dart';
import 'stats_screen.dart' show ratingToRank;
import 'theme/app_theme.dart';

// ── シチュエーション定義 ────────────────────────────────────────
class _Situation {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_Recommendation> recommendations;

  const _Situation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.recommendations,
  });
}

class _Recommendation {
  final String label;
  final String reason;
  final IconData icon;
  final String screenKey;

  const _Recommendation({
    required this.label,
    required this.reason,
    required this.icon,
    required this.screenKey,
  });
}

const _situations = [
  _Situation(
    id: 'losing',
    title: '負け続けている',
    subtitle: '勝てない原因を見つけて改善したい',
    icon: Icons.trending_down,
    color: Color(0xFFEF5350),
    recommendations: [
      _Recommendation(label: '弱点を分析する',    reason: 'どの局面で失敗しているかAIが教えてくれます',  icon: Icons.analytics,   screenKey: 'weakness'),
      _Recommendation(label: '手筋トレーニング',   reason: '逃げられる手や両取りを見落としていませんか？', icon: Icons.psychology,  screenKey: 'tesuji'),
      _Recommendation(label: '詰将棋',           reason: '終盤の詰み逃しが敗因になっていることが多いです', icon: Icons.extension,   screenKey: 'tsume'),
      _Recommendation(label: '次の一手',          reason: '序中盤の感覚を磨く実戦的な問題集',           icon: Icons.lightbulb,   screenKey: 'next_move'),
    ],
  ),
  _Situation(
    id: 'rank_up',
    title: '級・段を上げたい',
    subtitle: '今の棋力に合った課題に取り組みたい',
    icon: Icons.emoji_events,
    color: Color(0xFFFF9800),
    recommendations: [
      _Recommendation(label: '初段への道',        reason: '現在の棋力から目標まで最短ルートを提示',     icon: Icons.map,         screenKey: 'roadmap'),
      _Recommendation(label: '弱点分析',          reason: '伸び悩みの原因を特定して集中強化',           icon: Icons.analytics,   screenKey: 'weakness'),
      _Recommendation(label: '定跡ドリル',        reason: '序盤の定跡を覚えて有利な出だしを確保',       icon: Icons.repeat,      screenKey: 'joseki_drill'),
      _Recommendation(label: '手筋トレーニング',   reason: '手得・駒得の手筋を増やして中盤を制する',     icon: Icons.psychology,  screenKey: 'tesuji'),
    ],
  ),
  _Situation(
    id: 'learn_joseki',
    title: '定跡を学びたい',
    subtitle: '序盤の指し方がわからない・定跡を忘れる',
    icon: Icons.route,
    color: Color(0xFF42A5F5),
    recommendations: [
      _Recommendation(label: '定跡ガイド',        reason: '主要戦法の流れをビジュアルで学べます',       icon: Icons.menu_book,   screenKey: 'joseki'),
      _Recommendation(label: '定跡ドリル',        reason: '手順を実際に並べて体で覚える練習',           icon: Icons.repeat,      screenKey: 'joseki_drill'),
      _Recommendation(label: '戦法一覧',          reason: '四間飛車・矢倉・棒銀などの概要を把握',       icon: Icons.list_alt,    screenKey: 'strategies'),
      _Recommendation(label: '将棋の格言',        reason: '「角は引いて使え」など実戦に役立つ格言',      icon: Icons.format_quote, screenKey: 'proverbs'),
    ],
  ),
  _Situation(
    id: 'learn_castle',
    title: '囲い・守りを覚えたい',
    subtitle: '攻められると崩れる・玉が薄い',
    icon: Icons.shield,
    color: Color(0xFF66BB6A),
    recommendations: [
      _Recommendation(label: '囲いパターン集',    reason: '美濃・矢倉・穴熊など主要囲いを図解で学習',   icon: Icons.castle,      screenKey: 'castle_patterns'),
      _Recommendation(label: '囲い崩し道場',      reason: '相手の囲いを崩す手筋を学ぶと守りも強くなる', icon: Icons.security,    screenKey: 'castle_break'),
      _Recommendation(label: '定跡ガイド',        reason: '囲いと攻めがセットになった定跡を学ぶ',       icon: Icons.menu_book,   screenKey: 'joseki'),
      _Recommendation(label: '手筋トレーニング',   reason: '守りの手筋（合駒・受け）を練習',            icon: Icons.psychology,  screenKey: 'tesuji'),
    ],
  ),
  _Situation(
    id: 'end_game',
    title: '終盤が弱い',
    subtitle: '詰め損ない・逃げ方がわからない',
    icon: Icons.flag,
    color: Color(0xFFAB47BC),
    recommendations: [
      _Recommendation(label: '詰将棋',           reason: '詰みの形を数多く覚えることが最短の近道',      icon: Icons.extension,   screenKey: 'tsume'),
      _Recommendation(label: '次の一手',          reason: '終盤の寄せ・受けの感覚を実戦形式で鍛える',   icon: Icons.lightbulb,   screenKey: 'next_move'),
      _Recommendation(label: '手筋トレーニング',   reason: '寄せ・詰めの手筋パターンを増やす',          icon: Icons.psychology,  screenKey: 'tesuji'),
      _Recommendation(label: '将棋の格言',        reason: '「玉は包むように寄せよ」などの実践的格言',    icon: Icons.format_quote, screenKey: 'proverbs'),
    ],
  ),
  _Situation(
    id: 'shodan',
    title: '初段を目指す',
    subtitle: '段位取得・レーティング1150突破',
    icon: Icons.workspace_premium,
    color: Color(0xFFFFD700),
    recommendations: [
      _Recommendation(label: '初段への道',        reason: '棋力に合わせた段階別ロードマップ',           icon: Icons.map,         screenKey: 'roadmap'),
      _Recommendation(label: '弱点分析',          reason: 'AI対局後に課題を可視化して集中強化',         icon: Icons.analytics,   screenKey: 'weakness'),
      _Recommendation(label: '定跡ドリル',        reason: '序盤で差をつける高精度な定跡を習得',         icon: Icons.repeat,      screenKey: 'joseki_drill'),
      _Recommendation(label: '詰将棋7手+',        reason: '有段者は7手詰めを確実に読み切る力が必要',    icon: Icons.extension,   screenKey: 'tsume'),
    ],
  ),
  _Situation(
    id: 'beginner',
    title: 'はじめて覚えたい',
    subtitle: '駒の動き・基本ルールを知りたい',
    icon: Icons.school,
    color: Color(0xFF26C6DA),
    recommendations: [
      _Recommendation(label: '初段への道',        reason: '15級から段階的に学べるロードマップ',         icon: Icons.map,         screenKey: 'roadmap'),
      _Recommendation(label: '囲いパターン集',    reason: 'まず1つの囲いを覚えると対局が安定します',    icon: Icons.castle,      screenKey: 'castle_patterns'),
      _Recommendation(label: '1手詰め',           reason: '最も簡単な詰将棋から王手感覚を養う',         icon: Icons.extension,   screenKey: 'tsume'),
      _Recommendation(label: '将棋の格言',        reason: '「飛車はまっすぐ動け」などの覚えやすい格言', icon: Icons.format_quote, screenKey: 'proverbs'),
    ],
  ),
];

// ── 画面本体 ──────────────────────────────────────────────────
class LearningGuideScreen extends StatefulWidget {
  const LearningGuideScreen({super.key});

  @override
  State<LearningGuideScreen> createState() => _LearningGuideScreenState();
}

class _LearningGuideScreenState extends State<LearningGuideScreen> {
  _Situation? _selected;
  int _rating = 700;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _rating = prefs.getInt('rating_current') ?? 700);
    }
  }

  void _navigate(String screenKey) {
    Widget? screen;
    switch (screenKey) {
      case 'roadmap':      screen = const ShodanRoadmapScreen(); break;
      case 'weakness':     screen = const WeaknessAnalysisScreen(); break;
      case 'tsume':        screen = const TsumeScreen(); break;
      case 'tesuji':       screen = const TesujiScreen(); break;
      case 'joseki':       screen = const JosekiScreen(); break;
      case 'joseki_drill': screen = const JosekiDrillScreen(); break;
      case 'castle_patterns': screen = const CastlePatternsScreen(); break;
      case 'castle_break': screen = const CastleBreakScreen(); break;
      case 'proverbs':     screen = const ProverbsScreen(); break;
      case 'next_move':    screen = const NextMoveScreen(); break;
      case 'strategies':   screen = const StrategiesScreen(); break;
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('学習ガイド', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selected != null)
            TextButton(
              onPressed: () => setState(() => _selected = null),
              child: const Text('← 選び直す', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: _selected == null ? _buildSituationSelector() : _buildRecommendations(),
    );
  }

  // ── シチュエーション選択 ─────────────────────────────────────
  Widget _buildSituationSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 現在棋力表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  '現在の棋力: ${ratingToRank(_rating)} ($_rating)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            '今の状況はどれ？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '選ぶとあなたに合ったメニューを表示します',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // カード一覧
          ...List.generate(_situations.length, (i) {
            final sit = _situations[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SituationCard(
                situation: sit,
                onTap: () => setState(() => _selected = sit),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── レコメンド表示 ──────────────────────────────────────────
  Widget _buildRecommendations() {
    final sit = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 選択したシチュエーション表示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sit.color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sit.color.withAlpha(100)),
            ),
            child: Row(
              children: [
                Icon(sit.icon, color: sit.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sit.title,
                          style: TextStyle(
                              color: sit.color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(sit.subtitle,
                          style:
                              const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'おすすめのメニュー',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // レコメンドカード一覧
          ...List.generate(sit.recommendations.length, (i) {
            final rec = sit.recommendations[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendationCard(
                recommendation: rec,
                index: i,
                color: sit.color,
                onTap: () => _navigate(rec.screenKey),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── シチュエーションカードウィジェット ────────────────────────
class _SituationCard extends StatelessWidget {
  final _Situation situation;
  final VoidCallback onTap;

  const _SituationCard({required this.situation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: situation.color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(situation.icon, color: situation.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    situation.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    situation.subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

// ── レコメンドカードウィジェット ──────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final _Recommendation recommendation;
  final int index;
  final Color color;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.recommendation,
    required this.index,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // 番号バッジ
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // アイコン
            Icon(recommendation.icon, color: color, size: 20),
            const SizedBox(width: 10),
            // テキスト
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recommendation.reason,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, color: color.withAlpha(180), size: 14),
          ],
        ),
      ),
    );
  }
}
