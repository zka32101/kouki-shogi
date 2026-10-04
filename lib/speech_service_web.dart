// lib/speech_service_web.dart — Web Speech API による指し手読み上げ (Web専用)
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js' as js;

class SpeechService {
  static bool _enabled = false;
  static bool get enabled => _enabled;

  static void setEnabled(bool v) => _enabled = v;

  /// 指し手テキストを読み上げ（例: "７六歩"）
  static void speak(String text) {
    if (!_enabled) return;
    try {
      final synth = js.context['speechSynthesis'];
      if (synth == null) return;
      // 読み上げ中なら停止
      synth.callMethod('cancel');
      final utt = html.SpeechSynthesisUtterance(text);
      utt.lang = 'ja-JP';
      utt.rate = 1.1;
      utt.pitch = 1.0;
      html.window.speechSynthesis?.speak(utt);
    } catch (_) {}
  }

  /// テキスト生成ヘルパー: KifuMoveのnoteをそのまま読み上げ
  static String moveText(bool isP1, String note) => note;
}
