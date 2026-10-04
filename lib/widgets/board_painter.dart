// lib/widgets/board_painter.dart
// 将棋盤のグリッド・星・木目テクスチャを描く CustomPainter

import 'dart:math' as math;
import 'package:flutter/material.dart';

class BoardPainter extends CustomPainter {
  final Color cellColor;
  final Color borderColor;
  final Color starColor;
  final bool textured;
  final Color? gradientTop;
  final Color? gradientBottom;
  final double? advantageRatio;

  const BoardPainter({
    required this.cellColor,
    required this.borderColor,
    this.starColor = const Color(0xDD000000),
    this.textured = false,
    this.gradientTop,
    this.gradientBottom,
    this.advantageRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. 有利度オーバーレイ ──────────────────────────────────────────────
    if (advantageRatio != null && advantageRatio != 0.5) {
      final Color advantageColor;
      if (advantageRatio! > 0.5) {
        final blend = ((advantageRatio! - 0.5) * 2).clamp(0.0, 1.0);
        advantageColor = Color.lerp(
            Colors.transparent, Colors.blue.shade900.withAlpha(40), blend)!;
      } else {
        final blend = ((0.5 - advantageRatio!) * 2).clamp(0.0, 1.0);
        advantageColor = Color.lerp(
            Colors.transparent, Colors.red.shade900.withAlpha(40), blend)!;
      }
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = advantageColor,
      );
    }

    // ── 2. ベース塗り（木目グラデーション） ──────────────────────────────
    if (textured && gradientTop != null && gradientBottom != null) {
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop!, gradientBottom!],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);
    }

    // ── 3. 木目縞（疑似木目）─ 水平の微細な縞模様 ────────────────────────
    _drawWoodGrain(canvas, size);

    // ── 4. 内側ハイライト（盤の上端に白光沢） ────────────────────────────
    final topHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withAlpha(38), Colors.white.withAlpha(0)],
        stops: const [0.0, 0.25],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.25), topHighlight);

    // 注意: グリッド線・星（ほし）はここでは描かない。
    // マス目は不透明な背景色を持つ Container で1マスずつ描画されるため、
    // ここで描いても真上から塗りつぶされて見えなくなる。
    // 実際の描画は GridOverlayPainter（マスの上に重ねる）が担当する。
  }

  void _drawWoodGrain(Canvas canvas, Size size) {
    // シードベースで固定パターン（描画ごとにぶれない）
    final rng = math.Random(42);
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    // 水平の木目線を約18本描く
    final lineCount = 18;
    final baseSpacing = size.height / lineCount;
    var yPos = baseSpacing * 0.3;

    for (int i = 0; i < lineCount; i++) {
      final alpha = 8 + rng.nextInt(14); // 8〜21
      grainPaint.color = Color.fromARGB(
        alpha,
        0x3E, 0x27, 0x23, // 濃い焦茶
      );
      grainPaint.strokeWidth = 0.4 + rng.nextDouble() * 0.8;

      // 微妙なウェーブ（y方向に±2px）
      final path = Path();
      const segments = 9;
      path.moveTo(0, yPos);
      for (int s = 1; s <= segments; s++) {
        final xPrev = size.width * (s - 1) / segments;
        final xCurr = size.width * s / segments;
        final waveY = yPos + math.sin(s * 1.3 + i * 0.7) * 1.8;
        path.quadraticBezierTo(
          xPrev + (xCurr - xPrev) * 0.5,
          yPos + math.sin((s - 0.5) * 1.3 + i * 0.7) * 1.5,
          xCurr,
          waveY,
        );
      }
      canvas.drawPath(path, grainPaint);
      yPos += baseSpacing * (0.7 + rng.nextDouble() * 0.6);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) {
    return old.cellColor != cellColor ||
        old.borderColor != borderColor ||
        old.starColor != starColor ||
        old.textured != textured ||
        old.advantageRatio != advantageRatio ||
        old.gradientTop != gradientTop ||
        old.gradientBottom != gradientBottom;
  }

  @override
  bool shouldRebuildSemantics(covariant BoardPainter oldDelegate) => false;
}

/// グリッド線と星（ほし）だけを描く軽量painter。
/// マス目（1マスごとの不透明な色付きContainer）の「上」に重ねて使うこと。
/// BoardPainter は背景（木目・グラデーション）用で、マスの下に敷くと
/// グリッド線がマスの塗りつぶしで隠れてしまうため、線はこちらに分離している。
class GridOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color starColor;
  final Color? outerBorderColor; // 未指定なら borderColor を使う
  final double outerBorderWidth;

  const GridOverlayPainter({
    required this.borderColor,
    this.starColor = const Color(0xDD000000),
    this.outerBorderColor,
    this.outerBorderWidth = 1.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 9;
    final cellH = size.height / 9;

    // 内線
    final innerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.6;
    for (int i = 1; i < 9; i++) {
      canvas.drawLine(
          Offset(i * cellW, 0), Offset(i * cellW, size.height), innerPaint);
      canvas.drawLine(
          Offset(0, i * cellH), Offset(size.width, i * cellH), innerPaint);
    }

    // 外周線（太め・盤の縁は内線と別の明るい色で強調できる）
    final outerPaint = Paint()
      ..color = outerBorderColor ?? borderColor
      ..strokeWidth = outerBorderWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), outerPaint);
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), outerPaint);
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), outerPaint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, size.height), outerPaint);

    // 星（ほし）
    final starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill;
    final hoshiRadius = cellW * 0.11;
    const hoshiPositions = [(3, 3), (3, 6), (6, 3), (6, 6)];
    for (final (row, col) in hoshiPositions) {
      final x = col * cellW;
      final y = row * cellH;
      canvas.drawCircle(
        Offset(x - 0.6, y - 0.6),
        hoshiRadius * 0.5,
        Paint()..color = Colors.white.withAlpha(70)..style = PaintingStyle.fill,
      );
      canvas.drawCircle(Offset(x, y), hoshiRadius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridOverlayPainter old) =>
      old.borderColor != borderColor ||
      old.starColor != starColor ||
      old.outerBorderColor != outerBorderColor ||
      old.outerBorderWidth != outerBorderWidth;

  @override
  bool shouldRebuildSemantics(covariant GridOverlayPainter oldDelegate) =>
      false;
}
