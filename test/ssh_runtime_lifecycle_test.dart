import 'dart:async';

import 'package:agents/core/runtime/remote_runtime.dart';
import 'package:agents/core/security/ssh_credential_store.dart';
import 'package:agents/core/transport/ssh/ssh_connection.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const host = SshHostDraft(
    id: 'secure-host-1',
    name: 'Dev host',
    hostname: '127.0.0.1',
    username: 'dev',
  );
  const credentials = SshCredentials(password: 'not-saved-in-session');

  Future<bool> rejectNewKey(
          String host, String algorithm, String fingerprint) async =>
      false;

  test('duplicate SSH connection attempts share one handshake', () async {
    final future = Completer<SshConnection>();
    var attempts = 0;
    final runtime = RemoteRuntime(
      connector: (host, credentials, {required trustFirstKey}) {
        attempts++;
        return future.future;
      },
    );
    final first = runtime.connect(
      host,
      credentials,
      approveHostKey: rejectNewKey,
    );
    final second = runtime.connect(
      host,
      credentials,
      approveHostKey: rejectNewKey,
    );
    expect(identical(first, second), isTrue);
    expect(attempts, 1);

    final expectingError = expectLater(first, throwsStateError);
    runtime.dispose();
    future.completeError(StateError('SSH handshake interrupted'));
    await expectingError;
    expect(runtime.connectedHostIds, isEmpty);
  });

  test('explicit disconnect invalidates pending connect and permits retry',
      () async {
    final gates = [
      Completer<SshConnection>(),
      Completer<SshConnection>(),
    ];
    var attempts = 0;
    final runtime = RemoteRuntime(
      connector: (host, credentials, {required trustFirstKey}) {
        return gates[attempts++].future;
      },
    );

    final first = runtime.connect(
      host,
      credentials,
      approveHostKey: rejectNewKey,
    );
    await runtime.disconnect(host.id);
    final second = runtime.connect(
      host,
      credentials,
      approveHostKey: rejectNewKey,
    );
    expect(attempts, 2);
    final firstError = expectLater(first, throwsStateError);
    final secondError = expectLater(second, throwsStateError);
    gates[0].completeError(StateError('canceled'));
    gates[1].completeError(StateError('refused'));
    await firstError;
    await secondError;
    expect(runtime.connectedHostIds, isEmpty);
    runtime.dispose();
  });
}
