import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> openSshWebSocket(
  Uri uri,
  Map<String, String> headers,
) async {
  final channel = IOWebSocketChannel.connect(
    uri,
    headers: headers,
    connectTimeout: const Duration(seconds: 12),
    pingInterval: const Duration(seconds: 30),
  );
  try {
    await channel.ready.timeout(const Duration(seconds: 14));
    return channel;
  } catch (_) {
    await channel.sink.close();
    rethrow;
  }
}
