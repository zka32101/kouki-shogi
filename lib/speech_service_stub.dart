// lib/speech_service_stub.dart — モバイル/デスクトップ用 音声読み上げ（flutter_tts）
//
// 以前は non-web で speak() が完全な no-op だったため、音声入出力画面の
// 「再生」ボタンが「再生中…」と表示するだけで実際には無音だった。
// flutter_tts で実際に日本語音声を再生するよう実装。

import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  static bool _enabled = true;
  static bool get enabled => _enabled;
  static void setEnabled(bool v) => _enabled = v;

  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.5); // flutter_tts の rate スケールで自然な速さ
      await _tts.setPitch(1.0);
    } catch (_) {
      // TTSエンジン未対応の端末では黙ってフォールバック（無音）
    }
  }

  /// 指し手・解説テキストを日本語で読み上げる（fire-and-forget）。
  /// 音声入出力画面の再生ボタンからの明示的操作のため、グローバルの
  /// enabled フラグには依存せず常にベストエフォートで再生する。
  static void speak(String text) {
    if (text.isEmpty) return;
    _speakAsync(text);
  }

  static Future<void> _speakAsync(String text) async {
    try {
      await _ensureInit();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 再生失敗は無視（無音フォールバック）
    }
  }

  static String moveText(bool isP1, String note) => note;
}
