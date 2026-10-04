// lib/theme_config.dart — 盤面テーマ設定

import 'package:flutter/material.dart';
import 'game_screen.dart';

class BoardThemeConfig {
  final String label;
  final Color background;
  final Color cell;
  final Color cellBorder;
  final Color boardBorder;
  final Color pieceNormal;
  final Color pieceP2;
  final Color starPoint;
  final Color? gradientTop;
  final Color? gradientBottom;

  const BoardThemeConfig({
    required this.label,
    required this.background,
    required this.cell,
    required this.cellBorder,
    required this.boardBorder,
    required this.pieceNormal,
    required this.pieceP2,
    required this.starPoint,
    this.gradientTop,
    this.gradientBottom,
  });
}

BoardThemeConfig boardThemeConfig(PieceTheme theme) {
  switch (theme) {
    case PieceTheme.standard:
      return BoardThemeConfig(
        label: '標準',
        background: const Color(0xFF16213E),
        cell: const Color(0xFFDEB887),
        cellBorder: Colors.brown.shade600,
        boardBorder: Colors.brown.shade700,
        pieceNormal: Colors.black87,
        pieceP2: Colors.black87,
        starPoint: Colors.black,
      );
    case PieceTheme.dark:
      return BoardThemeConfig(
        label: 'ダーク',
        background: const Color(0xFF0F1729),
        cell: const Color(0xFF6B5310),
        cellBorder: const Color(0xFF3D2F0A),
        boardBorder: const Color(0xFF2A2208),
        pieceNormal: Colors.white,
        pieceP2: Colors.white,
        starPoint: Colors.white70,
      );
    case PieceTheme.textured:
      return BoardThemeConfig(
        label: '質感',
        background: const Color(0xFF1A1410),
        cell: const Color(0xD4AF87),
        cellBorder: const Color(0x8D6E63),
        boardBorder: const Color(0x5C4033),
        pieceNormal: Colors.black87,
        pieceP2: Colors.black87,
        starPoint: Colors.black,
        gradientTop: const Color(0x3E2723),
        gradientBottom: const Color(0x5D4037),
      );
    case PieceTheme.emerald:
      return BoardThemeConfig(
        label: 'エメラルド',
        background: const Color(0xFF0F2A1F),
        cell: const Color(0xFF4A9B7F),
        cellBorder: const Color(0xFF2D6B5B),
        boardBorder: const Color(0xFF1A4D3E),
        pieceNormal: Colors.white,
        pieceP2: Colors.white,
        starPoint: Colors.white70,
      );
    case PieceTheme.cherry:
      return BoardThemeConfig(
        label: '桜',
        background: const Color(0xFF2A1F2E),
        cell: const Color(0xFFE8A4C4),
        cellBorder: const Color(0xFFC87BA8),
        boardBorder: const Color(0xFF8B5A7D),
        pieceNormal: Colors.white,
        pieceP2: Colors.white,
        starPoint: Colors.white70,
      );
  }
}
