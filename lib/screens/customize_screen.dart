// lib/screens/customize_screen.dart
// カスタマイズ画面（アバターカラー・表示称号）

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme_config.dart';
import '../badge_service.dart';
import '../services/network_service.dart';
import '../character_icons.dart';
import '../purchase_service.dart';
import '../theme/app_theme.dart';
import '../services/character_bond_service.dart';

class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key});

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  final NetworkService _networkService = NetworkService();

  static const _avatarColors = [
    Colors.amber,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.orange,
    Colors.pink,
  ];

  int _selectedColorIdx = 0;
  String? _selectedTitle;
  String? _selectedCharIconId;
  List<String> _unlockedBadges = [];
  Map<String, int> _bondLevels = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorIdx = prefs.getInt('avatar_color_idx') ?? 0;
    final title = prefs.getString('display_title');
    final charIconId = prefs.getString('character_icon_id');

    // 絆レベルを読み込み（実際の勝利数ベースのCharacterBondServiceを使用）
    final bonds = <String, int>{};
    for (final char in allCharacterIcons) {
      final level = (await CharacterBondService.getBondLevel(char.id)).index;
      if (level > 0) bonds[char.id] = level;
    }

    // Firebase から解除済みバッジを取得
    List<String> badges = [];
    final uid = _networkService.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          badges = List<String>.from(doc.data()!['achievements'] as List? ?? []);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _selectedColorIdx = colorIdx.clamp(0, _avatarColors.length - 1);
        _selectedTitle = title;
        _selectedCharIconId = charIconId;
        _bondLevels = bonds;
        _unlockedBadges = badges;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avatar_color_idx', _selectedColorIdx);
    if (_selectedTitle != null) {
      await prefs.setString('display_title', _selectedTitle!);
    } else {
      await prefs.remove('display_title');
    }
    if (_selectedCharIconId != null) {
      await prefs.setString('character_icon_id', _selectedCharIconId!);
    } else {
      await prefs.remove('character_icon_id');
    }

    // Firestore にも保存
    final uid = _networkService.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'avatar_color_idx': _selectedColorIdx,
          'display_title': _selectedTitle,
          'character_icon_id': _selectedCharIconId,
        });
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('カスタマイズ', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // プレビュー
                  _buildPreview(),
                  const SizedBox(height: 24),

                  // キャラクターアイコン
                  _sectionHeader('キャラクターアイコン'),
                  const SizedBox(height: 4),
                  const Text(
                    '対局中に表示されるアイコンを選択',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _buildCharIconPicker(),
                  const SizedBox(height: 24),

                  // アバターカラー
                  _sectionHeader('アバターカラー'),
                  const SizedBox(height: 12),
                  _buildColorPicker(),
                  const SizedBox(height: 24),

                  // 表示称号
                  _sectionHeader('表示称号'),
                  const SizedBox(height: 4),
                  const Text(
                    '解除済みの実績から称号を選択できます',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _buildTitlePicker(),
                ],
              ),
            ),
    );
  }

  Widget _buildPreview() {
    final color = _avatarColors[_selectedColorIdx];
    final charIcon = _selectedCharIconId != null
        ? findCharacterById(_selectedCharIconId!)
        : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Stack(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 12)],
              ),
              child: charIcon != null
                  ? ClipOval(
                      child: Image.asset(
                        charIcon.imagePath,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(charIcon.emoji, style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            charIcon != null ? charIcon.name : 'プレビュー',
            style: const TextStyle(color: AppTheme.textHigh, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (_selectedTitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.withAlpha(80)),
              ),
              child: Text(
                _selectedTitle!,
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
            )
          else
            const Text('称号未設定', style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildCharIconPicker() {
    final isPremium = PurchaseService.isPremium;

    // ティア別グループ
    final groups = [
      ('無料', CharIconTier.free, Colors.white70, true),
      ('プレミアム限定', CharIconTier.subscription, Colors.amber, isPremium),
      ('プレミアム限定', CharIconTier.pack, AppTheme.accent, isPremium),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // なし
        _charIconTile(null, '表示なし', 'アイコンを使用しません', false),
        const SizedBox(height: 8),
        ...groups.map((g) {
          final icons = allCharacterIcons.where((c) => c.tier == g.$2).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  g.$1,
                  style: TextStyle(
                    color: g.$3,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                if (!g.$4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('🔒', style: TextStyle(fontSize: 10)),
                  ),
              ]),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((icon) {
                  final locked = !g.$4;
                  final bondLevel = _bondLevels[icon.id] ?? 0;
                  return _charIconCell(icon, locked, bondLevel);
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  Widget _charIconCell(CharacterIcon icon, bool locked, int bondLevel) {
    final selected = _selectedCharIconId == icon.id;
    return GestureDetector(
      onTap: locked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(icon.tier == CharIconTier.subscription
                      ? 'サブスクリプション加入で使用できます'
                      : 'キャラクターパックを購入すると使用できます'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : () => setState(() => _selectedCharIconId = icon.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? icon.bgColor.withAlpha(60) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? icon.bgColor : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharIconWidget(icon: icon, size: 44, locked: locked),
            const SizedBox(height: 4),
            Text(
              icon.name,
              style: TextStyle(
                color: locked ? AppTheme.textLow : AppTheme.textMid,
                fontSize: 10,
              ),
            ),
            if (!locked && bondLevel > 0) ...[
              const SizedBox(height: 3),
              SizedBox(
                width: 48,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1.5),
                  child: LinearProgressIndicator(
                    value: bondLevel / icon.maxBondLevel,
                    minHeight: 3,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(icon.bgColor),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '絆Lv$bondLevel',
                style: const TextStyle(color: Colors.amber, fontSize: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _charIconTile(String? id, String name, String sub, bool selectable) {
    final selected = _selectedCharIconId == id;
    return GestureDetector(
      onTap: selectable ? () => setState(() => _selectedCharIconId = id) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withAlpha(12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white54 : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? Colors.white70 : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(
              color: selected ? AppTheme.textHigh : AppTheme.textMid,
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(color: AppTheme.textLow, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(_avatarColors.length, (i) {
        final color = _avatarColors[i];
        final selected = _selectedColorIdx == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIdx = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: selected ? 3 : 0,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8)]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildTitlePicker() {
    // 解除済みバッジから称号リストを作成
    final titles = <String>[];
    for (final badge in allBadges) {
      if (_unlockedBadges.contains(badge.id.name)) {
        titles.add(badge.title);
      }
    }

    if (titles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '実績を解除すると称号が使えるようになります',
          style: TextStyle(color: AppTheme.textLow, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(children: [
      // なし
      _titleTile(null, '称号なし', '称号を表示しません'),
      ...titles.map((t) => _titleTile(t, t, '')),
    ]);
  }

  Widget _titleTile(String? value, String title, String subtitle) {
    final selected = _selectedTitle == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTitle = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.amber.withAlpha(20)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.amber : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? Colors.amber : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.amber : AppTheme.textHigh,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(color: AppTheme.textLow, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      color: AppTheme.textMid,
      fontSize: 13,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
  );
}
