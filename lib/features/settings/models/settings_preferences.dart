import 'dart:convert';

import '../../sessions/models/agent_session.dart';
import '../../profiles/models/agent_profile.dart';

/// Non-secret preferences and SSH host profiles, serialized locally.
/// Passwords/private keys must NEVER enter this model.
class SettingsPreferences {
  Agent defaultAgent = Agent.claude;
  String defaultDirectory = '~/projects';
  bool compactMessages = false;
  bool showActivity = true;
  bool autoReconnect = true;
  bool useTmux = true;
  bool approvalNotifications = true;
  bool completionNotifications = false;
  bool showCommandPreview = true;
  final List<SshHostDraft> hosts = [];
  final List<AgentProfile> profiles = [];
  String? activeProfileId;

  Map<String, Object?> toJson() => {
        'version': 1,
        'defaultAgent': defaultAgent.name,
        'defaultDirectory': defaultDirectory,
        'compactMessages': compactMessages,
        'showActivity': showActivity,
        'autoReconnect': autoReconnect,
        'useTmux': true,
        'approvalNotifications': approvalNotifications,
        'completionNotifications': completionNotifications,
        'showCommandPreview': true,
        'hosts': hosts.map((host) => host.toJson()).toList(),
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
        'activeProfileId': activeProfileId,
      };

  void loadFromJson(Map<String, dynamic> json) {
    defaultAgent = Agent.values.firstWhere(
      (agent) => agent.name == json['defaultAgent'],
      orElse: () => Agent.claude,
    );
    defaultDirectory = json['defaultDirectory'] is String
        ? json['defaultDirectory'] as String
        : '~/projects';
    compactMessages = json['compactMessages'] == true;
    showActivity = json['showActivity'] != false;
    autoReconnect = json['autoReconnect'] != false;
    useTmux = true;
    approvalNotifications = json['approvalNotifications'] != false;
    completionNotifications = json['completionNotifications'] == true;
    showCommandPreview = true;
    profiles.clear();
    for (final item in (json['profiles'] as List<dynamic>? ?? [])) {
      if (item is Map) {
        try {
          profiles.add(AgentProfile.fromJson(Map<String, dynamic>.from(item)));
        } on FormatException {
          // Invalid profile must never select a remote host.
        }
      }
    }
    activeProfileId = json['activeProfileId'] is String &&
            profiles.any((profile) => profile.id == json['activeProfileId'])
        ? json['activeProfileId'] as String
        : null;
    hosts.clear();
    for (final item in (json['hosts'] as List<dynamic>? ?? [])) {
      if (item is Map) {
        try {
          hosts.add(SshHostDraft.fromJson(Map<String, dynamic>.from(item)));
        } on FormatException {
          // Skip malformed profiles, never an arbitrary SSH destination.
        }
      }
    }
  }

  String encode() => jsonEncode(toJson());
}

class SshHostDraft {
  const SshHostDraft({
    required this.name,
    required this.hostname,
    required this.username,
    this.port = 22,
    this.id = '',
  });

  /// Stable identifier, assigned on save. Kept when a host is edited.
  final String id;
  final String name;
  final String hostname;
  final String username;
  final int port;

  SshHostDraft withId(String newId) => SshHostDraft(
        id: newId,
        name: name,
        hostname: hostname,
        username: username,
        port: port,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'hostname': hostname,
        'username': username,
        'port': port,
      };

  factory SshHostDraft.fromJson(Map<String, dynamic> json) {
    final hostname = json['hostname'];
    final username = json['username'];
    final name = json['name'];
    final port = json['port'];
    if (hostname is! String ||
        hostname.trim().isEmpty ||
        username is! String ||
        username.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        port is! int ||
        port < 1 ||
        port > 65535) {
      throw const FormatException('Invalid SSH host');
    }
    return SshHostDraft(
      id: json['id'] is String ? json['id'] as String : '',
      name: name,
      hostname: hostname,
      username: username,
      port: port,
    );
  }
}
