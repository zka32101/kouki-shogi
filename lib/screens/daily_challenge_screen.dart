// lib/screens/daily_challenge_screen.dart
// デイリーチャレンジ画面

import 'package:flutter/material.dart';
import '../services/daily_challenge_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title:
            const Text('デイリーチャレンジ', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const _DailyChallengeBody(),
    );
  }
}

class _DailyChallengeBody extends StatefulWidget {
  const _DailyChallengeBody();

  @override
  State<_DailyChallengeBody> createState() => _DailyChallengeBodyState();
}

class _DailyChallengeBodyState extends State<_DailyChallengeBody> {
  final DailyChallengeService _challengeService = DailyChallengeService();
  final NetworkService _networkService = NetworkService();

  int _loginStreak = 0;
  int _challengePoints = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = _networkService.currentUser?.uid;
    if (uid == null) return;

    final streak = await _challengeService.getLoginStreak(uid);
    final points = await _challengeService.getChallengePoints(uid);
    if (mounted) {
      setState(() {
        _loginStreak = streak;
        _challengePoints = points;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _networkService.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child:
              Text('ログインが必要です', style: TextStyle(color: AppTheme.textMid)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ヘッダー
          _buildHeader(),
          const SizedBox(height: 16),
          // チャレンジリスト
          _buildChallengeList(uid),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // ストリーク
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.orange.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_loginStreak 日連続',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('ログインストリーク',
                        style: TextStyle(
                            color: AppTheme.textMid, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ポイント
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.amber.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_challengePoints pt',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('チャレンジポイント',
                        style: TextStyle(
                            color: AppTheme.textMid, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeList(String userId) {
    return StreamBuilder<List<DailyChallenge>>(
      stream: _challengeService.watchTodayChallenges(),
      builder: (context, challengeSnap) {
        final challenges = challengeSnap.data ?? [];

        if (challenges.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.amber)),
                  SizedBox(height: 16),
                  Text(
                    '本日のチャレンジを読み込み中...',
                    style: TextStyle(color: AppTheme.textMid),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<Map<String, UserChallengeProgress>>(
          stream: _challengeService.watchMyProgress(userId),
          builder: (context, progressSnap) {
            final progress = progressSnap.data ?? {};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '本日のチャレンジ',
                    style: TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                ...challenges.map((c) {
                  final p = progress[c.id];
                  return _ChallengeTile(
                    challenge: c,
                    progress: p,
                  );
                }),
                const SizedBox(height: 24),
                // チャレンジ説明
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('チャレンジについて',
                          style: TextStyle(
                              color: AppTheme.textHigh,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        '• 毎日0時にリセットされます\n'
                        '• チャレンジポイントは将来のアイテム交換に使用予定\n'
                        '• ログインストリークを維持するとボーナスが付きます\n'
                        '• 対局を重ねてポイントを貯めましょう',
                        style: TextStyle(
                            color: AppTheme.textMid, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── チャレンジタイル ──────────────────────────────────────────────

class _ChallengeTile extends StatelessWidget {
  final DailyChallenge challenge;
  final UserChallengeProgress? progress;

  const _ChallengeTile({required this.challenge, this.progress});

  @override
  Widget build(BuildContext context) {
    final current = progress?.currentCount ?? 0;
    final completed = progress?.completed ?? false;
    final ratio = (current / challenge.targetCount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed
            ? Colors.green.shade900.withAlpha(120)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed
              ? Colors.green.withAlpha(120)
              : Colors.grey.shade800,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // アイコン
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: completed
                      ? Colors.green.shade700
                      : Colors.brown.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getIcon(challenge.type),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // タイトル・説明
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          challenge.title,
                          style: TextStyle(
                            color:
                                completed ? Colors.green : AppTheme.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (completed) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      style: const TextStyle(
                          color: AppTheme.textMid, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // 報酬
              Column(
                children: [
                  const Text('⭐',
                      style: TextStyle(fontSize: 18)),
                  Text(
                    '${challenge.rewardPoints}pt',
                    style: const TextStyle(
                        color: Colors.amber, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 進捗バー
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppTheme.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completed ? Colors.green : Colors.amber,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$current / ${challenge.targetCount}',
                style: TextStyle(
                  color: completed ? Colors.green : AppTheme.textMid,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.winMatch:
        return '🏆';
      case ChallengeType.winByCheckmate:
        return '♟️';
      case ChallengeType.winByResign:
        return '🤝';
      case ChallengeType.playMatches:
        return '⚔️';
      case ChallengeType.winStreak:
        return '🔥';
      case ChallengeType.ratingGain:
        return '📈';
      case ChallengeType.spectateMatch:
        return '👁️';
      case ChallengeType.useDrop:
        return '🎯';
    }
  }
}
