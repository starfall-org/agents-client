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

enum SshTransportMode { direct, websocket }

/// Non-secret SSH endpoint data. HTTP upgrade header values are separately
/// kept in the credential vault, never in SharedPreferences.
class SshHostDraft {
  const SshHostDraft({
    required this.name,
    required this.hostname,
    required this.username,
    this.port = 22,
    this.id = '',
    this.transport = SshTransportMode.direct,
    this.websocketUrl,
    this.websocketHeaderNames = const [],
  });

  final String id, name, hostname, username;
  final int port;
  final SshTransportMode transport;
  final String? websocketUrl;
  final List<String> websocketHeaderNames;

  bool get usesWebSocket => transport == SshTransportMode.websocket;

  /// Permits a TLS-protected remote gateway, or local cleartext for testing.
  /// URL user info is rejected: put credentials in headers, not the address.
  static String? validateWebSocketUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      return 'Enter a valid ws:// or wss:// URL without embedded credentials or fragment.';
    }
    // Query parameters may select a proxy route, but authentication secrets
    // belong in secure headers and must never be serialized in a URL.
    final secretName = RegExp(
        r'(token|secret|password|passphrase|apikey|api_key|auth|signature)',
        caseSensitive: false);
    if (uri.queryParameters.keys.any(secretName.hasMatch)) {
      return 'Do not put authentication secrets in the URL. Use proxy headers.';
    }
    final isLocal = {'localhost', '127.0.0.1', '::1', '[::1]'}
        .contains(uri.host.toLowerCase());
    if (uri.scheme == 'ws' && !isLocal) {
      return 'Use wss:// for remote proxies. ws:// is allowed only on localhost.';
    }
    return null;
  }

  /// Header identifiers use RFC 9110 token syntax. The WebSocket protocol
  /// owns Upgrade, Connection, Host, Sec-WebSocket-* and framing headers.
  static String? validateHeaderName(String input) {
    final name = input.trim();
    final token = RegExp(r"^[!#$%&'*+.^_\x60|~0-9A-Za-z-]+$");
    if (name.isEmpty || !token.hasMatch(name)) {
      return 'Header name must be a valid HTTP field name.';
    }
    final lower = name.toLowerCase();
    if (lower == 'host' ||
        lower == 'connection' ||
        lower == 'upgrade' ||
        lower == 'content-length' ||
        lower == 'transfer-encoding' ||
        lower.startsWith('sec-websocket-')) {
      return 'Header "$name" is managed by the WebSocket handshake.';
    }
    return null;
  }

  static String? validateHeaderValue(String value) =>
      value.contains('\r') || value.contains('\n') || value.contains('\u0000')
          ? 'Header values cannot contain CR, LF or NUL.'
          : null;

  SshHostDraft withId(String newId) => SshHostDraft(
        id: newId,
        name: name,
        hostname: hostname,
        username: username,
        port: port,
        transport: transport,
        websocketUrl: websocketUrl,
        websocketHeaderNames: websocketHeaderNames,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'hostname': hostname,
        'username': username,
        'port': port,
        'transport': transport.name,
        'websocketUrl': usesWebSocket ? websocketUrl : null,
        // Never serialize HTTP upgrade header values here.
        'websocketHeaderNames':
            usesWebSocket ? websocketHeaderNames : <String>[],
      };

  factory SshHostDraft.fromJson(Map<String, dynamic> json) {
    final hostname = json['hostname'];
    final username = json['username'];
    final name = json['name'];
    final port = json['port'];
    final transportName = json['transport'] ?? SshTransportMode.direct.name;
    if (hostname is! String ||
        hostname.trim().isEmpty ||
        username is! String ||
        username.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        transportName is! String ||
        !SshTransportMode.values.any((mode) => mode.name == transportName)) {
      throw const FormatException('Invalid SSH host');
    }
    final transport = SshTransportMode.values
        .firstWhere((mode) => mode.name == transportName);
    final headerNames = <String>[];
    if (transport == SshTransportMode.websocket) {
      final url = json['websocketUrl'];
      if (url is! String || validateWebSocketUrl(url) != null) {
        throw const FormatException('Invalid SSH WebSocket gateway URL');
      }
      final raw = json['websocketHeaderNames'];
      if (raw != null && raw is! List) {
        throw const FormatException('Invalid WebSocket header names');
      }
      for (final header in (raw as List<dynamic>? ?? [])) {
        if (header is! String ||
            validateHeaderName(header) != null ||
            headerNames
                .any((other) => other.toLowerCase() == header.toLowerCase())) {
          throw const FormatException('Invalid WebSocket header name');
        }
        headerNames.add(header);
      }
    }
    return SshHostDraft(
      id: json['id'] is String ? json['id'] as String : '',
      name: name,
      hostname: hostname,
      username: username,
      port: port,
      transport: transport,
      websocketUrl: transport == SshTransportMode.websocket
          ? (json['websocketUrl'] as String).trim()
          : null,
      websocketHeaderNames: List.unmodifiable(headerNames),
    );
  }
}
