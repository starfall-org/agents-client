import 'package:web_socket_channel/web_socket_channel.dart';

/// Browsers do not expose arbitrary HTTP upgrade headers. Do not pretend
/// Authorization/Cookie/X-* can be sent; users must configure proxy auth via
/// same-origin cookies/subprotocols at the gateway or use the native app.
Future<WebSocketChannel> openSshWebSocket(
  Uri uri,
  Map<String, String> headers,
) async {
  if (headers.isNotEmpty) {
    throw UnsupportedError(
      'Browsers cannot set custom WebSocket handshake headers. '
      'Use the native app for Authorization/Cookie/X-* headers, '
      'or configure gateway-managed browser authentication.',
    );
  }
  final channel = WebSocketChannel.connect(uri);
  try {
    await channel.ready.timeout(const Duration(seconds: 14));
    return channel;
  } catch (_) {
    await channel.sink.close();
    rethrow;
  }
}
