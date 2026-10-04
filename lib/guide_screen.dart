// lib/guide_screen.dart — ツール利用方法

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('使い方'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('ゲーム画面'),
          _GuideItem(
            '1',
            '駒を選ぶ',
            '盤上の自分の駒をタップして選びます。選べる駒は黄色く光ります。',
          ),
          _GuideItem(
            '2',
            '移動先を選ぶ',
            '選んだ駒が動けるマスが緑と赤で表示されます。動かしたいマスをタップします。',
          ),
          _GuideItem(
            '3',
            '駒を打つ',
            '下の「持ち駒」パネルで駒をタップして選び、盤上の置きたいマスをタップします。',
          ),
          const SizedBox(height: 20),
          _SectionTitle('効き表示'),
          _GuideItem(
            '🔵',
            '青い色',
            'あなたの駒が攻撃できるマスです。複数の駒が同じマスを攻撃するほど濃くなります。',
          ),
          _GuideItem(
            '🔴',
            '赤・オレンジ色',
            '相手の駒が攻撃できるマスです。相手が多く狙っているほど濃くなります。',
          ),
          _GuideItem(
            '🟣',
            '紫色',
            'あなたと相手の両方が攻撃しているマスです。どちらが多いかで色が変わります。',
          ),
          _GuideItem(
            '①②③',
            '数字表示',
            '右下の数字は、そのマスを攻撃している駒の数です。',
          ),
          const SizedBox(height: 20),
          _SectionTitle('ボタン機能'),
          _GuideItem(
            '🚩',
            '投了',
            '自分が負けたと思ったら、このボタンで投了できます。',
          ),
          _GuideItem(
            '💡',
            '局面分析',
            'AI の最善手を表示します。勉強用に使えます。',
          ),
          _GuideItem(
            '👁',
            '効きを表示',
            '効き表示をオン/オフできます。',
          ),
          _GuideItem(
            '📋',
            '棋譜',
            'これまでの手を一覧で確認できます。',
          ),
          _GuideItem(
            '💾',
            '保存',
            '今の棋譜をデバイスに保存します。',
          ),
          _GuideItem(
            '🔄',
            '新局',
            '新しいゲームを始めます。',
          ),
          const SizedBox(height: 20),
          _SectionTitle('設定'),
          _GuideItem(
            '1',
            'AI の強さ',
            'ランダム、弱、中、強から選べます。',
          ),
          _GuideItem(
            '2',
            '持ち時間',
            'なし、3分、5分、10分、15分から選べます。',
          ),
          _GuideItem(
            '3',
            '駒のテーマ',
            '標準またはダークテーマを選べます。',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  const _GuideItem(this.icon, this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.brown.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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
