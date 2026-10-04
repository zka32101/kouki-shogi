// lib/screens/story_overlay.dart
// ストーリー演出オーバーレイ（スキップ可能）

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_data.dart';
import '../theme/app_theme.dart';

class StoryOverlay extends StatefulWidget {
  final StoryEvent storyEvent;
  final VoidCallback onComplete;

  const StoryOverlay({
    Key? key,
    required this.storyEvent,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<StoryOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _delayController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _markAsShown();
  }

  void _initializeAnimations() {
    // フェードイン・フェードアウト（600ms）
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    // displayDurationがnull（手動スキップまで表示）の場合も、dispose()で
    // 無条件に破棄できるよう常に生成しておく（未使用のまま破棄されるだけ）
    _delayController = AnimationController(
      duration: widget.storyEvent.displayDuration ?? Duration.zero,
      vsync: this,
    );

    // 表示時間後に自動クローズ
    if (widget.storyEvent.displayDuration != null) {
      _fadeController.forward().then((_) {
        _delayController.forward().then((_) {
          _fadeController.reverse().then((_) {
            widget.onComplete();
          });
        });
      });
    } else {
      // 手動スキップまで表示
      _fadeController.forward();
    }
  }

  Future<void> _markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.storyEvent.sharedPrefKey, true);
  }

  void _skipStory() {
    _fadeController.reverse().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skipStory,
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          color: Color.lerp(
            _parseColor(widget.storyEvent.backgroundColor ?? '#000000'),
            AppTheme.bg,
            0.35,
          )!.withAlpha(215),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // キャラクターイメージ（該当する場合）
                if (widget.storyEvent.characterId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withAlpha(20),
                        border: Border.all(color: AppTheme.accent.withAlpha(140), width: 1.5),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: AppTheme.accent.withAlpha(150),
                      ),
                    ),
                  ),

                // タイトル（金の飾り線付き）
                if (widget.storyEvent.title.isNotEmpty) ...[
                  Text(
                    widget.storyEvent.title,
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 1.5,
                    color: AppTheme.accent.withAlpha(140),
                  ),
                  const SizedBox(height: 20),
                ],

                // 説明文
                if (widget.storyEvent.description != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      widget.storyEvent.description!,
                      style: TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 15,
                        height: 1.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // スキップ表示
                if (widget.storyEvent.displayDuration == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Text(
                      'タップでスキップ',
                      style: TextStyle(
                        color: AppTheme.textLow,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    // "#RRGGBB" 形式をパース。不正な文字列でも int.parse で例外を出さず
    // tryParse で黒にフォールバックする。
    String hexColor = colorString.replaceAll('#', '');
    if (hexColor.length == 6) {
      final value = int.tryParse('FF$hexColor', radix: 16);
      if (value != null) return Color(value);
    }
    return Colors.black;
  }
}

// ===== ストーリー表示ユーティリティ =====

class StoryManager {
  static Future<bool> shouldShowStory(StoryEvent storyEvent) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(storyEvent.sharedPrefKey) ?? false);
  }

  static Future<void> showStoryIfNeeded(
    BuildContext context,
    StoryEvent storyEvent,
  ) async {
    if (await shouldShowStory(storyEvent)) {
      if (!context.mounted) return;

      await _showStoryOverlay(context, storyEvent);
    }
  }

  static Future<void> _showStoryOverlay(
    BuildContext context,
    StoryEvent storyEvent,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: StoryOverlay(
          storyEvent: storyEvent,
          onComplete: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// 複数のストーリーイベントを順序付きで表示
  static Future<void> showStoriesInSequence(
    BuildContext context,
    List<StoryEvent> stories,
  ) async {
    for (final story in stories) {
      if (!context.mounted) break;
      await showStoryIfNeeded(context, story);
    }
  }
}

// ===== エンディング選択画面 =====

class EndingChoiceScreen extends StatelessWidget {
  final Function(EndingType) onChoose;

  const EndingChoiceScreen({Key? key, required this.onChoose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        side: BorderSide(color: AppTheme.accent.withAlpha(80)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '棋王が崩れ落ちる',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '「では、貴様が新しい秩序を決めよ」',
                style: TextStyle(color: AppTheme.textMid, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // エンディング選択肢
              ...endingChoices.map(
                (choice) => Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _EndingChoiceButton(
                    choice: choice,
                    onTap: () {
                      onChoose(choice.type);
                      Navigator.of(context).pop();
                    },
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

class _EndingChoiceButton extends StatelessWidget {
  final EndingChoice choice;
  final VoidCallback onTap;

  const _EndingChoiceButton({
    Key? key,
    required this.choice,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(AppTheme.rBtn),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.rBtn),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rBtn),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                choice.title,
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                choice.description,
                style: TextStyle(color: AppTheme.textMid, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Text(
                '報酬: ${choice.reward}',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
