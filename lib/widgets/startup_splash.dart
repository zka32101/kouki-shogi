import 'package:flutter/material.dart';

/// 起動中の読み込み画面（中央にアプリのアイコンと進行表示、下部に組織ロゴ）。
///
/// 端末側の起動画面（背景色だけ。`launch_background.xml` / `values-v31`）と同じ背景色にして、
/// アプリの画像と組織ロゴが「一枚の画面」として見えるようにする。
/// 初期化（Firebase・課金・広告など）が終わる前に出す。
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  /// 端末側の起動画面の背景色（colors.xml の `splash_background`）と同じ値。
  static const splashBackground = Color(0xFF15110C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: splashBackground,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/branding/app_icon.png', width: 112, height: 112),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Semantics(
                label: 'Your Wish',
                child: Image.asset(
                  'assets/branding/yourwish_logo.png',
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
