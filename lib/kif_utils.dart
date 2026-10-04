// lib/kif_utils.dart — プラットフォーム別 KIF ユーティリティ
// Web: dart:html ファイル操作あり / Native: no-op stub

export 'kif_utils_stub.dart'
    if (dart.library.html) 'kif_utils_web.dart';
