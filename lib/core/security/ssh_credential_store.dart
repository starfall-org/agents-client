import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SshCredentials {
  const SshCredentials({this.password, this.privateKeyPem, this.keyPassphrase});
  final String? password, privateKeyPem, keyPassphrase;
  bool get isValid =>
      (password?.isNotEmpty ?? false) || (privateKeyPem?.isNotEmpty ?? false);
  Map<String, Object?> toJson() => {
        'password': password,
        'privateKeyPem': privateKeyPem,
        'keyPassphrase': keyPassphrase,
      };
  factory SshCredentials.fromJson(Map<String, dynamic> value) => SshCredentials(
        password: value['password'] as String?,
        privateKeyPem: value['privateKeyPem'] as String?,
        keyPassphrase: value['keyPassphrase'] as String?,
      );
}

/// Native OS keychain only. Browsers cannot store SSH credentials here.
class SshCredentialStore {
  const SshCredentialStore();
  static const _storage = FlutterSecureStorage();
  String _key(String hostId) => 'agents.ssh.credentials.' + hostId;

  Future<SshCredentials?> read(String hostId) async {
    if (kIsWeb) return null;
    final encoded = await _storage.read(key: _key(hostId));
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded);
      if (json is Map<String, dynamic>) {
        return SshCredentials.fromJson(json);
      }
    } on FormatException {
      // Ignore malformed credentials rather than attempting authentication.
    }
    return null;
  }

  Future<void> save(String hostId, SshCredentials credentials) async {
    if (kIsWeb) throw UnsupportedError('Browser credential storage disabled');
    await _storage.write(
      key: _key(hostId),
      value: jsonEncode(credentials.toJson()),
    );
  }

  Future<void> delete(String hostId) async {
    if (!kIsWeb) await _storage.delete(key: _key(hostId));
  }
}
