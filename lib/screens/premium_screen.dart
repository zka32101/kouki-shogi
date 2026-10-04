// lib/screens/premium_screen.dart
// プレミアム・ストア画面（課金統合）

import 'package:flutter/material.dart';
import '../purchase_service.dart';
import '../theme/app_theme.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _hasPlan300 = false;
  bool _hasPlan500 = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    if (mounted) setState(() {
      _hasPlan300 = PurchaseService.hasPlan300;
      _hasPlan500 = PurchaseService.hasPlan500;
      _loading = false;
    });
  }

  Future<void> _buyPlan300() async {
    setState(() => _loading = true);
    final ok = await PurchaseService.purchasePlan300();
    if (mounted) {
      setState(() => _loading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('300円プランを購入しました！')),
        );
        _checkStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入をキャンセルしました')),
        );
      }
    }
  }

  Future<void> _buyPlan500() async {
    setState(() => _loading = true);
    final ok = await PurchaseService.purchasePlan500();
    if (mounted) {
      setState(() => _loading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('500円プランを購入しました！')),
        );
        _checkStatus();
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    await PurchaseService.restore();
    _checkStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入履歴を復元しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('プレミアム', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _restore,
            child: const Text('復元', style: TextStyle(color: AppTheme.textMid)),
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
                  // ヘッダー
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade900, Colors.indigo.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      const Icon(Icons.workspace_premium, color: Colors.amber, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        '効棋 Premium',
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '最高の将棋体験を',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // 機能比較表
                  _buildComparisonTable(),
                  const SizedBox(height: 20),

                  // 無料プラン
                  _buildFreePlanCard(),
                  const SizedBox(height: 16),

                  // 300円プラン
                  _buildPlan300Card(),
                  const SizedBox(height: 16),

                  // 500円プラン
                  _buildPlan500Card(),
                  const SizedBox(height: 24),

                  // 注意事項
                  const Text(
                    '・全てのプランは買い切りです\n'
                    '・購入の復元は「復元」ボタンから',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  // ── 機能比較表 ──────────────────────────────────────────────
  Widget _buildComparisonTable() {
    const rows = [
      ('対戦回数',      '5回/日', '無制限',  '無制限'),
      ('広告',         'あり',   'なし',    'なし'),
      ('棋風診断',      '×',     '✓',       '✓'),
      ('弱点分析',      '×',     '✓',       '✓'),
      ('ゴースト棋士',  '×',     '✓',       '✓'),
      ('難易度自動調整', '×',    '✓',       '✓'),
      ('忘却曲線AI',    '×',     '✓',       '✓'),
      ('AI週次振り返り', '×',   '×',       '✓'),
      ('クラウド同期',   '×',   '×',       '✓'),
      ('無制限履歴',    '×',    '×',       '✓'),
      ('プレミアムバッジ', '×', '×',       '✓'),
    ];

    Widget header(String text, {Color? bg}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: bg,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: bg != null ? Colors.black87 : AppTheme.textMid,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );

    Widget cell(String text, {bool isCheck = false, bool isCross = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: isCheck ? Colors.greenAccent.shade400
              : isCross ? Colors.white24
              : AppTheme.textHigh,
          fontWeight: isCheck ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.0),
        },
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Colors.white10, width: 0.5),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF0D1B2A)),
            children: [
              header('機能'),
              header('無料'),
              header('300円', bg: Colors.blue.shade800),
              header('500円', bg: Colors.amber.shade800),
            ],
          ),
          for (final r in rows)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text(r.$1, style: const TextStyle(color: AppTheme.textMid, fontSize: 11)),
              ),
              cell(r.$2, isCross: r.$2 == '×'),
              cell(r.$3, isCheck: r.$3 == '✓', isCross: r.$3 == '×'),
              cell(r.$4, isCheck: r.$4 == '✓', isCross: r.$4 == '×'),
            ]),
        ],
      ),
    );
  }

  Widget _buildFreePlanCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.diamond_outlined, color: Colors.grey.shade400, size: 18),
            const SizedBox(width: 6),
            const Text(
              '無料プラン',
              style: TextStyle(color: AppTheme.textHigh, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ]),
          const SizedBox(height: 12),
          _benefitRow(Icons.sports_esports, '対戦', '5回まで'),
          _benefitRow(Icons.campaign, '広告', '表示あり'),
        ],
      ),
    );
  }

  Widget _buildPlan300Card() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasPlan300 ? Colors.blue.shade700 : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.diamond, color: Colors.blue.shade400, size: 18),
            const SizedBox(width: 6),
            const Text(
              '300円プラン',
              style: TextStyle(color: AppTheme.textHigh, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            if (_hasPlan300)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('購入済み', style: TextStyle(color: AppTheme.textHigh, fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 12),
          _benefitRow(Icons.done, '対戦', '無制限'),
          _benefitRow(Icons.psychology, '棋風判断', '自動分析'),
          _benefitRow(Icons.analytics, '弱点分析', '詳細表示'),
          _benefitRow(Icons.smart_toy, 'ゴースト棋士', 'AI対局シミュレーション'),
          _benefitRow(Icons.block, '広告', '非表示'),
          if (!_hasPlan300) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _buyPlan300,
                icon: const Icon(Icons.shopping_bag),
                label: const Text('300円で購入'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.catConfig,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlan500Card() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasPlan500 ? Colors.amber.shade700 : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.diamond, color: Colors.amber.shade400, size: 18),
            const SizedBox(width: 6),
            const Text(
              '500円プラン',
              style: TextStyle(color: AppTheme.textHigh, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            if (_hasPlan500)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('購入済み', style: TextStyle(color: AppTheme.textHigh, fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 12),
          const Text('300円プランのすべて +', style: TextStyle(color: AppTheme.textMid, fontSize: 12)),
          const SizedBox(height: 8),
          _benefitRow(Icons.auto_awesome, 'AI週次振り返り', '毎週の対局分析'),
          _benefitRow(Icons.cloud_sync, 'クラウド同期', '棋譜自動バックアップ'),
          _benefitRow(Icons.history, '対局履歴', '無制限保存'),
          _benefitRow(Icons.workspace_premium, 'プレミアムバッジ', 'プロフィール表示'),
          if (!_hasPlan500) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _buyPlan500,
                icon: const Icon(Icons.shopping_bag),
                label: const Text('500円で購入'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.catConfig,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _benefitRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: Colors.amber.shade600, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textHigh, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(desc, style: const TextStyle(color: AppTheme.textLow, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

}
