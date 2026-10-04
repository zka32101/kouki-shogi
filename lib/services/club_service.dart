// lib/services/club_service.dart
// Club/チーム機能サービス

import 'package:cloud_firestore/cloud_firestore.dart';
import 'network_service.dart';

class Club {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String ownerName;
  final int memberCount;
  final int avgRating;
  final DateTime createdAt;
  final bool isPublic;

  const Club({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    required this.memberCount,
    required this.avgRating,
    required this.createdAt,
    required this.isPublic,
  });

  factory Club.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Club(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      ownerId: d['owner_id'] as String? ?? '',
      ownerName: d['owner_name'] as String? ?? '',
      memberCount: d['member_count'] as int? ?? 0,
      avgRating: d['avg_rating'] as int? ?? 1500,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: d['is_public'] as bool? ?? true,
    );
  }
}

class ClubMember {
  final String userId;
  final String username;
  final int rating;
  final String role; // 'owner', 'member'
  final DateTime joinedAt;

  const ClubMember({
    required this.userId,
    required this.username,
    required this.rating,
    required this.role,
    required this.joinedAt,
  });

  factory ClubMember.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClubMember(
      userId: doc.id,
      username: d['username'] as String? ?? '',
      rating: d['rating'] as int? ?? 1500,
      role: d['role'] as String? ?? 'member',
      joinedAt: (d['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ClubService {
  static final ClubService _instance = ClubService._();
  ClubService._();
  factory ClubService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NetworkService _networkService = NetworkService();

  String? get _uid => _networkService.currentUser?.uid;

  // クラブ一覧（公開）を取得
  Stream<List<Club>> watchPublicClubs() {
    return _db
        .collection('clubs')
        .where('is_public', isEqualTo: true)
        .orderBy('member_count', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(Club.fromDoc).toList());
  }

  // 自分が所属するクラブ
  Stream<List<Club>> watchMyClubs() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('clubs')
        .where('member_ids', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.map(Club.fromDoc).toList());
  }

  // クラブメンバー一覧
  Stream<List<ClubMember>> watchMembers(String clubId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .orderBy('rating', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ClubMember.fromDoc).toList());
  }

  // クラブ作成
  Future<String?> createClub({
    required String name,
    required String description,
    required bool isPublic,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    if (name.trim().isEmpty) return null;

    try {
      // 自分のユーザー情報を取得
      final userDoc = await _db.collection('users').doc(uid).get();
      final username = userDoc.data()?['username'] as String? ?? 'Unknown';
      final rating = userDoc.data()?['rating'] as int? ?? 1500;

      final batch = _db.batch();

      // クラブドキュメント
      final clubRef = _db.collection('clubs').doc();
      batch.set(clubRef, {
        'name': name.trim(),
        'description': description.trim(),
        'owner_id': uid,
        'owner_name': username,
        'member_count': 1,
        'avg_rating': rating,
        'is_public': isPublic,
        'member_ids': [uid],
        'created_at': FieldValue.serverTimestamp(),
      });

      // メンバーサブコレクション
      final memberRef = clubRef.collection('members').doc(uid);
      batch.set(memberRef, {
        'username': username,
        'rating': rating,
        'role': 'owner',
        'joined_at': FieldValue.serverTimestamp(),
      });

      // ユーザーのクラブ参照を更新
      final userRef = _db.collection('users').doc(uid);
      batch.update(userRef, {
        'club_ids': FieldValue.arrayUnion([clubRef.id]),
      });

      await batch.commit();
      return clubRef.id;
    } catch (e) {
      return null;
    }
  }

  // クラブに参加
  Future<bool> joinClub(String clubId) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final username = userDoc.data()?['username'] as String? ?? 'Unknown';
      final rating = userDoc.data()?['rating'] as int? ?? 1500;

      final batch = _db.batch();

      // クラブのメンバー数と平均レートを更新
      final clubRef = _db.collection('clubs').doc(clubId);
      batch.update(clubRef, {
        'member_count': FieldValue.increment(1),
        'member_ids': FieldValue.arrayUnion([uid]),
      });

      // メンバーサブコレクション
      final memberRef = clubRef.collection('members').doc(uid);
      batch.set(memberRef, {
        'username': username,
        'rating': rating,
        'role': 'member',
        'joined_at': FieldValue.serverTimestamp(),
      });

      // ユーザーのクラブ参照を更新
      final userRef = _db.collection('users').doc(uid);
      batch.update(userRef, {
        'club_ids': FieldValue.arrayUnion([clubId]),
      });

      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  // クラブを退会
  Future<bool> leaveClub(String clubId) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final batch = _db.batch();

      final clubRef = _db.collection('clubs').doc(clubId);
      batch.update(clubRef, {
        'member_count': FieldValue.increment(-1),
        'member_ids': FieldValue.arrayRemove([uid]),
      });

      batch.delete(clubRef.collection('members').doc(uid));

      final userRef = _db.collection('users').doc(uid);
      batch.update(userRef, {
        'club_ids': FieldValue.arrayRemove([clubId]),
      });

      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  // クラブ名検索
  Future<List<Club>> searchClubs(String query) async {
    if (query.isEmpty) return [];
    try {
      final snap = await _db
          .collection('clubs')
          .where('is_public', isEqualTo: true)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query')
          .limit(20)
          .get();
      return snap.docs.map(Club.fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  // 自分がメンバーか確認
  Future<bool> isMember(String clubId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(uid)
        .get();
    return doc.exists;
  }
}
