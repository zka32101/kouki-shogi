// lib/services/rating_service.dart
// ELO レーティング計算エンジン

class RatingService {
  static final RatingService _instance = RatingService._internal();

  factory RatingService() {
    return _instance;
  }

  RatingService._internal();

  // ELO定数
  static const int kFactor = 32; // 標準K値
  static const int kFactorNewUser = 48; // 新規ユーザー（50試合未満）用K値

  /// 対局結果からレーティング変動を計算
  /// [player1Rating] 先手のレーティング
  /// [player2Rating] 後手のレーティング
  /// [player1Won] 先手が勝利したか
  /// [player1Games] 先手の試合数（新規判定用）
  /// [player2Games] 後手の試合数（新規判定用）
  ///
  /// 返値: {'player1': 変動量, 'player2': 変動量}
  Map<String, int> calculateRatingChange({
    required int player1Rating,
    required int player2Rating,
    required bool player1Won,
    required int player1Games,
    required int player2Games,
  }) {
    // 新規ユーザーかどうかを判定（50試合未満）
    final k1 = player1Games < 50 ? kFactorNewUser : kFactor;
    final k2 = player2Games < 50 ? kFactorNewUser : kFactor;

    // 期待勝率を計算
    final expectedPlayer1 = _calculateExpected(player1Rating, player2Rating);
    final expectedPlayer2 = 1.0 - expectedPlayer1;

    // 実際のスコア（勝=1.0、負=0.0）
    final score1 = player1Won ? 1.0 : 0.0;
    final score2 = player1Won ? 0.0 : 1.0;

    // レーティング変動を計算
    final change1 = (k1 * (score1 - expectedPlayer1)).round();
    final change2 = (k2 * (score2 - expectedPlayer2)).round();

    return {
      'player1': change1,
      'player2': change2,
    };
  }

  /// 期待勝率を計算（Elo Formula）
  /// rating差が200の場合、高い方の期待勝率は約0.76
  double _calculateExpected(int rating1, int rating2) {
    final ratingDiff = rating2 - rating1;
    return 1.0 / (1.0 + Math.pow(10, ratingDiff / 400.0));
  }

  /// ユーザーのランキング順位を計算
  /// [userRating] ユーザーのレーティング
  /// [allRatings] 全ユーザーのレーティング
  int calculateRank(int userRating, List<int> allRatings) {
    return allRatings.where((r) => r > userRating).length + 1;
  }

  /// レーティングからランク表示を取得
  String getRankLabel(int rating) {
    if (rating >= 2800) return '9段';
    if (rating >= 2600) return '8段';
    if (rating >= 2400) return '7段';
    if (rating >= 2200) return '6段';
    if (rating >= 2000) return '5段';
    if (rating >= 1800) return '4段';
    if (rating >= 1600) return '3段';
    if (rating >= 1400) return '2段';
    if (rating >= 1200) return '1段';
    if (rating >= 1000) return '初段';
    if (rating >= 800) return '1級';
    if (rating >= 600) return '2級';
    if (rating >= 400) return '3級';
    if (rating >= 200) return '4級';
    return '5級以下';
  }
}

class Math {
  static double pow(double base, double exponent) {
    return base == 0 ? 0 : _pow(base, exponent);
  }

  static double _pow(double base, double exponent) {
    var result = 1.0;
    while (exponent > 0) {
      if (exponent % 2 == 1) {
        result *= base;
      }
      base *= base;
      exponent = (exponent / 2).floorToDouble();
    }
    return result;
  }
}
