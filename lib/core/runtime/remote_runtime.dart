import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/settings/models/settings_preferences.dart';
import '../../features/sessions/models/agent_session.dart';
import '../../features/sessions/data/provider_session_source.dart';
import '../security/host_key_store.dart';
import '../security/ssh_credential_store.dart';
import '../transport/ssh/ssh_connection.dart';
import '../transport/remote_executor.dart';
import 'tmux_service.dart';

class RemoteCapabilities {
  const RemoteCapabilities({required this.tmux, required this.agents});
  final bool tmux;
  final Map<Agent, bool> agents;
}

/// Keeps a single SSH connection per host. Closing a PTY detaches from tmux
/// while the remote coding agent process continues to run.
class RemoteRuntime extends ChangeNotifier {
  RemoteRuntime({TmuxService tmux = const TmuxService()}) : _tmux = tmux;
  final TmuxService _tmux;
  final Map<String, SshConnection> _connections = {};
  void Function(String hostId)? onConnectionLost;

  bool isConnected(String hostId) => _connections[hostId]?.connected ?? false;

  List<String> get connectedHostIds =>
      _connections.keys.where((id) => isConnected(id)).toList(growable: false);

  SshConnection requireConnection(String hostId) {
    final ssh = _connections[hostId];
    if (ssh == null || !ssh.connected) {
      throw StateError('Connect to the SSH host in Settings first');
    }
    return ssh;
  }

  Future<void> connect(
    SshHostDraft host,
    SshCredentials credentials, {
    required TrustOnFirstUse approveHostKey,
  }) async {
    if (isConnected(host.id)) return;
    final client = await SshConnection.connect(
      host,
      credentials,
      trustFirstKey: approveHostKey,
    );
    final previous = _connections[host.id];
    _connections[host.id] = client;
    notifyListeners();
    void handleClosed() {
      if (!identical(_connections[host.id], client)) return;
      _connections.remove(host.id);
      notifyListeners();
      onConnectionLost?.call(host.id);
    }

    unawaited(client.done.then(
      (_) => handleClosed(),
      onError: (Object error, StackTrace trace) => handleClosed(),
    ));
    if (previous != null) unawaited(previous.disconnect());
  }

  Future<RemoteCapabilities> detect(String hostId) async {
    final ssh = requireConnection(hostId);
    final available = <Agent, bool>{};
    for (final kind in Agent.values) {
      available[kind] = await _tmux.hasAgent(ssh, kind);
    }
    return RemoteCapabilities(
      tmux: await _tmux.hasTmux(ssh),
      agents: available,
    );
  }

  Future<AgentSession> launch({
    required SshHostDraft host,
    required Agent agent,
    required String project,
    required String directory,
  }) async {
    final ssh = requireConnection(host.id);
    final identifier = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final name = await _tmux.create(
      ssh,
      agent: agent,
      directory: directory,
      identifier: identifier,
    );
    return AgentSession(
      'remote_' + identifier,
      project,
      host.name,
      directory,
      agent,
      WorkState.available,
      'Session created · open Terminal to interact',
      'Just now',
      [],
      remoteHostId: host.id,
      tmuxName: name,
    );
  }

  Future<List<AgentSession>> listProviderSessions(
    SshHostDraft host,
    Agent agent,
  ) =>
      const ProviderSessionSource().list(
        requireConnection(host.id),
        host,
        agent,
      );

  Future<List<ChatLine>> loadProviderMessages(AgentSession session) {
    if (!session.isSshRemote || session.remoteHostId == null) {
      throw StateError('Only provider sessions have saved history');
    }
    return const ProviderSessionSource().loadMessages(
      requireConnection(session.remoteHostId!),
      session,
    );
  }

  Future<void> ensureAttached(AgentSession session) async {
    if (!session.isSshRemote)
      throw StateError('Demo sessions cannot be resumed');
    if (session.tmuxName != null) return;
    if (session.providerSessionId == null) {
      throw StateError('No provider session ID to resume');
    }
    session.tmuxName = await _tmux.resume(
      requireConnection(session.remoteHostId!),
      agent: session.agent,
      providerSessionId: session.providerSessionId!,
      directory: session.path,
    );
    session.state = WorkState.available;
    session.summary = 'Resumed native session in persistent tmux';
    notifyListeners();
  }

  Future<List<TmuxSessionInfo>> listSessions(String hostId) =>
      _tmux.list(requireConnection(hostId));

  Future<bool> sessionExists(AgentSession session) async {
    if (!session.isSshRemote || session.tmuxName == null) return false;
    return _tmux.exists(
      requireConnection(session.remoteHostId!),
      session.tmuxName!,
    );
  }

  Future<RemoteTerminalChannel> attach(AgentSession session) async {
    await ensureAttached(session);
    if (!session.isSshRemote) throw StateError('This is a demo session');
    return _tmux.attach(
      requireConnection(session.remoteHostId!),
      session.tmuxName!,
    );
  }

  Future<void> sendPrompt(AgentSession session, String prompt) async {
    await ensureAttached(session);
    if (!session.isSshRemote) throw StateError('This is a demo session');
    return _tmux.sendPrompt(
      requireConnection(session.remoteHostId!),
      session.tmuxName!,
      prompt,
    );
  }

  Future<String> gitChanges(AgentSession session) async {
    if (!session.isSshRemote) throw StateError('This is a demo session');
    return _tmux.gitChanges(
      requireConnection(session.remoteHostId!),
      session.path,
    );
  }

  Future<String> gitDiff(AgentSession session) async {
    if (!session.isSshRemote) throw StateError('This is a demo session');
    return _tmux.gitDiff(
      requireConnection(session.remoteHostId!),
      session.path,
    );
  }

  Future<void> terminate(AgentSession session) {
    if (!session.isSshRemote || session.tmuxName == null) {
      throw StateError('There is no running tmux session to terminate');
    }
    return _tmux.terminate(
      requireConnection(session.remoteHostId!),
      session.tmuxName!,
    );
  }

  Future<void> disconnect(String hostId) async {
    final old = _connections.remove(hostId);
    notifyListeners();
    await old?.disconnect();
  }

  @override
  void dispose() {
    for (final ssh in _connections.values) {
      unawaited(ssh.disconnect());
    }
    _connections.clear();
    super.dispose();
  }
}
