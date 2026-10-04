// lib/screens/ranking_screen.dart
// グローバルランキング表示

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/rating_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RatingService _ratingService = RatingService();
  final NetworkService _networkService = NetworkService();

  late TabController _tabController;
  String? _currentUserId;
  int? _currentUserRank;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = _networkService.currentUser?.uid;
    _loadCurrentUserRank();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserRank() async {
    if (_currentUserId == null) return;

    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final userRating = currentUserDoc['rating'] as int? ?? 1500;

      // 全ユーザーのレーティングを取得
      final allUsers = await _firestore.collection('users').get();
      final allRatings = allUsers.docs
          .map((doc) => doc['rating'] as int? ?? 1500)
          .toList();

      final rank = _ratingService.calculateRank(userRating, allRatings);

      if (mounted) {
        setState(() {
          _currentUserRank = rank;
        });
      }
    } catch (e) {
      print('Load current user rank error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ランキング', style: TextStyle(color: AppTheme.textHigh)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'グローバル'),
            Tab(text: 'あなた'),
            Tab(text: '統計'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalRanking(),
          _buildUserRanking(),
          _buildStatistics(),
        ],
      ),
    );
  }

  // ① グローバルランキング
  Widget _buildGlobalRanking() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .orderBy('rating', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;
            final rank = index + 1;
            final rating = data['rating'] as int? ?? 1500;
            final username = data['username'] as String? ?? 'Unknown';
            final wins = data['wins'] as int? ?? 0;
            final losses = data['losses'] as int? ?? 0;
            final total = wins + losses;
            final winRate =
                total > 0 ? ((wins / total) * 100).toStringAsFixed(1) : '0.0';

            final rankLabel = _ratingService.getRankLabel(rating);
            final isCurrentUser = user.id == _currentUserId;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Colors.blue.shade900.withAlpha(100)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: isCurrentUser
                    ? Border.all(color: AppTheme.accent, width: 1)
                    : null,
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    color: _getMedalColor(rank),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '$rankLabel • $rating点 • 勝率: ${winRate}%',
                  style: const TextStyle(color: AppTheme.textMid, fontSize: 12),
                ),
                trailing: Text(
                  '$wins勝 $losses敗',
                  style: const TextStyle(
                    color: AppTheme.textMid,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ② あなたのランキング
  Widget _buildUserRanking() {
    if (_currentUserId == null) {
      return const Center(
        child: Text('ログインが必要です',
            style: TextStyle(color: AppTheme.textMid)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          _firestore.collection('users').doc(_currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final rating = data['rating'] as int? ?? 1500;
        final username = data['username'] as String? ?? 'Unknown';
        final wins = data['wins'] as int? ?? 0;
        final losses = data['losses'] as int? ?? 0;
        final total = wins + losses;
        final winRate =
            total > 0 ? ((wins / total) * 100).toStringAsFixed(1) : '0.0';
        final rankLabel = _ratingService.getRankLabel(rating);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _currentUserRank?.toString() ?? '?',
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  username,
                  style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rankLabel,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                // 統計
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBox('レート', '$rating点'),
                    _buildStatBox('勝率', '${winRate}%'),
                    _buildStatBox('試合数', '$total'),
                  ],
                ),
                const SizedBox(height: 32),
                // 詳細
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '詳細統計',
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatLine('勝利', '$wins勝'),
                      _buildStatLine('敗北', '$losses敗'),
                      _buildStatLine('総試合数', '$total試合'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMid, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMid)),
          Text(value, style: const TextStyle(color: AppTheme.textHigh)),
        ],
      ),
    );
  }

  // ③ 統計情報
  Widget _buildStatistics() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プラットフォーム統計',
              style: TextStyle(
                color: AppTheme.textHigh,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;
                final totalUsers = users.length;
                final totalMatches = users.fold<int>(
                  0,
                  (sum, doc) =>
                      sum +
                      ((doc['wins'] as int? ?? 0) +
                          (doc['losses'] as int? ?? 0)),
                );
                final avgRating = users.isEmpty
                    ? 1500
                    : (users.fold<int>(
                            0, (sum, doc) => sum + (doc['rating'] as int? ?? 1500)) /
                        users.length)
                        .round();

                return Column(
                  children: [
                    _buildStatBox('登録ユーザー数', '$totalUsers名'),
                    const SizedBox(height: 16),
                    _buildStatBox('総対局数', '$totalMatches試合'),
                    const SizedBox(height: 16),
                    _buildStatBox('平均レート', '$avgRating点'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getMedalColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return Colors.orange.shade700;
    return Colors.blue.shade700;
  }
}
