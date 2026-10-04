// lib/local_network_service.dart — 同一ネットワーク内 WebSocket 対局サービス
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

import 'piece.dart';            // AMove, PieceType
import 'network_game_service.dart'; // NetworkStatus

const int _kPort = 8788;

class LocalNetworkService {
  static HttpServer? _server;
  static WebSocket?  _socket;
  static bool _isHost = false;

  static final _moveCtrl   = StreamController<AMove>.broadcast();
  static final _statusCtrl = StreamController<NetworkStatus>.broadcast();

  static Stream<AMove>         get moveStream   => _moveCtrl.stream;
  static Stream<NetworkStatus> get statusStream => _statusCtrl.stream;
  static bool get isHost => _isHost;
  /// ホスト = 先手（P1）
  static bool get hostIsP1 => true;

  // ─── ホスト側: サーバ起動 ────────────────────────────────────────────────
  static Future<void> startHost() async {
    _isHost = true;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, _kPort);

    _server!.transform(WebSocketTransformer()).listen((ws) {
      _socket = ws;
      _statusCtrl.add(NetworkStatus.playing);
      _listenSocket(ws);
    });
  }

  // ─── ゲスト側: ホストへ接続 ──────────────────────────────────────────────
  static Future<void> connectToHost(String ip) async {
    _isHost = false;
    final ws = await WebSocket.connect('ws://$ip:$_kPort')
        .timeout(const Duration(seconds: 10));
    _socket = ws;
    _statusCtrl.add(NetworkStatus.playing);
    _listenSocket(ws);
  }

  // ─── 着手を送信 ─────────────────────────────────────────────────────────
  static void sendMove(AMove mv, {required bool isP1}) {
    _socket?.add(jsonEncode(_encodeMove(mv, isP1: isP1)));
  }

  // ─── 投了を送信 ─────────────────────────────────────────────────────────
  static Future<void> resign({required bool isP1}) async {
    _socket?.add(jsonEncode({'type': 'resign', 'isP1': isP1}));
    _statusCtrl.add(NetworkStatus.opponentResigned);
  }

  // ─── 端末のローカル IP 取得 ──────────────────────────────────────────────
  static Future<String> getLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}
    // フォールバック: NetworkInterface
    for (final iface in await NetworkInterface.list()) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '???';
  }

  // ─── 着手エンコード ──────────────────────────────────────────────────────
  static Map<String, dynamic> _encodeMove(AMove mv, {required bool isP1}) => {
    'fr':      mv.fr,
    'fc':      mv.fc,
    'tr':      mv.tr,
    'tc':      mv.tc,
    'promote': mv.promote,
    'drop':    mv.drop?.index,
    'isP1':    isP1,
  };

  // ─── 着手デコード ────────────────────────────────────────────────────────
  static AMove? _decodeMove(Map<String, dynamic> m) {
    try {
      final fr      = (m['fr'] as num).toInt();
      final fc      = (m['fc'] as num).toInt();
      final tr      = (m['tr'] as num).toInt();
      final tc      = (m['tc'] as num).toInt();
      final promote = m['promote'] as bool? ?? false;
      final dropIdx = m['drop'];
      final drop    = dropIdx != null
          ? PieceType.values[(dropIdx as num).toInt()]
          : null;
      return AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: promote, drop: drop);
    } catch (_) { return null; }
  }

  // ─── 受信ループ ─────────────────────────────────────────────────────────
  static void _listenSocket(WebSocket ws) {
    ws.listen(
      (data) {
        try {
          if (data is! String) return;
          final json = jsonDecode(data) as Map<String, dynamic>;
          if (json['type'] == 'resign') {
            _statusCtrl.add(NetworkStatus.opponentResigned);
          } else {
            final mv = _decodeMove(json);
            if (mv != null) _moveCtrl.add(mv);
          }
        } catch (_) {}
      },
      onDone:  () => _statusCtrl.add(NetworkStatus.ended),
      onError: (_) => _statusCtrl.add(NetworkStatus.ended),
    );
  }

  // ─── リソース解放 ────────────────────────────────────────────────────────
  static Future<void> dispose() async {
    await _socket?.close();
    await _server?.close(force: true);
    _socket = null;
    _server = null;
    _isHost = false;
  }
}
