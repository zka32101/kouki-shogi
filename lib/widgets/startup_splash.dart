import 'package:flutter/material.dart';

/// 起動中の読み込み画面（中央に進行表示、下部に組織ロゴ）。
///
/// 初期化（Firebase・課金・広告など）が終わる前に出す。app_common_kit の
/// `StartupSplash` と同じ見た目で、アプリ内に持つ。
///
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Expanded(child: Center(child: CircularProgressIndicator())),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Semantics(
                label: 'Your Wish',
                child: Image.asset(
                  'assets/branding/yourwish_logo.png',
                  height: 40,
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
