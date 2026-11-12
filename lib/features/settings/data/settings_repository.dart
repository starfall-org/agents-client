import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_preferences.dart';

/// Only non-secret profile metadata and UX preferences are stored here.
class SettingsRepository {
  const SettingsRepository();

  static const _key = 'agents.preferences.v1';
  SharedPreferencesAsync get _storage => SharedPreferencesAsync();

  Future<void> loadInto(SettingsPreferences preferences) async {
    final raw = await _storage.getString(_key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) preferences.loadFromJson(json);
    } on FormatException {
      // Fail closed: invalid storage never becomes an SSH profile.
    }
  }

  Future<void> save(SettingsPreferences preferences) =>
      _storage.setString(_key, preferences.encode());
}
