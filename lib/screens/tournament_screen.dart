// lib/screens/tournament_screen.dart
// トーナメント画面（一覧 + 詳細ブラケット表示）

import 'package:flutter/material.dart';
import '../services/tournament_service.dart';
import '../services/network_service.dart';
import '../services/rating_service.dart';
import '../services/network_achievement_service.dart';
import '../theme/app_theme.dart';

// ── 一覧画面 ─────────────────────────────────────────────────

class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title:
            const Text('トーナメント', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showCreateDialog(context),
            tooltip: '新規作成',
          ),
        ],
      ),
      body: _TournamentList(),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();
    int selectedSize = 8;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('トーナメントを作成',
              style: TextStyle(color: AppTheme.textHigh)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 24,
                style: const TextStyle(color: AppTheme.textHigh),
                decoration: const InputDecoration(
                  hintText: 'トーナメント名',
                  hintStyle: TextStyle(color: AppTheme.textLow),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textLow),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('人数',
                      style: TextStyle(color: AppTheme.textMid)),
                  DropdownButton<int>(
                    value: selectedSize,
                    dropdownColor: AppTheme.surface,
                    items: [4, 8, 16, 32]
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text('$n名',
                                  style:
                                      const TextStyle(color: AppTheme.textHigh)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setSt(() => selectedSize = v ?? 8),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final networkService = NetworkService();
    final uid = networkService.currentUser?.uid;
    if (uid == null) return;

    final id = await TournamentService().createTournament(
      creatorId: uid,
      name: name,
      maxPlayers: selectedSize,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournamentId: id),
        ),
      );
    }
  }
}

class _TournamentList extends StatelessWidget {
  final TournamentService _service = TournamentService();

  _TournamentList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tournament>>(
      stream: _service.watchOpenTournaments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tournaments = snap.data ?? [];

        if (tournaments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events,
                    size: 64, color: Colors.white24),
                const SizedBox(height: 12),
                const Text('トーナメントがありません',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => const TournamentListScreen()
                      ._showCreateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('作成する'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catPlay,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tournaments.length,
          itemBuilder: (_, i) => _TournamentTile(tournament: tournaments[i]),
        );
      },
    );
  }
}

class _TournamentTile extends StatelessWidget {
  final Tournament tournament;
  const _TournamentTile({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final statusColor = tournament.status == 'open'
        ? Colors.green
        : tournament.status == 'started'
            ? Colors.amber
            : Colors.grey;
    final statusLabel = tournament.status == 'open'
        ? '参加受付中'
        : tournament.status == 'started'
            ? '進行中'
            : '終了';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TournamentDetailScreen(tournamentId: tournament.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // トロフィーアイコン
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: const TextStyle(
                          color: AppTheme.textHigh,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${tournament.entries.length}/${tournament.maxPlayers}名 • ${tournament.currentRound == 0 ? "開始前" : "${tournament.currentRound}回戦"}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 詳細画面（ブラケット表示） ────────────────────────────────

class TournamentDetailScreen extends StatelessWidget {
  final String tournamentId;
  final TournamentService _service = TournamentService();
  final NetworkService _networkService = NetworkService();
  final RatingService _ratingService = RatingService();

  TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('トーナメント詳細',
            style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<Tournament?>(
        stream: _service.watchTournament(tournamentId),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = snap.data!;
          return _buildBody(context, t);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Tournament t) {
    final myId = _networkService.currentUser?.uid;
    final isEntered = t.entries.any((e) => e.userId == myId);
    final isCreator = t.creatorId == myId;

    // 優勝実績の付与はusers/{uid}への書き込みが本人のみ許可されているため、
    // 対局結果を確定させた側(勝者・敗者どちらの端末でもありうる)ではなく、
    // 優勝者自身のセッションで判定・付与する必要がある
    if (t.status == 'finished' && t.championId != null && t.championId == myId) {
      NetworkAchievementService().checkTournamentWin(myId!);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ヘッダー
        _buildHeader(t),
        const SizedBox(height: 16),

        // アクションボタン
        if (t.status == 'open') ...[
          if (!isEntered)
            ElevatedButton.icon(
              onPressed: () => _join(context, t),
              icon: const Icon(Icons.login),
              label: const Text('エントリーする'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: () => _leave(context, t),
              icon: const Icon(Icons.logout),
              label: const Text('キャンセル'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isCreator && t.entries.length >= 2)
            ElevatedButton.icon(
              onPressed: () => _start(context, t),
              icon: const Icon(Icons.play_arrow),
              label: const Text('トーナメント開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.catPlay,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // 参加者一覧
        _buildEntryList(t),
        const SizedBox(height: 16),

        // ブラケット表示
        if (t.matches.isNotEmpty) ...[
          const Text('ブラケット',
              style: TextStyle(
                  color: AppTheme.textHigh,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          _buildBracket(context, t),
        ],
      ],
    );
  }

  Widget _buildHeader(Tournament t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textHigh,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _infoChip('参加者',
                  '${t.entries.length}/${t.maxPlayers}名'),
              _infoChip('ラウンド',
                  t.currentRound == 0 ? '開始前' : '第${t.currentRound}回戦'),
              _infoChip('状態',
                  t.status == 'open'
                      ? '受付中'
                      : t.status == 'started'
                          ? '進行中'
                          : '終了'),
            ],
          ),
          if (t.status == 'finished' && t.championId != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final championName = t.entries
                  .firstWhere(
                    (e) => e.userId == t.championId,
                    orElse: () => TournamentEntry(
                        userId: t.championId!, username: '?', rating: 0),
                  )
                  .username;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 6),
                  Text('優勝: $championName',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold)),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textHigh, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEntryList(Tournament t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('参加者',
            style: TextStyle(
                color: AppTheme.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 8),
        ...t.entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        e.username.isNotEmpty
                            ? e.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppTheme.textHigh,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textHigh)),
                  ),
                  Text(
                    '${_ratingService.getRankLabel(e.rating)} ${e.rating}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildBracket(BuildContext context, Tournament t) {
    final maxRound = t.currentRound;
    if (maxRound == 0) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(maxRound, (roundIdx) {
          final round = roundIdx + 1;
          final roundMatches =
              t.matches.where((m) => m.round == round).toList();
          roundMatches.sort((a, b) => a.position.compareTo(b.position));

          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  round == maxRound && roundMatches.length == 1
                      ? '決勝'
                      : '第$round回戦',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ...roundMatches.map((m) => _buildMatchCard(context, m, t)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMatchCard(
      BuildContext context, TournamentMatch m, Tournament t) {
    final isFinished = m.isFinished;
    final myId = _networkService.currentUser?.uid;
    final isMyMatch =
        m.player1?.userId == myId || m.player2?.userId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMyMatch
            ? Colors.blue.shade900.withAlpha(80)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: isMyMatch
            ? Border.all(color: AppTheme.accent.withAlpha(100), width: 1)
            : null,
      ),
      child: Column(
        children: [
          _playerRow(m.player1, m.winnerId),
          const Divider(color: Colors.white12, height: 8),
          m.player2 != null
              ? _playerRow(m.player2, m.winnerId)
              : const Text('BYE',
                  style: TextStyle(color: AppTheme.textLow, fontSize: 11)),
          if (m.status == 'pending' && isMyMatch) ...[
            const SizedBox(height: 4),
            if (m.isDisputed)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('相手の申告と食い違っています。再度申告してください',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10)),
              )
            else if (m.reportedWinnerIdFor(myId ?? '') != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('申告済み・相手の確認待ちです',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 10)),
              ),
            GestureDetector(
              onTap: () => _showMatchActions(context, m, t),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.reportedWinnerIdFor(myId ?? '') != null ? '申告し直す' : '対局する',
                  style: const TextStyle(color: Colors.amber, fontSize: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playerRow(TournamentEntry? player, String? winnerId) {
    if (player == null) return const SizedBox.shrink();
    final isWinner = player.userId == winnerId;
    return Row(
      children: [
        Icon(
          isWinner ? Icons.emoji_events : Icons.person_outline,
          size: 12,
          color: isWinner ? Colors.amber : AppTheme.textLow,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            player.username,
            style: TextStyle(
              color: isWinner ? Colors.amber : AppTheme.textHigh,
              fontSize: 12,
              fontWeight:
                  isWinner ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${player.rating}',
          style: const TextStyle(color: AppTheme.textLow, fontSize: 10),
        ),
      ],
    );
  }

  Future<void> _join(BuildContext context, Tournament t) async {
    final myId = _networkService.currentUser?.uid;
    if (myId == null) return;
    final profile = await _networkService.getUserProfile(myId);
    if (profile == null) return;

    final entry = TournamentEntry(
      userId: myId,
      username: profile.username,
      rating: profile.rating,
    );

    final success = await _service.joinTournament(t.id, entry);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                success ? 'エントリーしました！' : '参加できませんでした')),
      );
    }
  }

  Future<void> _leave(BuildContext context, Tournament t) async {
    final myId = _networkService.currentUser?.uid;
    if (myId == null) return;
    await _service.leaveTournament(t.id, myId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エントリーをキャンセルしました')),
      );
    }
  }

  Future<void> _start(BuildContext context, Tournament t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('トーナメントを開始'),
        content: Text('${t.entries.length}名でトーナメントを開始しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('開始')),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.startTournament(t.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('トーナメントを開始しました！')),
      );
    }
  }

  Future<void> _showMatchActions(
      BuildContext context, TournamentMatch m, Tournament t) async {
    final myId = _networkService.currentUser?.uid;
    if (myId == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('対局',
            style: TextStyle(color: AppTheme.textHigh)),
        content: Text(
          '${m.player1?.username ?? "?"} vs ${m.player2?.username ?? "?"}',
          style: const TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'p1_win'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white),
            child: Text('${m.player1?.username ?? "先手"} 勝利'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'p2_win'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.catPlay,
                foregroundColor: Colors.white),
            child: Text('${m.player2?.username ?? "後手"} 勝利'),
          ),
        ],
      ),
    );

    if (action == null) return;
    final winnerId = action == 'p1_win'
        ? m.player1?.userId
        : m.player2?.userId;
    if (winnerId == null) return;

    final result =
        await _service.reportMatchResult(t.id, m.id, myId, winnerId);
    if (!context.mounted) return;
    final message = switch (result) {
      'confirmed' => '両者の申告が一致し、結果が確定しました！',
      'recorded' => '申告を受け付けました。相手の確認をお待ちください',
      'disputed' => '相手の申告と食い違いがあります。お互い確認して再度申告してください',
      _ => 'エラーが発生しました',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result == 'disputed' || result == 'error'
            ? Colors.red
            : null,
      ),
    );
  }
}
