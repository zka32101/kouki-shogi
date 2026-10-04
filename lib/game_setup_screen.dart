// lib/game_setup_screen.dart — 対局前設定 UI

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'purchase_service.dart';
import 'castle_guide_service.dart';
import 'theme_config.dart';
import 'character_icons.dart';
import 'ai_personality.dart';
import 'screens/premium_screen.dart';
import 'piece.dart';
import 'services/adaptive_difficulty_service.dart';
import 'theme/app_theme.dart';

class GameSetupScreen extends StatefulWidget {
  final GameMode mode; // pvp or vsAI
  const GameSetupScreen({super.key, required this.mode});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  // ── 設定値 ──
  bool _aiIsP2 = true; // AI が後手か
  int? _timeLimitSec;
  int? _byoyomiSec;
  int _fischerIncrementSec = 0;
  Handicap _handicap = Handicap.none;
  PieceTheme _theme = PieceTheme.standard;
  PieceLabelStyle _labelStyle = PieceLabelStyle.kanji;
  VariantType _variant = VariantType.normal;
  bool _aiRated = true;

  // 囲いガイドモード
  bool _castleGuideEnabled = false;
  String _castleGuideName = 'mino';
  int _castleGuideMaxPly = 30;

  // コーチモード
  bool _coachMode = false;

  // 対戦相手キャラクター
  String? _opponentCharacterId;

  // オープニング局面
  String? _selectedOpeningId;

  // 適応難易度（直近の調子を加味したAIレベル調整）
  AdaptiveLevelResult? _adaptiveResult;
  bool _loadingAdaptive = true;

  @override
  void initState() {
    super.initState();
    if (widget.mode == GameMode.vsAI) {
      _loadAdaptiveLevel();
    }
  }

  Future<void> _loadAdaptiveLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final currentRating = prefs.getInt('rating_current') ?? 700;
    final result = await AdaptiveDifficultyService.computeAdaptiveLevel(rating: currentRating);
    if (mounted) {
      setState(() {
        _adaptiveResult = result;
        _loadingAdaptive = false;
      });
    }
  }

  // 持ち時間の選択肢
  static const _timeOptions = <int?>[null, 180, 300, 600, 900, 1800];
  static const _timeLabels = ['なし', '3分', '5分', '10分', '15分', '30分'];

  static const _openingMoves = {
    'shiken': [[6,2,5,2],[7,7,7,3],[2,1,3,1],[6,3,5,3]],
    'chuuhi': [[6,2,5,2],[7,7,7,4],[2,1,3,1],[2,7,3,7]],
    'bogin':  [[6,2,5,2],[6,7,5,7],[5,7,4,7],[2,1,3,1],[8,6,7,6],[2,6,3,6]],
    'yagura': [[6,2,5,2],[8,2,7,3],[7,3,6,2],[6,3,5,3],[2,1,3,1],[0,2,1,3]],
  };

  List<List<Piece?>> _buildOpeningBoard(String id) {
    final b = initShogiBoard();
    final moves = _openingMoves[id];
    if (moves == null) return b;
    for (final m in moves) {
      final p = b[m[0]][m[1]];
      if (p == null) continue;
      b[m[2]][m[3]] = p;
      b[m[0]][m[1]] = null;
    }
    return b;
  }

  Widget _openingSection() {
    const options = [
      ('none', '初期局面', '通常の初期配置'),
      ('shiken', '四間飛車形', '飛車を6筋(6八)に振る'),
      ('chuuhi', '中飛車形', '飛車を5筋(中央)に'),
      ('bogin', '棒銀形', '銀を前線へ繰り出す'),
      ('yagura', '矢倉形', '銀・歩で矢倉の形'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((o) {
        final (id, label, desc) = o;
        final selected = (id == 'none' ? null : id) == _selectedOpeningId;
        return GestureDetector(
          onTap: () => setState(() => _selectedOpeningId = id == 'none' ? null : id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.brown.shade800 : const Color(0xFF0F3460),
              border: Border.all(
                color: selected ? Colors.amber.shade600 : Colors.white24,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                      color: selected ? Colors.amber : Colors.white70,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    )),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _startGame() async {
    final prefs = await SharedPreferences.getInstance();

    // ローカル対局の場合、無料プラン対戦5回制限をチェック
    if (widget.mode == GameMode.pvp && !PurchaseService.isPremium) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString('local_game_date') ?? '';
      int count = savedDate == today ? (prefs.getInt('local_game_count') ?? 0) : 0;

      if (count >= 5) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('本日の対戦回数に達しました', style: TextStyle(color: Colors.white)),
              content: const Text(
                '無料プランでは1日5回までのローカル対局が可能です。\nプレミアムプランで無制限にプレイできます。',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    );
                  },
                  child: const Text('プレミアムプラン', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          return;
        }
      }

      // カウント更新
      await prefs.setString('local_game_date', today);
      await prefs.setInt('local_game_count', count + 1);
    }

    // レーティング + 直近の調子から適応的にAIレベルを決定
    final currentRating = prefs.getInt('rating_current') ?? 700;
    final autoAiLevel = _adaptiveResult?.level ?? autoAiLevelFromRating(currentRating);

    final settings = GameSettings(
      mode: widget.mode,
      aiLevel: autoAiLevel,
      aiIsP2: _aiIsP2,
      timeLimitSec: _timeLimitSec,
      byoyomiSec: _byoyomiSec,
      fischerIncrementSec: _fischerIncrementSec,
      theme: _theme,
      labelStyle: _labelStyle,
      handicap: _handicap,
      variant: _variant,
      aiRated: _aiRated,
      castleGuideEnabled: _castleGuideEnabled,
      castleGuideName: _castleGuideName,
      castleGuideMaxPly: _castleGuideMaxPly,
      coachMode: _coachMode,
      opponentCharacterId: _opponentCharacterId,
    );
    final openingBoard = _selectedOpeningId != null
        ? _buildOpeningBoard(_selectedOpeningId!)
        : null;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            settings: settings,
            initialBoard: openingBoard,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVsAI = widget.mode == GameMode.vsAI;
    final title = isVsAI ? 'AI対局 - 設定' : 'ローカル対局 - 設定';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── AI 自動適応 ──────────────────
                if (isVsAI) ...[
                  _autoAiInfoBanner(),
                  const SizedBox(height: 16),
                  _sectionHeader(Icons.swap_horiz, 'AIの担当'),
                  const SizedBox(height: 10),
                  _aiSideSection(),
                  const SizedBox(height: 20),
                  // ── レーティング戦 ──────────────────
                  Row(children: [
                    const Icon(Icons.military_tech, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    const Text('レーティング戦', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: _aiRated,
                      activeColor: Colors.amber,
                      onChanged: (v) => setState(() => _aiRated = v),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // ── 囲いガイドモード ──────────────────
                  _sectionHeader(Icons.castle, '囲いガイドモード'),
                  const SizedBox(height: 10),
                  _castleGuideSection(),
                  const SizedBox(height: 20),

                  // ── コーチモード ──────────────────
                  _sectionHeader(Icons.psychology, 'コーチモード（AI指導対局）'),
                  const SizedBox(height: 10),
                  _coachModeSection(),
                  const SizedBox(height: 20),

                  // ── 対戦相手キャラクター ──────────────────
                  _sectionHeader(Icons.face, '対戦相手キャラクター'),
                  const SizedBox(height: 4),
                  const Text(
                    'キャラによって棋風が変わります',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _opponentCharSection(),
                  const SizedBox(height: 20),
                ],

                // ── pvp 専用セクション ──────────────────
                // 変則将棋・駒落ちは一時無効（近日公開）


                // ── 共通: オープニング局面 ──────────────────
                _sectionHeader(Icons.play_circle_outline, 'オープニング局面'),
                const SizedBox(height: 10),
                _openingSection(),
                const SizedBox(height: 20),

                // ── 共通: 持ち時間 ──────────────────
                _sectionHeader(Icons.timer, '持ち時間'),
                const SizedBox(height: 10),
                _timeSection(),
                const SizedBox(height: 16),
                _byoyomiSection(),
                const SizedBox(height: 16),
                _fischerSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── 固定フッター「対局を始める」ボタン ──────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  '対局を始める',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI自動適応バナー ──────────────────────────────────────
  Widget _autoAiInfoBanner() {
    final result = _adaptiveResult;
    final isAdjusted = result?.isAdjusted ?? false;
    final adjustedUp = (result?.adjustmentSteps ?? 0) > 0;

    final accentColor = isAdjusted
        ? (adjustedUp ? Colors.redAccent : Colors.lightBlueAccent)
        : Colors.amber;
    final icon = isAdjusted
        ? (adjustedUp ? Icons.trending_up : Icons.trending_down)
        : Icons.auto_awesome;
    final title = isAdjusted
        ? (adjustedUp ? 'AIを少し手強めに調整中' : 'AIを少し易しめに調整中')
        : 'AIはあなたの棋力に自動調整';

    final subtitle = _loadingAdaptive
        ? '直近の調子を分析しています…'
        : (result?.reason ?? '現在のレーティングに合わせたAIと対局します');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI担当（先手/後手） ──────────────────────────────────
  Widget _aiSideSection() {
    return Row(
      children: [
        _sideChip('先手（▲）', !_aiIsP2, () => setState(() => _aiIsP2 = false)),
        const SizedBox(width: 10),
        _sideChip('後手（△）', _aiIsP2, () => setState(() => _aiIsP2 = true)),
      ],
    );
  }

  Widget _sideChip(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blueGrey.shade800 : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.amber : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.amber : Colors.white54,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── 持ち時間 ──────────────────────────────────────
  Widget _timeSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_timeOptions.length, (i) {
        final val = _timeOptions[i];
        final sel = _timeLimitSec == val;
        return ChoiceChip(
          label: Text(_timeLabels[i]),
          selected: sel,
          onSelected: (_) => setState(() {
            _timeLimitSec = val;
            // 時間なしなら秒読みもクリア
            if (val == null) _byoyomiSec = null;
          }),
          selectedColor: Colors.green.shade700,
          backgroundColor: AppTheme.surface,
          labelStyle: TextStyle(
            color: sel ? Colors.white : Colors.white54,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(color: sel ? Colors.green.shade400 : Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      }),
    );
  }

  // ── 秒読み ──────────────────────────────────────
  Widget _byoyomiSection() {
    final enabled = _timeLimitSec != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.alarm, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              '秒読み${enabled ? '' : '（持ち時間設定時のみ）'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _byoyomiChip('なし', null, enabled),
              _byoyomiChip('30秒', 30, enabled),
              _byoyomiChip('60秒', 60, enabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _byoyomiChip(String label, int? val, bool enabled) {
    final sel = _byoyomiSec == val;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: enabled ? (_) => setState(() => _byoyomiSec = val) : null,
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: sel ? Colors.white : Colors.white54,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: sel ? AppTheme.accent : Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // ── フィッシャー加算 ──────────────────────────────
  Widget _fischerSection() {
    final enabled = _timeLimitSec != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.add_alarm, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              'フィッシャー加算${enabled ? '' : '（持ち時間設定時のみ）'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _fischerChip('なし', 0, enabled),
              _fischerChip('+5秒', 5, enabled),
              _fischerChip('+10秒', 10, enabled),
              _fischerChip('+15秒', 15, enabled),
              _fischerChip('+30秒', 30, enabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fischerChip(String label, int val, bool enabled) {
    final sel = _fischerIncrementSec == val;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: enabled ? (_) => setState(() => _fischerIncrementSec = val) : null,
      selectedColor: Colors.green.shade800,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: sel ? Colors.white : Colors.white54,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: sel ? Colors.green.shade400 : Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // ── 駒落ち ──────────────────────────────────────
  Widget _handicapSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButton<Handicap>(
        value: _handicap,
        isExpanded: true,
        dropdownColor: AppTheme.surface,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: Handicap.values.map((h) => DropdownMenuItem(
          value: h,
          child: Text(h.label, style: const TextStyle(color: Colors.white)),
        )).toList(),
        onChanged: (h) { if (h != null) setState(() => _handicap = h); },
      ),
    );
  }

  // ── 駒落ちプレビュー ──────────────────────────────────────
  Widget _handicapPreview() {
    final board = initShogiBoard(_handicap);
    final cfg = boardThemeConfig(_theme);
    const cellSize = 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.grid_on, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          const Text('配置プレビュー', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: cfg.background,
              border: Border.all(color: cfg.boardBorder, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(9, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(9, (col) {
                    final piece = board[row][col];
                    return Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: cfg.cell,
                        border: Border.all(color: cfg.cellBorder.withAlpha(80), width: 0.5),
                      ),
                      child: piece == null
                          ? null
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Transform.rotate(
                                angle: piece.isPlayer1 ? 0 : 3.14159,
                                child: Text(
                                  piece.label,
                                  style: TextStyle(
                                    color: piece.isPlayer1 ? cfg.pieceNormal : cfg.pieceP2,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── 変則将棋選択 ──────────────────────────────────────
  Widget _variantSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: VariantType.values.map((v) {
        final sel = _variant == v;
        return ChoiceChip(
          label: Text(v.label),
          selected: sel,
          onSelected: (_) => setState(() => _variant = v),
          selectedColor: Colors.deepPurple.shade700,
          backgroundColor: AppTheme.surface,
          labelStyle: TextStyle(
            color: sel ? Colors.white : Colors.white54,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          side: BorderSide(
            color: sel ? Colors.deepPurple.shade300 : Colors.white24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      }).toList(),
    );
  }

  // ── プレミアムテーマ判定 ──────────────────────────────────────
  bool _isPremiumTheme(PieceTheme t) =>
      t == PieceTheme.textured || t == PieceTheme.emerald || t == PieceTheme.cherry;

  // ── テーマ選択タップ ──────────────────────────────────────
  void _onThemeTap(PieceTheme t) {
    if (_isPremiumTheme(t) && !PurchaseService.isPremium) {
      _showPremiumDialog();
      return;
    }
    setState(() => _theme = t);
    SharedPreferences.getInstance().then((p) => p.setInt('piece_theme_idx', t.index));
  }

  // ── プレミアム購入ダイアログ ──────────────────────────────────────
  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [
          Icon(Icons.diamond, color: Colors.amber),
          SizedBox(width: 8),
          Text('プレミアムプラン', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'このテーマを使用するにはプレミアムプランが必要です。',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              '300円または500円のプランをご購入ください。',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700),
            onPressed: () async {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            child: const Text('プレミアムプランを購入',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 駒テーマ ──────────────────────────────────────
  Widget _themeSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PieceTheme.values.map((t) {
        final cfg = boardThemeConfig(t);
        final sel = _theme == t;
        final locked = _isPremiumTheme(t) && !PurchaseService.isPremium;
        return GestureDetector(
          onTap: () => _onThemeTap(t),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 88,
                decoration: BoxDecoration(
                  color: cfg.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? Colors.amber : Colors.white24,
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.amber.withAlpha(70), blurRadius: 6)]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: cfg.cell,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: cfg.boardBorder, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '王',
                            style: TextStyle(
                              color: cfg.pieceNormal,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        cfg.label,
                        style: TextStyle(
                          color: sel ? Colors.amber : Colors.white70,
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(130),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 囲いガイドモード ──────────────────────────────────────
  Widget _castleGuideSection() {
    final castleOptions = ['yagura', 'mino', 'anaguma', 'kinmusou'];
    final plyOptions = [20, 30, 40];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _castleGuideEnabled ? Colors.amber.withAlpha(120) : Colors.white12,
          width: _castleGuideEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // トグルスイッチ行
          Row(
            children: [
              Switch(
                value: _castleGuideEnabled,
                onChanged: (v) => setState(() => _castleGuideEnabled = v),
                activeColor: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                '囲いガイドモード',
                style: TextStyle(
                  color: _castleGuideEnabled ? Colors.amber : Colors.white70,
                  fontSize: 14,
                  fontWeight: _castleGuideEnabled ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          // 詳細設定（ON時のみ表示）
          if (_castleGuideEnabled) ...[
            const SizedBox(height: 12),
            const Text(
              'どの囲いを練習しますか？',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: castleOptions.map((key) {
                final sel = _castleGuideName == key;
                return GestureDetector(
                  onTap: () => setState(() => _castleGuideName = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? Colors.amber.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? Colors.amber : Colors.white24,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      CastleGuideService.castleName(key),
                      style: TextStyle(
                        color: sel ? Colors.amber : Colors.white70,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              '目標手数:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: plyOptions.map((ply) {
                final sel = _castleGuideMaxPly == ply;
                return ChoiceChip(
                  label: Text('${ply}手'),
                  selected: sel,
                  onSelected: (_) => setState(() => _castleGuideMaxPly = ply),
                  selectedColor: Colors.amber.shade700,
                  backgroundColor: const Color(0xFF0F1729),
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: sel ? Colors.amber : Colors.white24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '対局開始後 ${_castleGuideMaxPly}手まで、盤面に囲いへの誘導矢印を表示します。',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ── コーチモード ──────────────────────────────────────
  Widget _coachModeSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _coachMode ? Colors.deepPurpleAccent.withAlpha(150) : Colors.white12,
          width: _coachMode ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Switch(
              value: _coachMode,
              onChanged: (v) => setState(() => _coachMode = v),
              activeColor: Colors.deepPurpleAccent,
            ),
            const SizedBox(width: 8),
            Text(
              'コーチモード',
              style: TextStyle(
                color: _coachMode ? Colors.deepPurpleAccent.shade100 : Colors.white70,
                fontSize: 14,
                fontWeight: _coachMode ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ]),
          if (_coachMode) ...[
            const SizedBox(height: 8),
            const Text(
              '• 指した手の良し悪しをリアルタイムで表示\n'
              '• 「待った」でやり直し＋正着ヒント\n'
              '• 対局後に AI 1局講評レポートを表示',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.7),
            ),
          ],
        ],
      ),
    );
  }

  // ── ヘルパー ──────────────────────────────────────
  Widget _opponentCharSection() {
    final isPremium = PurchaseService.isPremium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // なし（デフォルト）
        _opponentCharTile(null, 'デフォルト', '標準的なバランスAI', true),
        const SizedBox(height: 8),
        // キャラ一覧（ティア別）
        ...allCharacterIcons.map((icon) {
          final unlocked = switch (icon.tier) {
            CharIconTier.free => true,
            CharIconTier.subscription => isPremium,
            CharIconTier.pack => isPremium,
          };
          return _opponentCharTile(
            icon.id,
            icon.name,
            _personalityDesc(icon.id),
            unlocked,
          );
        }),
      ],
    );
  }

  String _personalityDesc(String id) {
    final p = characterPersonalities[id];
    if (p == null) return '';
    final parts = <String>[];
    if (p.attackBias >= 1.8) parts.add('超攻撃的');
    else if (p.attackBias >= 1.3) parts.add('攻め型');
    else if (p.attackBias <= 0.6) parts.add('受け型');
    if (p.defenceBias >= 1.8) parts.add('堅陣重視');
    else if (p.defenceBias >= 1.3) parts.add('守り堅め');
    else if (p.defenceBias <= 0.4) parts.add('玉無視');
    if (p.greedBias >= 1.3) parts.add('駒得貪欲');
    if (p.depthBonus >= 2) parts.add('超深読み');
    else if (p.depthBonus >= 1) parts.add('深読み');
    else if (p.depthBonus <= -1) parts.add('速攻浅読み');
    return parts.isEmpty ? 'バランス型' : parts.join('・');
  }

  Widget _opponentCharTile(String? id, String label, String desc, bool unlocked) {
    final selected = _opponentCharacterId == id;
    final icon = id != null ? findCharacterById(id) : null;
    return GestureDetector(
      onTap: unlocked
          ? () => setState(() => _opponentCharacterId = id)
          : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    characterPersonalities[id]?.attackBias != null
                        ? 'このキャラはサブスクまたはパック購入が必要です'
                        : 'このキャラはサブスクまたはパック購入が必要です',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (icon != null ? icon.bgColor.withAlpha(50) : Colors.amber.withAlpha(30))
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? (icon != null ? icon.bgColor : Colors.amber)
                : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // アイコン
          if (icon != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: icon.bgColor,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  icon.imagePath,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Center(child: Text(icon.emoji, style: const TextStyle(fontSize: 16))),
                ),
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A4A),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Icon(Icons.computer, color: Colors.white54, size: 16)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                label,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
            ]),
          ),
          if (!unlocked)
            const Icon(Icons.lock, size: 14, color: Colors.white38),
          if (selected)
            Icon(Icons.check_circle, size: 16, color: icon?.bgColor ?? Colors.amber),
        ]),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.amber.shade300),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: Colors.amber.shade200,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }
}
