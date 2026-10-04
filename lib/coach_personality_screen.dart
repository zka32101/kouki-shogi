import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ai_service.dart';
import 'services/kifu_analytics_service.dart';

/// AI棋風コーチ - AI Personality Coach Screen
/// Premium feature that analyzes play style and provides personalized coaching
class CoachPersonalityScreen extends StatefulWidget {
  final String gameHistory; // JSON or serialized game history
  final VoidCallback? onAdvancedTechniqueUnlocked;

  const CoachPersonalityScreen({
    Key? key,
    this.gameHistory = '',
    this.onAdvancedTechniqueUnlocked,
  }) : super(key: key);

  @override
  State<CoachPersonalityScreen> createState() => _CoachPersonalityScreenState();
}

class _CoachPersonalityScreenState extends State<CoachPersonalityScreen>
    with TickerProviderStateMixin {
  int _coachRelationshipLevel = 0;
  String _coachPersonality = '未定型'; // Not yet determined
  late SharedPreferences _prefs;
  bool _isLoading = true;
  late AnimationController _avatarAnimController;
  late AnimationController _feedbackAnimController;

  // Coach personality data
  static const Map<String, CoachPersonalityData> _personalityDatabase = {
    '熱血型': CoachPersonalityData(
      name: '熱血型',
      emoji: '🔥',
      description: '攻撃的で積極的なプレイスタイルを得意とするコーチ',
      feedbackMessages: [
        'その手、思い切りがいい！もっと攻めろ！',
        '勇敢なプレイだ！自信を持って前に出ろ！',
        '相手の隙をついた素晴らしい一手だ！',
        'その積極性、気に入ったぞ！',
        'もっと大胆に行け！恐れるな！',
      ],
    ),
    '冷静型': CoachPersonalityData(
      name: '冷静型',
      emoji: '❄️',
      description: '正確で堅実なプレイスタイルを重視するコーチ',
      feedbackMessages: [
        'その手は正確です。しかし相手の反撃を考慮しましたか？',
        '堅実な判断ですね。計算が甘くないか確認してください。',
        '慎重ですが、チャンスを逃していないでしょうか？',
        '正確性は素晴らしい。次は深さを求めます。',
        '感情に左右されない、素晴らしいプレイです。',
      ],
    ),
    '戦術家': CoachPersonalityData(
      name: '戦術家',
      emoji: '♟️',
      description: 'パターンと定跡に強い知識派コーチ',
      feedbackMessages: [
        '典型的な美濃崩しですね。パターン習得を勧めます。',
        'その組み合わせ、標準定跡を外れていますね。',
        'パターン認識が必要です。形の習得をお勧めします。',
        '創意的な手ですが、古典的な手法を知っていますか？',
        '理論的に素晴らしい展開ですね。',
      ],
    ),
    'バランス型': CoachPersonalityData(
      name: 'バランス型',
      emoji: '⚖️',
      description: '全方位対応の柔軟なコーチ',
      feedbackMessages: [
        'バランスの取れたプレイですね。',
        'その判断、とても実戦的です。',
        '状況に応じた適切な判断ですね。',
        '総合的に見て、良いプレイです。',
        'すべての要素が調和した良い一手ですね。',
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _avatarAnimController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _feedbackAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initializeCoachData();
  }

  @override
  void dispose() {
    _avatarAnimController.dispose();
    _feedbackAnimController.dispose();
    super.dispose();
  }

  // レベルLに到達するために必要な累計対局数（レベルが上がるごとに必要局数も増える：
  // Lv1=10局, Lv2はさらに20局(累計30局), Lv3はさらに30局(累計60局)...）
  static int _gamesRequiredForLevel(int level) => 5 * level * (level + 1);

  static int _levelForGames(int games) {
    int level = 0;
    while (level < 20 && games >= _gamesRequiredForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  int _totalGamesPlayed = 0;

  Future<void> _initializeCoachData() async {
    _prefs = await SharedPreferences.getInstance();
    final totalGames = _prefs.getInt('stats_total') ?? 0;
    setState(() {
      _totalGamesPlayed = totalGames;
      _coachRelationshipLevel = _levelForGames(totalGames);
      _coachPersonality =
          _prefs.getString('coach_personality') ?? _analyzePlayStyle();
      _isLoading = false;
    });
    _savePersistence();
  }

  // 棋風診断画面（playstyle_diagnosis_screen.dart）が集計している実際の指し手データ
  // （攻め/引き/打ちの比率）から判定する。判定基準もその画面と揃え、
  // アプリ内で棋風の判定結果が食い違わないようにしている。
  String _analyzePlayStyle() {
    final attack = _prefs.getInt('playstyle_attack') ?? 0;
    final retreat = _prefs.getInt('playstyle_retreat') ?? 0;
    final drop = _prefs.getInt('playstyle_drop') ?? 0;
    final total = _prefs.getInt('playstyle_total') ?? 0;
    if (total == 0) return 'バランス型';

    final attackRatio = attack / total;
    final retreatRatio = retreat / total;
    final dropRatio = drop / total;

    if (attackRatio > 0.38) return '熱血型';
    if (retreatRatio > 0.32) return '冷静型';
    if (dropRatio > 0.22) return '戦術家';
    return 'バランス型';
  }

  Future<void> _savePersistence() async {
    await _prefs.setString('coach_personality', _coachPersonality);
  }

  Future<void> _simulateGameFeedback() async {
    final personalityData = _personalityDatabase[_coachPersonality];
    if (personalityData == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 直近の実際の対局分析（KifuAnalyticsService）を渡し、Claude による
    // 本物のコーチフィードバックを取得する。対局データがない・API呼び出しに
    // 失敗した場合はキャラクター別の定型文にフォールバックする。
    String feedback;
    try {
      final analyses = await KifuAnalyticsService().getAllAnalyses();
      if (analyses.isEmpty) {
        feedback = _fallbackFeedback(personalityData);
      } else {
        final latest = analyses.first;
        final gameResult = latest.playerWon
            ? '勝ち（${latest.movesCount}手、悪手${latest.blunders.length}回）'
            : '負け（${latest.movesCount}手、悪手${latest.blunders.length}回）';
        feedback = await AIService.generateCoachFeedback(
          gameResult,
          _coachPersonality,
        );
      }
    } catch (_) {
      feedback = _fallbackFeedback(personalityData);
    }

    if (!mounted) return;
    Navigator.pop(context); // ローディングダイアログを閉じる

    // レベルは実際の対局数からのみ決まる（このボタンでは上がらない）
    _showFeedbackPopup(feedback, personalityData.emoji);
  }

  String _fallbackFeedback(CoachPersonalityData personalityData) {
    final feedbackIndex =
        DateTime.now().microsecond % personalityData.feedbackMessages.length;
    return personalityData.feedbackMessages[feedbackIndex];
  }

  void _showFeedbackPopup(String feedback, String emoji) {
    _feedbackAnimController.reset();
    _feedbackAnimController.forward();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ScaleTransition(
        scale: _feedbackAnimController.drive(
          Tween<double>(begin: 0.5, end: 1.0).chain(
            CurveTween(curve: Curves.elasticOut),
          ),
        ),
        child: AlertDialog(
          backgroundColor: Colors.amber[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.amber[300]!, width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                feedback,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '関係度 +1 → Lv.$_coachRelationshipLevel',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.amber[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('了解'),
            ),
          ],
        ),
      ),
    );
  }

  void _unlockAdvancedTechniques() {
    if (_coachRelationshipLevel < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'コーチ関係度 Lv.10 以上で奥義が解放されます',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎖️ 奥義習得'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getAdvancedTechniqueByPersonality(_coachPersonality),
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⭐ この奥義はコーチの特殊スキルです。\n'
                '対局で活用してさらに関係度を高めましょう！',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onAdvancedTechniqueUnlocked?.call();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('奥義を習得しました！'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('習得'),
          ),
        ],
      ),
    );
  }

  String _getAdvancedTechniqueByPersonality(String personality) {
    switch (personality) {
      case '熱血型':
        return '【 飛車先の鬼手 】\n'
            '飛車先の歩を伸ばすタイミングを極め、相手の隙をついた鋭い攻撃を繰り出す。\n'
            'リスクを恐れない攻撃的なプレイ。';
      case '冷静型':
        return '【 完全計算術 】\n'
            '10手先までの全ての変化を脳内で計算し、最適な一手を導き出す。\n'
            '感情に左右されない究極の冷徹性。';
      case '戦術家':
        return '【 定跡破壊 】\n'
            '定跡の本質を理解した上で、新しい手を創出する。\n'
            '古い知識に縛られない柔軟な思考。';
      case 'バランス型':
        return '【 万能手 】\n'
            '攻防のバランスを完璧に保ちながら、全ての局面に対応する。\n'
            '最高の汎用性と安定性。';
      default:
        return '奥義の詳細は不明です。';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI棋風コーチ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final personalityData = _personalityDatabase[_coachPersonality];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI棋風コーチ'),
        elevation: 0,
        backgroundColor: Colors.amber[100],
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with coach avatar
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber[50]!, Colors.amber[100]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  // Coach Avatar
                  ScaleTransition(
                    scale: _avatarAnimController.drive(
                      Tween<double>(begin: 0.95, end: 1.05),
                    ),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.amber[300]!, Colors.orange[400]!],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          personalityData?.emoji ?? '🤖',
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Coach Personality Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber[400]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          personalityData?.name ?? '未定型',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          personalityData?.description ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Relationship Level Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'コーチとの関係度',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Relationship Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Lv. $_coachRelationshipLevel',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              '${_coachRelationshipLevel}/20',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Heart Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _coachRelationshipLevel / 20,
                            minHeight: 24,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red[400]!,
                            ),
                            semanticsLabel: 'Relationship level',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Heart icons
                        Wrap(
                          spacing: 4,
                          children: List.generate(
                            _coachRelationshipLevel,
                            (index) => const Text(
                              '♥',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_coachRelationshipLevel < 20)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '次のレベルまで: あと'
                              '${_gamesRequiredForLevel(_coachRelationshipLevel + 1) - _totalGamesPlayed}局'
                              '（対局してレベルアップ）',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Milestone Badges
                  _buildMilestoneBadges(),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Game Feedback Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _simulateGameFeedback,
                      icon: const Icon(Icons.gamepad),
                      label: const Text('コーチのアドバイスを見る'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Unlock Advanced Technique Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _unlockAdvancedTechniques,
                      icon: const Icon(Icons.stars),
                      label: const Text('奥義習得'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor:
                            _coachRelationshipLevel >= 10
                                ? Colors.purple[400]
                                : Colors.grey[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info Card
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        const Text(
                          'プレミアム機能',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'コーチはあなたの棋風を分析し、'
                      'パーソナライズされたフィードバックを提供します。\n'
                      '対局後のフィードバックでコーチとの関係度を上げ、'
                      'Lv.10で奥義を習得できます。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'マイルストーン',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMilestoneBadge('Lv. 5', 'コーチの信頼', 5),
            _buildMilestoneBadge('Lv. 10', '奥義習得', 10),
            _buildMilestoneBadge('Lv. 15', 'マスター', 15),
            _buildMilestoneBadge('Lv. 20', '究極', 20),
          ],
        ),
      ],
    );
  }

  Widget _buildMilestoneBadge(String label, String title, int requiredLevel) {
    final isUnlocked = _coachRelationshipLevel >= requiredLevel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.amber[200] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnlocked ? Colors.amber[400]! : Colors.grey[400]!,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUnlocked ? '✓' : '🔒',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.amber[900] : Colors.grey[600],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: isUnlocked ? Colors.amber[800] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for coach personality information
class CoachPersonalityData {
  final String name;
  final String emoji;
  final String description;
  final List<String> feedbackMessages;

  const CoachPersonalityData({
    required this.name,
    required this.emoji,
    required this.description,
    required this.feedbackMessages,
  });
}
