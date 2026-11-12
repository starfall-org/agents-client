import '../../../features/sessions/models/agent_session.dart';
import '../../agents/agent_adapter.dart';
import '../transport/remote_executor.dart';
import '../utils/shell_escape.dart';

class TmuxSessionInfo {
  const TmuxSessionInfo(this.name, this.created);
  final String name, created;
}

class TmuxService {
  const TmuxService();

  String agentBinary(Agent agent) =>
      const AgentRegistry().adapterFor(agent).executable;

  Future<bool> hasTmux(RemoteExecutor ssh) async =>
      (await ssh.run('command -v tmux >/dev/null 2>&1')).succeeded;

  Future<bool> hasAgent(RemoteExecutor ssh, Agent agent) async =>
      (await ssh.run(
        'command -v ' + agentBinary(agent) + ' >/dev/null 2>&1',
      ))
          .succeeded;

  /// List active persistent sessions (not inferred agent processing state).
  Future<List<TmuxSessionInfo>> list(RemoteExecutor ssh) async {
    final result = await ssh.run(
      'tmux list-sessions -F ' +
          shellQuote(r'#{session_name}|#{session_created}'),
    );
    if (!result.succeeded) {
      if (result.stderr.contains('no server running') ||
          result.stderr.contains('no sessions') ||
          result.stderr.contains("can't find")) {
        return [];
      }
      throw StateError('Failed to list tmux sessions: ' + result.stderr);
    }
    return result.stdout
        .split('\n')
        .where((line) => line.startsWith('agents_'))
        .map((line) {
      final parts = line.trim().split('|');
      return TmuxSessionInfo(parts.first, parts.length > 1 ? parts.last : '');
    }).toList();
  }

  /// Start CLI in persistent tmux; never disables the CLI permission system.
  Future<String> create(
    RemoteExecutor ssh, {
    required Agent agent,
    required String directory,
    required String identifier,
  }) async {
    if (!await hasTmux(ssh)) {
      throw StateError('tmux must be installed on the remote host');
    }
    if (!await hasAgent(ssh, agent)) {
      throw StateError(agentBinary(agent) + ' is not on the remote PATH');
    }
    final name = tmuxTarget('agents_' + agent.name + '_' + identifier);
    final cmd = 'tmux new-session -d -s ' +
        shellQuote(name) +
        ' -c ' +
        shellPath(directory) +
        ' ' +
        shellQuote('exec ' + agentBinary(agent));
    final result = await ssh.run(cmd);
    if (!result.succeeded) {
      throw StateError('Cannot launch remote agent: ' +
          (result.stderr.isEmpty ? result.stdout : result.stderr));
    }
    return name;
  }

  /// Resume an existing native provider session in tmux, without bypassing
  /// any of the CLI's own permission prompts.
  Future<String> resume(
    RemoteExecutor ssh, {
    required Agent agent,
    required String providerSessionId,
    required String directory,
  }) async {
    final valid = agent == Agent.opencode
        ? RegExp(r'^ses_[a-zA-Z0-9_-]+$').hasMatch(providerSessionId)
        : RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(providerSessionId);
    if (!valid)
      throw ArgumentError.value(providerSessionId, 'providerSessionId');
    if (!await hasTmux(ssh)) throw StateError('tmux is required on this host');
    if (!await hasAgent(ssh, agent)) {
      throw StateError(agentBinary(agent) + ' is not installed');
    }
    final idArg = shellQuote(providerSessionId);
    final launch = switch (agent) {
      Agent.claude => 'exec claude --resume ' + idArg,
      Agent.codex => 'exec codex resume ' + idArg,
      Agent.opencode => 'exec opencode --session ' + idArg,
    };
    final tmuxName = tmuxTarget('agents_' +
        agent.name +
        '_' +
        DateTime.now().microsecondsSinceEpoch.toRadixString(36));
    final command = 'tmux new-session -d -s ' +
        shellQuote(tmuxName) +
        ' -c ' +
        shellPath(directory) +
        ' ' +
        shellQuote(launch);
    final result = await ssh.run(command);
    if (!result.succeeded) {
      throw StateError('Unable to resume native session: ' + result.stderr);
    }
    return tmuxName;
  }

  Future<bool> exists(RemoteExecutor ssh, String name) async => (await ssh.run(
        'tmux has-session -t ' + shellQuote(tmuxTarget(name)) + ' 2>/dev/null',
      ))
          .succeeded;

  Future<RemoteTerminalChannel> attach(
    RemoteExecutor ssh,
    String name,
  ) async {
    final target = tmuxTarget(name);
    if (!await exists(ssh, target)) {
      throw StateError('Session no longer exists on this host');
    }
    return ssh.openTerminal('tmux attach-session -t ' + shellQuote(target));
  }

  /// Literal text and a separate Enter, never an arbitrary shell command.
  /// A prompt is only sent to an agent session created/selected by the user.
  Future<void> sendPrompt(
    RemoteExecutor ssh,
    String sessionName,
    String prompt,
  ) async {
    final name = shellQuote(tmuxTarget(sessionName));
    if (prompt.trim().isEmpty ||
        prompt.length > 8192 ||
        prompt.contains('\r') ||
        prompt.contains('\n')) {
      throw ArgumentError('Enter a single-line prompt (max 8192 characters)');
    }
    if (!await exists(ssh, sessionName)) {
      throw StateError('Remote session is not running');
    }
    final result = await ssh.run(
      'tmux send-keys -l -t ' +
          name +
          ' ' +
          shellQuote(prompt) +
          ' && tmux send-keys -t ' +
          name +
          ' Enter',
    );
    if (!result.succeeded) {
      throw StateError('Failed to send prompt to tmux: ' + result.stderr);
    }
  }

  Future<String> gitChanges(
    RemoteExecutor ssh,
    String workingDirectory,
  ) async {
    final result = await ssh.run(
      'git -C ' +
          shellPath(workingDirectory) +
          ' status --short --untracked-files=normal',
    );
    if (!result.succeeded) {
      throw StateError(result.stderr.trim().isEmpty
          ? 'No git worktree found'
          : result.stderr.trim());
    }
    return result.stdout;
  }

  /// Read-only diff including staged and unstaged tracked files, with a
  /// hard output ceiling. Git filters and external diff helpers are disabled.
  /// Untracked files remain discoverable through gitChanges(), not this diff.
  Future<String> gitDiff(
    RemoteExecutor ssh,
    String workingDirectory, {
    int maxBytes = 131072,
  }) async {
    if (maxBytes < 1024 || maxBytes > 262144) {
      throw RangeError.range(maxBytes, 1024, 262144, 'maxBytes');
    }
    final root = shellPath(workingDirectory);
    // First confirm a Git worktree rather than accepting a pipeline's success.
    final check = await ssh.run('git -C $root rev-parse --is-inside-work-tree');
    if (!check.succeeded || check.stdout.trim() != 'true') {
      throw StateError('Directory is not inside a Git working tree');
    }

    final command = 'git -C $root --no-pager '
        '-c diff.external= -c core.pager=cat '
        'diff --no-ext-diff --no-textconv --no-color HEAD -- . '
        '| head -c $maxBytes';
    final result = await ssh.run(command);
    if (!result.succeeded) {
      throw StateError(result.stderr.trim().isNotEmpty
          ? result.stderr.trim()
          : 'Unable to read Git diff');
    }
    return result.stdout;
  }

  Future<void> terminate(RemoteExecutor ssh, String name) async {
    final result = await ssh.run(
      'tmux kill-session -t ' + shellQuote(tmuxTarget(name)),
    );
    if (!result.succeeded) {
      throw StateError('Unable to terminate session: ' + result.stderr);
    }
  }
}
