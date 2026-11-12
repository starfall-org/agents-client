import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../../features/settings/models/settings_preferences.dart';
import '../../security/host_key_store.dart';
import '../../security/ssh_credential_store.dart';
import '../../security/ssh_websocket_header_store.dart';
import 'websocket_ssh_socket.dart';
import '../remote_executor.dart';

/// A live interactive PTY bound to one SSH session.
class SshTerminalChannel implements RemoteTerminalChannel {
  SshTerminalChannel(this._session);
  final SSHSession _session;
  Stream<String> get output => _session.stdout
      .cast<List<int>>()
      .transform(const Utf8Decoder(allowMalformed: true));
  void write(String text) =>
      _session.write(Uint8List.fromList(utf8.encode(text)));
  void resize(int columns, int rows) => _session.resizeTerminal(columns, rows);
  Future<void> get done => _session.done;
  void close() => _session.close();
}

/// SSH over native TCP or an explicit raw-binary WebSocket gateway.
/// Browser connections require a WebSocket gateway; no direct TCP is attempted.
class SshConnection implements RemoteExecutor {
  SshConnection._(this.host, this._client);
  final SshHostDraft host;
  final SSHClient _client;
  bool get connected => !_client.isClosed;
  Future<void> get done => _client.done;

  static Future<SshConnection> connect(
    SshHostDraft host,
    SshCredentials credentials, {
    required TrustOnFirstUse trustFirstKey,
    SshHostKeyStore keyStore = const SshHostKeyStore(),
  }) async {
    if (kIsWeb && !host.usesWebSocket) {
      throw UnsupportedError(
        'Browsers cannot open direct SSH sockets. '
        'Select WebSocket proxy on the SSH host.',
      );
    }
    if (!credentials.isValid) {
      throw ArgumentError('Provide an SSH password or a private key');
    }
    final identities = credentials.privateKeyPem?.isNotEmpty == true
        ? SSHKeyPair.fromPem(
            credentials.privateKeyPem!,
            credentials.keyPassphrase,
          )
        : <SSHKeyPair>[];
    final SSHSocket socket;
    if (host.usesWebSocket) {
      final url = host.websocketUrl;
      if (url == null || SshHostDraft.validateWebSocketUrl(url) != null) {
        throw ArgumentError('Invalid SSH WebSocket proxy URL');
      }
      if (kIsWeb && host.websocketHeaderNames.isNotEmpty) {
        throw UnsupportedError(
          'Browser WebSocket APIs cannot set HTTP upgrade headers. '
          'Use the native app for Authorization/Cookie/X-* headers.',
        );
      }
      final storedHeaders = await const SshWebSocketHeaderStore().read(host.id);
      final headers = <String, String>{};
      for (final name in host.websocketHeaderNames) {
        if (SshHostDraft.validateHeaderName(name) != null ||
            !storedHeaders.containsKey(name) ||
            SshHostDraft.validateHeaderValue(storedHeaders[name]!) != null) {
          throw StateError('Missing or invalid WebSocket header "$name". '
              'Edit the SSH host under Settings → Connections.');
        }
        headers[name] = storedHeaders[name]!;
      }
      socket = await WebSocketSshSocket.connect(
        url,
        headers: headers,
      );
    } else {
      socket = await SSHSocket.connect(
        host.hostname,
        host.port,
        timeout: const Duration(seconds: 12),
      );
    }
    final client = SSHClient(
      socket,
      username: host.username,
      identities: identities,
      onPasswordRequest:
          credentials.password == null ? null : () => credentials.password,
      onVerifyHostKey: (algorithm, key) => keyStore.verify(
        host: host,
        algorithm: algorithm,
        fingerprint: utf8.decode(key),
        confirm: trustFirstKey,
      ),
      handshakeTimeout: const Duration(seconds: 20),
      authTimeout: const Duration(seconds: 30),
    );
    try {
      await client.run('true'); // Wait for authentication.
      return SshConnection._(host, client);
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  Future<RemoteCommandResult> run(String command) async {
    if (!connected) throw StateError('SSH connection is closed');
    final result = await _client.runWithResult(command);
    return RemoteCommandResult(
      utf8.decode(result.stdout, allowMalformed: true),
      utf8.decode(result.stderr, allowMalformed: true),
      result.exitCode,
    );
  }

  Future<RemoteTerminalChannel> openTerminal(String command) async {
    if (!connected) throw StateError('SSH connection is closed');
    return SshTerminalChannel(await _client.execute(
      command,
      pty: const SSHPtyConfig(type: 'xterm-256color'),
    ));
  }

  Future<SftpClient> sftp() async {
    if (!connected) throw StateError('SSH connection is closed');
    return _client.sftp();
  }

  Future<void> disconnect() async {
    _client.close();
    try {
      await _client.done;
    } catch (_) {
      // Already disconnected.
    }
  }
}
