// lib/screens/friend_screen.dart
// フレンドリスト・申請・対局招待

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friend_service.dart';
import '../services/network_service.dart';
import '../services/rating_service.dart';
import '../services/board_sync_service.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import '../logic.dart';
import 'player_profile_screen.dart';
import 'match_screen.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key});

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  final NetworkService _networkService = NetworkService();
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('フレンド', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search, color: Colors.white70),
            onPressed: _showSearchDialog,
            tooltip: 'ユーザー検索',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'フレンド'),
            Tab(text: '申請'),
            Tab(text: '招待'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendListTab(
            friendService: _friendService,
            networkService: _networkService,
          ),
          _RequestsTab(
            friendService: _friendService,
            networkService: _networkService,
          ),
          _ChallengesTab(
            friendService: _friendService,
            networkService: _networkService,
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('ユーザー検索',
              style: TextStyle(color: AppTheme.textHigh)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(color: AppTheme.textHigh),
                  decoration: InputDecoration(
                    hintText: 'ユーザー名',
                    hintStyle:
                        const TextStyle(color: AppTheme.textLow),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search,
                          color: Colors.white54),
                      onPressed: () async {
                        final r = await _friendService
                            .searchUsers(controller.text.trim());
                        setS(() => results = r);
                      },
                    ),
                  ),
                  onSubmitted: (v) async {
                    final r =
                        await _friendService.searchUsers(v.trim());
                    setS(() => results = r);
                  },
                ),
                const SizedBox(height: 8),
                if (results.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final user = results[i];
                        return _SearchResultTile(
                          user: user,
                          currentUserId:
                              _networkService.currentUser?.uid ?? '',
                          friendService: _friendService,
                          networkService: _networkService,
                        );
                      },
                    ),
                  ),
                if (results.isEmpty && controller.text.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('見つかりませんでした',
                        style: TextStyle(color: AppTheme.textLow)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

// ── フレンドリストタブ ────────────────────────────────────────────

class _FriendListTab extends StatelessWidget {
  final FriendService friendService;
  final NetworkService networkService;
  const _FriendListTab(
      {required this.friendService, required this.networkService});

  @override
  Widget build(BuildContext context) {
    final uid = networkService.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child: Text('ログインが必要です',
              style: TextStyle(color: Colors.white54)));
    }

    return StreamBuilder<List<FriendInfo>>(
      stream: friendService.watchFriends(uid),
      builder: (context, snap) {
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text('フレンドがいません',
                    style: TextStyle(color: AppTheme.textLow)),
                SizedBox(height: 8),
                Text('右上のアイコンからユーザーを検索できます',
                    style:
                        TextStyle(color: Colors.white24, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: friends.length,
          itemBuilder: (_, i) => _FriendTile(
            friend: friends[i],
            currentUserId: uid,
            friendService: friendService,
            networkService: networkService,
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendInfo friend;
  final String currentUserId;
  final FriendService friendService;
  final NetworkService networkService;

  const _FriendTile({
    required this.friend,
    required this.currentUserId,
    required this.friendService,
    required this.networkService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: friend.isOnline
              ? Colors.green.withAlpha(100)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(
              userId: friend.userId,
              isCurrentUser: false,
            ),
          ),
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.brown.shade700,
              child: Text(
                friend.username[0].toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.textHigh, fontWeight: FontWeight.bold),
              ),
            ),
            if (friend.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.grey.shade900, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friend.username,
          style: const TextStyle(
              color: AppTheme.textHigh, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${RatingService().getRankLabel(friend.rating)} (${friend.rating})',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (friend.currentMatchId != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('対局中',
                      style:
                          TextStyle(color: AppTheme.textHigh, fontSize: 9)),
                ),
              ),
            IconButton(
              icon:
                  const Icon(Icons.sports_esports, color: Colors.amber),
              onPressed: friend.isOnline
                  ? () => _sendChallenge(context)
                  : null,
              tooltip: '対局に招待',
            ),
            IconButton(
              icon: const Icon(Icons.person_remove,
                  color: Colors.white38, size: 18),
              onPressed: () => _confirmRemoveFriend(context),
              tooltip: 'フレンド解除',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendChallenge(BuildContext context) async {
    final profile =
        await networkService.getUserProfile(currentUserId);
    if (profile == null) return;

    await friendService.sendDirectChallenge(
      senderId: currentUserId,
      senderName: profile.username,
      senderRating: profile.rating,
      recipientId: friend.userId,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${friend.username} に対局招待を送りました')),
      );
    }
  }

  Future<void> _confirmRemoveFriend(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('フレンド解除',
            style: TextStyle(color: AppTheme.textHigh)),
        content: Text(
          '${friend.username} をフレンドから解除しますか？',
          style: const TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await friendService.removeFriend(currentUserId, friend.userId);
    }
  }
}

// ── 申請タブ ──────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final FriendService friendService;
  final NetworkService networkService;
  const _RequestsTab(
      {required this.friendService, required this.networkService});

  @override
  Widget build(BuildContext context) {
    final uid = networkService.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child: Text('ログインが必要です',
              style: TextStyle(color: Colors.white54)));
    }

    return StreamBuilder<List<FriendRequest>>(
      stream: friendService.watchIncomingRequests(uid),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text('フレンド申請はありません',
                    style: TextStyle(color: AppTheme.textLow)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (_, i) {
            final req = requests[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.amber.withAlpha(60)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.brown.shade700,
                    child: Text(req.senderName[0].toUpperCase(),
                        style:
                            const TextStyle(color: AppTheme.textHigh)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req.senderName,
                            style: const TextStyle(
                                color: AppTheme.textHigh,
                                fontWeight: FontWeight.w500)),
                        Text(
                          '${RatingService().getRankLabel(req.senderRating)} (${req.senderRating})',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green),
                    onPressed: () async {
                      await friendService.acceptFriendRequest(
                          req.id, uid, req.senderId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${req.senderName} とフレンドになりました！'),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel,
                        color: Colors.red),
                    onPressed: () =>
                        friendService.declineFriendRequest(req.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── 招待タブ ──────────────────────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  final FriendService friendService;
  final NetworkService networkService;
  const _ChallengesTab(
      {required this.friendService, required this.networkService});

  @override
  Widget build(BuildContext context) {
    final uid = networkService.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child: Text('ログインが必要です',
              style: TextStyle(color: Colors.white54)));
    }

    return StreamBuilder<List<DirectChallenge>>(
      stream: friendService.watchIncomingChallenges(uid),
      builder: (context, snap) {
        final challenges = snap.data ?? [];
        if (challenges.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_esports,
                    size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text('対局招待はありません',
                    style: TextStyle(color: AppTheme.textLow)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: challenges.length,
          itemBuilder: (_, i) {
            final c = challenges[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.amber.withAlpha(80)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.brown.shade700,
                    child: const Icon(Icons.sports_esports,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.senderName} から対局招待',
                          style: const TextStyle(
                              color: AppTheme.textHigh,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${RatingService().getRankLabel(c.senderRating)} (${c.senderRating})',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await friendService.respondToChallenge(c.id, true);
                        final me = FirebaseAuth.instance.currentUser;
                        if (me == null) return;

                        final firestore = FirebaseFirestore.instance;
                        final myProfile = await networkService.getUserProfile(me.uid);
                        final matchRef = firestore.collection('matches').doc();
                        final now = DateTime.now();

                        await matchRef.set({
                          'id': matchRef.id,
                          'player1_id': c.senderId,
                          'player1_name': c.senderName,
                          'player1_rating': c.senderRating,
                          'player2_id': me.uid,
                          'player2_name': myProfile?.username ?? '自分',
                          'player2_rating': myProfile?.rating ?? 1500,
                          'board_state': '',
                          'current_turn': 1,
                          'moves': [],
                          'player1_time': 600,
                          'player2_time': 600,
                          'status': 'playing',
                          'winner': null,
                          'result': null,
                          'created_at': now,
                          'started_at': now,
                          'finished_at': null,
                        });

                        await firestore.collection('direct_challenges').doc(c.id).update({
                          'match_id': matchRef.id,
                        });

                        // RTDB盤面を初期化（MatchScreen は isPlayer1==true 側でしか
                        // 自動初期化しないが、フレンド対局では常に受諾者が isPlayer1:false
                        // で入室するため、ここで明示的に作成しないと対局が開始できない）
                        await BoardSyncService().initMatchBoard(
                          matchRef.id,
                          board: GL.initialBoard(),
                          player1Id: c.senderId,
                          player2Id: me.uid,
                          timeLimitSec: 600,
                        );

                        // 招待した側（未入室）に対局開始を通知
                        await FcmService().notifyMatchFound(
                          recipientId: c.senderId,
                          opponentName: myProfile?.username ?? '相手',
                          opponentRating: myProfile?.rating ?? 1500,
                          matchId: matchRef.id,
                        );

                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchScreen(
                              matchId: matchRef.id,
                              isPlayer1: false,
                              myPlayerId: me.uid,
                              timeLimitSec: 600,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('対局の開始に失敗しました。もう一度お試しください'),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: const Text('受ける', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () =>
                        friendService.respondToChallenge(c.id, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(
                          color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                    child: const Text('断る',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── 検索結果タイル ────────────────────────────────────────────────

class _SearchResultTile extends StatefulWidget {
  final Map<String, dynamic> user;
  final String currentUserId;
  final FriendService friendService;
  final NetworkService networkService;

  const _SearchResultTile({
    required this.user,
    required this.currentUserId,
    required this.friendService,
    required this.networkService,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final uid = widget.user['uid'] as String;
    final username = widget.user['username'] as String;
    final rating = widget.user['rating'] as int;
    final isBanned = widget.user['is_banned'] as bool? ?? false;
    final isSelf = uid == widget.currentUserId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.brown.shade700,
        child: Text(username[0].toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textHigh, fontSize: 12)),
      ),
      title: Text(username,
          style: const TextStyle(
              color: AppTheme.textHigh, fontSize: 13)),
      subtitle: Text(
          '${RatingService().getRankLabel(rating)} ($rating)',
          style: const TextStyle(
              color: AppTheme.textLow, fontSize: 11)),
      trailing: isSelf
          ? const Text('自分',
              style:
                  TextStyle(color: AppTheme.textLow, fontSize: 11))
          : isBanned
              ? const Text('停止中',
                  style: TextStyle(color: Colors.red, fontSize: 11))
              : _sent
                  ? const Icon(Icons.check, color: Colors.green, size: 18)
                  : TextButton(
                      onPressed: () async {
                        final profile = await widget.networkService
                            .getUserProfile(widget.currentUserId);
                        if (profile == null) return;
                        await widget.friendService.sendFriendRequest(
                          senderId: widget.currentUserId,
                          senderName: profile.username,
                          senderRating: profile.rating,
                          recipientId: uid,
                        );
                        setState(() => _sent = true);
                      },
                      child: const Text(
                        '申請',
                        style: TextStyle(
                            color: Colors.amber, fontSize: 12),
                      ),
                    ),
    );
  }
}
