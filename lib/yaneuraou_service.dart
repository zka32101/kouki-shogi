// lib/yaneuraou_service.dart — プラットフォーム別 YaneuraouService
// Web: dart:html Web Worker + WASM / Native: no-op stub

export 'yaneuraou_service_stub.dart'
    if (dart.library.html) 'yaneuraou_service_web.dart';
