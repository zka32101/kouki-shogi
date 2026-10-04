// lib/widgets/menu_tile.dart
// ホーム画面などで使うメニュータイル。アイコン+ラベル+左カテゴリ色帯。

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// カテゴリ色の縦帯を左端に持つ、アイコン+ラベルのタップ可能カード。
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color categoryColor;
  final VoidCallback? onTap;
  final String? badge; // 右上の小バッジ（例: "NEW"）

  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.categoryColor,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rCard),
            border: Border(
              left: BorderSide(color: categoryColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.s3, vertical: AppTheme.s3),
          child: Stack(
            children: [
              Row(
                children: [
                  Icon(icon, color: categoryColor, size: 24),
                  const SizedBox(width: AppTheme.s3),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(AppTheme.rChip),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 統一スタイルのカード（surface色+角丸+影）。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: padding ?? const EdgeInsets.all(AppTheme.s4),
      child: child,
    );
  }
}
