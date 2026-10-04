// lib/screens/spectator_screen.dart
// ライブ対局観戦画面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/spectator_service.dart';
import '../services/network_service.dart';
import '../services/board_sync_service.dart';
import 'network_board_widget.dart';
import '../theme/app_theme.dart';

class SpectatorListScreen extends StatelessWidget {
  const SpectatorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ライブ観戦', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _LiveMatchList(),
    );
  }
}

class _LiveMatchList extends StatelessWidget {
  final SpectatorService _spectatorService = SpectatorService();

  _LiveMatchList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveMatch>>(
      stream: _spectatorService.watchLiveMatches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.live_tv, size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text('現在ライブ対局はありません',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: matches.length,
          itemBuilder: (_, i) => _LiveMatchTile(match: matches[i]),
        );
      },
    );
  }
}

class _LiveMatchTile extends StatelessWidget {
  final LiveMatch match;
  const _LiveMatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(match.startedAt);
    final elapsedStr =
        '${elapsed.inMinutes}分${elapsed.inSeconds % 60}秒';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown.shade800, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpectatorGameScreen(matchId: match.matchId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ライブバッジ
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              // 対局情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.player1Name} (${match.player1Rating})'
                      ' vs '
                      '${match.player2Name} (${match.player2Rating})',
                      style: const TextStyle(
                          color: AppTheme.textHigh,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${match.moveCount}手 • $elapsedStr経過',
                      style: const TextStyle(
                          color: AppTheme.textLow, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // 観戦者数
              Column(
                children: [
                  const Icon(Icons.visibility,
                      size: 14, color: AppTheme.textLow),
                  Text(
                    '${match.spectatorCount}',
                    style: const TextStyle(
                        color: AppTheme.textLow, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 観戦画面 ──────────────────────────────────────────────────

class SpectatorGameScreen extends StatefulWidget {
  final String matchId;
  const SpectatorGameScreen({super.key, required this.matchId});

  @override
  State<SpectatorGameScreen> createState() => _SpectatorGameScreenState();
}

class _SpectatorGameScreenState extends State<SpectatorGameScreen> {
  final SpectatorService _spectatorService = SpectatorService();
  final NetworkService _networkService = NetworkService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _showChat = true;

  @override
  void initState() {
    super.initState();
    final uid = _networkService.currentUser?.uid;
    if (uid != null) {
      _spectatorService.joinSpectate(widget.matchId, uid);
    }
  }

  @override
  void dispose() {
    final uid = _networkService.currentUser?.uid;
    if (uid != null) {
      _spectatorService.leaveSpectate(widget.matchId, uid);
    }
    _commentController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final user = _networkService.currentUser;
    if (user == null) return;

    final profile = await _networkService.getUserProfile(user.uid);
    _commentController.clear();

    await _spectatorService.sendSpectatorComment(
      widget.matchId,
      user.uid,
      profile?.username ?? '観戦者',
      text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('観戦中', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.chat,
                color: _showChat ? Colors.amber : Colors.white70),
            onPressed: () => setState(() => _showChat = !_showChat),
            tooltip: '観戦チャット',
          ),
        ],
      ),
      body: StreamBuilder<NetworkBoardState?>(
        stream: _spectatorService.watchBoardAsSpectator(widget.matchId),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final state = snap.data!;

          if (state.isFinished) {
            return _buildFinishedScreen(state);
          }

          final currentIsP1 = state.currentTurn == 1;
          final turnName = currentIsP1 ? '先手' : '後手';

          return SafeArea(
            child: Column(
              children: [
                // プレイヤーバー
                _buildPlayerHeader(state),

                // 手番インジケーター
                Container(
                  color: const Color(0xFF0F0F2E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$turnName の番 (${state.moveCount}手目)',
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '観戦モード',
                        style: const TextStyle(
                            color: AppTheme.textLow, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // 盤面（操作不可）
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: IgnorePointer(
                            child: NetworkBoardWidget(
                              state: state,
                              isPlayer1: true, // 先手視点で表示
                              isMyTurn: false,
                              onMove: (_) {},
                            ),
                          ),
                        ),
                      ),
                      if (_showChat)
                        SizedBox(
                          width: 140,
                          child: _buildSpectatorChat(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerHeader(NetworkBoardState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surface,
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .get(),
        builder: (context, snap) {
          final p1 = snap.data?['player1_name'] as String? ?? '先手';
          final p2 = snap.data?['player2_name'] as String? ?? '後手';
          final r1 = snap.data?['player1_rating'] as int? ?? 1500;
          final r2 = snap.data?['player2_rating'] as int? ?? 1500;
          final spec = snap.data?['spectator_count'] as int? ?? 0;

          return Row(
            children: [
              Expanded(
                child: Text('▲$p1($r1)',
                    style: const TextStyle(color: AppTheme.textHigh, fontSize: 12)),
              ),
              const Text('vs',
                  style: TextStyle(color: AppTheme.textLow, fontSize: 11)),
              Expanded(
                child: Text('△$p2($r2)',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppTheme.textHigh, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.visibility, size: 12, color: AppTheme.textLow),
              Text(' $spec',
                  style:
                      const TextStyle(color: AppTheme.textLow, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpectatorChat() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          color: const Color(0xFF0F0F2E),
          child: const Text('観戦チャット',
              style: TextStyle(color: Colors.amber, fontSize: 11)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _spectatorService.watchSpectatorChat(widget.matchId),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_chatScrollController.hasClients) {
                  _chatScrollController.jumpTo(
                      _chatScrollController.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(4),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data =
                      docs[i].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${data['username']}: ',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: data['text'] as String? ?? '',
                            style: const TextStyle(
                              color: AppTheme.textMid,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // コメント入力
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLength: 40,
                  style: const TextStyle(color: AppTheme.textHigh, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'コメント...',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 10),
                    filled: true,
                    fillColor: AppTheme.surface,
                    counterText: '',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.send,
                    size: 16, color: Colors.amber),
                onPressed: _sendComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedScreen(NetworkBoardState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_kabaddi,
              size: 64, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('対局終了', style: TextStyle(color: AppTheme.textHigh, fontSize: 20)),
          const SizedBox(height: 8),
          Text('${state.moveCount}手で終了',
              style: const TextStyle(color: AppTheme.textMid)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catPlay,
              foregroundColor: Colors.white,
            ),
            child: const Text('一覧に戻る'),
          ),
        ],
      ),
    );
  }
}
