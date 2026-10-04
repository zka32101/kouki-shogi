// lib/purchase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  // 300円プラン (買い切り)
  static const String _plan300Id = 'liki_shogi_plan_300';
  static const String _plan300PrefKey = 'plan_300_purchased';

  // 500円プラン (買い切り)
  static const String _plan500Id = 'liki_shogi_plan_500';
  static const String _plan500PrefKey = 'plan_500_purchased';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static bool _isAvailable = false;
  static bool _hasPlan300 = false;
  static bool _hasPlan500 = false;
  static ProductDetails? _plan300Product;
  static ProductDetails? _plan500Product;

  static bool get isAvailable => _isAvailable && !kIsWeb;
  static bool get hasPlan300 => _hasPlan300;
  static bool get hasPlan500 => _hasPlan500;
  static bool get isPremium => _hasPlan300 || _hasPlan500;
  static ProductDetails? get plan300Product => _plan300Product;
  static ProductDetails? get plan500Product => _plan500Product;

  /// アプリ起動時に呼ぶ
  static Future<void> initialize() async {
    if (kIsWeb) return;

    // SharedPreferences から既存の購入状態を復元
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasPlan300 = prefs.getBool(_plan300PrefKey) ?? false;
      _hasPlan500 = prefs.getBool(_plan500PrefKey) ?? false;
    } catch (_) {}

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) return;

      // 購入イベントを購読
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (_) {},
      );

      // 未完了の購入を復元
      await _iap.restorePurchases();

      // 商品情報を取得（300円 + 500円）
      final response = await _iap.queryProductDetails({_plan300Id, _plan500Id});
      for (final p in response.productDetails) {
        if (p.id == _plan300Id) _plan300Product = p;
        if (p.id == _plan500Id) _plan500Product = p;
      }
    } catch (_) {}
  }

  static void dispose() {
    _subscription?.cancel();
  }

  /// 300円プラン購入
  static Future<bool> purchasePlan300() async {
    if (!_isAvailable || _plan300Product == null) return false;
    try {
      final param = PurchaseParam(productDetails: _plan300Product!);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// 500円プラン購入
  static Future<bool> purchasePlan500() async {
    if (!_isAvailable || _plan500Product == null) return false;
    try {
      final param = PurchaseParam(productDetails: _plan500Product!);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// 購入復元
  /// restorePurchases()はリクエストを送るだけで、実際の反映は非同期の
  /// purchaseStream経由（_onPurchaseUpdate）のため、呼び出し元が即座に
  /// hasPlan300/500を読んでも反映前の古い値のままになる。復元対象がある
  /// 場合はストリームからイベントが届くまで待ってから返す。
  static Future<void> restore() async {
    if (!_isAvailable) return;
    try {
      final completer = Completer<void>();
      final sub = _iap.purchaseStream.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _iap.restorePurchases();
      // 復元対象が無ければイベントが来ないため、タイムアウトで抜ける
      await completer.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      // _onPurchaseUpdate側の非同期処理(SharedPreferences書き込み等)が
      // 追いつくよう少し待つ
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
    } catch (_) {}
  }

  static void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == _plan300Id) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _setPlan300(true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.productID == _plan500Id) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _setPlan500(true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  static Future<void> _setPlan300(bool value) async {
    _hasPlan300 = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_plan300PrefKey, value);
    } catch (_) {}
  }

  static Future<void> _setPlan500(bool value) async {
    _hasPlan500 = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_plan500PrefKey, value);
    } catch (_) {}
  }
}
