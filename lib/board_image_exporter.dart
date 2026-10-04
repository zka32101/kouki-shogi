// lib/board_image_exporter.dart — プラットフォーム別 exportBoardImage
// Web: dart:html Canvas / Native: no-op stub

export 'board_image_exporter_stub.dart'
    if (dart.library.html) 'board_image_exporter_web.dart';
