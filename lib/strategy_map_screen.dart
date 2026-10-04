// lib/strategy_map_screen.dart — 戦法マッピング画面
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'strategy_data.dart';
import 'theme/app_theme.dart';

class StrategyMapScreen extends StatefulWidget {
  final OppCastle? initialCastle;
  final OppStrategy? initialStrategy;

  const StrategyMapScreen({
    super.key,
    this.initialCastle,
    this.initialStrategy,
  });

  @override
  State<StrategyMapScreen> createState() => _StrategyMapScreenState();
}

class _StrategyMapScreenState extends State<StrategyMapScreen> {
  late OppCastle _castle;
  late OppStrategy _strategy;

  @override
  void initState() {
    super.initState();
    _castle = widget.initialCastle ?? OppCastle.mino;
    _strategy = widget.initialStrategy ?? OppStrategy.shiken;
  }

  List<StrategyRec> get _recs =>
      kStrategyMap[(_castle, _strategy)] ??
      [
        const StrategyRec(
          name: 'データ準備中',
          stars: 0,
          warType: WarType.kyusen,
          point: 'この組み合わせは近日追加予定です',
          detail: '',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('対策マップ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        // セレクタ部分（固定ヘッダー）
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('相手の囲い',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .5)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: OppCastle.values
                      .map((c) => _SelectChip(
                            label: c.label,
                            selected: c == _castle,
                            color: Colors.blue.shade400,
                            onTap: () => setState(() => _castle = c),
                          ))
                      .toList()),
            ),
            const SizedBox(height: 12),
            const Text('相手の戦法',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .5)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: OppStrategy.values
                      .map((s) => _SelectChip(
                            label: s.label,
                            selected: s == _strategy,
                            color: Colors.purple.shade300,
                            onTap: () => setState(() => _strategy = s),
                          ))
                      .toList()),
            ),
          ]),
        ),

        // 結果リスト
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // 組合せラベル
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withAlpha(80)),
                  ),
                  child: Text(_castle.label,
                      style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('×',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purple.withAlpha(80)),
                  ),
                  child: Text(_strategy.label,
                      style: TextStyle(
                          color: Colors.purple.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('への対策',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 10),

              // 囲いの特徴
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: Colors.blue, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_castle.desc,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12, height: 1.4)),
                  ),
                ]),
              ),

              // おすすめ戦法カード
              ..._recs.asMap().entries.map((e) => _StrategyCard(
                    rec: e.value,
                    isTop: e.key == 0,
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

// ===== セレクタチップ =====
class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(45) : Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? color : Colors.white70,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

// ===== 戦法カード =====
class _StrategyCard extends StatelessWidget {
  final StrategyRec rec;
  final bool isTop;

  const _StrategyCard({required this.rec, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final typeColor =
        rec.warType == WarType.kyusen ? Colors.orange : Colors.teal;
    final typeLabel = rec.warType == WarType.kyusen ? '急戦' : '持久戦';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop ? Colors.amber.withAlpha(160) : Colors.white12,
          width: isTop ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // タイトル行
          Row(children: [
            ...List.generate(
                3,
                (i) => Icon(
                      i < rec.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 17,
                    )),
            const SizedBox(width: 8),
            Expanded(
              child: Text(rec.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            if (isTop)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('おすすめ',
                    style:
                        TextStyle(color: Colors.amber, fontSize: 10)),
              ),
          ]),
          const SizedBox(height: 8),

          // タグ
          Row(children: [
            _Tag(label: typeLabel, color: typeColor),
            if (rec.isHard) ...[
              const SizedBox(width: 6),
              _Tag(label: '高難度', color: Colors.purpleAccent),
            ],
          ]),
          const SizedBox(height: 8),

          // ポイント（太字）
          Text(rec.point,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),

          // 詳細
          if (rec.detail.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(rec.detail,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.55)),
          ],
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
