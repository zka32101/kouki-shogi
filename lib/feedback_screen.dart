// lib/feedback_screen.dart — バグ報告・改善要望フォーム

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'piece.dart';
import 'theme/app_theme.dart';

// ===== SFEN エンコーダ（盤面→SFEN文字列） =====
// SFEN 標準形式: 大文字=先手, 小文字=後手, +P/+p=成り駒
const _sfenChar = {
  PieceType.king:          'K',
  PieceType.rook:          'R',
  PieceType.bishop:        'B',
  PieceType.gold:          'G',
  PieceType.silver:        'S',
  PieceType.knight:        'N',
  PieceType.lance:         'L',
  PieceType.pawn:          'P',
  PieceType.promotedRook:  '+R',
  PieceType.promotedBishop:'+B',
  PieceType.promotedSilver:'+S',
  PieceType.promotedKnight:'+N',
  PieceType.promotedLance: '+L',
  PieceType.promotedPawn:  '+P',
};

String boardToSfen(List<List<Piece?>> board) {
  final rows = <String>[];
  for (int r = 0; r < 9; r++) {
    var empty = 0;
    var rowStr = '';
    for (int c = 0; c < 9; c++) {
      final p = board[r][c];
      if (p == null) {
        empty++;
      } else {
        if (empty > 0) { rowStr += empty.toString(); empty = 0; }
        var ch = _sfenChar[p.type] ?? '?';
        if (!p.isPlayer1) {
          // 後手は小文字（+P → +p）
          ch = ch.startsWith('+')
              ? '+${ch.substring(1).toLowerCase()}'
              : ch.toLowerCase();
        }
        rowStr += ch;
      }
    }
    if (empty > 0) rowStr += empty.toString();
    rows.add(rowStr);
  }
  return rows.join('/');
}

// 持ち駒を表示用テキストに変換
String handToText(Map<PieceType, int> hand, String player) {
  if (hand.isEmpty) return '$player 持ち駒: なし';
  final parts = hand.entries
      .where((e) => e.value > 0)
      .map((e) => '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}')
      .join(' ');
  return '$player 持ち駒: $parts';
}

// ===== 報告タイプ・カテゴリ =====
enum FeedbackType { bug, request, other }
enum FeedbackCategory { game, kifu, study, ui, network, other }

extension FeedbackTypeLabel on FeedbackType {
  String get label {
    switch (this) {
      case FeedbackType.bug:     return '🐛 バグ報告';
      case FeedbackType.request: return '💡 改善要望';
      case FeedbackType.other:   return '💬 その他';
    }
  }
  String get hint {
    switch (this) {
      case FeedbackType.bug:     return '何が起きましたか？どの操作で発生しましたか？';
      case FeedbackType.request: return 'どんな機能・改善があると嬉しいですか？';
      case FeedbackType.other:   return 'ご意見・ご感想をお聞かせください';
    }
  }
}

extension FeedbackCategoryLabel on FeedbackCategory {
  String get label {
    switch (this) {
      case FeedbackCategory.game:    return '対局・AI';
      case FeedbackCategory.kifu:    return '棋譜';
      case FeedbackCategory.study:   return '学習・詰将棋';
      case FeedbackCategory.ui:      return 'UI・デザイン';
      case FeedbackCategory.network: return 'ネットワーク';
      case FeedbackCategory.other:   return 'その他';
    }
  }
}

// ===== FeedbackScreen =====
class FeedbackScreen extends StatefulWidget {
  /// 設定タブから呼ぶ場合は initialType でタイプを指定
  final FeedbackType initialType;
  /// ゲーム画面から呼ぶ場合は以下を渡す
  final List<List<Piece?>>? board;
  final Map<PieceType, int>? p1Hand;
  final Map<PieceType, int>? p2Hand;
  final List<String>? recentKifu;   // 直近の棋譜テキスト（最大20手）
  final int? moveCount;

  const FeedbackScreen({
    super.key,
    this.initialType = FeedbackType.bug,
    this.board,
    this.p1Hand,
    this.p2Hand,
    this.recentKifu,
    this.moveCount,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late FeedbackType _type;
  FeedbackCategory _category = FeedbackCategory.game;
  final _descCtrl = TextEditingController();
  bool _includeBoardPos = false;
  bool _submitting = false;

  String? get _sfen =>
      widget.board != null ? boardToSfen(widget.board!) : null;

  bool get _hasBoardData => widget.board != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    // ゲーム中から呼ばれた場合は局面添付をデフォルト ON
    if (_hasBoardData) _includeBoardPos = true;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ===== 送信 =====
  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容を入力してください'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _submitting = true);

    final data = {
      'type':      _type.name,
      'category':  _category.name,
      'description': desc,
      'appVersion': '1.1.2+13',
      'submittedAt': DateTime.now().toIso8601String(),
      if (_includeBoardPos && _sfen != null) 'boardSfen': _sfen,
      if (_includeBoardPos && widget.p1Hand != null)
        'p1Hand': widget.p1Hand!.map((k, v) => MapEntry(k.name, v)),
      if (_includeBoardPos && widget.p2Hand != null)
        'p2Hand': widget.p2Hand!.map((k, v) => MapEntry(k.name, v)),
      if (_includeBoardPos && widget.recentKifu != null)
        'recentKifu': widget.recentKifu!.join('\n'),
      if (widget.moveCount != null) 'moveCount': widget.moveCount,
    };

    bool success = false;
    try {
      // Firebase に送信
      await FirebaseDatabase.instance
          .ref('feedback/${DateTime.now().millisecondsSinceEpoch}')
          .set(data);
      success = true;
    } catch (_) {
      // Firebase 未設定の場合はクリップボードにフォールバック
    }

    setState(() => _submitting = false);

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      // フォールバック: テキストをコピー
      final text = _buildFallbackText(data);
      await Clipboard.setData(ClipboardData(text: text));
      _showFallbackDialog(text);
    }
  }

  String _buildFallbackText(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('=== 効棋 フィードバック ===');
    buf.writeln('種類: ${_type.label}');
    buf.writeln('カテゴリ: ${_category.label}');
    buf.writeln('バージョン: ${data['appVersion']}');
    buf.writeln('日時: ${data['submittedAt']}');
    buf.writeln('');
    buf.writeln('【内容】');
    buf.writeln(data['description']);
    if (data.containsKey('boardSfen')) {
      buf.writeln('');
      buf.writeln('【局面 SFEN】');
      buf.writeln(data['boardSfen']);
      if (data.containsKey('moveCount')) buf.writeln('手数: ${data['moveCount']}手目');
    }
    if (data.containsKey('recentKifu')) {
      buf.writeln('');
      buf.writeln('【直近の棋譜】');
      buf.writeln(data['recentKifu']);
    }
    return buf.toString();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('送信完了', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'フィードバックを送信しました。\nご協力ありがとうございます！',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('閉じる', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _showFallbackDialog(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('送信できませんでした', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.content_copy, color: Colors.amber, size: 40),
            const SizedBox(height: 12),
            const Text(
              'オフライン状態のため、内容をクリップボードにコピーしました。\n以下のメールアドレスに貼り付けて送信してください:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              'support@kouki.jp',
              style: TextStyle(color: Colors.lightBlue.shade300, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'フィードバック',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: _submitting
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                : const Icon(Icons.send, color: Colors.amber, size: 18),
            label: const Text('送信', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 種類セレクター ──
            _sectionLabel('種類'),
            const SizedBox(height: 8),
            Row(
              children: FeedbackType.values.map((t) {
                final sel = _type == t;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? Colors.brown.shade700 : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? Colors.amber : Colors.white24,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── カテゴリ ──
            _sectionLabel('カテゴリ'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FeedbackCategory.values.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? Colors.brown.shade800 : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? Colors.amber : Colors.white24,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      c.label,
                      style: TextStyle(
                        color: sel ? Colors.amber : Colors.white54,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── 内容 ──
            _sectionLabel('内容 *'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _descCtrl,
                maxLines: 6,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _type.hint,
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 局面添付（ゲーム画面から呼ばれた場合のみ） ──
            if (_hasBoardData) ...[
              _sectionLabel('対象局面'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _includeBoardPos ? Colors.amber.withAlpha(120) : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _includeBoardPos ? Icons.attach_file : Icons.attach_file_outlined,
                          color: _includeBoardPos ? Colors.amber : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text('局面データを添付', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const Spacer(),
                        Switch(
                          value: _includeBoardPos,
                          activeThumbColor: Colors.amber,
                          activeTrackColor: Colors.amber.withAlpha(80),
                          onChanged: (v) => setState(() => _includeBoardPos = v),
                        ),
                      ],
                    ),
                    if (_includeBoardPos) ...[
                      const Divider(color: Colors.white12, height: 16),
                      // 手数
                      if (widget.moveCount != null)
                        _infoRow(Icons.tag, '手数', '${widget.moveCount}手目'),
                      // SFEN
                      if (_sfen != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'SFEN（局面符号）',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _sfen!,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.white38, size: 16),
                                tooltip: 'SFENをコピー',
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: _sfen!));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('SFENをコピーしました'), duration: Duration(seconds: 1)),
                                    );
                                  }
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // 持ち駒
                      if (widget.p1Hand != null || widget.p2Hand != null) ...[
                        const SizedBox(height: 6),
                        if (widget.p1Hand != null)
                          Text(
                            handToText(widget.p1Hand!, '▲先手'),
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        if (widget.p2Hand != null)
                          Text(
                            handToText(widget.p2Hand!, '△後手'),
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                      ],
                      // 直近の棋譜
                      if (widget.recentKifu != null && widget.recentKifu!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '直近の棋譜（最新${widget.recentKifu!.length}手）',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            widget.recentKifu!.join('\n'),
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 送信ボタン ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18),
                label: Text(_submitting ? '送信中...' : '送信する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _submitting ? null : _submit,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '送信されたフィードバックは開発改善のみに使用します。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== 共通 UI ヘルパー =====
Widget _sectionLabel(String text) => Text(
  text,
  style: const TextStyle(
    color: Colors.white70,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
  ),
);

Widget _infoRow(IconData icon, String label, String value) => Row(
  children: [
    Icon(icon, color: Colors.white38, size: 14),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    const SizedBox(width: 4),
    Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
  ],
);
