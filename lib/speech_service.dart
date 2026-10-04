// lib/speech_service.dart — プラットフォーム別 SpeechService
// Web: dart:html Speech API / Native: no-op stub

export 'speech_service_stub.dart'
    if (dart.library.html) 'speech_service_web.dart';
