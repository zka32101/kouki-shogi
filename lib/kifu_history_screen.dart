// lib/kifu_history_screen.dart — 棋譜一覧・KIF エクスポート/インポート
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'kifu_replay_screen.dart';
import 'kif_utils.dart';
import 'kansousen_screen.dart';
import 'game_screen.dart'
    show
        initShogiBoard,
        PieceTheme,
        GameScreen,
        GameSettings,
        GameMode,
        autoAiLevelFromRating;
import 'logic.dart' show GL;
import 'services/kifu_backup_service.dart';
import 'theme/app_theme.dart';

class KifuHistoryScreen extends StatefulWidget {
  /// タブに埋め込む場合は false（戻るボタンを非表示）
  final bool showBackButton;
  const KifuHistoryScreen({super.key, this.showBackButton = true});
  @override
  State<KifuHistoryScreen> createState() => _KifuHistoryScreenState();
}

enum _SortMode { dateDesc, dateAsc, movesDesc, movesAsc }
enum _FilterResult { all, p1Win, p2Win, draw, favorite }

class _KifuHistoryScreenState extends State<KifuHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  bool _cloudBusy = false;

  // ── フィルター・ソート ──
  _SortMode _sortMode = _SortMode.dateDesc;
  _FilterResult _filterResult = _FilterResult.all;
  String _searchQuery = '';
  String _tagFilter = '';
  bool _showFilter = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_records);
    // 結果フィルター
    if (_filterResult != _FilterResult.all) {
      list = list.where((r) {
        final res = r['result'] as String? ?? '';
        switch (_filterResult) {
          case _FilterResult.p1Win:    return res.startsWith('先手の勝ち');
          case _FilterResult.p2Win:    return res.startsWith('後手の勝ち');
          case _FilterResult.draw:     return res.contains('引き分け');
          case _FilterResult.favorite: return r['favorite'] == true;
          default: return true;
        }
      }).toList();
    }
    // 検索
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final result = (r['result'] as String? ?? '').toLowerCase();
        final mode   = (r['mode']   as String? ?? '').toLowerCase();
        final date   = (r['date']   as String? ?? '').toLowerCase();
        final comment = (r['comment'] as String? ?? '').toLowerCase();
        final tags = ((r['tags'] as List<dynamic>?)?.whereType<String>().toList() ?? []).join(' ').toLowerCase();
        return result.contains(q) || mode.contains(q) ||
               date.contains(q)   || comment.contains(q) || tags.contains(q);
      }).toList();
    }
    // タグフィルター
    if (_tagFilter.isNotEmpty) {
      list = list.where((r) {
        final tags = (r['tags'] as List<dynamic>?)?.whereType<String>().toList() ?? [];
        return tags.contains(_tagFilter);
      }).toList();
    }
    // ソート
    list.sort((a, b) {
      switch (_sortMode) {
        case _SortMode.dateDesc:
          return (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? '');
        case _SortMode.dateAsc:
          return (a['date'] as String? ?? '').compareTo(b['date'] as String? ?? '');
        case _SortMode.movesDesc:
          return ((b['moveCount'] as int? ?? 0)).compareTo(a['moveCount'] as int? ?? 0);
        case _SortMode.movesAsc:
          return ((a['moveCount'] as int? ?? 0)).compareTo(b['moveCount'] as int? ?? 0);
      }
    });
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('kifu_records') ?? '[]';
      final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() { _records = list; _loading = false; });
      final beforeLen = _records.length;
      _autoCleanRecords();
      if (_records.length != beforeLen) {
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setString('kifu_records', jsonEncode(_records));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _autoCleanRecords() {
    if (_records.length <= 100) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _records.removeWhere((r) {
      if (r['favorite'] == true) return false;
      final dateStr = r['date'] as String? ?? '';
      try {
        final date = DateTime.parse(
            dateStr.replaceAll('/', '-').replaceFirst(' ', 'T'));
        return date.isBefore(cutoff);
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('削除', style: TextStyle(color: Colors.white)),
        content: const Text('この棋譜を削除しますか？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _records.remove(r));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kifu_records', jsonEncode(_records));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('削除しました')));
      }
    }
  }

  // ── お気に入りトグル ──────────────────────────────
  Future<void> _toggleFavorite(Map<String, dynamic> r) async {
    setState(() => r['favorite'] = !(r['favorite'] as bool? ?? false));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kifu_records', jsonEncode(_records));
  }

  // ── コメント編集 ──────────────────────────────
  Future<void> _editComment(Map<String, dynamic> r) async {
    final current = r['comment'] as String? ?? '';
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('メモを編集', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'この棋譜へのメモを入力...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F1A30),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    setState(() => r['comment'] = result);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kifu_records', jsonEncode(_records));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('メモを保存しました')));
    }
  }

  // ── KIF エクスポート ──────────────────────────────
  void _exportKif(Map<String, dynamic> r) {
    try {
      final rawMoves = (r['moves'] as List).whereType<Map<String, dynamic>>().toList();
      final moves = rawMoves.map((j) => KifuMove.fromJson(j)).toList();
      final date = r['date'] as String? ?? '';
      final result = r['result'] as String? ?? '';
      final handicap = r['handicap'] as String? ?? '平手';
      final kif = KifEncoder.encode(moves,
          date: date, result: result, handicap: handicap);
      final filename = 'kifu_${date.replaceAll('/', '-').replaceAll(' ', '_')}.kif';
      downloadKifFile(kif, filename);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$filename をダウンロードしました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エクスポート失敗: $e')));
      }
    }
  }

  // ── シェア ────────────────────────────────────────
  static const _aiLevelLabels = {
    'random': 'ランダム', 'beginner': '入門', 'easy': '初級',
    'elementary': '初中級', 'medium': '中級', 'upperMedium': '中上級',
    'hard': '上級', 'expert': '達人',
  };

  Future<void> _shareKifu(Map<String, dynamic> r) async {
    try {
      final shareText = _buildShareText(r);
      final subject = '効棋 対局結果 ${r['date'] ?? ''}';
      await Share.share(shareText, subject: subject);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('シェア失敗: $e')));
      }
    }
  }

  String _buildShareText(Map<String, dynamic> r) {
    final result = r['result'] as String? ?? '';
    final mode = r['mode'] as String? ?? '';
    final aiLevelKey = r['aiLevel'] as String? ?? '';
    final aiLabel = aiLevelKey.isNotEmpty
        ? (_aiLevelLabels[aiLevelKey] ?? aiLevelKey)
        : '';
    final moveCount = r['moveCount'] ?? 0;
    final date = r['date'] as String? ?? '';
    final castle = r['castle'] as String? ?? '';
    final opening = r['opening'] as String? ?? '';
    final comment = r['comment'] as String? ?? '';

    final buf = StringBuffer();
    buf.writeln('【効棋 将棋対局結果】');
    buf.writeln('━━━━━━━━━━━━━━');
    buf.writeln('結果: $result');
    if (mode == 'AI対局' && aiLabel.isNotEmpty) {
      buf.writeln('相手: AI ($aiLabel)');
    } else if (mode.isNotEmpty) {
      buf.writeln('形式: $mode');
    }
    buf.writeln('手数: ${moveCount}手');
    if (opening.isNotEmpty) buf.writeln('戦型: $opening');
    if (castle.isNotEmpty) buf.writeln('囲い: $castle');
    buf.writeln('日時: $date');
    if (comment.isNotEmpty) buf.writeln('メモ: $comment');
    buf.writeln('━━━━━━━━━━━━━━');
    buf.writeln('#効棋 #将棋');
    return buf.toString();
  }

  // ── コードから復元 ────────────────────────────────
  Future<void> _importFromCode() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('コードから棋譜を復元',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'シェア用テキストまたは棋譜データ部分を貼り付けてください',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 5,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: '棋譜データ: <base64文字列>',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF0F1A30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('復元', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;

    try {
      // 「棋譜データ: <base64>」形式と生のbase64両方に対応
      final encoded = result.contains('棋譜データ: ')
          ? result.split('棋譜データ: ').last.trim()
          : result;
      final jsonStr = utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final record = <String, dynamic>{
        'date':      data['date'] ?? '',
        'result':    data['result'] ?? 'インポート',
        'mode':      'コードから復元',
        'handicap':  data['handicap'] ?? '平手',
        'moveCount': data['moveCount'] ?? 0,
        'moves':     data['moves'] ?? [],
        'comment':   '',
      };

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('kifu_records') ?? '[]';
      final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().toList();
      list.insert(0, record);
      await prefs.setString('kifu_records', jsonEncode(list));
      setState(() => _records = list);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('棋譜を復元しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('復元失敗: コードが正しくありません ($e)')));
      }
    }
  }

  Future<void> _copyKif(Map<String, dynamic> r) async {
    try {
      final rawMoves = r['moves'] as List<dynamic>? ?? [];
      final moves = rawMoves.map((j) => KifuMove.fromJson(j)).toList();
      final date = r['date'] as String? ?? '';
      final result = r['result'] as String? ?? '';
      final kif = KifEncoder.encode(
        moves,
        date: date,
        result: result,
        handicap: r['handicap'] as String?,
      );
      await Clipboard.setData(ClipboardData(text: kif));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KIFをクリップボードにコピーしました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コピーに失敗しました: $e')),
        );
      }
    }
  }

  // ── KIF インポート ──────────────────────────────
  void _importKif() {
    pickKifFile((content, filename) async {
      final moves = KifDecoder.decode(content);
      if (moves == null || moves.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('KIFの読み込みに失敗しました')));
        }
        return;
      }

      // 棋譜レコードとして保存
      final handicap = KifEncoder.extractHandicap(content) ?? '平手';
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final record = <String, dynamic>{
        'date': date,
        'result': 'インポート',
        'mode': 'インポート',
        'handicap': handicap,
        'moveCount': moves.length,
        'moves': moves.map((m) => m.toJson()).toList(),
      };

      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('kifu_records') ?? '[]';
        final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().toList();
        list.insert(0, record);
        await prefs.setString('kifu_records', jsonEncode(list));
        setState(() => _records = list);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('棋譜を読み込みました')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('KIFの読み込みに失敗しました')));
        }
      }
    });
  }

  // ── 棋譜再生 ──────────────────────────────
  void _openReplay(Map<String, dynamic> record) {
    try {
      final rawMoves = (record['moves'] as List).whereType<Map<String, dynamic>>().toList();
      final moves = rawMoves.map((j) => KifuMove.fromJson(j)).toList();
      final title = '棋譜 (${record['date'] ?? ''})';
      final handicap = record['handicap'] as String? ?? '平手';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KifuReplayScreen(
            moves: moves,
            title: title,
            handicap: handicap,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('再生できませんでした: $e')));
    }
  }

  // ── 感想戦 ──────────────────────────────
  void _openKansousen(Map<String, dynamic> record) {
    final result = record['result'] as String? ?? '';
    if (result.isEmpty || result == '不明' || result.contains('未完')) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.bg,
          title: const Text('感想戦', style: TextStyle(color: Colors.white)),
          content: const Text('勝敗が確定した棋譜のみ感想戦を利用できます。',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    try {
      final rawMoves = (record['moves'] as List).whereType<Map<String, dynamic>>().toList();
      final moves = rawMoves.map((j) => KifuMove.fromJson(j)).toList();
      final title = '感想戦 (${record['date'] ?? ''})';
      // テーマ復元
      final themeStr = record['theme'] as String? ?? 'standard';
      final theme = PieceTheme.values.firstWhere(
          (t) => t.name == themeStr, orElse: () => PieceTheme.standard);
      // 先手が人間の場合は flipped=true（先手が下＝通常の将棋盤）
      // 棋譜の isP1Human が保存されていれば使用、なければ true をデフォルトに
      final isP1Human = record['isP1Human'] as bool? ?? true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KansousenScreen(
            moves: moves,
            initialBoard: initShogiBoard(),
            title: title,
            flipped: isP1Human,
            pieceTheme: theme,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('感想戦エラー: $e')));
    }
  }

  // ── AI対局再開 ──────────────────────────────
  // 棋譜の指し手を初期局面から再生して最終局面（盤面・持ち駒・手番）を
  // 復元し、その局面からAI対局を継続する。対局途中で終了した棋譜のみ対象
  // （詰み・投了等で決着済みの棋譜は続きが指せないため再開できない）。
  Future<void> _resumeAIGame(Map<String, dynamic> r) async {
    final resultStr = r['result'] as String? ?? '未完了';
    if (resultStr != '未完了') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.bg,
          title: const Text('棋譜再開', style: TextStyle(color: Colors.white)),
          content: const Text(
            'この対局はすでに終局しているため再開できません。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    try {
      final rawMoves =
          (r['moves'] as List).whereType<Map<String, dynamic>>().toList();
      final moves = rawMoves.map((j) => KifuMove.fromJson(j)).toList();

      final board = initShogiBoard();
      final p1Hand = <PieceType, int>{};
      final p2Hand = <PieceType, int>{};
      for (final m in moves) {
        GL.applyKifuMove(board, p1Hand, p2Hand, m);
      }
      final nextIsP1 = moves.isEmpty ? true : !moves.last.p1;

      final prefs = await SharedPreferences.getInstance();
      final rating = prefs.getInt('rating_current') ?? 700;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            settings: GameSettings(
              mode: GameMode.vsAI,
              aiLevel: autoAiLevelFromRating(rating),
            ),
            initialBoard: board,
            initialP1Hand: p1Hand,
            initialP2Hand: p2Hand,
            initialP1Turn: nextIsP1,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('棋譜再開エラー: $e')));
    }
  }

  // ── クラウドバックアップ ─────────────────
  Future<void> _showCloudBackupDialog() async {
    final svc = KifuBackupService();
    final info = await svc.getBackupInfo();
    if (!mounted) return;

    final dateStr = info.backedUpAt != null
        ? '${info.backedUpAt!.year}/${info.backedUpAt!.month.toString().padLeft(2,'0')}/${info.backedUpAt!.day.toString().padLeft(2,'0')} '
          '${info.backedUpAt!.hour.toString().padLeft(2,'0')}:${info.backedUpAt!.minute.toString().padLeft(2,'0')}'
        : 'なし';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('クラウドバックアップ', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最終バックアップ: $dateStr',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text('クラウド棋譜数: ${info.count}件',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('ローカル棋譜をクラウドに保存、または\nクラウドからローカルに復元できます。',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download, size: 16),
            label: const Text('リストア'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _cloudBusy = true);
              final count = await svc.restoreAll();
              if (!mounted) return;
              setState(() => _cloudBusy = false);
              if (count >= 0) {
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(count > 0 ? '$count件の棋譜をリストアしました' : 'クラウドに棋譜がありません')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('リストアに失敗しました（ネットワークを確認してください）')),
                );
              }
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload, size: 16),
            label: const Text('バックアップ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _cloudBusy = true);
              final count = await svc.backupAll();
              if (mounted) {
                setState(() => _cloudBusy = false);
                if (count >= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count件の棋譜をバックアップしました')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('バックアップに失敗しました（ログイン・ネットワークを確認）')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ── UI ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    final displayed = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('保存した棋譜',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: (_filterResult != _FilterResult.all || _searchQuery.isNotEmpty || _tagFilter.isNotEmpty)
                  ? Colors.amber
                  : Colors.white70,
            ),
            tooltip: 'フィルター・ソート',
            onPressed: () => setState(() => _showFilter = !_showFilter),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined, color: Colors.white70),
            tooltip: 'コードから棋譜を復元',
            onPressed: _importFromCode,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white70),
            tooltip: 'KIFファイルを読み込む',
            onPressed: _importKif,
          ),
          IconButton(
            icon: _cloudBusy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  )
                : const Icon(Icons.cloud_sync, color: Colors.white70),
            tooltip: 'クラウドバックアップ',
            onPressed: _cloudBusy ? null : _showCloudBackupDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : Column(children: [
              // ── フィルターパネル ──
              if (_showFilter) _filterPanel(),
              // ── リスト ──
              Expanded(
                child: displayed.isEmpty
                    ? (_records.isEmpty ? _emptyState() : _noResultState())
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: displayed.length,
                        itemBuilder: (_, i) {
                          final orig = _records.indexOf(displayed[i]);
                          return _recordCard(displayed[i], orig);
                        },
                      ),
              ),
            ]),
    );
  }

  Widget _filterPanel() {
    return Container(
      color: const Color(0xFF0F1A30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 検索
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: '日付・結果・タグ・メモで検索...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                    onPressed: () => setState(() {
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }),
                  )
                : null,
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 8),
        // 結果フィルター
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Text('絞り込み: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ..._FilterResult.values.map((f) {
              final labels = ['すべて', '先手勝', '後手勝', '引分', '★お気に入り'];
              final sel = _filterResult == f;
              return GestureDetector(
                onTap: () => setState(() => _filterResult = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? Colors.amber.withAlpha(60) : Colors.transparent,
                    border: Border.all(
                      color: sel ? Colors.amber : Colors.white24, width: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labels[f.index],
                    style: TextStyle(
                      color: sel ? Colors.amber : Colors.white54,
                      fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ]),
        ),
        const SizedBox(height: 6),
        // ソート
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Text('ソート: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ...{
              _SortMode.dateDesc: '日付↓',
              _SortMode.dateAsc:  '日付↑',
              _SortMode.movesDesc:'手数↓',
              _SortMode.movesAsc: '手数↑',
            }.entries.map((e) {
              final sel = _sortMode == e.key;
              return GestureDetector(
                onTap: () => setState(() => _sortMode = e.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? Colors.lightBlue.withAlpha(40) : Colors.transparent,
                    border: Border.all(
                      color: sel ? Colors.lightBlue : Colors.white24, width: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: sel ? Colors.lightBlue : Colors.white54,
                      fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ]),
        ),
        const SizedBox(height: 6),
        // タグフィルター
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Text('タグ: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ...['', '居飛車', '四間飛車', '中飛車', '棒銀', '矢倉', '美濃', '穴熊', '舟囲い'].map((tag) {
              final sel = _tagFilter == tag;
              final label = tag.isEmpty ? 'すべて' : tag;
              return GestureDetector(
                onTap: () => setState(() => _tagFilter = tag),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? Colors.green.withAlpha(60) : Colors.transparent,
                    border: Border.all(
                      color: sel ? Colors.green.shade400 : Colors.white24, width: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: sel ? Colors.green.shade300 : Colors.white54,
                      fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _noResultState() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off, size: 48, color: Colors.white24),
      SizedBox(height: 12),
      Text('条件に一致する棋譜がありません',
          style: TextStyle(color: Colors.white38, fontSize: 14)),
    ]),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.history, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        const Text('棋譜が保存されていません',
            style: TextStyle(color: Colors.white38, fontSize: 15)),
        const SizedBox(height: 8),
        const Text('対局後に棋譜保存ボタンを押してください',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24)),
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('KIFファイルを読み込む'),
          onPressed: _importKif,
        ),
      ],
    ),
  );

  // ── 勝敗バッジ ──────────────────────────────
  Widget _resultBadge(String result) {
    // 結果文字列は必ず「{勝者}の勝ち」で始まる。投了の場合は敗者側の呼称も
    // 括弧内に含むため contains() では誤判定する（startsWith で判定）。
    if (result.startsWith('先手の勝ち')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_upward, color: Colors.blue.shade300, size: 18),
          Text('先勝',
              style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    if (result.startsWith('後手の勝ち')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_downward, color: Colors.red.shade300, size: 18),
          Text('後勝',
              style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    if (result.contains('引き分け') || result.contains('引分')) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove, color: Colors.grey, size: 18),
          Text('引分',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.hourglass_empty, color: Colors.white38, size: 18),
        Text('未完',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _recordCard(Map<String, dynamic> r, int index) {
    final date = r['date'] as String? ?? '';
    final result = r['result'] as String? ?? '';
    final mode = r['mode'] as String? ?? '';
    final handicap = r['handicap'] as String? ?? '平手';
    final moveCount = r['moveCount'] as int? ?? 0;
    final comment = r['comment'] as String? ?? '';
    final isFavorite = r['favorite'] as bool? ?? false;

    Color resultColor = Colors.white54;
    if (result.startsWith('先手の勝ち')) resultColor = Colors.blue.shade300;
    if (result.startsWith('後手の勝ち')) resultColor = Colors.red.shade300;
    if (result.contains('引き分け')) resultColor = Colors.grey;

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.brown.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: _resultBadge(result)),
            ),
            title: Text(
              result,
              style: TextStyle(
                  color: resultColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('$mode  /$moveCount手  $handicap',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(date,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            onTap: () => _openReplay(r),
          ),
          // ── コメント表示 ──
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 12, color: Colors.teal.shade300),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      comment,
                      style: TextStyle(color: Colors.teal.shade200, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // ── タグ表示 ──
          Builder(builder: (_) {
            final tags = (r['tags'] as List<dynamic>?)?.whereType<String>().toList() ?? [];
            if (tags.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    border: Border.all(color: Colors.green.shade800, width: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tag, style: TextStyle(color: Colors.green.shade300, fontSize: 10)),
                )).toList(),
              ),
            );
          }),
          // ── 自動生成コメント ──
          Builder(builder: (_) {
            final autoComment = r['autoComment'] as String? ?? '';
            if (autoComment.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: Colors.amber.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      autoComment,
                      style: TextStyle(color: Colors.amber.shade200, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          // ── アクションボタン行 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                _actionBtn(Icons.play_arrow_outlined, '再生',
                    Colors.green.shade400, () => _openReplay(r)),
                if (mode == 'AI対局')
                  _actionBtn(Icons.play_circle_outline, '再開',
                      Colors.green.shade600, () => _resumeAIGame(r)),
                _actionBtn(Icons.analytics_outlined, '感想戦',
                    Colors.blue.shade300, () => _openKansousen(r)),
                _actionBtn(Icons.notes_outlined, 'メモ',
                    Colors.teal.shade300, () => _editComment(r)),
                _actionBtn(Icons.download_outlined, 'KIF',
                    Colors.amber.shade300, () => _exportKif(r)),
                _actionBtn(Icons.copy_outlined, 'コピー',
                    Colors.purple.shade300, () => _copyKif(r)),
                _actionBtn(Icons.share_outlined, 'シェア',
                    Colors.orange.shade300, () => _shareKifu(r)),
                _actionBtn(
                  isFavorite ? Icons.star : Icons.star_border,
                  'お気に入り',
                  isFavorite ? Colors.amber : Colors.white24,
                  () => _toggleFavorite(r),
                ),
                _actionBtn(Icons.delete_outline, '削除',
                    Colors.red.shade400, () => _delete(r)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
