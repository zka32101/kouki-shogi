// lib/sound_service_stub.dart — Android/iOS スタブ（システム音・振動フィードバック）
import 'package:flutter/services.dart';

void playTone(double freq, double dur, double vol, String shape) {
  // Webでのみ本格的な音声合成が動作する
  // Android/iOSではシステムクリック音でフィードバック
  try {
    SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}
