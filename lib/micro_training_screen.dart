import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mini_board_widget.dart';
import 'piece.dart';
import 'study_calendar_screen.dart';
import 'theme/app_theme.dart';

class MicroTrainingScreen extends StatefulWidget {
  const MicroTrainingScreen({Key? key}) : super(key: key);

  @override
  State<MicroTrainingScreen> createState() => _MicroTrainingScreenState();
}

class _MicroTrainingScreenState extends State<MicroTrainingScreen>
    with WidgetsBindingObserver {
  // Problem data structure
  late List<MicroTrainingProblem> todayProblems;
  int currentProblemIndex = 0;

  // Timer
  late Timer _timer;
  int _secondsRemaining = 180; // 3 minutes
  bool _timerRunning = false;
  DateTime _sessionStartTime = DateTime.now();

  // Results
  int _correctCount = 0;
  int _skippedCount = 0;
  List<bool> _problemResults = []; // true = correct, false = incorrect/skipped
  bool _sessionCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTodayProblems();
    _startTimer();
  }

  void _initializeTodayProblems() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Generate 3 problems (rotate daily based on date hash)
    todayProblems = _generateDailyProblems(today);
    _problemResults = List.filled(3, false);
  }

  List<MicroTrainingProblem> _generateDailyProblems(String dateStr) {
    // 検証済みの問題プール（盤面・選択肢・正解が連動）から日替わりで3問選ぶ
    final allProblems = _buildMicroProblems();
    final dateHash = dateStr.hashCode.abs();
    final startIndex = dateHash % allProblems.length;
    return [
      allProblems[startIndex % allProblems.length],
      allProblems[(startIndex + 1) % allProblems.length],
      allProblems[(startIndex + 2) % allProblems.length],
    ];
  }

  void _startTimer() {
    _timerRunning = true;
    _sessionStartTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _completeSession();
          _timer.cancel();
        }
      });
    });
  }

  void _answerProblem(int choiceIndex) {
    final problem = todayProblems[currentProblemIndex];
    final isCorrect = choiceIndex == problem.correctAnswerIndex;

    _problemResults[currentProblemIndex] = isCorrect;
    if (isCorrect) {
      _correctCount++;
      _showFeedback(true, problem.explanation);
    } else {
      _showFeedback(false, problem.explanation);
    }

    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      _moveToNextProblem();
    });
  }

  void _skipProblem() {
    _skippedCount++;
    _problemResults[currentProblemIndex] = false;
    _moveToNextProblem();
  }

  void _moveToNextProblem() {
    setState(() {
      if (currentProblemIndex < 2) {
        currentProblemIndex++;
      } else {
        _completeSession();
      }
    });
  }

  void _completeSession() {
    _timer.cancel();
    _timerRunning = false;
    _sessionCompleted = true;

    // Save to SharedPreferences
    _saveMicroTrainingResult();
    // 3手詰め相当の手筋ドリルのため、学習カレンダーには「tesuji」として記録する
    StudyCalendarScreen.recordActivity('tesuji');

    setState(() {});
  }

  Future<void> _saveMicroTrainingResult() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = 'micro_training_today_$today';

    final result = {
      'date': today,
      'timestamp': DateTime.now().toIso8601String(),
      'correct_count': _correctCount,
      'skipped_count': _skippedCount,
      'time_spent_seconds': 180 - _secondsRemaining,
      'problem_results': _problemResults,
    };

    await prefs.setString(key, jsonEncode(result));
  }

  void _showFeedback(bool isCorrect, String explanation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? '✓ 正解！' : '✗ 不正解',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            SizedBox(height: 8),
            Text(
              explanation,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: isCorrect ? Colors.green[800] : Colors.red[800],
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _closeScreen() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCompleted) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          '3分筋トレ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber[400],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white70),
          onPressed: _closeScreen,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header: Problem counter + Timer
            _buildHeaderBar(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    _buildProblemTitle(),
                    SizedBox(height: 32),

                    // Placeholder board visualization
                    _buildBoardArea(),

                    SizedBox(height: 32),

                    // Problem type label
                    _buildProblemTypeLabel(),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Answer buttons
            _buildAnswerButtons(),

            // Skip button
            _buildSkipButton(),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      color: Color(0xFF1A1A1A),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Problem counter
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${currentProblemIndex + 1}/3',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber[400],
              ),
            ),
          ),

          // Timer with icon
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondsRemaining < 30
                  ? Color(0xFF4A2222)
                  : Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: _secondsRemaining < 30
                  ? Border.all(color: Colors.red[400]!, width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: _secondsRemaining < 30
                      ? Colors.red[400]
                      : AppTheme.accent,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  _formatTime(_secondsRemaining),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _secondsRemaining < 30
                        ? Colors.red[400]
                        : AppTheme.accent,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemTitle() {
    final problem = todayProblems[currentProblemIndex];
    return Text(
      problem.title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProblemTypeLabel() {
    final problem = todayProblems[currentProblemIndex];
    final typeLabel = _getProblemTypeLabel(problem.type);
    final typeColor = _getProblemTypeColor(problem.type);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.2),
        border: Border.all(color: typeColor, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        typeLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: typeColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  String _getProblemTypeLabel(String type) {
    switch (type) {
      case 'tsume':
        return '詰め問題';
      case 'tesuji':
        return '手筋問題';
      case 'next_move':
        return '次の一手';
      default:
        return '問題';
    }
  }

  Color _getProblemTypeColor(String type) {
    switch (type) {
      case 'tsume':
        return Colors.red[400]!;
      case 'tesuji':
        return Colors.orange[400]!;
      case 'next_move':
        return Colors.blue[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  Widget _buildBoardArea() {
    final problem = todayProblems[currentProblemIndex];
    return SizedBox(
      width: 280,
      child: MiniBoardWidget(
        board: problem.board,
        showLabels: true,
        size: 280,
      ),
    );
  }

  Widget _buildAnswerButtons() {
    final problem = todayProblems[currentProblemIndex];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < problem.choices.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _answerProblem(i),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2A3A4A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppTheme.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    problem.choices[i],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkipButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _skipProblem,
          icon: Icon(Icons.skip_next),
          label: Text('スキップ (-1点)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: BorderSide(color: Colors.white30, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final elapsedSeconds = 180 - _secondsRemaining;
    final totalScore = _correctCount;

    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          '結果',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber[400],
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 32),

                // Celebration icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0xFF2A3A4A),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.amber[400]!,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '🎯',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                ),

                SizedBox(height: 32),

                // Main message
                Text(
                  'おつかれさま！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 16),

                // Encouragement
                Text(
                  totalScore == 3
                      ? 'パーフェクト！見事です！'
                      : totalScore == 2
                          ? 'よくできました！'
                          : '頑張ってください！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                SizedBox(height: 48),

                // Results card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    border: Border.all(
                      color: Colors.amber[700]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildResultRow(
                        '正解数',
                        '$_correctCount/3',
                        Colors.greenAccent,
                      ),
                      Divider(
                        color: Colors.white10,
                        height: 24,
                      ),
                      _buildResultRow(
                        '所要時間',
                        _formatTime(elapsedSeconds),
                        AppTheme.accent,
                      ),
                      Divider(
                        color: Colors.white10,
                        height: 24,
                      ),
                      _buildResultRow(
                        'スキップ',
                        '$_skippedCount回',
                        Colors.orange[400]!,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 48),

                // Daily challenge message
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]?.withOpacity(0.3),
                    border: Border.all(
                      color: Colors.blue[400]!,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_repeat,
                        color: Colors.blue[400],
                        size: 28,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '明日もチャレンジしよう',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '毎日新しい問題をお届けします',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[200],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 48),

                // Main CTA
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _closeScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '明日もチャレンジ！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Secondary button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _closeScreen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white30, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'トップに戻る',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// Data model for micro training problems
class MicroTrainingProblem {
  final String type; // 'tsume', 'tesuji', 'next_move'
  final String title;
  final List<List<Piece?>> board; // 表示する実際の盤面（選択肢と連動）
  final List<String> choices;
  final int correctAnswerIndex;
  final String explanation;

  MicroTrainingProblem({
    required this.type,
    required this.title,
    required this.board,
    required this.choices,
    required this.correctAnswerIndex,
    required this.explanation,
  });
}

List<MicroTrainingProblem> _buildMicroProblems() {
  final list = <MicroTrainingProblem>[];
  {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[0][4] = Piece(PieceType.king, false);
    b[2][4] = Piece(PieceType.gold, false);
    b[4][4] = Piece(PieceType.rook, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(MicroTrainingProblem(
      type: 'next_move',
      title: '次の一手：飛車の成り込み',
      board: b,
      choices: ['▲5三飛成', '▲5四飛', '▲4五飛'],
      correctAnswerIndex: 0,
      explanation: '▲5三飛成！金を取りながら龍を作り、5一の玉に王手。駒得と王手を同時に実現する最善手。',
    ));
  }
  {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[0][4] = Piece(PieceType.king, false);
    b[0][6] = Piece(PieceType.rook, false);
    b[4][4] = Piece(PieceType.knight, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(MicroTrainingProblem(
      type: 'tesuji',
      title: '手筋：桂の高飛び',
      board: b,
      choices: ['▲4三桂', '▲6三桂', '▲4三桂成'],
      correctAnswerIndex: 0,
      explanation: '▲4三桂不成！玉(5一)と飛(3一)の両方に当てる桂の両取り。成ると当たりが消えるので不成が正着。',
    ));
  }
  {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[1][7] = Piece(PieceType.king, false);
    b[2][7] = Piece(PieceType.pawn, false);
    b[3][7] = Piece(PieceType.silver, true);
    b[8][1] = Piece(PieceType.king, true);
    list.add(MicroTrainingProblem(
      type: 'next_move',
      title: '次の一手：銀で食いつく',
      board: b,
      choices: ['▲2三銀成', '▲3三銀', '▲1三銀'],
      correctAnswerIndex: 0,
      explanation: '▲2三銀成！歩を取りつつ成銀を作り、2二の玉に王手。銀が敵陣に食いつく強手。',
    ));
  }
  {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[0][2] = Piece(PieceType.king, false);
    b[2][4] = Piece(PieceType.gold, false);
    b[4][6] = Piece(PieceType.bishop, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(MicroTrainingProblem(
      type: 'tesuji',
      title: '手筋：角のにらみ',
      board: b,
      choices: ['▲5三角成', '▲4四角', '▲2六角'],
      correctAnswerIndex: 0,
      explanation: '▲5三角成！角を成って馬を作りながら金を補獲。馬は守りにも攻めにも使える強力な成駒。',
    ));
  }
  {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[0][7] = Piece(PieceType.king, false);
    b[2][7] = Piece(PieceType.pawn, false);
    b[4][1] = Piece(PieceType.rook, true);
    b[8][1] = Piece(PieceType.king, true);
    list.add(MicroTrainingProblem(
      type: 'next_move',
      title: '次の一手：飛車を回す',
      board: b,
      choices: ['▲2五飛', '▲5五飛', '▲8二飛成'],
      correctAnswerIndex: 0,
      explanation: '▲2五飛！飛車を玉のいる2筋に回し、次の2三飛成・2二への寄せを狙う。攻めの飛車は使う筋を変えるのが要点。',
    ));
  }
  {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[0][6] = Piece(PieceType.king, false);
    b[2][6] = Piece(PieceType.gold, false);
    b[5][6] = Piece(PieceType.rook, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(MicroTrainingProblem(
      type: 'next_move',
      title: '次の一手：龍を作る',
      board: b,
      choices: ['▲3三飛成', '▲3四飛', '▲7六飛'],
      correctAnswerIndex: 0,
      explanation: '▲3三飛成！金を取って龍を作り、3一の玉に王手。飛車を成って龍にすると攻守ともに働く強力な駒になる。',
    ));
  }
  return list;
}
