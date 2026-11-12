import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/models/settings_preferences.dart';

typedef TrustOnFirstUse = Future<bool> Function(
  String host,
  String algorithm,
  String fingerprint,
);

class HostKeyMismatch implements Exception {
  HostKeyMismatch(this.host, this.expected, this.received);
  final String host, expected, received;
  @override
  String toString() =>
      'SSH host key CHANGED for $host. Expected $expected, received $received. Connection refused.';
}

/// Explicit trust-on-first-use. Any subsequent change is refused.
class SshHostKeyStore {
  const SshHostKeyStore();
  String _key(SshHostDraft host) =>
      'agents.ssh.hostkey.' +
      host.hostname.toLowerCase() +
      ':' +
      host.port.toString();

  Future<String?> trustedKey(SshHostDraft host) =>
      SharedPreferencesAsync().getString(_key(host));

  Future<bool> verify({
    required SshHostDraft host,
    required String algorithm,
    required String fingerprint,
    required TrustOnFirstUse confirm,
  }) async {
    if (!fingerprint.startsWith('SHA256:')) {
      throw const FormatException('Unsupported host key fingerprint');
    }
    final line = algorithm + ' ' + fingerprint;
    final stored = await trustedKey(host);
    if (stored != null) {
      if (stored != line) {
        throw HostKeyMismatch(host.hostname, stored, line);
      }
      return true;
    }
    final approved = await confirm(
      host.hostname + ':' + host.port.toString(),
      algorithm,
      fingerprint,
    );
    if (!approved) return false;
    await SharedPreferencesAsync().setString(_key(host), line);
    return true;
  }
}
