import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// OpenCode HTTP Basic-auth secrets are never part of profile JSON.
/// Native: OS secure storage. Browser: process-memory only, no persistence.
class OpenCodePasswordStore {
  const OpenCodePasswordStore();
  static const _storage = FlutterSecureStorage();
  static final Map<String, String> _browserPasswords = {};

  String _key(String profileId) => 'agents.opencode.http.password.$profileId';

  Future<String?> read(String profileId) {
    if (kIsWeb) return Future.value(_browserPasswords[profileId]);
    return _storage.read(key: _key(profileId));
  }

  Future<void> save(String profileId, String password) {
    if (kIsWeb) {
      if (password.isEmpty) {
        _browserPasswords.remove(profileId);
      } else {
        _browserPasswords[profileId] = password;
      }
      return Future.value();
    }
    return password.isEmpty
        ? _storage.delete(key: _key(profileId))
        : _storage.write(key: _key(profileId), value: password);
  }

  Future<void> delete(String profileId) {
    _browserPasswords.remove(profileId);
    if (kIsWeb) return Future.value();
    return _storage.delete(key: _key(profileId));
  }
}
