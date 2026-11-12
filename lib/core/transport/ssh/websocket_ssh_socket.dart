import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_channel_web.dart' if (dart.library.io) 'ws_channel_io.dart'
    as platform;

/// Transports the raw SSH byte stream in WebSocket **binary frames**.
///
/// The gateway MUST forward bytes to one authorized SSH endpoint and return
/// SSH bytes, not JSON, text frames, base64, terminal commands, or a shell.
/// TLS and proxy authentication do not replace the SSH host-key check.
class WebSocketSshSocket implements SSHSocket {
  WebSocketSshSocket._(this._channel) {
    _subscription = _channel.stream.listen(
      (event) {
        if (event is List<int>) {
          if (!_input.isClosed) _input.add(Uint8List.fromList(event));
        } else {
          if (!_input.isClosed) {
            _input.addError(const FormatException(
              'SSH WebSocket gateway must send binary frames, not text.',
            ));
          }
          destroy();
        }
      },
      onError: (Object error, StackTrace trace) {
        if (!_input.isClosed) _input.addError(error, trace);
        _finish();
      },
      onDone: _finish,
    );

    _output.stream.listen(
      (bytes) {
        _channel.sink.add(Uint8List.fromList(bytes));
      },
      onDone: () {
        unawaited(_channel.sink.close());
      },
    );
  }

  final WebSocketChannel _channel;
  late final StreamSubscription<dynamic> _subscription;
  final StreamController<Uint8List> _input = StreamController<Uint8List>();
  final StreamController<List<int>> _output = StreamController<List<int>>();
  final Completer<void> _closed = Completer<void>();

  static Future<WebSocketSshSocket> connect(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    final channel = await platform.openSshWebSocket(Uri.parse(url), headers);
    return WebSocketSshSocket._(channel);
  }

  void _finish() {
    if (!_input.isClosed) unawaited(_input.close());
    if (!_output.isClosed) unawaited(_output.close());
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Stream<Uint8List> get stream => _input.stream;

  @override
  StreamSink<List<int>> get sink => _output.sink;

  @override
  Future<void> get done => _closed.future;

  @override
  Future<void> close() async {
    if (!_output.isClosed) await _output.close();
    await _channel.sink.close();
    await done;
  }

  @override
  void destroy() {
    unawaited(_channel.sink.close());
    unawaited(_subscription.cancel());
    _finish();
  }

  @override
  Future<void> flush() async {}
}
