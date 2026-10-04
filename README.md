# 効棋 (kouki-shogi)

将棋の「利き」を学べる Flutter アプリ（Android / iOS）。AI対局・詰将棋・手筋・感想戦など。

## ビルド

署名鍵と Firebase 設定はこのリポジトリに含まれません。

1. `lib/firebase_options.dart.example` を `lib/firebase_options.dart` にコピーして値を埋める（`flutterfire configure` でも生成可）
2. `android/app/google-services.json` を配置
3. リリース署名は `android/key.properties`（`storeFile` / `storePassword` / `keyAlias` / `keyPassword`）を用意
4. `flutter pub get` → `flutter run`

© Petit Works Apps
