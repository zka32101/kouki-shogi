import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_analysis.dart';

class KifuAnalyticsService {
  static const String _analysisPrefix = 'game_analysis_';
  static const String _patternsKey = 'blunder_patterns_';

  Future<GameAnalysis> analyzeAndSaveGame({
    required List<int> evalHistory,
    required List<String> moveNotations,
    required bool playerWon,
    required String? openingName,
    required bool playerIsP1,
  }) async {
    final gameId = DateTime.now().millisecondsSinceEpoch.toString();

    final (blunders, goodMoves) = _extractMoveQualities(
      evalHistory,
      moveNotations,
      playerIsP1,
    );

    final analysis = GameAnalysis(
      id: gameId,
      playedAt: DateTime.now(),
      evalHistory: evalHistory,
      moveNotations: moveNotations,
      playerWon: playerWon,
      movesCount: moveNotations.length,
      blunders: blunders,
      goodMoves: goodMoves,
      openingName: openingName,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_analysisPrefix$gameId',
      jsonEncode(analysis.toJson()),
    );

    await _updateBlunderPatterns(blunders, gameId);

    return analysis;
  }

  (List<BlunderInfo>, List<GoodMoveInfo>) _extractMoveQualities(
    List<int> evalHistory,
    List<String> moveNotations,
    bool playerIsP1,
  ) {
    final blunders = <BlunderInfo>[];
    final goodMoves = <GoodMoveInfo>[];

    if (evalHistory.length < 2) return (blunders, goodMoves);

    for (int i = 1; i < evalHistory.length && i <= moveNotations.length; i++) {
      final delta = evalHistory[i] - evalHistory[i - 1];

      final moveIsP1 = (i % 2 == 1);
      final playerDelta = playerIsP1 == moveIsP1 ? delta : -delta;

      final notation = moveNotations[i - 1];
      final (fromSq, toSq, piece) = _parseNotation(notation);

      if (playerDelta <= -80) {
        blunders.add(BlunderInfo(
          moveNum: i,
          evalDelta: playerDelta,
          fromSquare: fromSq,
          toSquare: toSq,
          pieceMoved: piece,
          analyzedAt: DateTime.now(),
        ));
      }

      if (playerDelta >= 150) {
        goodMoves.add(GoodMoveInfo(
          moveNum: i,
          evalDelta: playerDelta,
          toSquare: toSq,
          pieceMoved: piece,
          analyzedAt: DateTime.now(),
        ));
      }
    }

    return (blunders, goodMoves);
  }

  (String?, String, String) _parseNotation(String notation) {
    if (notation.length < 2) return (null, '?', '?');

    if (notation.contains('打')) {
      final idx = notation.indexOf('打');
      final toSq = notation.substring(0, 2);
      final piece = idx > 2 ? notation.substring(2, idx) : '?';
      return ('', toSq, piece);
    }

    final toSq = notation.substring(0, 2);
    final rest = notation.length > 2 ? notation.substring(2) : '';
    final piece = rest.replaceAll('成', '').replaceAll('不成', '');

    return (null, toSq, piece.isEmpty ? '?' : piece);
  }

  Future<void> _updateBlunderPatterns(
    List<BlunderInfo> blunders,
    String gameId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    for (final blunder in blunders) {
      final patternKey = '${blunder.toSquare}_${blunder.pieceMoved}';
      final hash = md5.convert(utf8.encode(patternKey)).toString();

      final patternsJson = prefs.getString('$_patternsKey$hash') ?? '{}';
      final patternData = jsonDecode(patternsJson) as Map<String, dynamic>;

      late BlunderPattern pattern;
      try {
        pattern = BlunderPattern.fromJson(patternData);
      } catch (_) {
        pattern = BlunderPattern(
          boardHash: hash,
          occurrenceCount: 0,
          mistakes: [],
          lastOccurred: DateTime.now(),
        );
      }

      final updated = BlunderPattern(
        boardHash: hash,
        occurrenceCount: pattern.occurrenceCount + 1,
        mistakes: [
          ...pattern.mistakes,
          blunder.toSquare,
        ],
        lastOccurred: DateTime.now(),
      );

      await prefs.setString(
        '$_patternsKey$hash',
        jsonEncode(updated.toJson()),
      );
    }
  }

  Future<List<GameAnalysis>> getAllAnalyses() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_analysisPrefix));

    final analyses = <GameAnalysis>[];
    for (final key in keys) {
      final json = prefs.getString(key);
      if (json != null) {
        try {
          analyses.add(
            GameAnalysis.fromJson(jsonDecode(json) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
    }

    analyses.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return analyses;
  }

  Future<GameAnalysis?> getAnalysis(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_analysisPrefix$gameId');
    if (json == null) return null;

    try {
      return GameAnalysis.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<BlunderPattern>> getRepeatedBlunders({int topN = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_patternsKey));

    final patterns = <BlunderPattern>[];
    for (final key in keys) {
      final json = prefs.getString(key);
      if (json != null) {
        try {
          patterns.add(
            BlunderPattern.fromJson(jsonDecode(json) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
    }

    patterns.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
    return patterns.take(topN).toList();
  }
}
