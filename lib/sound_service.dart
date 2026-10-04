// lib/sound_service.dart — 効果音サービス（Web: AudioAPI / Mobile: SystemSound+Haptic）
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sound_service_stub.dart'
    if (dart.library.js) 'sound_service_web.dart' as _impl;

class SoundService {
  static bool enabled = true;

  // ── Web 向け内部メソッド ───────────────────────────────────
  static void _playTone(double freq, double dur, double vol,
      {String shape = 'sine'}) {
    if (!enabled || !kIsWeb) return;
    _impl.playTone(freq, dur, vol, shape);
  }

  // ── モバイル向け内部メソッド ──────────────────────────────
  static Future<void> _haptic(HapticType type) async {
    if (!enabled || kIsWeb) return;
    switch (type) {
      case HapticType.light:
        await HapticFeedback.selectionClick();
      case HapticType.medium:
        await HapticFeedback.lightImpact();
      case HapticType.heavy:
        await HapticFeedback.mediumImpact();
      case HapticType.click:
        await SystemSound.play(SystemSoundType.click);
    }
  }

  // ── 公開API ───────────────────────────────────────────────

  /// 駒を移動したとき
  static void playMove() {
    _playTone(440, 0.08, 0.20);
    _haptic(HapticType.light);
  }

  /// 駒を取ったとき
  static void playCapture() {
    _playTone(220, 0.18, 0.35);
    _haptic(HapticType.medium);
  }

  /// 持ち駒を打ったとき
  static void playDrop() {
    _playTone(330, 0.10, 0.25);
    _haptic(HapticType.click);
  }

  /// 王手
  static void playCheck() {
    _playTone(880, 0.20, 0.35);
    _haptic(HapticType.heavy);
  }

  /// ゲーム終了
  static void playGameEnd() {
    _playTone(523.25, 0.20, 0.30);
    Future.delayed(
      const Duration(milliseconds: 240),
      () => _playTone(659.25, 0.20, 0.30),
    );
    Future.delayed(
      const Duration(milliseconds: 480),
      () => _playTone(783.99, 0.50, 0.30),
    );
    _haptic(HapticType.heavy);
  }

  /// 投了
  static void playResign() {
    _playTone(440, 0.15, 0.25);
    Future.delayed(
      const Duration(milliseconds: 180),
      () => _playTone(330, 0.30, 0.20),
    );
    _haptic(HapticType.medium);
  }
}

enum HapticType { light, medium, heavy, click }
