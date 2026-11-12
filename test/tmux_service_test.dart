import 'package:agents/core/runtime/tmux_service.dart';
import 'package:agents/core/transport/remote_executor.dart';
import 'package:agents/features/sessions/models/agent_session.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeExecutor implements RemoteExecutor {
  final commands = <String>[];
  String listing = '';
  bool isGitRepo = true;
  String gitPatch = 'diff --git a/main.dart b/main.dart\n+new line\n';
  @override
  bool get connected => true;
  @override
  Future<RemoteCommandResult> run(String cmd) async {
    commands.add(cmd);
    if (cmd.contains('rev-parse --is-inside-work-tree')) {
      return isGitRepo
          ? const RemoteCommandResult('true\n', '', 0)
          : const RemoteCommandResult('', 'not a git repo', 128);
    }
    if (cmd.contains('diff --no-ext-diff')) {
      return RemoteCommandResult(gitPatch, '', 0);
    }
    if (cmd.startsWith('tmux list-sessions')) {
      return RemoteCommandResult(listing, '', 0);
    }
    return const RemoteCommandResult('', '', 0);
  }

  @override
  Future<RemoteTerminalChannel> openTerminal(String _) async {
    throw UnimplementedError();
  }
}

void main() {
  test('tmux launch quotes project path and uses the allowed binary', () async {
    final ssh = FakeExecutor();
    final name = await const TmuxService().create(
      ssh,
      agent: Agent.claude,
      directory: "~/Projects/it's cool",
      identifier: 'abc123',
    );
    expect(name, 'agents_claude_abc123');
    final command = ssh.commands.last;
    expect(command, contains("tmux new-session -d -s "));
    expect(command, contains("agents_claude_abc123"));
    expect(command, contains(r'"$HOME"/'));
    expect(command, contains('exec claude'));
    expect(command, isNot(contains('--dangerously-skip-permissions')));
  });

  test('native resume commands use provider ID and safe tmux launch', () async {
    const id = '12345678-1234-1234-1234-123456789012';
    for (final agent in [Agent.claude, Agent.codex, Agent.opencode]) {
      final ssh = FakeExecutor();
      final nativeId = agent == Agent.opencode ? 'ses_test0123' : id;
      final name = await const TmuxService().resume(
        ssh,
        agent: agent,
        providerSessionId: nativeId,
        directory: '/work/project',
      );
      expect(name, startsWith('agents_'));
      final command = ssh.commands.last;
      expect(command, contains(nativeId));
      expect(command, contains('tmux new-session -d'));
      expect(command, isNot(contains('--dangerously-skip-permissions')));
    }
    await expectLater(
      const TmuxService().resume(FakeExecutor(),
          agent: Agent.claude,
          providerSessionId: '; rm -rf ~',
          directory: '/work'),
      throwsArgumentError,
    );
  });

  test('tmux sends literal prompt and separate Enter', () async {
    final ssh = FakeExecutor();
    await const TmuxService().sendPrompt(
      ssh,
      'agents_codex_abc123',
      r'Please print $(whoami)',
    );
    expect(ssh.commands.last,
        contains("tmux send-keys -l -t 'agents_codex_abc123'"));
    expect(ssh.commands.last, contains(r"'Please print $(whoami)'"));
    expect(ssh.commands.last, contains('&& tmux send-keys -t'));
    expect(
      () => const TmuxService().sendPrompt(
        ssh,
        'agents_codex_abc123',
        'unsafe\nnewline',
      ),
      throwsArgumentError,
    );
  });

  test('git diff is read-only and escapes hostile directory names', () async {
    final ssh = FakeExecutor();
    final result = await const TmuxService().gitDiff(
      ssh,
      '~/Projects/thing; echo pwned',
    );
    expect(result, contains('+new line'));
    expect(ssh.commands.length, 2);
    final diff = ssh.commands.last;
    expect(diff, contains(r'"$HOME"/'));
    expect(diff, contains("'Projects/thing; echo pwned'"));
    expect(diff, contains('diff --no-ext-diff --no-textconv --no-color HEAD'));
    expect(diff, contains('head -c 131072'));
    expect(diff, isNot(contains('git apply')));
    expect(diff, isNot(contains('git add')));
  });

  test('git diff rejects non-working trees and invalid size limits', () async {
    final ssh = FakeExecutor()..isGitRepo = false;
    await expectLater(
      const TmuxService().gitDiff(ssh, '~/demo'),
      throwsStateError,
    );
    expect(ssh.commands.length, 1);
    await expectLater(
      const TmuxService().gitDiff(ssh, '~/demo', maxBytes: 999999),
      throwsRangeError,
    );
  });

  test('list only discovers managed sessions', () async {
    final ssh = FakeExecutor()
      ..listing = 'user|111\nagents_claude_abc|123\nagents_codex_xyz|456\n';
    final sessions = await const TmuxService().list(ssh);
    expect(sessions.map((s) => s.name), [
      'agents_claude_abc',
      'agents_codex_xyz',
    ]);
  });
}
