// lib/board_image_exporter_web.dart — 盤面PNG画像エクスポート (Flutter Web専用)
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'piece.dart';

/// canvas を使って盤面を描画し PNG としてダウンロードする
void exportBoardImage({
  required List<List<Piece?>> board,
  required Map<PieceType, int> p1Hand,
  required Map<PieceType, int> p2Hand,
  String filename = 'shogi_board.png',
}) {
  const int cellPx = 56;
  const int pad    = 12;
  const int handH  = 40;
  const int boardPx = cellPx * 9;
  const int width   = boardPx + pad * 2;
  const int height  = boardPx + pad * 2 + handH * 2;

  final canvas = html.CanvasElement(width: width, height: height);
  final ctx = canvas.context2D;

  // ── 背景 ──
  ctx.fillStyle = '#1A1A2E';
  ctx.fillRect(0, 0, width, height);

  // ── 後手持ち駒（上） ──
  ctx.fillStyle = '#FFFFFF99';
  ctx.font = '13px sans-serif';
  ctx.textBaseline = 'middle';
  final p2HandStr = _handStr(p2Hand, false);
  ctx.fillText('△持駒: $p2HandStr', pad, pad + handH / 2);

  // ── 盤面外枠 ──
  final boardX = pad;
  final boardY = pad + handH;
  ctx.fillStyle = '#DCB36B';
  ctx.fillRect(boardX, boardY, boardPx, boardPx);

  // ── グリッド線 ──
  ctx.strokeStyle = '#5C3A1E';
  ctx.lineWidth = 0.8;
  for (int i = 0; i <= 9; i++) {
    final x = boardX + i * cellPx;
    ctx.beginPath();
    ctx.moveTo(x, boardY);
    ctx.lineTo(x, boardY + boardPx);
    ctx.stroke();
    final y = boardY + i * cellPx;
    ctx.beginPath();
    ctx.moveTo(boardX, y);
    ctx.lineTo(boardX + boardPx, y);
    ctx.stroke();
  }

  // ── 駒 ──
  ctx.textAlign = 'center';
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final piece = board[r][c];
      if (piece == null) continue;
      final cx = boardX + c * cellPx + cellPx / 2;
      final cy = boardY + r * cellPx + cellPx / 2;

      // 駒背景
      ctx.fillStyle = '#F5DEB3';
      ctx.fillRect(cx - cellPx * 0.4, cy - cellPx * 0.46,
          cellPx * 0.8, cellPx * 0.92);

      // 後手は回転（180度）
      if (!piece.isPlayer1) {
        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(3.14159);
        ctx.translate(-cx, -cy);
      }

      ctx.font = 'bold ${cellPx * 0.55}px serif';
      ctx.fillStyle = piece.isPromoted
          ? '#CC0000'
          : (piece.isPlayer1 ? '#1A0A00' : '#8B0000');
      ctx.fillText(piece.label, cx, cy);

      if (!piece.isPlayer1) ctx.restore();
    }
  }

  // ── 先手持ち駒（下） ──
  ctx.font = '13px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillStyle = '#FFFFFF99';
  final p1HandStr = _handStr(p1Hand, true);
  ctx.fillText('▲持駒: $p1HandStr', pad, boardY + boardPx + handH / 2);

  // ── ダウンロード ──
  final dataUrl = canvas.toDataUrl('image/png');
  final anchor = html.AnchorElement(href: dataUrl)
    ..setAttribute('download', filename)
    ..click();
}

String _handStr(Map<PieceType, int> hand, bool isP1) {
  if (hand.isEmpty) return 'なし';
  return hand.entries
      .map((e) => '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}')
      .join('  ');
}
