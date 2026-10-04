// lib/rank_badge_widget.dart — 段位バッジウィジェット

import 'dart:math';
import 'package:flutter/material.dart';
import 'stats_screen.dart' show ratingToRank, ratingToColor, rankProgress, nextRankInfo, isKyuu;
import 'theme/app_theme.dart';

/// 段位バッジ（コンパクト表示）
class RankBadge extends StatelessWidget {
  final int rating;
  final double size;
  final bool showLabel;

  const RankBadge({
    super.key,
    required this.rating,
    this.size = 48,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final rank = ratingToRank(rating);
    final color = ratingToColor(rating);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withAlpha(200),
                color.withAlpha(80),
              ],
            ),
            border: Border.all(
              color: color,
              width: size >= 60 ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(100),
                blurRadius: size / 3,
              ),
            ],
          ),
          child: Center(
            child: Text(
              rank,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.28,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            'ELO $rating',
            style: TextStyle(color: color.withAlpha(200), fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// 段位進捗バー
class RankProgressBar extends StatelessWidget {
  final int rating;

  const RankProgressBar({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final rank = ratingToRank(rating);
    final color = ratingToColor(rating);
    final progress = rankProgress(rating);
    final next = nextRankInfo(rating);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              rank,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (next != null) ...[
              Text(
                '次: ${next.$1} まで ${next.$2} ELO',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ] else
              const Text('最高位', style: TextStyle(color: Colors.amber, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ELO: $rating',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── 昇段/昇級 祝福ダイアログ ────────────────────────────────────

class _ConfettiParticle {
  double x, y, vx, vy, size, angle, spin;
  Color color;
  _ConfettiParticle(Random rng)
      : x = rng.nextDouble(),
        y = -rng.nextDouble() * 0.3,
        vx = (rng.nextDouble() - 0.5) * 0.012,
        vy = 0.008 + rng.nextDouble() * 0.012,
        size = 5 + rng.nextDouble() * 8,
        angle = rng.nextDouble() * 2 * pi,
        spin = (rng.nextDouble() - 0.5) * 0.2,
        color = [
          const Color(0xFFFFD700),
          const Color(0xFFFF6B6B),
          const Color(0xFF4FC3F7),
          const Color(0xFF81C784),
          const Color(0xFFCE93D8),
          const Color(0xFFFFAB40),
        ][rng.nextInt(6)];

  void update() {
    x += vx;
    y += vy;
    angle += spin;
  }

  bool get isDead => y > 1.1;
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = p.color.withAlpha(210);
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

class _RankUpCelebrationDialog extends StatefulWidget {
  final String newRank;
  final Color rankColor;
  const _RankUpCelebrationDialog({required this.newRank, required this.rankColor});

  @override
  State<_RankUpCelebrationDialog> createState() => _RankUpCelebrationDialogState();
}

class _RankUpCelebrationDialogState extends State<_RankUpCelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _confettiCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  final List<_ConfettiParticle> _particles = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..forward();

    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(_rng));
    }

    _confettiCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        for (final p in _particles) {
          p.update();
        }
        _particles.removeWhere((p) => p.isDead);
        if (_particles.length < 40 && _confettiCtrl.value < 0.7) {
          _particles.add(_ConfettiParticle(_rng));
        }
      });
    });

    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _glowCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  bool get _isKyuu => isKyuu(widget.newRank);

  String get _titleText => _isKyuu ? '昇級おめでとうございます！' : '昇段おめでとうございます！';
  String get _bodyText => _isKyuu
      ? '${widget.newRank} に昇級しました！'
      : '${widget.newRank} に昇段しました！';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 紙吹雪レイヤー
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ConfettiPainter(_particles)),
            ),
          ),
          // メインカード
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.rankColor.withAlpha(
                    (120 + (_glowAnim.value * 100)).toInt(),
                  ),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.rankColor.withAlpha(
                      (80 + (_glowAnim.value * 80)).toInt(),
                    ),
                    blurRadius: 24 + _glowAnim.value * 16,
                  ),
                ],
              ),
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isKyuu ? '🎊' : '🏆',
                    style: const TextStyle(fontSize: 52),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _titleText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: AnimatedBuilder(
                      animation: _glowAnim,
                      builder: (_, __) => Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.rankColor.withAlpha(220),
                              widget.rankColor.withAlpha(60),
                            ],
                          ),
                          border: Border.all(
                            color: widget.rankColor,
                            width: 3 + _glowAnim.value * 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.rankColor.withAlpha(
                                (100 + (_glowAnim.value * 120)).toInt(),
                              ),
                              blurRadius: 20 + _glowAnim.value * 20,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.newRank,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _bodyText,
                    style: TextStyle(
                      color: widget.rankColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isKyuu ? '着実に力がついています！' : '将棋の腕が一段上がりました！',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.rankColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'ありがとう！',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 昇段/昇級 祝福ダイアログを表示する
Future<void> showRankUpDialog(BuildContext context, String newRank, Color rankColor) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _RankUpCelebrationDialog(newRank: newRank, rankColor: rankColor),
  );
}
