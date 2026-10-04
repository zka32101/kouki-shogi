// lib/screens/club_screen.dart
// Club/チーム機能画面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/club_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ClubService _clubService = ClubService();
  final NetworkService _networkService = NetworkService();

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
        title: const Text('クラブ', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: AppTheme.textHigh),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.textHigh),
            onPressed: () => _showCreateClubDialog(context),
            tooltip: 'クラブを作成',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMid,
          tabs: const [
            Tab(text: '公開クラブ'),
            Tab(text: 'マイクラブ'),
            Tab(text: '掲示板'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PublicClubsTab(clubService: _clubService),
          _MyClubsTab(clubService: _clubService),
          const _GlobalBulletinTab(),
        ],
      ),
    );
  }

  void _showCreateClubDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('クラブを作成', style: TextStyle(color: AppTheme.textHigh)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                maxLength: 24,
                style: const TextStyle(color: AppTheme.textHigh),
                decoration: const InputDecoration(
                  labelText: 'クラブ名 *',
                  labelStyle: TextStyle(color: AppTheme.textMid),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textLow),
                  ),
                ),
              ),
              TextField(
                controller: descCtrl,
                maxLength: 100,
                maxLines: 2,
                style: const TextStyle(color: AppTheme.textHigh),
                decoration: const InputDecoration(
                  labelText: '説明',
                  labelStyle: TextStyle(color: AppTheme.textMid),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textLow),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('公開クラブ', style: TextStyle(color: AppTheme.textMid)),
                const Spacer(),
                Switch(
                  value: isPublic,
                  activeColor: AppTheme.accent,
                  onChanged: (v) => setDlgState(() => isPublic = v),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final clubId = await _clubService.createClub(
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  isPublic: isPublic,
                );
                if (clubId != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('クラブを作成しました！')),
                  );
                  _tabController.animateTo(1);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('作成', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 公開クラブ一覧 ─────────────────────────────────────────────

class _PublicClubsTab extends StatelessWidget {
  final ClubService clubService;
  const _PublicClubsTab({required this.clubService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Club>>(
      stream: clubService.watchPublicClubs(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final clubs = snap.data ?? [];
        if (clubs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, color: AppTheme.textLow, size: 64),
                SizedBox(height: 12),
                Text('公開クラブがありません', style: TextStyle(color: AppTheme.textMid)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: clubs.length,
          itemBuilder: (ctx, i) => _ClubTile(
            club: clubs[i],
            clubService: clubService,
          ),
        );
      },
    );
  }
}

// ── マイクラブ ─────────────────────────────────────────────────

class _MyClubsTab extends StatelessWidget {
  final ClubService clubService;
  const _MyClubsTab({required this.clubService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Club>>(
      stream: clubService.watchMyClubs(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final clubs = snap.data ?? [];
        if (clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add, color: AppTheme.textLow, size: 64),
                const SizedBox(height: 12),
                const Text('クラブに参加していません',
                    style: TextStyle(color: AppTheme.textMid)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  label: const Text('クラブを探す'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: clubs.length,
          itemBuilder: (ctx, i) => _ClubTile(
            club: clubs[i],
            clubService: clubService,
            isMine: true,
          ),
        );
      },
    );
  }
}

// ── クラブカード ───────────────────────────────────────────────

class _ClubTile extends StatelessWidget {
  final Club club;
  final ClubService clubService;
  final bool isMine;

  const _ClubTile({
    required this.club,
    required this.clubService,
    this.isMine = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubDetailScreen(club: club),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMine ? AppTheme.accent.withAlpha(80) : AppTheme.textLow.withAlpha(30),
          ),
        ),
        child: Row(children: [
          // アイコン
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.brown.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                club.name.isNotEmpty ? club.name[0] : '?',
                style: const TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      club.name,
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (!club.isPublic)
                    const Icon(Icons.lock, color: AppTheme.textLow, size: 14),
                ]),
                const SizedBox(height: 2),
                if (club.description.isNotEmpty)
                  Text(
                    club.description,
                    style: const TextStyle(color: AppTheme.textMid, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.people, color: AppTheme.textLow, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '${club.memberCount}人',
                    style: const TextStyle(color: AppTheme.textLow, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.military_tech, color: AppTheme.textLow, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '平均${club.avgRating}',
                    style: const TextStyle(color: AppTheme.textLow, fontSize: 11),
                  ),
                ]),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppTheme.textLow, size: 14),
        ]),
      ),
    );
  }
}

// ── クラブ詳細 ─────────────────────────────────────────────────

class ClubDetailScreen extends StatefulWidget {
  final Club club;
  const ClubDetailScreen({super.key, required this.club});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  final ClubService _clubService = ClubService();
  final NetworkService _networkService = NetworkService();
  bool _isMember = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    final result = await _clubService.isMember(widget.club.id);
    if (mounted) setState(() => _isMember = result);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _networkService.currentUser?.uid;
    final isOwner = widget.club.ownerId == myUid;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(widget.club.name, style: const TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: AppTheme.textHigh),
        actions: [
          if (_isMember && !isOwner)
            TextButton(
              onPressed: _leaveClub,
              child: const Text('退会', style: TextStyle(color: AppTheme.danger)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.brown.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    widget.club.name.isNotEmpty ? widget.club.name[0] : '?',
                    style: const TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.club.name,
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.club.memberCount}人 • 平均${widget.club.avgRating}',
                      style: const TextStyle(color: AppTheme.textMid, fontSize: 12),
                    ),
                    if (widget.club.description.isNotEmpty)
                      Text(
                        widget.club.description,
                        style: const TextStyle(color: AppTheme.textMid, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!_isMember)
                ElevatedButton(
                  onPressed: _joining ? null : _joinClub,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('参加'),
                ),
            ]),
          ),

          // メンバー一覧
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'メンバー',
                style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClubMember>>(
              stream: _clubService.watchMembers(widget.club.id),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snap.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length,
                  itemBuilder: (ctx, i) => _MemberTile(
                    member: members[i],
                    rank: i + 1,
                    ownerId: widget.club.ownerId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinClub() async {
    setState(() => _joining = true);
    final ok = await _clubService.joinClub(widget.club.id);
    if (mounted) {
      setState(() {
        _joining = false;
        _isMember = ok;
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.club.name} に参加しました！')),
        );
      }
    }
  }

  Future<void> _leaveClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('退会確認', style: TextStyle(color: AppTheme.textHigh)),
        content: Text(
          '${widget.club.name} を退会しますか？',
          style: const TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('退会'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await _clubService.leaveClub(widget.club.id);
    if (ok && mounted) {
      Navigator.pop(context);
    }
  }
}

// ── グローバル掲示板タブ ────────────────────────────────────────

class _GlobalBulletinTab extends StatefulWidget {
  const _GlobalBulletinTab();

  @override
  State<_GlobalBulletinTab> createState() => _GlobalBulletinTabState();
}

class _GlobalBulletinTabState extends State<_GlobalBulletinTab> {
  final _db = FirebaseFirestore.instance;
  final _networkService = NetworkService();
  final _ctrl = TextEditingController();
  bool _posting = false;

  String get _postsPath => 'club_bulletin';

  Stream<QuerySnapshot> _postsStream() => _db
      .collection(_postsPath)
      .orderBy('created_at', descending: true)
      .limit(50)
      .snapshots();

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = _networkService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _posting = true);
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final username = userDoc.data()?['username'] as String? ?? 'ゲスト';
      await _db.collection(_postsPath).add({
        'text': text,
        'author_id': uid,
        'author_name': username,
        'created_at': FieldValue.serverTimestamp(),
      });
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _networkService.currentUser?.uid;
    return Column(children: [
      // 投稿フォーム
      Container(
        padding: const EdgeInsets.all(12),
        color: AppTheme.surface,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(color: AppTheme.textHigh),
              decoration: InputDecoration(
                hintText: '掲示板に投稿...',
                hintStyle: const TextStyle(color: AppTheme.textLow),
                counterStyle: const TextStyle(color: AppTheme.textLow),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _posting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, color: AppTheme.accent),
            onPressed: _posting ? null : _post,
          ),
        ]),
      ),
      // 投稿一覧
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _postsStream(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum, color: AppTheme.textLow, size: 48),
                    SizedBox(height: 12),
                    Text('まだ投稿がありません', style: TextStyle(color: AppTheme.textLow)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final isMe = d['author_id'] == myUid;
                final ts = d['created_at'] as Timestamp?;
                final time = ts != null
                    ? _fmtTs(ts.toDate())
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.catSocial.withAlpha(40)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMe ? AppTheme.catSocial.withAlpha(80) : AppTheme.textLow.withAlpha(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          d['author_name'] as String? ?? '?',
                          style: TextStyle(
                            color: isMe ? AppTheme.catSocial : AppTheme.textMid,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(time, style: const TextStyle(color: AppTheme.textLow, fontSize: 10)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        d['text'] as String? ?? '',
                        style: const TextStyle(color: AppTheme.textHigh, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  String _fmtTs(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inHours < 1) return '${diff.inMinutes}分前';
    if (diff.inDays < 1) return '${diff.inHours}時間前';
    return '${dt.month}/${dt.day}';
  }
}

// ── メンバータイル ─────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final ClubMember member;
  final int rank;
  final String ownerId;

  const _MemberTile({
    required this.member,
    required this.rank,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = member.userId == ownerId;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textLow, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.brown.shade700,
          child: Text(
            member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.textHigh, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                member.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textHigh, fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            if (isOwner)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.accent.withAlpha(80)),
                ),
                child: const Text(
                  'オーナー',
                  style: TextStyle(color: AppTheme.accent, fontSize: 9),
                ),
              ),
          ]),
        ),
        Text(
          '${member.rating}',
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }
}
