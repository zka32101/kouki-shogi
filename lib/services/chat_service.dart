// lib/services/chat_service.dart
// 対局中チャット + 定型文メッセージ（RTDB版：低遅延・Firestoreルール不要）

import 'package:firebase_database/firebase_database.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final bool isPreset;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.isPreset = false,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'text': text,
        'is_preset': isPreset,
        'sent_at': sentAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromJson(String id, Map<dynamic, dynamic> json) =>
      ChatMessage(
        id: id,
        senderId: json['sender_id'] as String? ?? '',
        senderName: json['sender_name'] as String? ?? '?',
        text: json['text'] as String? ?? '',
        isPreset: json['is_preset'] as bool? ?? false,
        sentAt: DateTime.fromMillisecondsSinceEpoch(
            json['sent_at'] as int? ?? 0),
      );
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  static const List<String> presetMessages = [
    'よろしくお願いします🙇',
    'ありがとうございました🙏',
    'お疲れ様でした！',
    '良い対局でした👍',
    'もう一局お願いします！',
    '考え中...',
    '惜しかった！',
    '参りました🙇',
  ];

  DatabaseReference _chatRef(String matchId) =>
      _rtdb.ref('games/$matchId/chat');

  // ── 対局中チャット（RTDB） ──────────────────────────────

  Future<void> sendPresetMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String presetText,
  }) async {
    try {
      final ref = _chatRef(matchId).push();
      await ref.set({
        'id': ref.key,
        'sender_id': senderId,
        'sender_name': senderName,
        'text': presetText,
        'is_preset': true,
        'sent_at': ServerValue.timestamp,
      });
    } catch (e) {
      print('Send preset message error: $e');
    }
  }

  Stream<List<ChatMessage>> watchMessages(String matchId) {
    return _chatRef(matchId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <ChatMessage>[];
      try {
        final map = Map<dynamic, dynamic>.from(raw as Map);
        final entries = map.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        return entries.map((e) {
          final data = Map<dynamic, dynamic>.from(e.value as Map);
          return ChatMessage.fromJson(e.key.toString(), data);
        }).toList();
      } catch (_) {
        return <ChatMessage>[];
      }
    });
  }

  // ── 感想戦チャット（RTDB） ──────────────────────────────

  DatabaseReference _postChatRef(String matchId) =>
      _rtdb.ref('games/$matchId/post_chat');

  Future<void> sendPostMatchMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      final ref = _postChatRef(matchId).push();
      await ref.set({
        'id': ref.key,
        'sender_id': senderId,
        'sender_name': senderName,
        'text': text,
        'is_preset': false,
        'sent_at': ServerValue.timestamp,
      });
    } catch (e) {
      print('Send post match message error: $e');
    }
  }

  Stream<List<ChatMessage>> watchPostMatchMessages(String matchId) {
    return _postChatRef(matchId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <ChatMessage>[];
      try {
        final map = Map<dynamic, dynamic>.from(raw as Map);
        final entries = map.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        return entries.map((e) {
          final data = Map<dynamic, dynamic>.from(e.value as Map);
          return ChatMessage.fromJson(e.key.toString(), data);
        }).toList();
      } catch (_) {
        return <ChatMessage>[];
      }
    });
  }
}
