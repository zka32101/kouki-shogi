// lib/shodan_roadmap_screen.dart — 初段への学習ロードマップ
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stats_screen.dart';
import 'tsume_screen.dart';
import 'joseki_screen.dart';
import 'tesuji_screen.dart';
import 'proverbs_screen.dart';
import 'weakness_analysis_screen.dart';
import 'game_setup_screen.dart';
import 'game_screen.dart' show GameMode;
import 'theme/app_theme.dart';

// ── 段位ステージ定義 ──────────────────────────────────────
class _Stage {
  final String rank;
  final Color color;
  final int minRating;
  final List<_Skill> skills;
  final String advice;

  const _Stage({
    required this.rank,
    required this.color,
    required this.minRating,
    required this.skills,
    required this.advice,
  });
}

class _Skill {
  final String label;
  final String detail;
  final IconData icon;
  final String? screen; // ルーティング用キー

  const _Skill({
    required this.label,
    required this.detail,
    required this.icon,
    this.screen,
  });
}

const _stages = [
  _Stage(
    rank: '15〜12級',
    color: Color(0xFF546E7A),
    minRating: 0,
    advice: 'まずは駒の動きを完全に覚えましょう。毎日1手詰めを5問解くだけで棋力が伸びます。',
    skills: [
      _Skill(label: '駒の動きを覚える',    detail: '全9種類の駒の動き・成りを完璧に', icon: Icons.book),
      _Skill(label: '1手詰めを解く',       detail: '毎日5問。まず王手に慣れる',       icon: Icons.extension, screen: 'tsume'),
      _Skill(label: '玉の囲いを1つ覚える', detail: '美濃囲いか矢倉を1種類だけ',       icon: Icons.security),
    ],
  ),
  _Stage(
    rank: '11〜8級',
    color: Color(0xFF607D8B),
    minRating: 450,
    advice: '3手詰めが安定して解けると8級に届きます。飛車・角の使い方を意識しましょう。',
    skills: [
      _Skill(label: '3手詰めを解く',       detail: '毎日10問。詰みパターンを増やす',  icon: Icons.extension, screen: 'tsume'),
      _Skill(label: '美濃囲いを完璧に',    detail: '7手で組める速さを目標に',         icon: Icons.security),
      _Skill(label: '飛車先の歩を交換する', detail: '序盤の基本。2六歩〜2五歩の流れ', icon: Icons.trending_up),
    ],
  ),
  _Stage(
    rank: '7〜5級',
    color: Color(0xFF4CAF50),
    minRating: 600,
    advice: '5手詰めが見えるようになると一気に伸びます。囲いを2種類使い分けましょう。',
    skills: [
      _Skill(label: '5手詰めを解く',       detail: '週3回。見えない手を読む訓練',     icon: Icons.extension, screen: 'tsume'),
      _Skill(label: '四間飛車の基本定跡',   detail: '穴熊対策・棒銀対策を覚える',      icon: Icons.route,  screen: 'joseki'),
      _Skill(label: '飛車・角の手筋',      detail: '王手金取り・両取りの形を覚える',  icon: Icons.psychology, screen: 'tesuji'),
    ],
  ),
  _Stage(
    rank: '4〜2級',
    color: Color(0xFF2196F3),
    minRating: 820,
    advice: 'ここからは終盤力が勝負を決めます。寄せ・受けのパターンを蓄積しましょう。',
    skills: [
      _Skill(label: '7手詰めを解く',       detail: '詰みの形を増やす。毎日1問でOK',  icon: Icons.extension, screen: 'tsume'),
      _Skill(label: '矢倉・角換わりの定跡', detail: '先手・後手両方の作戦を知る',      icon: Icons.route, screen: 'joseki'),
      _Skill(label: '寄せの手筋',          detail: '金底の歩・端攻め・底歩のパターン', icon: Icons.psychology, screen: 'tesuji'),
      _Skill(label: '弱点を分析する',       detail: 'AI対局後に自分の弱点を確認',      icon: Icons.analytics, screen: 'weakness'),
    ],
  ),
  _Stage(
    rank: '1級',
    color: Color(0xFFFF9800),
    minRating: 1050,
    advice: '初段の直前。中盤の構想力が鍵です。プロ棋士の定跡・格言を積極的に吸収しましょう。',
    skills: [
      _Skill(label: '7手詰めを解く',       detail: '長手数の詰みを読み切る訓練',      icon: Icons.extension, screen: 'tsume'),
      _Skill(label: '中盤の構想',           detail: '駒の効率・手番の使い方を意識',    icon: Icons.psychology, screen: 'game'),
      _Skill(label: '将棋の格言を覚える',   detail: '「角は引いて使え」など実戦格言を', icon: Icons.menu_book, screen: 'proverbs'),
      _Skill(label: 'コーチモードで指す',   detail: 'AI指導で悪手の癖を矯正する',     icon: Icons.school, screen: 'coach'),
    ],
  ),
  _Stage(
    rank: '初段',
    color: Color(0xFFFFC107),
    minRating: 1150,
    advice: 'おめでとうございます！初段はアマチュアの大きな節目。さらなる高みを目指しましょう。',
    skills: [
      _Skill(label: '11手詰めを解く',      detail: '有段者の詰将棋に挑戦',            icon: Icons.extension, screen: 'tsume'),
      _Skill(label: '相矢倉の深い定跡',    detail: '局面の細かい差を理解する',         icon: Icons.route, screen: 'joseki'),
      _Skill(label: '弱点を徹底分析',      detail: '上達のボトルネックを特定する',     icon: Icons.analytics, screen: 'weakness'),
    ],
  ),
];

// ── 画面 ────────────────────────────────────────────────
class ShodanRoadmapScreen extends StatefulWidget {
  const ShodanRoadmapScreen({super.key});

  @override
  State<ShodanRoadmapScreen> createState() => _ShodanRoadmapScreenState();
}

class _ShodanRoadmapScreenState extends State<ShodanRoadmapScreen> {
  int _rating = 700;
  int _tsumeCount = 0;
  int _tesujiCount = 0;
  int _totalGames = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // 詰将棋: 'tsume_clear_0' 〜 'tsume_clear_N' が true のもの
    int tsumeCount = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith('tsume_clear_') && (prefs.getBool(key) ?? false)) {
        tsumeCount++;
      }
    }
    // 手筋: 'tesuji_cleared_<id>' が true のもの
    int tesujiCount = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith('tesuji_cleared_') && (prefs.getBool(key) ?? false)) {
        tesujiCount++;
      }
    }
    if (mounted) {
      setState(() {
        _rating      = prefs.getInt('rating_current') ?? 700;
        _tsumeCount  = tsumeCount;
        _tesujiCount = tesujiCount;
        _totalGames  = prefs.getInt('stats_total') ?? 0; // total_gamesは存在しないキーで常に0だった
      });
    }
  }

  String get _currentRank => ratingToRank(_rating);

  // 現在のレーティングから該当ステージindex
  int get _currentStageIndex {
    for (int i = _stages.length - 1; i >= 0; i--) {
      if (_rating >= _stages[i].minRating) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final stageIdx = _currentStageIndex;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('初段への道', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(
              rating: _rating,
              rank: _currentRank,
              tsumeCount: _tsumeCount,
              tesujiCount: _tesujiCount,
              totalGames: _totalGames,
            ),
            const SizedBox(height: 20),
            const Text(
              'ロードマップ',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._stages.asMap().entries.map((e) {
              final idx   = e.key;
              final stage = e.value;
              final isCurrent = idx == stageIdx;
              final isDone    = _rating >= stage.minRating &&
                                idx < _stages.length - 1 &&
                                _rating >= _stages[idx + 1].minRating;
              return _StageCard(
                stage: stage,
                isCurrent: isCurrent,
                isDone: isDone,
                onNavigate: _navigate,
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigate(String? screen) {
    if (screen == null) return;
    switch (screen) {
      case 'joseki':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const JosekiScreen()));
        break;
      case 'tesuji':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TesujiScreen()));
        break;
      case 'proverbs':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProverbsScreen()));
        break;
      case 'tsume':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TsumeScreen()));
        break;
      case 'weakness':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => WeaknessAnalysisScreen(
            onGoToTsume: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TsumeScreen())),
            onGoToJoseki: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const JosekiScreen())),
            onGoToTesuji: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TesujiScreen())),
            onGoToAiGame: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GameSetupScreen(mode: GameMode.vsAI))),
          ),
        ));
        break;
      case 'game':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => GameSetupScreen(mode: GameMode.vsAI)));
        break;
      case 'coach':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI対局 → 設定 → コーチモードをONにしてください'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => GameSetupScreen(mode: GameMode.vsAI)));
        break;
      default:
        break;
    }
  }
}

// ── 現在の棋力サマリーカード ────────────────────────────
class _StatusCard extends StatelessWidget {
  final int rating;
  final String rank;
  final int tsumeCount;
  final int tesujiCount;
  final int totalGames;

  const _StatusCard({
    required this.rating,
    required this.rank,
    required this.tsumeCount,
    required this.tesujiCount,
    required this.totalGames,
  });

  @override
  Widget build(BuildContext context) {
    // 初段まで必要なレーティング
    const shodanMin = 1150;
    final toShodan = (shodanMin - rating).clamp(0, shodanMin);
    final progress = (rating / shodanMin).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F3A5F), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ratingToColor(rating).withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ratingToColor(rating).withAlpha(120)),
                ),
                child: Text(
                  rank,
                  style: TextStyle(
                    color: ratingToColor(rating),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('レーティング: $rating',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (toShodan > 0)
                    Text('初段まであと $toShodan',
                        style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  if (toShodan == 0)
                    const Text('初段以上！',
                        style: TextStyle(color: Colors.amber, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 初段進捗バー
          Row(
            children: [
              const Text('初段', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.amber : Colors.blue.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('詰将棋', '$tsumeCount問', Icons.extension),
              _stat('手筋',   '$tesujiCount問', Icons.psychology),
              _stat('対局数', '$totalGames局',  Icons.sports_esports),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, color: Colors.white38, size: 18),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ],
  );
}

// ── ステージカード ────────────────────────────────────────
class _StageCard extends StatefulWidget {
  final _Stage stage;
  final bool isCurrent;
  final bool isDone;
  final void Function(String?) onNavigate;

  const _StageCard({
    required this.stage,
    required this.isCurrent,
    required this.isDone,
    required this.onNavigate,
  });

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isCurrent;
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isCurrent
              ? stage.color.withAlpha(30)
              : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isCurrent
                ? stage.color.withAlpha(180)
                : widget.isDone
                    ? Colors.green.withAlpha(80)
                    : Colors.white12,
            width: widget.isCurrent ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // ヘッダー
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // ランクバッジ
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: stage.color.withAlpha(40),
                        shape: BoxShape.circle,
                        border: Border.all(color: stage.color.withAlpha(120)),
                      ),
                      child: widget.isDone
                          ? Icon(Icons.check, color: Colors.green.shade400, size: 22)
                          : Center(
                              child: Text(
                                stage.rank.contains('初段') ? '初' : stage.rank[0],
                                style: TextStyle(
                                  color: stage.color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                stage.rank,
                                style: TextStyle(
                                  color: stage.color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: stage.color.withAlpha(60),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('現在地',
                                      style: TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${stage.skills.length}つのスキル',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
            // 展開時: スキル一覧 + アドバイス
            if (_expanded) ...[
              Container(
                height: 1,
                color: Colors.white12,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  stage.advice,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 8),
              ...stage.skills.map((skill) => _SkillRow(skill: skill, onTap: widget.onNavigate)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// ── スキル行 ────────────────────────────────────────────
class _SkillRow extends StatelessWidget {
  final _Skill skill;
  final void Function(String?) onTap;

  const _SkillRow({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: skill.screen != null ? () => onTap(skill.screen) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(skill.icon, color: Colors.white38, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.label,
                      style: const TextStyle(color: Color(0xDEFFFFFF), fontSize: 14)),
                  Text(skill.detail,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (skill.screen != null)
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
          ],
        ),
      ),
    );
  }
}
