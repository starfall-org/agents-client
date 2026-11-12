import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../features/settings/models/settings_preferences.dart';

/// WebSocket HTTP-upgrade values (including Authorization/Cookie) must never
/// enter SharedPreferences, JSON exports or logs. Native uses OS secure storage.
class SshWebSocketHeaderStore {
  const SshWebSocketHeaderStore();

  static const _storage = FlutterSecureStorage();
  static final Map<String, Map<String, String>> _webMemory = {};

  String _key(String hostId) => 'agents.ssh.websocket.headers.' + hostId;

  Future<Map<String, String>> read(String hostId) async {
    if (kIsWeb) return Map.of(_webMemory[hostId] ?? const {});
    final raw = await _storage.read(key: _key(hostId));
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      final result = <String, String>{};
      for (final entry in json.entries) {
        if (entry.key is! String || entry.value is! String) return {};
        final name = entry.key as String;
        final value = entry.value as String;
        if (SshHostDraft.validateHeaderName(name) != null ||
            SshHostDraft.validateHeaderValue(value) != null) {
          return {};
        }
        result[name] = value;
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<void> save(String hostId, Map<String, String> values) async {
    final checked = <String, String>{};
    for (final entry in values.entries) {
      final name = entry.key.trim();
      final error = SshHostDraft.validateHeaderName(name) ??
          SshHostDraft.validateHeaderValue(entry.value);
      if (error != null) throw FormatException(error);
      if (entry.value.length > 8192) {
        throw const FormatException('WebSocket header value is too long');
      }
      if (checked.keys.any((key) => key.toLowerCase() == name.toLowerCase())) {
        throw const FormatException('Duplicate header name');
      }
      checked[name] = entry.value;
    }
    if (kIsWeb) {
      _webMemory[hostId] = checked;
    } else {
      await _storage.write(key: _key(hostId), value: jsonEncode(checked));
    }
  }

  Future<void> delete(String hostId) async {
    _webMemory.remove(hostId);
    if (!kIsWeb) await _storage.delete(key: _key(hostId));
  }
}
