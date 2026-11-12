import 'dart:convert';

import '../../../core/transport/remote_executor.dart';
import '../../../core/utils/shell_escape.dart';
import '../../settings/models/settings_preferences.dart';
import '../models/agent_session.dart';

/// Reads provider-owned session data. It does NOT use the app's tmux registry.
/// Claude/Codex persist JSONL transcripts; OpenCode provides a JSON CLI list.
/// All reads are bounded, read-only and occur on the selected SSH host.
class ProviderSessionSource {
  const ProviderSessionSource({this.limit = 40});
  final int limit;

  Future<List<AgentSession>> list(
    RemoteExecutor ssh,
    SshHostDraft host,
    Agent agent,
  ) =>
      switch (agent) {
        Agent.claude =>
          _jsonl(ssh, host, agent, r'$HOME/.claude/projects', 'Claude Code'),
        Agent.codex =>
          _jsonl(ssh, host, agent, r'$HOME/.codex/sessions', 'Codex'),
        Agent.opencode => _opencode(ssh, host),
      };

  Future<List<AgentSession>> _jsonl(
    RemoteExecutor ssh,
    SshHostDraft host,
    Agent agent,
    String root,
    String display,
  ) async {
    // HOME expands only in this trusted fixed expression, never user input.
    // Provider files are listed newest-first by modification time. Absolute
    // paths cannot be treated as command options by ls. No user input enters
    // this command, and the read below remains bounded by [limit].
    final command = 'if test -d "' +
        root +
        '"; then find "' +
        root +
        '" -type f -name ' +
        shellQuote('*.jsonl') +
        ' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n ' +
        (limit * 3).toString() +
        '; fi';
    final paths = await ssh.run(command);
    if (!paths.succeeded && paths.stdout.trim().isEmpty) {
      throw StateError('No readable $display session store on this host');
    }
    final results = <AgentSession>[];
    final uuid = RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
    );
    for (final line in paths.stdout.split('\n')) {
      if (results.length >= limit) break;
      final path = line.trim();
      if (path.isEmpty || path.contains('\r')) continue;
      final filename = path.split('/').last;
      if (!filename.endsWith('.jsonl')) continue;
      final id = agent == Agent.claude
          ? filename.substring(0, filename.length - 6)
          : _codexId(filename);
      if (id == null || !uuid.hasMatch(id)) continue;
      final read = await ssh.run('head -c 65536 -- ' + shellQuote(path));
      if (!read.succeeded && read.stdout.isEmpty) continue;
      String? cwd, title, timestamp;
      for (final raw in const LineSplitter().convert(read.stdout)) {
        try {
          final value = jsonDecode(raw);
          if (value is! Map) continue;
          final data = Map<String, dynamic>.from(value);
          final payload = data['payload'] is Map
              ? Map<String, dynamic>.from(data['payload'] as Map)
              : data;
          cwd ??= (payload['cwd'] is String ? payload['cwd'] : null);
          cwd ??= (data['cwd'] is String ? data['cwd'] : null);
          if (data['timestamp'] is String) {
            timestamp = data['timestamp'] as String;
          }
          if (agent == Agent.claude && data['type'] == 'user') {
            title ??= _plainText(data['message']);
          }
          if (agent == Agent.codex &&
              data['type'] == 'event_msg' &&
              payload['type'] == 'user_message') {
            title ??= _plainText(payload['message']);
          }
        } on FormatException {
          // Truncated final record or a provider-specific record.
        }
      }
      final directory = cwd ?? '~';
      final project = directory == '~'
          ? (title ?? display + ' session')
          : directory.split('/').where((segment) => segment.isNotEmpty).last;
      results.add(AgentSession(
        'provider_${host.id}_${agent.name}_$id',
        project,
        host.name,
        directory,
        agent,
        WorkState.ready,
        title ?? 'Saved $display conversation',
        timestamp ?? 'Saved session',
        [],
        remoteHostId: host.id,
        providerSessionId: id,
        providerSourcePath: path,
      ));
    }
    // File enumeration is not guaranteed to be sorted by timestamp.
    results.sort((a, b) => b.updated.compareTo(a.updated));
    return results;
  }

  String? _codexId(String filename) {
    final match = RegExp(
      r'([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})\.jsonl$',
    ).firstMatch(filename);
    return match?.group(1);
  }

  String? _plainText(Object? value) {
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map) {
      return _plainText(value['text']) ??
          _plainText(value['content']) ??
          _plainText(value['message']);
    }
    if (value is List) {
      for (final part in value) {
        final text = _plainText(part);
        if (text != null) return text;
      }
    }
    return null;
  }

  /// Reads the recent provider-owned conversation; no synthetic model output.
  Future<List<ChatLine>> loadMessages(
    RemoteExecutor ssh,
    AgentSession session,
  ) async {
    if (session.providerSessionId == null) return [];
    if (session.agent == Agent.opencode) {
      return _opencodeMessages(ssh, session.providerSessionId!);
    }
    final source = session.providerSourcePath;
    if (source == null) return [];
    // Recent tail only; last truncated JSONL fragment is safely ignored.
    final result = await ssh.run('tail -c 262144 -- ' + shellQuote(source));
    if (!result.succeeded) {
      throw StateError('Cannot read provider conversation history');
    }
    final messages = <ChatLine>[];
    for (final raw in const LineSplitter().convert(result.stdout)) {
      try {
        final data = jsonDecode(raw);
        if (data is! Map) continue;
        final record = Map<String, dynamic>.from(data);
        final payload = record['payload'] is Map
            ? Map<String, dynamic>.from(record['payload'] as Map)
            : record;
        String? message;
        bool? byUser;
        if (session.agent == Agent.claude) {
          if (record['type'] == 'user') {
            byUser = true;
            message = _plainText(record['message']);
          } else if (record['type'] == 'assistant') {
            byUser = false;
            message = _plainText(record['message']);
          }
        } else if (session.agent == Agent.codex &&
            record['type'] == 'event_msg') {
          if (payload['type'] == 'user_message') {
            byUser = true;
            message = _plainText(payload['message']);
          } else if (payload['type'] == 'agent_message') {
            byUser = false;
            message = _plainText(payload['message']);
          }
        }
        if (byUser == null || message == null || message.isEmpty) continue;
        // UI preview is bounded independently of original provider history.
        messages.add(ChatLine(
          message.length > 12000 ? message.substring(0, 12000) : message,
          byUser,
          (record['timestamp'] ?? 'Saved').toString(),
        ));
      } on FormatException {
        // The first or last line may be partial due to the byte limit.
      }
    }
    return messages.length <= 40
        ? messages
        : messages.sublist(messages.length - 40);
  }

  Future<List<ChatLine>> _opencodeMessages(
    RemoteExecutor ssh,
    String id,
  ) async {
    if (!RegExp(r'^ses_[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
    final response = await ssh.run(
      'opencode session export ' +
          shellQuote(id) +
          ' --sanitize | head -c 262144',
    );
    if (!response.succeeded || response.stdout.isEmpty) return [];
    final value = jsonDecode(response.stdout);
    final entries = value is Map ? value['messages'] : null;
    if (entries is! List) return [];
    final messages = <ChatLine>[];
    for (final item in entries) {
      if (item is! Map) continue;
      final info = item['info'];
      final role = info is Map ? info['role'] : item['role'];
      if (role != 'user' && role != 'assistant') continue;
      final text = _plainText(item['parts'] ?? item['content']);
      if (text == null || text.isEmpty) continue;
      messages.add(ChatLine(
        text.length > 12000 ? text.substring(0, 12000) : text,
        role == 'user',
        'Saved',
      ));
    }
    return messages.length <= 40
        ? messages
        : messages.sublist(messages.length - 40);
  }

  Future<List<AgentSession>> _opencode(
    RemoteExecutor ssh,
    SshHostDraft host,
  ) async {
    final result = await ssh.run(
      'opencode session list --max-count $limit --format json',
    );
    if (!result.succeeded) {
      throw StateError('OpenCode session list failed: ${result.stderr.trim()}');
    }
    final decoded = jsonDecode(result.stdout);
    final items = decoded is List
        ? decoded
        : decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : <dynamic>[];
    final found = <AgentSession>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = item['id'];
      if (id is! String || !RegExp(r'^ses_[a-zA-Z0-9_-]+$').hasMatch(id)) {
        continue;
      }
      final directory =
          item['directory'] is String ? item['directory'] as String : '~';
      final title = item['title'] is String
          ? item['title'] as String
          : 'OpenCode session';
      final project = directory == '~'
          ? 'OpenCode'
          : directory.split('/').where((part) => part.isNotEmpty).last;
      final time = item['time'] is Map ? item['time'] as Map : null;
      found.add(AgentSession(
        'provider_${host.id}_opencode_$id',
        project,
        host.name,
        directory,
        Agent.opencode,
        WorkState.ready,
        title,
        (time?['updated'] ?? 'Saved session').toString(),
        [],
        remoteHostId: host.id,
        providerSessionId: id,
      ));
    }
    return found;
  }
}
