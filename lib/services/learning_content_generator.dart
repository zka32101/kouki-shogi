// lib/services/learning_content_generator.dart
//
// 対局データ（悪手・好手の駒種別集計）から、プレイヤー個人に合わせた
// 学習アドバイスを自動生成するサービス。
//
// 外部LLM APIには依存せず、自分の対局履歴（GameAnalysis）を集計し、
// 駒種ごとに用意した将棋知識テンプレートと組み合わせることで
// 「あなたはこの駒の扱いでよく悪手を指している」という
// パーソナライズされた学習コンテンツを都度生成する。

import '../models/game_analysis.dart';
import 'kifu_analytics_service.dart';

class GeneratedLesson {
  final String piece;
  final String title;
  final String summary;
  final String adviceText;
  final String drillSuggestion;
  final int priority;
  final int occurrenceCount;
  final double avgDelta;

  GeneratedLesson({
    required this.piece,
    required this.title,
    required this.summary,
    required this.adviceText,
    required this.drillSuggestion,
    required this.priority,
    required this.occurrenceCount,
    required this.avgDelta,
  });

  String get severityLabel {
    if (avgDelta <= -200) return '重大';
    if (avgDelta <= -100) return '中程度';
    return '軽度';
  }
}

class LearningContentGenerator {
  static const int _analysisWindow = 30; // 直近何局を分析対象にするか

  static const Map<String, String> _pieceAdvice = {
    '歩': '歩の突き捨てや垂れ歩のタイミングを誤ると、後の攻めが続かなくなります。'
        '歩を突く前に、その歩が取られた後の展開まで読みましょう。',
    '香': '香車を安易に上げると、成り込まれたり質駒に取られたりするリスクがあります。'
        '香車を動かす前に相手の飛車・角の利きを確認しましょう。',
    '桂': '桂馬は一度跳ねると後戻りができません。'
        '跳ねる前に、その桂が相手の駒に当たられないか、成り込める見込みがあるかを確認しましょう。',
    '銀': '銀は攻めにも守りにも使える駒ですが、無理に繰り出すと只捨てになりがちです。'
        '銀交換が自分に有利かどうかを一手ずつ見極めましょう。',
    '金': '金を動かすと玉の守りが薄くなることがあります。'
        '金を動かす前に、玉の安全度が下がらないかチェックしましょう。',
    '角': '角は斜めの利きが強力な反面、位置によっては相手の駒に睨まれやすくなります。'
        '角道を止められていないか、当たられていないか確認してから動かしましょう。',
    '飛': '飛車先の歩を切った後、飛車が浮いた状態で放置すると質に取られることがあります。'
        '飛車の逃げ場・安全度を常に意識しましょう。',
    '玉': '玉の早逃げ・入城のタイミングが遅れると受けが利かなくなります。'
        '攻めを急ぐ前に玉の囲いを済ませることを優先しましょう。',
    '王': '玉の早逃げ・入城のタイミングが遅れると受けが利かなくなります。'
        '攻めを急ぐ前に玉の囲いを済ませることを優先しましょう。',
  };

  static String _normalizePiece(String raw) {
    for (final key in _pieceAdvice.keys) {
      if (raw.contains(key)) return key;
    }
    return raw.isEmpty ? '駒' : raw;
  }

  /// 対局履歴を分析し、優先度順のパーソナライズ学習レッスンを生成する。
  static Future<List<GeneratedLesson>> generatePersonalizedLessons({
    int maxLessons = 5,
  }) async {
    List<GameAnalysis> games;
    try {
      games = await KifuAnalyticsService().getAllAnalyses();
    } catch (_) {
      games = const [];
    }
    final recentGames = games.take(_analysisWindow).toList();

    if (recentGames.isEmpty) return [];

    final blunderDeltasByPiece = <String, List<int>>{};
    final goodCountByPiece = <String, int>{};

    for (final g in recentGames) {
      for (final b in g.blunders) {
        final piece = _normalizePiece(b.pieceMoved);
        blunderDeltasByPiece.putIfAbsent(piece, () => []).add(b.evalDelta);
      }
      for (final gm in g.goodMoves) {
        final piece = _normalizePiece(gm.pieceMoved);
        goodCountByPiece[piece] = (goodCountByPiece[piece] ?? 0) + 1;
      }
    }

    if (blunderDeltasByPiece.isEmpty) return [];

    final lessons = <GeneratedLesson>[];

    for (final entry in blunderDeltasByPiece.entries) {
      final piece = entry.key;
      final deltas = entry.value;
      final count = deltas.length;
      final avgDelta = deltas.reduce((a, b) => a + b) / count;
      final goodCount = goodCountByPiece[piece] ?? 0;

      final advice = _pieceAdvice[piece] ??
          '$piece の扱いに注意が必要です。局面をよく読んでから指しましょう。';

      final summary = '直近${recentGames.length}局中、「$piece」を動かした手で$count回悪手'
          '（平均評価値Δ${avgDelta.toStringAsFixed(0)}）が発生しています。'
          '${goodCount > 0 ? 'この駒での好手も$goodCount回あります。' : ''}';

      lessons.add(GeneratedLesson(
        piece: piece,
        title: '「$piece」の手が悪手になりやすい傾向',
        summary: summary,
        adviceText: advice,
        drillSuggestion: '次の対局では、$piece を動かす前に一呼吸置いて、'
            '相手の応手を1手先まで読んでから指してみましょう。',
        priority: count * (avgDelta <= -150 ? 2 : 1),
        occurrenceCount: count,
        avgDelta: avgDelta,
      ));
    }

    lessons.sort((a, b) => b.priority.compareTo(a.priority));
    return lessons.take(maxLessons).toList();
  }
}
