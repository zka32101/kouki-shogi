// lib/character_icons.dart
// キャラクターアイコン定義（無料 / サブスク専用 / キャラパック）

import 'package:flutter/material.dart';

/// アイコンの解放ティア
enum CharIconTier {
  free,         // 無料
  subscription, // サブスク加入で使用可能
  pack,         // キャラクターパック購入で使用可能
}

class CharacterIcon {
  final String id;
  final String name;
  final String emoji;
  final Color bgColor;
  final CharIconTier tier;
  final String description;
  final int maxBondLevel;

  const CharacterIcon({
    required this.id,
    required this.name,
    required this.emoji,
    required this.bgColor,
    required this.tier,
    required this.description,
    this.maxBondLevel = 10,
  });

  // AI生成キャラアイコン画像（tools/shogi_app_image_gen で生成、assets/character_icons/）。
  // 読み込みに失敗した場合はCharIconWidget側で絵文字表示にフォールバックする。
  String get imagePath => 'assets/character_icons/$id.png';
}

// ===== キャラクター一覧 =====

const List<CharacterIcon> allCharacterIcons = [
  // ── 無料（デフォルト） ──────────────────────────────
  CharacterIcon(
    id: 'samurai',
    name: '武士',
    emoji: '⚔️',
    bgColor: Color(0xFF1565C0),
    tier: CharIconTier.free,
    description: '誇り高き武士',
  ),
  CharacterIcon(
    id: 'ninja',
    name: '忍者',
    emoji: '🥷',
    bgColor: Color(0xFF37474F),
    tier: CharIconTier.free,
    description: '影に潜む忍者',
  ),
  CharacterIcon(
    id: 'kenshi',
    name: '剣士',
    emoji: '🗡️',
    bgColor: Color(0xFF455A64),
    tier: CharIconTier.free,
    description: '剣の達人',
  ),

  // ── サブスク限定 ─────────────────────────────────────
  CharacterIcon(
    id: 'shogun',
    name: '将軍',
    emoji: '👑',
    bgColor: Color(0xFFB8860B),
    tier: CharIconTier.subscription,
    description: '天下人・将軍',
  ),
  CharacterIcon(
    id: 'tengu',
    name: '天狗',
    emoji: '👺',
    bgColor: Color(0xFFC62828),
    tier: CharIconTier.subscription,
    description: '山の霊峰・天狗',
  ),
  CharacterIcon(
    id: 'ryuou',
    name: '龍王',
    emoji: '🐉',
    bgColor: Color(0xFF4A148C),
    tier: CharIconTier.subscription,
    description: '伝説の龍王',
  ),

  // ── キャラクターパック ────────────────────────────────
  CharacterIcon(
    id: 'kitsunebi',
    name: '狐火',
    emoji: '🦊',
    bgColor: Color(0xFFE65100),
    tier: CharIconTier.pack,
    description: '神秘の狐火',
  ),
  CharacterIcon(
    id: 'taka',
    name: '鷹',
    emoji: '🦅',
    bgColor: Color(0xFF4E342E),
    tier: CharIconTier.pack,
    description: '大空の鷹',
  ),
  CharacterIcon(
    id: 'tora',
    name: '虎',
    emoji: '🐯',
    bgColor: Color(0xFFF57F17),
    tier: CharIconTier.pack,
    description: '百獣の王・虎',
  ),
  CharacterIcon(
    id: 'ookami',
    name: '狼',
    emoji: '🐺',
    bgColor: Color(0xFF546E7A),
    tier: CharIconTier.pack,
    description: '孤高の狼',
  ),
  CharacterIcon(
    id: 'oni',
    name: '鬼',
    emoji: '👹',
    bgColor: Color(0xFF880E4F),
    tier: CharIconTier.pack,
    description: '恐怖の鬼神',
  ),
  CharacterIcon(
    id: 'sennin',
    name: '仙人',
    emoji: '🧙',
    bgColor: Color(0xFF00695C),
    tier: CharIconTier.pack,
    description: '不老不死の仙人',
  ),
];

/// IDからキャラクターを取得
CharacterIcon? findCharacterById(String id) {
  try {
    return allCharacterIcons.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

/// キャラクターアイコンを表示するウィジェット
class CharIconWidget extends StatelessWidget {
  final CharacterIcon? icon;
  final double size;
  final bool locked;

  const CharIconWidget({
    super.key,
    required this.icon,
    this.size = 36,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.blueGrey.shade800,
        child: Icon(Icons.person, color: Colors.white54, size: size * 0.55),
      );
    }
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: icon!.bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: locked ? Colors.white12 : Colors.white30,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              icon!.imagePath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  icon!.emoji,
                  style: TextStyle(fontSize: size * 0.48),
                ),
              ),
            ),
          ),
        ),
        if (locked)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.lock, color: Colors.white70, size: size * 0.38),
              ),
            ),
          ),
      ],
    );
  }
}
