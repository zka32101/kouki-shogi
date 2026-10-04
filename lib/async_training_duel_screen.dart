// lib/async_training_duel_screen.dart
// 非同期トレーニング対戦画面（詰将棋で競うレース対戦）
//
// フレンド機能（services/friend_service.dart）で実際に繋がっている相手とだけ
// 対戦を作成できる。進捗は Firestore の async_duels コレクションで同期され、
// 「相手の進捗」もリアルタイムの実データを表示する
// （旧版はCPU/ランダムプレイヤーという名ばかりの相手とRandom()による
// フェイクの進捗・結果を表示していた）。

import 'package:flutter/material.dart';
import 'services/async_duel_service.dart';
import 'services/friend_service.dart';
import 'services/network_service.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';
import 'tsume_builtin_problems.dart' show TsumeProb;

class AsyncTrainingDuelScreen extends StatefulWidget {
  const AsyncTrainingDuelScreen({super.key});

  @override
  State<AsyncTrainingDuelScreen> createState() =>
      _AsyncTrainingDuelScreenState();
}

class _AsyncTrainingDuelScreenState extends State<AsyncTrainingDuelScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final NetworkService _networkService = NetworkService();
  final FriendService _friendService = FriendService();
  final AsyncDuelService _duelService = AsyncDuelService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _myUid => _networkService.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final myUid = _myUid;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('非同期トレーニング対戦',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: '対戦作成'),
            Tab(text: '進行中'),
            Tab(text: '結果'),
          ],
        ),
      ),
      body: myUid == null
          ? const Center(
              child: Text('ログインが必要です', style: TextStyle(color: Colors.white54)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCreateTab(myUid),
                _buildActiveDuelsTab(myUid),
                _buildResultsTab(myUid),
              ],
            ),
    );
  }

  // ─── 対戦作成タブ ────────────────────────────────────────────

  Widget _buildCreateTab(String myUid) {
    return StreamBuilder<List<FriendInfo>>(
      stream: _friendService.watchFriends(myUid),
      builder: (context, snapshot) {
        final friends = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                '難易度を選んで対戦を作成',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildCreateCard(
                myUid: myUid,
                friends: friends,
                title: '1手詰め 5問',
                description: '基本的な詰将棋',
                difficulty: '1手詰め',
                icon: '🟢',
              ),
              const SizedBox(height: 12),
              _buildCreateCard(
                myUid: myUid,
                friends: friends,
                title: '3手詰め 5問',
                description: '中級レベル',
                difficulty: '3手詰め',
                icon: '🟡',
              ),
              const SizedBox(height: 12),
              _buildCreateCard(
                myUid: myUid,
                friends: friends,
                title: '5手詰め 5問',
                description: '上級レベル',
                difficulty: '5手詰め',
                icon: '🔴',
              ),
              if (friends.isEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.group_outlined, color: Colors.white38, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'フレンドがいません。フレンド画面から\n申請・承認すると対戦を作成できます。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateCard({
    required String myUid,
    required List<FriendInfo> friends,
    required String title,
    required String description,
    required String difficulty,
    required String icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed:
                  friends.isEmpty ? null : () => _showCreateDuelDialog(myUid, friends, difficulty),
              child: const Text('対戦を開始',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDuelDialog(
      String myUid, List<FriendInfo> friends, String difficulty) {
    int selectedHours = 24;
    FriendInfo selectedFriend = friends.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('対戦を開始', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('制限時間',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                selected: {selectedHours},
                onSelectionChanged: (selected) {
                  setLocalState(() => selectedHours = selected.first);
                },
                segments: const [
                  ButtonSegment(value: 6, label: Text('6時間')),
                  ButtonSegment(value: 12, label: Text('12時間')),
                  ButtonSegment(value: 24, label: Text('24時間')),
                  ButtonSegment(value: 48, label: Text('48時間')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('相手を選択',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedFriend.userId,
                dropdownColor: AppTheme.surface,
                isExpanded: true,
                items: friends
                    .map((f) => DropdownMenuItem(
                          value: f.userId,
                          child: Text('${f.username}（${f.rating}）',
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocalState(() {
                    selectedFriend = friends.firstWhere((f) => f.userId == value);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('キャンセル', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _duelService.createDuel(
                    opponentId: selectedFriend.userId,
                    opponentName: selectedFriend.username,
                    difficulty: difficulty,
                    deadlineHours: selectedHours,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${selectedFriend.username}との対戦を開始しました'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    _tabController.animateTo(1);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('エラー: $e')),
                    );
                  }
                }
              },
              child: const Text('開始', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 進行中タブ ──────────────────────────────────────────────

  Widget _buildActiveDuelsTab(String myUid) {
    return StreamBuilder<List<AsyncDuel>>(
      stream: _duelService.watchMyDuels(myUid),
      builder: (context, snapshot) {
        final duels = (snapshot.data ?? [])
            .where((d) => d.status == 'active')
            .toList()
          ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));

        if (duels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('進行中の対戦はありません',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('対戦を作成',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: duels.length,
          itemBuilder: (context, index) =>
              _buildActiveDuelCard(myUid, duels[index]),
        );
      },
    );
  }

  Widget _buildActiveDuelCard(String myUid, AsyncDuel duel) {
    final myProgress = duel.myProgress(myUid);
    final oppProgress = duel.opponentProgress(myUid);
    final total = duel.problemIndices.length;
    final progress = total == 0 ? 0.0 : myProgress.solvedCount / total;
    final isExpired = duel.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? Colors.red.withAlpha(80) : Colors.orange.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${duel.difficulty} 対 ${duel.opponentName(myUid)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'あなた ${myProgress.solvedCount}/$total  ·  相手 ${oppProgress.solvedCount}/$total',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.withAlpha(30) : Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExpired ? '期限切れ' : '${duel.remainingMinutes}分',
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(Colors.orange.withAlpha(200)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: (isExpired || myProgress.finished)
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _DuelSolveScreen(duel: duel, myUid: myUid),
                          ),
                        );
                      },
                child: Text(
                  isExpired
                      ? '期限切れ'
                      : (myProgress.finished ? '相手の完了待ち' : '解く'),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 結果タブ ────────────────────────────────────────────────

  Widget _buildResultsTab(String myUid) {
    return StreamBuilder<List<AsyncDuel>>(
      stream: _duelService.watchMyDuels(myUid),
      builder: (context, snapshot) {
        final duels = (snapshot.data ?? [])
            .where((d) => d.status == 'completed')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (duels.isEmpty) {
          return const Center(
            child: Text('完了した対戦はありません',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: duels.length,
          itemBuilder: (context, index) => _buildResultCard(myUid, duels[index]),
        );
      },
    );
  }

  Widget _buildResultCard(String myUid, AsyncDuel duel) {
    final myProgress = duel.myProgress(myUid);
    final oppProgress = duel.opponentProgress(myUid);
    final total = duel.problemIndices.length;
    final playerWon = duel.winnerId == myUid;
    final isDraw = duel.winnerId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: playerWon ? Colors.amber.withAlpha(80) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          if (playerWon || isDraw)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (playerWon ? Colors.amber : Colors.white24).withAlpha(30),
                borderRadius:
                    const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(playerWon ? '🏆 ' : '🤝 ', style: const TextStyle(fontSize: 20)),
                  Text(
                    playerWon ? 'あなたが勝利！' : '引き分け',
                    style: TextStyle(
                      color: playerWon ? Colors.amber : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${duel.difficulty} 対 ${duel.opponentName(myUid)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _resultColumn('あなた', myProgress, total, !playerWon && !isDraw ? '🥈' : (playerWon ? '🥇' : '🤝')),
                    _resultColumn(duel.opponentName(myUid), oppProgress, total,
                        playerWon ? '🥈' : (isDraw ? '🤝' : '🥇')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultColumn(String name, AsyncDuelProgress p, int total, String medal) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(medal, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${p.solvedCount}/$total',
            style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.totalSolveTimeSec ~/ 60}分${p.totalSolveTimeSec % 60}秒',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ===== 対戦問題を解く画面 =====

class _DuelSolveScreen extends StatefulWidget {
  final AsyncDuel duel;
  final String myUid;

  const _DuelSolveScreen({required this.duel, required this.myUid});

  @override
  State<_DuelSolveScreen> createState() => _DuelSolveScreenState();
}

class _DuelSolveScreenState extends State<_DuelSolveScreen> {
  late final List<TsumeProb> _problems;
  int _currentQuestionIndex = 0;
  int _solvedCount = 0;
  late final Stopwatch _stopwatch;
  int? _selectedAnswer;
  bool? _answerResult;

  late List<List<String>> _choices;
  late List<int> _correctIndices;

  static const _rowKanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];

  @override
  void initState() {
    super.initState();
    _problems = widget.duel.problems;
    _initChoices();
    _stopwatch = Stopwatch()..start();
  }

  void _initChoices() {
    _choices = [];
    _correctIndices = [];
    for (final q in _problems) {
      final sol = q.solution;
      final correctMove = sol.isNotEmpty
          ? '${9 - sol[0].tc}${_rowKanji[sol[0].tr]}へ'
          : '5五金打';
      final dummies = ['3三銀打', '7七桂成', '4四飛引', '2二角成', '6六歩成'];
      final options = [correctMove];
      for (final d in dummies) {
        if (!options.contains(d)) options.add(d);
        if (options.length == 3) break;
      }
      options.shuffle();
      _correctIndices.add(options.indexOf(correctMove));
      _choices.add(options);
    }
  }

  Future<void> _submitProgress({required bool finished}) async {
    try {
      await AsyncDuelService().submitProgress(
        widget.duel.id,
        widget.myUid,
        solvedCount: _solvedCount,
        totalSolveTimeSec: _stopwatch.elapsed.inSeconds,
        finished: finished,
      );
    } catch (_) {
      // オフライン等での失敗は次回同期時にリトライされるため無視する
    }
  }

  void _answerQuestion(int choiceIndex) {
    if (_answerResult != null) return;
    final isCorrect = choiceIndex == _correctIndices[_currentQuestionIndex];
    setState(() {
      _selectedAnswer = choiceIndex;
      _answerResult = isCorrect;
      if (isCorrect) _solvedCount++;
    });
    _submitProgress(finished: false);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    setState(() {
      _selectedAnswer = null;
      _answerResult = null;
    });
    if (_currentQuestionIndex < _problems.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      _finishDuel();
    }
  }

  void _finishDuel() {
    _stopwatch.stop();
    _submitProgress(finished: true);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('対戦を完了しました（$_solvedCount/${_problems.length}問正解）')),
    );
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 問題が空のデュエル（不正なFirestoreデータや、ビルドインの問題IDが
    // 変わって problemIndices が解決できない場合）でクラッシュしないようガードする。
    if (_problems.isEmpty || _currentQuestionIndex >= _problems.length) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'この対戦の問題を読み込めませんでした',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final question = _problems[_currentQuestionIndex];
    final timeString = _formatDuration(_stopwatch.elapsed);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          '問題 ${_currentQuestionIndex + 1}/${_problems.length}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('累計時間', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(
                      timeString,
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // 相手の進捗はFirestoreからリアルタイムに反映する
                StreamBuilder<AsyncDuel?>(
                  stream: AsyncDuelService().watchDuel(widget.duel.id),
                  builder: (context, snapshot) {
                    final oppProgress =
                        snapshot.data?.opponentProgress(widget.myUid);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('相手の進捗', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Text(
                          '${oppProgress?.solvedCount ?? 0}/${_problems.length}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  MiniBoardWidget(board: question.board),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.title.isNotEmpty ? question.title : '課題: 詰将棋を解く',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '先手が${question.moves}手で詰ませるルートを見つけてください。',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_answerResult != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: (_answerResult! ? Colors.green : Colors.red).withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _answerResult! ? '✓ 正解！' : '✗ 不正解',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _answerResult! ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ...List.generate(_choices[_currentQuestionIndex].length, (i) {
                  final choice = _choices[_currentQuestionIndex][i];
                  final isCorrect = i == _correctIndices[_currentQuestionIndex];
                  Color btnColor = Colors.orange;
                  if (_answerResult != null) {
                    if (isCorrect) {
                      btnColor = Colors.green;
                    } else if (i == _selectedAnswer) {
                      btnColor = Colors.red.shade700;
                    } else {
                      btnColor = Colors.grey.shade700;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _answerResult != null ? null : () => _answerQuestion(i),
                      child: Text(
                        choice,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
