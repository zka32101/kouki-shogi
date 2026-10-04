// lib/screens/report_user_screen.dart
// ユーザー不正報告画面

import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../models/report.dart';
import '../theme/app_theme.dart';

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUsername;
  final String matchId;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUsername,
    required this.matchId,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final NetworkService _networkService = NetworkService();
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  bool _isBlocking = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    final blocked = await _networkService.isBlocked(widget.reportedUserId);
    if (mounted) setState(() => _isBlocked = blocked);
  }

  Future<void> _toggleBlock() async {
    setState(() => _isBlocking = true);
    try {
      if (_isBlocked) {
        await _networkService.unblockUser(widget.reportedUserId);
        if (mounted) setState(() => _isBlocked = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ブロックを解除しました')),
          );
        }
      } else {
        await _networkService.blockUser(widget.reportedUserId);
        if (mounted) setState(() => _isBlocked = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.reportedUsername} をブロックしました'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isBlocking = false);
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ユーザーを報告', style: TextStyle(color: AppTheme.textHigh)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // 報告対象ユーザー
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
                      '報告対象ユーザー',
                      style: TextStyle(color: AppTheme.textMid, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.reportedUsername,
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 報告理由
              const Text(
                '報告理由',
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ── 不正行為 ──────────────────────────────
              _buildCategoryLabel('不正行為'),
              _buildReasonOption('soft_play', 'ソフト指し（AI支援）'),
              _buildReasonOption('time_cheat', 'タイムチート（時間操作）'),

              // ── 嫌がらせ行為 ──────────────────────────
              _buildCategoryLabel('嫌がらせ行為'),
              _buildReasonOption('abandoned_game', '途中放棄・逃げ'),
              _buildReasonOption(
                  'intentional_stalling', '遅延行為（わざとゆっくり指す）'),
              _buildReasonOption('abusive_chat', '暴言・ハラスメント'),
              _buildReasonOption('griefing', 'その他の嫌がらせ・妨害'),

              // ── その他 ──────────────────────────────
              _buildCategoryLabel('その他'),
              _buildReasonOption('other', 'その他の不正・問題行動'),

              const SizedBox(height: 24),

              // 詳細（オプション）
              const Text(
                '詳細（オプション）',
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textHigh),
                decoration: InputDecoration(
                  hintText: '不正の詳細を記入してください',
                  hintStyle: TextStyle(color: AppTheme.textLow),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ブロックボタン
              OutlinedButton.icon(
                onPressed: _isBlocking ? null : _toggleBlock,
                icon: _isBlocking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isBlocked ? Icons.person_add : Icons.block,
                        size: 18,
                      ),
                label: Flexible(
                  child: Text(
                    _isBlocked
                        ? '${widget.reportedUsername} のブロックを解除'
                        : '${widget.reportedUsername} をブロック',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isBlocked ? Colors.grey : Colors.orange.shade300,
                  side: BorderSide(
                    color: _isBlocked
                        ? Colors.grey.shade600
                        : Colors.orange.shade700,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              // 警告テキスト
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ 虚偽の報告は禁止です。不正な報告を繰り返すと、あなたのアカウントがペナルティを受ける可能性があります。',
                  style: TextStyle(color: AppTheme.textMid, fontSize: 12),
                ),
              ),

              const SizedBox(height: 24),

              // 報告ボタン
              ElevatedButton(
                onPressed: _selectedReason == null || _isSubmitting
                    ? null
                    : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('報告を送信'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textMid,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildReasonOption(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _selectedReason == value
              ? Colors.brown.shade700.withAlpha(100)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedReason == value
                ? Colors.brown.shade700
                : Colors.transparent,
          ),
        ),
        child: RadioListTile<String>(
          value: value,
          groupValue: _selectedReason,
          onChanged: (v) => setState(() => _selectedReason = v),
          title: Text(label, style: const TextStyle(color: AppTheme.textHigh)),
          activeColor: Colors.amber,
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = _networkService.currentUser;
      if (currentUser == null) {
        throw Exception('ログインが必要です');
      }

      final success = await _networkService.submitReport(
        currentUser.uid,
        widget.reportedUserId,
        widget.matchId,
        _selectedReason!,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('報告を送信しました')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('報告に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
