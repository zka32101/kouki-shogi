// lib/yaneuraou_service_stub.dart — モバイル/デスクトップ用スタブ（YaneuraOu非対応）

import 'dart:async';
import 'piece.dart';

/// モバイルプラットフォームでは YaneuraOu WASM は使用不可
class YaneuraouService {
  YaneuraouService._();

  static Future<bool> initialize() async => false;

  static Future<String?> getBestMove({
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required bool p1Turn,
    int byoyomi = 3000,
  }) async => null;

  static String boardToSfen(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool p1Turn,
  ) => '';

  static AMove? usiToAMove(String usi) => null;

  static void dispose() {}
}
