import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agents/core/transport/ssh/websocket_ssh_socket.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Legacy SSH hosts deserialize as direct TCP', () {
    final host = SshHostDraft.fromJson({
      'id': 'h1',
      'name': 'Lab',
      'hostname': '127.0.0.1',
      'username': 'dev',
      'port': 22,
    });
    expect(host.transport, SshTransportMode.direct);
    expect(host.websocketHeaderNames, isEmpty);
  });

  test('WS gateway metadata persists header names, not values', () {
    const host = SshHostDraft(
      id: 'proxy1',
      name: 'Production SSH',
      hostname: 'ssh.example.com',
      username: 'dev',
      port: 2222,
      transport: SshTransportMode.websocket,
      websocketUrl: 'wss://gateway.example.com/ssh?port=2222',
      websocketHeaderNames: [
        'Authorization',
        'Origin',
        'Cookie',
        'Cloudflare-Access-Client-Secret',
        'X-Custom-Name',
      ],
    );
    final preferences = SettingsPreferences()..hosts.add(host);
    final json = preferences.encode();
    expect(json, contains('Authorization'));
    expect(json, isNot(contains('Bearer top-secret')));
    final loaded = SettingsPreferences()..loadFromJson(preferences.toJson());
    expect(loaded.hosts.single.usesWebSocket, isTrue);
    expect(loaded.hosts.single.websocketHeaderNames, hasLength(5));
    expect(loaded.hosts.single.withId('second').websocketHeaderNames,
        hasLength(5));
  });

  test('Remote WS must use TLS and WS URLs have no userinfo', () {
    expect(
        SshHostDraft.validateWebSocketUrl('wss://proxy.example/ssh'), isNull);
    expect(
        SshHostDraft.validateWebSocketUrl('ws://localhost:3010/ssh'), isNull);
    expect(
        SshHostDraft.validateWebSocketUrl('ws://127.0.0.1:3010/ssh'), isNull);
    expect(
        SshHostDraft.validateWebSocketUrl('ws://proxy.example/ssh'), isNotNull);
    expect(SshHostDraft.validateWebSocketUrl('wss://user:pw@proxy.example'),
        isNotNull);
    expect(
        SshHostDraft.validateWebSocketUrl('https://proxy.example'), isNotNull);
  });

  test('Accept customizable headers; reject managed names and CRLF', () {
    for (final name in [
      'Authorization',
      'Origin',
      'Cookie',
      'User-Agent',
      'X-Proxy-Token',
      'Cloudflare-Access-Client-Id',
      'Cloudflare-Access-Client-Secret',
    ]) {
      expect(SshHostDraft.validateHeaderName(name), isNull);
    }
    for (final name in [
      'Host',
      'Upgrade',
      'Connection',
      'sec-websocket-protocol',
      'SEC-WEBSOCKET-KEY',
      'Content-Length',
      'Authorization\r\nEvil',
    ]) {
      expect(SshHostDraft.validateHeaderName(name), isNotNull);
    }
    expect(SshHostDraft.validateHeaderValue('Bearer abc123'), isNull);
    expect(SshHostDraft.validateHeaderValue('Bearer abc\r\nInjected: yes'),
        isNotNull);
    expect(
        () => SshHostDraft.fromJson({
              'name': 'x',
              'hostname': 'example.com',
              'username': 'dev',
              'port': 22,
              'transport': 'websocket',
              'websocketUrl': 'wss://proxy.example',
              'websocketHeaderNames': ['X-Test', 'x-test'],
            }),
        throwsFormatException);
  });

  test('Binary SSH transport and arbitrary WS headers work end-to-end',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final observed = Completer<String>();
    final incoming = <int>[];
    server.listen((request) async {
      if (!observed.isCompleted) {
        observed.complete(request.headers.value('Authorization') ?? '');
      }
      final websocket = await WebSocketTransformer.upgrade(request);
      websocket.listen((message) {
        if (message is List<int>) {
          incoming.addAll(message);
          websocket.add(Uint8List.fromList(message));
        }
      });
    });

    final socket = await WebSocketSshSocket.connect(
      'ws://127.0.0.1:' + server.port.toString() + '/ssh',
      headers: {'Authorization': 'Bearer sample-token'},
    );
    final received = Completer<List<int>>();
    final subscription = socket.stream.listen((data) {
      if (!received.isCompleted) received.complete(data);
    });
    final payload = [0, 1, 2, 3, 0, 255, 254, 240, 128];
    socket.sink.add(payload);
    expect(await received.future.timeout(const Duration(seconds: 3)), payload);
    expect(incoming, payload);
    expect(await observed.future, 'Bearer sample-token');
    await socket.close().timeout(const Duration(seconds: 4));
    await subscription.cancel();
    await server.close(force: true);
  });
}
