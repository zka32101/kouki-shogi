// lib/playstyle_diagnosis_screen.dart — 棋風診断画面

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'character_icons.dart';
import 'theme/app_theme.dart';

// ===== 棋風タイプ定義 =====

class _PlaystyleType {
  final String label;
  final String emoji;
  final String description;
  final String characterId;
  final Color color;
  final List<String> traits;

  const _PlaystyleType({
    required this.label,
    required this.emoji,
    required this.description,
    required this.characterId,
    required this.color,
    required this.traits,
  });
}

const _playstyleTypes = <String, _PlaystyleType>{
  'ultra_attack': _PlaystyleType(
    label: '超攻撃型',
    emoji: '🔥',
    description: '駒を前進させることに特化した極端な攻め将棋。守りを捨てても攻め続ける。',
    characterId: 'oni',
    color: Color(0xFFB71C1C),
    traits: ['速攻', '捨て駒多用', '守りを捨てる', '一点突破'],
  ),
  'attack': _PlaystyleType(
    label: '攻撃型',
    emoji: '⚔️',
    description: '積極的に駒を進め、相手陣地に切り込む攻め将棋。',
    characterId: 'tengu',
    color: Color(0xFFC62828),
    traits: ['積極的', '駒を前進', '速い展開', '押し将棋'],
  ),
  'balanced': _PlaystyleType(
    label: 'バランス型',
    emoji: '⚖️',
    description: '攻めと守りのバランスが取れた万能型。状況に応じた柔軟な指し回し。',
    characterId: 'samurai',
    color: Color(0xFF1565C0),
    traits: ['万能型', '柔軟', '状況対応', '手堅い'],
  ),
  'defence': _PlaystyleType(
    label: '守備型',
    emoji: '🛡️',
    description: '玉の安全を最優先に、堅固な陣形を築いてから攻める持久戦型。',
    characterId: 'shogun',
    color: Color(0xFF2E7D32),
    traits: ['堅陣', '持久戦', '相手の攻めを受ける', '手堅い勝ち'],
  ),
  'drop_master': _PlaystyleType(
    label: '打ち駒師',
    emoji: '🎯',
    description: '持ち駒を効果的に使いこなす。打ち駒で局面を一変させるスタイル。',
    characterId: 'ryuou',
    color: Color(0xFF6A1B9A),
    traits: ['持ち駒活用', '柔軟な戦略', '盤上外から攻める', '駒得重視'],
  ),
};

// ===== メイン画面 =====

class PlaystyleDiagnosisScreen extends StatefulWidget {
  const PlaystyleDiagnosisScreen({super.key});

  @override
  State<PlaystyleDiagnosisScreen> createState() => _PlaystyleDiagnosisScreenState();
}

class _PlaystyleDiagnosisScreenState extends State<PlaystyleDiagnosisScreen> {
  static const _bg = AppTheme.bg;

  int _attackMoves = 0;
  int _retreatMoves = 0;
  int _dropMoves = 0;
  int _totalMoves = 0;
  int _games = 0;
  bool _loaded = false;
  static const _minGamesForAccuracy = 5;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _attackMoves = prefs.getInt('playstyle_attack') ?? 0;
      _retreatMoves = prefs.getInt('playstyle_retreat') ?? 0;
      _dropMoves = prefs.getInt('playstyle_drop') ?? 0;
      _totalMoves = prefs.getInt('playstyle_total') ?? 0;
      _games = prefs.getInt('playstyle_games') ?? 0;
      _loaded = true;
    });
  }

  Future<void> _resetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('データをリセット', style: TextStyle(color: Colors.white)),
        content: const Text('棋風診断データをリセットしますか？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('リセット', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['playstyle_attack', 'playstyle_retreat', 'playstyle_drop', 'playstyle_total', 'playstyle_games']) {
      await prefs.remove(key);
    }
    _loadStats();
  }

  _PlaystyleType _diagnose() {
    if (_totalMoves == 0) return _playstyleTypes['balanced']!;

    final attackRatio = _attackMoves / _totalMoves;
    final retreatRatio = _retreatMoves / _totalMoves;
    final dropRatio = _dropMoves / _totalMoves;

    if (attackRatio > 0.45 && retreatRatio < 0.15) return _playstyleTypes['ultra_attack']!;
    if (attackRatio > 0.38) return _playstyleTypes['attack']!;
    if (retreatRatio > 0.32) return _playstyleTypes['defence']!;
    if (dropRatio > 0.22) return _playstyleTypes['drop_master']!;
    return _playstyleTypes['balanced']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('棋風診断', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_games > 0)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _resetStats,
              tooltip: 'データをリセット',
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _games == 0
              ? _buildNoData()
              : _buildDiagnosis(),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'データがまだありません',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI対局をいくつかプレイすると\nあなたの棋風を診断します。',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'より精度の高い診断には10局以上の\nデータが必要です。',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosis() {
    final type = _diagnose();
    final char = findCharacterById(type.characterId);
    final lateralMoves = _totalMoves - _attackMoves - _retreatMoves - _dropMoves;
    final lateralPct = _totalMoves > 0 ? (lateralMoves * 100 / _totalMoves).round() : 0;
    final attackPct = _totalMoves > 0 ? (_attackMoves * 100 / _totalMoves).round() : 0;
    final retreatPct = _totalMoves > 0 ? (_retreatMoves * 100 / _totalMoves).round() : 0;
    final dropPct = _totalMoves > 0 ? (_dropMoves * 100 / _totalMoves).round() : 0;
    final isAccurate = _games >= _minGamesForAccuracy;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 精度警告 ──
          if (!isAccurate)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withAlpha(200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'データが少ないため精度が低い可能性があります。($_games/${_minGamesForAccuracy}局)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // ── データ数 ──
          Text(
            '$_games局のデータから診断',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // ── 棋風タイプカード ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [type.color.withAlpha(180), type.color.withAlpha(80)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: type.color.withAlpha(180)),
            ),
            child: Column(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  type.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  type.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: type.traits.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(60)),
                    ),
                    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 近いキャラクター ──
          if (char != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: char.bgColor.withAlpha(120)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: char.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(char.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('あなたに近いキャラクター', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          char.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          char.description,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 指し手分布 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '指し手の傾向',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _statBar('前進（攻め）', attackPct, Colors.redAccent),
                const SizedBox(height: 10),
                _statBar('後退（守り）', retreatPct, Colors.blueAccent),
                const SizedBox(height: 10),
                _statBar('横（陣形整備）', lateralPct, Colors.amber),
                const SizedBox(height: 10),
                _statBar('打ち駒', dropPct, Colors.purpleAccent),
                const SizedBox(height: 12),
                Text(
                  '総手数: $_totalMoves手 / $_games局',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 精度注記 ──
          if (_games < 10)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'より正確な診断には10局以上のデータが必要です。現在${_games}局。',
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statBar(String label, int pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('$pct%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
