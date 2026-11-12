import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_session.dart';

/// Stores only non-secret tmux session metadata, never conversation content.
class RemoteSessionRepository {
  const RemoteSessionRepository();
  static const _key = 'agents.remote.sessions.v1';

  Future<List<AgentSession>> read() async {
    final text = await SharedPreferencesAsync().getString(_key);
    if (text == null) return [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return [];
      final result = <AgentSession>[];
      for (final record in decoded) {
        if (record is! Map) continue;
        final data = Map<String, dynamic>.from(record);
        final hostId = data['hostId'];
        final tmuxName = data['tmuxName'];
        final id = data['id'];
        if (hostId is! String || tmuxName is! String || id is! String) {
          continue;
        }
        final agent = Agent.values.firstWhere(
          (agent) => agent.name == data['agent'],
          orElse: () => Agent.claude,
        );
        result.add(AgentSession(
          id,
          (data['project'] as String?) ?? 'Remote agent',
          (data['hostName'] as String?) ?? 'Remote host',
          (data['directory'] as String?) ?? '~/projects',
          agent,
          WorkState.disconnected,
          'Reconnect to continue remote session',
          'Saved session',
          [],
          remoteHostId: hostId,
          tmuxName: tmuxName,
        ));
      }
      return result;
    } on FormatException {
      return [];
    }
  }

  Future<void> save(Iterable<AgentSession> sessions) async {
    final data = sessions
        .where((s) => s.isSshRemote && s.tmuxName != null)
        .map((session) => {
              'id': session.id,
              'project': session.project,
              'hostName': session.host,
              'hostId': session.remoteHostId,
              'directory': session.path,
              'agent': session.agent.name,
              'tmuxName': session.tmuxName,
            })
        .toList();
    await SharedPreferencesAsync().setString(_key, jsonEncode(data));
  }
}
