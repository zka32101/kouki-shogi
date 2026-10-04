// lib/screens/ghost_screen.dart
// ゴースト棋士画面 - 自分の棋風ゴーストで他プレイヤーと自動対戦

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ghost_service.dart';
import '../theme/app_theme.dart';

class GhostScreen extends StatefulWidget {
  const GhostScreen({super.key});

  @override
  State<GhostScreen> createState() => _GhostScreenState();
}

class _GhostScreenState extends State<GhostScreen> {
  GhostPersonalityData? _myPersonality;
  List<GhostOpponent> _opponents = [];
  bool _loading = true;
  bool _battling = false;
  int _battleProgress = 0;
  String? _battleResult; // 'win' | 'loss'
  String? _battleOpponentName;
  int _todayWins = 0;
  int _todayLosses = 0;
  bool _hasEnoughData = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final games = prefs.getInt('playstyle_games') ?? 0;
    final total = (prefs.getInt('playstyle_total') ?? 0);

    GhostPersonalityData? pers;
    if (games >= 5 && total > 0) {
      final attack = prefs.getInt('playstyle_attack') ?? 0;
      final retreat = prefs.getInt('playstyle_retreat') ?? 0;
      final drop = prefs.getInt('playstyle_drop') ?? 0;
      pers = GhostPersonalityData.fromPlaystyleStats(
        attackRatio: attack / total,
        retreatRatio: retreat / total,
        dropRatio: drop / total,
      );
    }

    final record = await GhostService.getTodayRecord();
    final opponents = await GhostService.fetchOpponents();

    if (mounted) {
      setState(() {
        _myPersonality = pers;
        _hasEnoughData = games >= 5 && total > 0;
        _opponents = opponents ?? [];
        _todayWins = record.wins;
        _todayLosses = record.losses;
        _errorMessage = opponents == null ? 'ネットワークエラー: ゴースト棋士を読み込めません' : null;
        _loading = false;
      });
    }
  }

  Future<void> _startBattle(GhostOpponent opponent) async {
    if (_battling || _myPersonality == null) return;

    setState(() {
      _battling = true;
      _battleProgress = 0;
      _battleResult = null;
      _battleOpponentName = opponent.displayName;
    });

    // プログレスアニメーション（対戦中演出）
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 280));
      if (mounted) setState(() => _battleProgress = i);
    }

    final won =
        await GhostService.simulateBattle(_myPersonality!, opponent.personality);

    final success = await GhostService.recordResult(
      oppUid: opponent.uid,
      oppName: opponent.displayName,
      myWon: won,
    );

    if (mounted) {
      setState(() {
        _battling = false;
        _battleResult = won ? 'win' : 'loss';
        if (won) {
          _todayWins++;
        } else {
          _todayLosses++;
        }
        if (!success) {
          _errorMessage = 'オフラインの可能性: 対戦結果が保存されない場合があります';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ゴースト棋士', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loading ? null : () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withAlpha(200),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildMyGhostCard(),
                  const SizedBox(height: 12),
                  _buildTodayRecord(),
                  if (_battleResult != null) ...[
                    const SizedBox(height: 12),
                    _buildBattleResultCard(),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    '対戦相手',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_opponents.isEmpty)
                    _buildEmptyOpponents()
                  else
                    ..._opponents.map(_buildOpponentCard),
                ],
              ),
            ),
    );
  }

  Widget _buildMyGhostCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A237E),
            Colors.indigo.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.indigo.shade300.withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('👻', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text(
              '自分のゴースト',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (!_hasEnoughData)
            const Text(
              'AI対局を5回以上行うとゴーストが誕生します',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            )
          else if (_myPersonality != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.withAlpha(80),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.indigo.shade300.withAlpha(100)),
              ),
              child: Text(
                _myPersonality!.typeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _myPersonality!.description,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _buildBar('攻撃', _myPersonality!.attackBias / 3.0,
                Colors.red.shade400),
            const SizedBox(height: 4),
            _buildBar('守備', _myPersonality!.defenceBias / 3.0,
                Colors.blue.shade400),
            const SizedBox(height: 4),
            _buildBar('駒欲', _myPersonality!.greedBias / 2.0,
                Colors.amber.shade400),
          ],
        ],
      ),
    );
  }

  Widget _buildBar(String label, double value, Color color) {
    return Row(children: [
      SizedBox(
        width: 36,
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    ]);
  }

  Widget _buildTodayRecord() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('今日の戦績',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 16),
          Text(
            '$_todayWins勝',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_todayLosses敗',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleResultCard() {
    final isWin = _battleResult == 'win';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWin
            ? Colors.green.shade900.withAlpha(200)
            : Colors.red.shade900.withAlpha(200),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWin
              ? Colors.greenAccent.withAlpha(120)
              : Colors.redAccent.withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isWin ? '⚔️ 勝利！' : '🛡️ 敗北',
            style: TextStyle(
              color: isWin ? Colors.greenAccent : Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'vs $_battleOpponentName',
            style:
                const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentCard(GhostOpponent opponent) {
    final isBattlingThis =
        _battling && _battleOpponentName == opponent.displayName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade800,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('👻', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  opponent.personality.typeName,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '通算 ${opponent.wins}勝 ${opponent.losses}敗',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isBattlingThis)
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _battleProgress / 5.0,
                    strokeWidth: 3,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.amber),
                  ),
                  Text(
                    '$_battleProgress',
                    style: const TextStyle(
                        color: Colors.amber, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: (!_battling && _hasEnoughData)
                  ? () => _startBattle(opponent)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('出陣', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyOpponents() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        children: [
          Text('👻', style: TextStyle(fontSize: 40)),
          SizedBox(height: 10),
          Text(
            'まだゴーストが集まっていません',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'AI対局を続けると他プレイヤーのゴーストが現れます',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
