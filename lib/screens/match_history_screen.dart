// lib/screens/match_history_screen.dart
// 対局履歴一覧画面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/rating_service.dart';
import '../services/network_service.dart';
import 'match_analyzer_screen.dart';
import '../theme/app_theme.dart';

class MatchHistoryScreen extends StatelessWidget {
  final String userId;

  const MatchHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title:
            const Text('対局履歴', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _MatchHistoryBody(userId: userId),
    );
  }
}

class _MatchHistoryBody extends StatelessWidget {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RatingService _ratingService = RatingService();
  final NetworkService _networkService = NetworkService();

  _MatchHistoryBody({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('matches')
          .where(Filter.or(
            Filter('player1_id', isEqualTo: userId),
            Filter('player2_id', isEqualTo: userId),
          ))
          .where('status', isEqualTo: 'finished')
          .orderBy('finished_at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, color: Colors.white24, size: 64),
                SizedBox(height: 12),
                Text('対局履歴がありません',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _MatchHistoryTile(
              matchData: data,
              userId: userId,
              ratingService: _ratingService,
            );
          },
        );
      },
    );
  }
}

class _MatchHistoryTile extends StatelessWidget {
  final Map<String, dynamic> matchData;
  final String userId;
  final RatingService ratingService;

  const _MatchHistoryTile({
    required this.matchData,
    required this.userId,
    required this.ratingService,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayer1 = matchData['player1_id'] == userId;
    final myName = isPlayer1
        ? matchData['player1_name'] as String? ?? '?'
        : matchData['player2_name'] as String? ?? '?';
    final opponentName = isPlayer1
        ? matchData['player2_name'] as String? ?? '?'
        : matchData['player1_name'] as String? ?? '?';
    final myRating = isPlayer1
        ? matchData['player1_rating'] as int? ?? 1500
        : matchData['player2_rating'] as int? ?? 1500;
    final opponentRating = isPlayer1
        ? matchData['player2_rating'] as int? ?? 1500
        : matchData['player1_rating'] as int? ?? 1500;

    final winner = matchData['winner'] as String?;
    final result = matchData['result'] as String? ?? '';
    final isWin = winner == userId;
    final isDraw = winner == null && result == 'draw';

    final finishedAt = matchData['finished_at'];
    final dateStr = finishedAt != null
        ? _formatDate(finishedAt)
        : '不明';

    final resultLabel = _getResultLabel(result);
    final resultColor = isDraw
        ? Colors.grey
        : isWin
            ? Colors.green
            : Colors.red;
    final resultText = isDraw ? '引き分け' : isWin ? '勝利' : '敗北';

    return InkWell(
      onTap: () {
        final matchId = matchData['id'] as String?;
        if (matchId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchAnalyzerScreen(matchId: matchId),
            ),
          );
        }
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: resultColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 結果バッジ
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: resultColor.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Text(
                    resultText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    resultLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // 対戦相手情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs $opponentName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '相手レート: $opponentRating  自分: $myRating',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // 日付 + 分析アイコン
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.analytics,
                    size: 14, color: Colors.white24),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _getResultLabel(String result) {
    switch (result) {
      case 'checkmate':
        return '詰み';
      case 'resignation':
        return '投了';
      case 'timeout':
        return '時間切れ';
      case 'draw':
        return '引き分け';
      default:
        return result;
    }
  }

  String _formatDate(dynamic ts) {
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else {
        dt = DateTime.parse(ts.toString());
      }
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '?';
    }
  }
}
