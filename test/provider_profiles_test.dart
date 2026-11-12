import 'package:agents/core/transport/remote_executor.dart';
import 'package:agents/features/sessions/data/provider_session_source.dart';
import 'package:agents/features/sessions/models/agent_session.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
import 'package:agents/features/profiles/models/agent_profile.dart';
import 'package:flutter_test/flutter_test.dart';

class SourceFake implements RemoteExecutor {
  final commands = <String>[];
  late String listing;
  late String content;
  @override
  bool get connected => true;
  @override
  Future<RemoteCommandResult> run(String command) async {
    commands.add(command);
    if (command.contains(' -print0 2>/dev/null')) {
      return RemoteCommandResult(listing, '', 0);
    }
    if (command.startsWith('head -c') || command.startsWith('tail -c')) {
      return RemoteCommandResult(content, '', 0);
    }
    if (command.startsWith('opencode session list')) {
      return RemoteCommandResult(content, '', 0);
    }
    return const RemoteCommandResult('', 'unexpected command', 1);
  }

  @override
  Future<RemoteTerminalChannel> openTerminal(String command) async =>
      throw UnimplementedError();
}

void main() {
  const host = SshHostDraft(
    id: 'host123',
    name: 'Remote mac',
    hostname: 'remote.example',
    username: 'dev',
  );
  const id = '12345678-1234-1234-1234-123456789012';

  test('Claude session discovery reads the provider transcript files',
      () async {
    final ssh = SourceFake()
      ..listing = '/Users/dev/.claude/projects/sample/$id.jsonl\n'
      ..content =
          '{"type":"user","cwd":"/work/myapp","timestamp":"2026-11-12T10:00:00Z","message":{"content":"Build login"}}\n';
    final result =
        await const ProviderSessionSource().list(ssh, host, Agent.claude);
    expect(result, hasLength(1));
    expect(result.first.providerSessionId, id);
    expect(result.first.project, 'myapp');
    expect(result.first.summary, 'Build login');
    expect(result.first.tmuxName, isNull);
    expect(ssh.commands.first, contains('.claude/projects'));
  });

  test('Codex discovery reads the official persisted rollout', () async {
    final ssh = SourceFake()
      ..listing =
          '/home/dev/.codex/sessions/2026/11/12/rollout-2026-$id.jsonl\n'
      ..content = '{"type":"session_meta","payload":{"cwd":"/srv/api"}}\n'
          '{"type":"event_msg","payload":{"type":"user_message","message":"Run tests"}}\n';
    final result =
        await const ProviderSessionSource().list(ssh, host, Agent.codex);
    expect(result, hasLength(1));
    expect(result.single.providerSessionId, id);
    expect(result.single.summary, 'Run tests');
    expect(result.single.project, 'api');
  });

  test('OpenCode uses its supported JSON session list CLI', () async {
    final ssh = SourceFake()
      ..content = '[{"id":"ses_demo123","title":"Fix lint",'
          '"directory":"/work/mobile","time":{"updated":12345}}]';
    final result =
        await const ProviderSessionSource().list(ssh, host, Agent.opencode);
    expect(result, hasLength(1));
    expect(result.single.providerSessionId, 'ses_demo123');
    expect(result.single.summary, 'Fix lint');
    expect(result.single.project, 'mobile');
    expect(ssh.commands.single, contains('opencode session list'));
  });

  test('Claude saved conversation is read from provider JSONL', () async {
    final ssh = SourceFake()
      ..content = '{"type":"user","message":{"content":"Hello"}}\n'
          '{"type":"assistant","message":{"content":[{"type":"text","text":"Hi there"}]}}\n';
    final session = AgentSession(
      'test',
      'demo',
      'Remote mac',
      '/work/demo',
      Agent.claude,
      WorkState.ready,
      'Saved',
      '',
      [],
      remoteHostId: host.id,
      providerSessionId: id,
      providerSourcePath: '/Users/dev/.claude/projects/demo/$id.jsonl',
    );
    final messages =
        await const ProviderSessionSource().loadMessages(ssh, session);
    expect(messages, hasLength(2));
    expect(messages.first.byUser, true);
    expect(messages.last.content, 'Hi there');
    expect(ssh.commands.single, startsWith('tail -c 262144'));
  });

  test('profiles serialize their host+agent and active choice', () {
    final prefs = SettingsPreferences();
    prefs.hosts.add(host);
    prefs.profiles.add(const AgentProfile(
      id: 'p1',
      name: 'Prod Claude',
      hostId: 'host123',
      agent: Agent.claude,
    ));
    prefs.activeProfileId = 'p1';
    final restored = SettingsPreferences()..loadFromJson(prefs.toJson());
    expect(restored.activeProfileId, 'p1');
    expect(restored.profiles.single.agent, Agent.claude);
    expect(restored.profiles.single.hostId, 'host123');
  });
}
