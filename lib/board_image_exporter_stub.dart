// lib/board_image_exporter_stub.dart — モバイル/デスクトップ用スタブ（画像エクスポート非対応）
import 'piece.dart';

/// モバイルプラットフォームでは画像エクスポートは非対応
void exportBoardImage({
  required List<List<Piece?>> board,
  required Map<PieceType, int> p1Hand,
  required Map<PieceType, int> p2Hand,
  String filename = 'shogi_board.png',
}) {
  // No-op on non-web platforms
}
