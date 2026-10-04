import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_analysis.dart';
import '../theme/app_theme.dart';

class PersonalBlunderQuizScreen extends StatefulWidget {
  final List<BlunderInfo> blunders;
  final List<BlunderInfo> historicalBlunders;

  const PersonalBlunderQuizScreen({
    required this.blunders,
    required this.historicalBlunders,
  });

  @override
  State<PersonalBlunderQuizScreen> createState() =>
      _PersonalBlunderQuizScreenState();
}

class _PersonalBlunderQuizScreenState
    extends State<PersonalBlunderQuizScreen> {
  late PageController _pageController;
  late List<BlunderQuestion> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _generateQuestions();
  }

  void _generateQuestions() {
    _questions = widget.blunders.asMap().entries.map((e) {
      final i = e.key;
      final blunder = e.value;
      final historicalCount = widget.historicalBlunders
          .where((h) =>
              h.toSquare == blunder.toSquare &&
              h.pieceMoved == blunder.pieceMoved)
          .length;
      return BlunderQuestion(
        index: i,
        blunder: blunder,
        historicalCount: historicalCount,
      );
    }).toList();
  }

  void _onAnswered(bool isCorrect) {
    if (isCorrect) _correctCount++;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else {
        _showResultsDialog();
      }
    });
  }

  void _showResultsDialog() {
    final accuracy = (_correctCount / _questions.length * 100).toInt();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '復習完了！',
          style: TextStyle(color: Colors.amber, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$_correctCount / ${_questions.length}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正答率 $accuracy%',
                    style: TextStyle(
                      color: accuracy >= 70
                          ? Colors.green.shade400
                          : Colors.orange.shade400,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              accuracy >= 100
                  ? '完璧です！悪手のパターンをマスターしました 🎉'
                  : accuracy >= 70
                      ? 'もう一度チャレンジして完璧を目指しましょう'
                      : 'この悪手パターンを何度も練習して、改善を目指しましょう',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              '対局に戻る',
              style: TextStyle(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: Row(
          children: [
            const Text('悪手の復習'),
            const Spacer(),
            Text(
              '$_correctCount/${_questions.length} 正解',
              style: const TextStyle(fontSize: 13, color: Colors.amber),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
            ),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: _questions.length,
        itemBuilder: (context, index) =>
            _buildQuizPage(_questions[index], index),
      ),
    );
  }

  Widget _buildQuizPage(BlunderQuestion question, int index) {
    final severity = question.blunder.evalDelta.abs();
    final severityLabel = severity >= 200
        ? '致命的な悪手'
        : severity >= 100
            ? '悪手'
            : '緩手';
    final severityColor = severity >= 200
        ? Colors.red.shade400
        : severity >= 100
            ? Colors.orange.shade400
            : Colors.yellow.shade600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 悪手の情報カード ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: severityColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '問 ${index + 1} / ${_questions.length}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: severityColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: severityColor),
                      ),
                      child: Text(
                        severityLabel,
                        style: TextStyle(color: severityColor, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${question.blunder.moveNum}手目',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '▲${question.blunder.toSquare}${question.blunder.pieceMoved}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('評価値の変化',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          '${question.blunder.evalDelta > 0 ? '+' : ''}${question.blunder.evalDelta}',
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (question.historicalCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, color: Colors.red.shade300, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '過去 ${question.historicalCount} 回同じパターンで失敗',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 問い ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Q. この手が悪手になった主な理由は？',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '評価値が ${question.blunder.evalDelta.abs()} 下がった局面です。',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 選択肢 ────────────────────────────────────────────
          ..._buildOptions(question),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(BlunderQuestion question) {
    final options = _generateOptions(question);
    return options.asMap().entries.map((e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OptionCard(
          label: e.value.label,
          isCorrect: e.value.isCorrect,
          onAnswered: _onAnswered,
        ),
      );
    }).toList();
  }

  List<_OptionData> _generateOptions(BlunderQuestion question) {
    final severity = question.blunder.evalDelta.abs();
    final piece = question.blunder.pieceMoved;

    // 不正解の選択肢（3つ）
    final wrongs = _wrongOptions(piece, severity);

    // 正解の選択肢（1つ）
    final correct = _correctOption(piece, severity);

    final options = [
      ...wrongs.map((l) => _OptionData(label: l, isCorrect: false)),
      _OptionData(label: correct, isCorrect: true),
    ];

    // シャッフルで正解位置をランダム化
    options.shuffle(Random());
    return options;
  }

  List<String> _wrongOptions(String piece, int severity) {
    if (piece == '飛' || piece == '竜') {
      return ['飛車を大駒として温存すべきだった', '飛車のコースが通っていて問題ない', '手番を使う価値があった'];
    }
    if (piece == '角' || piece == '馬') {
      return ['角の利きを活かした手だった', '角打ちで攻撃を継続できる', '遠距離攻撃なので評価は高い'];
    }
    if (piece == '金' || piece == '銀') {
      return ['金銀は玉の近くが最適', '守備駒なので前進しても安全', '相手の攻撃を受ける良い手だった'];
    }
    if (piece == '歩' || piece == 'と') {
      return ['歩を突くのは常に良い手', '手数を稼げるので得', '相手の陣形を乱せる'];
    }
    return ['手の価値が高い', 'テンポを稼げる', '相手の選択肢を狭める'];
  }

  String _correctOption(String piece, int severity) {
    if (severity >= 200) {
      return '相手に一方的に得をさせた（取られる/王手されるリスク）';
    }
    if (piece == '飛' || piece == '角') {
      return '大駒が危険にさらされ、取られる可能性があった';
    }
    if (piece == '金' || piece == '銀') {
      return '守備の要を離してしまい、玉が薄くなった';
    }
    return '局面のバランスを崩し、相手に主導権を渡した';
  }
}

class _OptionData {
  final String label;
  final bool isCorrect;
  _OptionData({required this.label, required this.isCorrect});
}

class BlunderQuestion {
  final int index;
  final BlunderInfo blunder;
  final int historicalCount;

  BlunderQuestion({
    required this.index,
    required this.blunder,
    required this.historicalCount,
  });
}

class OptionCard extends StatefulWidget {
  final String label;
  final bool isCorrect;
  final void Function(bool) onAnswered;

  const OptionCard({
    required this.label,
    required this.isCorrect,
    required this.onAnswered,
  });

  @override
  State<OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<OptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.97), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  void _handleTap() {
    if (_isAnswered) return;
    setState(() => _isAnswered = true);
    _animController.forward();
    widget.onAnswered(widget.isCorrect);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = _isAnswered && widget.isCorrect;
    final isWrong = _isAnswered && !widget.isCorrect;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isCorrect
                ? Colors.green.withAlpha(55)
                : isWrong
                    ? Colors.red.withAlpha(45)
                    : Colors.white.withAlpha(10),
            border: Border.all(
              color: isCorrect
                  ? Colors.green.shade400
                  : isWrong
                      ? Colors.red.shade400
                      : Colors.white24,
              width: isCorrect || isWrong ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isCorrect
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 20, key: ValueKey('ok'))
                    : isWrong
                        ? const Icon(Icons.cancel,
                            color: Colors.red, size: 20, key: ValueKey('ng'))
                        : const Icon(Icons.radio_button_unchecked,
                            color: Colors.white38,
                            size: 20,
                            key: ValueKey('none')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isCorrect
                        ? Colors.green.shade300
                        : isWrong
                            ? Colors.red.shade300
                            : Colors.white70,
                    fontWeight:
                        isCorrect ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isCorrect)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(60),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '正解！',
                    style: TextStyle(
                      color: Colors.green.shade400,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else if (isWrong)
                Text(
                  'はずれ',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
