// lib/ad_service_stub.dart
import 'package:flutter/widgets.dart';

class AdService {
  static Future<void> initialize() async {}
  static bool get isSupported => false;
}

class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
