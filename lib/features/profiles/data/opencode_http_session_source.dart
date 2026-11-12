import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../sessions/models/agent_session.dart';
import '../models/agent_profile.dart';

/// OpenCode's documented HTTP API, independent of SSH and tmux.
/// All requests stay on the configured origin, reject redirects, and have
/// a bounded response size and deadline.
class OpenCodeHttpSessionSource {
  const OpenCodeHttpSessionSource({this.limit = 40});
  final int limit;

  Future<List<AgentSession>> list(
    AgentProfile profile, {
    String? password,
    http.Client? client,
  }) async {
    final value = await _request(
      profile,
      password: password,
      client: client,
      method: 'GET',
      path: 'session',
    );
    if (value is! List) {
      throw const FormatException('OpenCode returned an invalid session list');
    }
    final sessions = <AgentSession>[];
    for (final raw in value.take(limit)) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = item['id'];
      if (id is! String || !_validId(id)) continue;
      final directory =
          item['directory'] is String ? item['directory'] as String : '~';
      final title = item['title'] is String
          ? item['title'] as String
          : 'Saved OpenCode session';
      final folder = directory == '~'
          ? 'OpenCode'
          : directory.split('/').where((part) => part.isNotEmpty).last;
      final times = item['time'] is Map ? item['time'] as Map : null;
      final updated = times?['updated'];
      final lastActivity = updated is num
          ? DateTime.fromMillisecondsSinceEpoch(updated.toInt())
              .toLocal()
              .toIso8601String()
          : 'Saved session';
      sessions.add(AgentSession(
        'opencode_http_${profile.id}_$id',
        folder,
        profile.name,
        directory,
        Agent.opencode,
        WorkState.ready,
        title,
        lastActivity,
        [],
        providerSessionId: id,
        httpProfileId: profile.id,
      ));
    }
    return sessions;
  }

  Future<AgentSession> createSession(
    AgentProfile profile,
    String title, {
    String? password,
    http.Client? client,
  }) async {
    final value = await _request(
      profile,
      password: password,
      client: client,
      method: 'POST',
      path: 'session',
      body: {'title': title},
    );
    if (value is! Map ||
        value['id'] is! String ||
        !_validId(value['id'] as String)) {
      throw const FormatException('OpenCode returned an invalid session');
    }
    final id = value['id'] as String;
    final directory =
        value['directory'] is String ? value['directory'] as String : '~';
    final project = directory == '~'
        ? 'OpenCode'
        : directory.split('/').where((part) => part.isNotEmpty).last;
    return AgentSession(
      'opencode_http_' + profile.id + '_' + id,
      project,
      profile.name,
      directory,
      Agent.opencode,
      WorkState.ready,
      value['title'] is String ? value['title'] as String : title,
      'Just now',
      [],
      providerSessionId: id,
      httpProfileId: profile.id,
    );
  }

  Future<List<ChatLine>> messages(
    AgentProfile profile,
    String sessionId, {
    String? password,
    http.Client? client,
  }) async {
    if (!_validId(sessionId)) throw ArgumentError.value(sessionId);
    final value = await _request(
      profile,
      password: password,
      client: client,
      method: 'GET',
      path: 'session/${Uri.encodeComponent(sessionId)}/message',
      query: {'limit': '40'},
    );
    if (value is! List) {
      throw const FormatException('OpenCode returned invalid messages');
    }
    final result = <ChatLine>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      final info = record['info'];
      final role = info is Map ? info['role'] : record['role'];
      if (role != 'user' && role != 'assistant') continue;
      final parts = record['parts'];
      final texts = <String>[];
      if (parts is List) {
        for (final part in parts) {
          if (part is Map && part['type'] == 'text' && part['text'] is String) {
            texts.add(part['text'] as String);
          }
        }
      }
      if (texts.isEmpty) continue;
      final text = texts.join('\n');
      result.add(ChatLine(
        text.length > 12000 ? text.substring(0, 12000) : text,
        role == 'user',
        'Saved',
      ));
    }
    return result.length > 40 ? result.sublist(result.length - 40) : result;
  }

  Future<void> sendPrompt(
    AgentProfile profile,
    String sessionId,
    String prompt, {
    String? password,
    http.Client? client,
  }) async {
    if (!_validId(sessionId)) throw ArgumentError.value(sessionId);
    if (prompt.trim().isEmpty) throw ArgumentError.value(prompt, 'prompt');
    await _request(
      profile,
      password: password,
      client: client,
      method: 'POST',
      path: 'session/${Uri.encodeComponent(sessionId)}/prompt_async',
      body: {
        'parts': [
          {'type': 'text', 'text': prompt},
        ],
      },
    );
  }

  static bool _validId(String id) =>
      id.startsWith('ses_') &&
      id.length <= 128 &&
      RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);

  Future<dynamic> _request(
    AgentProfile profile, {
    required String method,
    required String path,
    required String? password,
    http.Client? client,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (!profile.usesHttp ||
        AgentProfile.validateHttpUrl(profile.httpUrl ?? '') != null) {
      throw ArgumentError('A valid OpenCode HTTP profile is required');
    }
    final base = Uri.parse(profile.httpUrl!);
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final url = base.replace(
      path: basePath + path,
      queryParameters: query,
    );
    final ownClient = client == null;
    final connection = client ?? http.Client();
    try {
      final request = http.Request(method, url)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      if (password != null && password.isNotEmpty) {
        request.headers['Authorization'] = 'Basic ' +
            base64Encode(utf8.encode('${profile.httpUsername}:$password'));
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response =
          await connection.send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('OpenCode login rejected. Check username/password.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'OpenCode HTTP request failed (${response.statusCode}). '
          'Check the server URL and API version.',
        );
      }
      if (response.statusCode == 204) return null;
      final output = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        output.addAll(chunk);
        if (output.length > 1024 * 1024) {
          throw const FormatException('OpenCode response exceeds 1 MiB');
        }
      }
      if (output.isEmpty) return null;
      return jsonDecode(utf8.decode(output));
    } finally {
      if (ownClient) connection.close();
    }
  }
}
