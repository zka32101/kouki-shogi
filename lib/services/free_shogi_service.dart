// 自由将棋のテンプレート管理・保存機能
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/free_shogi_config.dart';
import '../piece.dart';

class FreeShogiFiemplateService {
  static const String _localKey = 'free_shogi_templates';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ローカル：テンプレート一覧を取得
  Future<List<FreeShogiFiemplateEntry>> getLocalTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localKey);
      if (jsonStr == null) return [];
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => FreeShogiFiemplateEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ローカル：テンプレートを保存
  Future<void> saveLocalTemplate(FreeShogiFiemplateEntry template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getLocalTemplates();
      final idx = existing.indexWhere((t) => t.id == template.id);
      if (idx >= 0) {
        existing[idx] = template;
      } else {
        existing.add(template);
      }
      final jsonStr = jsonEncode(existing.map((t) => t.toJson()).toList());
      await prefs.setString(_localKey, jsonStr);
    } catch (e) {
      rethrow;
    }
  }

  /// ローカル：テンプレートを削除
  Future<void> deleteLocalTemplate(String templateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getLocalTemplates();
      existing.removeWhere((t) => t.id == templateId);
      final jsonStr = jsonEncode(existing.map((t) => t.toJson()).toList());
      await prefs.setString(_localKey, jsonStr);
    } catch (e) {
      rethrow;
    }
  }

  /// Firebase：テンプレートを保存（ユーザー公開用）
  Future<void> savePublicTemplate(
    String uid,
    FreeShogiFiemplateEntry template,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('free_shogi_templates')
          .doc(template.id)
          .set(template.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Firebase：ユーザーのテンプレート一覧を取得
  Future<List<FreeShogiFiemplateEntry>> getPublicTemplates(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('free_shogi_templates')
          .get();
      return snap.docs
          .map((doc) => FreeShogiFiemplateEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Firebase：テンプレートを削除
  Future<void> deletePublicTemplate(String uid, String templateId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('free_shogi_templates')
          .doc(templateId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// デフォルトテンプレート（標準将棋）を生成
  static FreeShogiFiemplateEntry createStandardTemplate() {
    // 標準的な将棋の初期配置を生成（簡略版）
    // 実装時に正確な初期配置で埋める
    final p1Board = List.generate(9, (_) => List<Piece?>.filled(9, null));
    final p2Board = List.generate(9, (_) => List<Piece?>.filled(9, null));

    return FreeShogiFiemplateEntry(
      id: 'standard_shogi',
      name: '標準将棋',
      description: '通常の将棋初期配置',
      p1Board: p1Board,
      p2Board: p2Board,
    );
  }
}
