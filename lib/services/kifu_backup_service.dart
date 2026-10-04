// lib/services/kifu_backup_service.dart
// クラウド棋譜バックアップ / リストアサービス

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KifuBackupService {
  static final KifuBackupService _instance = KifuBackupService._();
  factory KifuBackupService() => _instance;
  KifuBackupService._();

  static const _col = 'kifu_backups';
  static const _localKey = 'kifu_records';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── バックアップ ────────────────────────────────────────────

  /// ローカルの全棋譜をFirestoreにアップロード
  /// 返り値: アップロードした棋譜数（失敗時は-1）
  Future<int> backupAll() async {
    final uid = _uid;
    if (uid == null) return -1;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final records = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (records.isEmpty) return 0;

      final batch = _db.batch();
      final userBackupRef = _db.collection(_col).doc(uid);

      // メタドキュメント（最終バックアップ日時など）
      batch.set(userBackupRef, {
        'uid': uid,
        'count': records.length,
        'backed_up_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 各棋譜をサブコレクションに保存（日付IDをキーに）
      for (final record in records) {
        final date = (record['date'] as String? ?? '').replaceAll(RegExp(r'[/:. ]'), '_');
        final modeRaw = (record['mode'] as String?) ?? 'game';
        final mode = modeRaw.isEmpty
            ? 'game'
            : modeRaw.substring(0, modeRaw.length < 4 ? modeRaw.length : 4);
        final moveCount = record['moveCount'] as int? ?? 0;
        final docId = '${date}_${mode}_$moveCount'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
        final docRef = userBackupRef.collection('records').doc(docId.isEmpty ? null : docId);
        batch.set(docRef, {
          ...record,
          'synced_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return records.length;
    } catch (e) {
      return -1;
    }
  }

  // ── リストア ────────────────────────────────────────────────

  /// Firestoreから棋譜を取得してローカルにマージ
  /// 返り値: リストアした棋譜数（失敗時は-1）
  Future<int> restoreAll() async {
    final uid = _uid;
    if (uid == null) return -1;

    try {
      final snap = await _db
          .collection(_col)
          .doc(uid)
          .collection('records')
          .orderBy('synced_at', descending: true)
          .limit(300)
          .get();

      if (snap.docs.isEmpty) return 0;

      final cloudRecords = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data.remove('synced_at'); // Firestoreのタイムスタンプを除去
        return data;
      }).toList();

      // ローカルとマージ（重複は日付+手数でチェック）
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final localRecords = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

      final localKeys = localRecords
          .map((r) => '${r['date']}_${r['moveCount']}')
          .toSet();

      int added = 0;
      for (final cloud in cloudRecords) {
        final key = '${cloud['date']}_${cloud['moveCount']}';
        if (!localKeys.contains(key)) {
          localRecords.add(cloud);
          localKeys.add(key);
          added++;
        }
      }

      if (added > 0) {
        // 日付降順でソート
        localRecords.sort((a, b) =>
            (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
        await prefs.setString(_localKey, jsonEncode(localRecords));
      }

      return added;
    } catch (e) {
      return -1;
    }
  }

  // ── バックアップ情報取得 ─────────────────────────────────────

  /// 最後のバックアップ情報を取得
  Future<({DateTime? backedUpAt, int count})> getBackupInfo() async {
    final uid = _uid;
    if (uid == null) return (backedUpAt: null, count: 0);

    try {
      final doc = await _db.collection(_col).doc(uid).get();
      if (!doc.exists) return (backedUpAt: null, count: 0);

      final data = doc.data()!;
      final ts = data['backed_up_at'] as Timestamp?;
      final count = data['count'] as int? ?? 0;
      return (backedUpAt: ts?.toDate(), count: count);
    } catch (_) {
      return (backedUpAt: null, count: 0);
    }
  }
}
