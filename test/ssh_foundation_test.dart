import 'package:agents/core/security/host_key_store.dart';
import 'package:agents/core/utils/shell_escape.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
import 'package:agents/features/profiles/models/agent_profile.dart';
import 'package:agents/features/sessions/models/agent_session.dart';
import 'package:agents/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('shell quoting preserves literal untrusted values', () {
    expect(shellQuote('simple'), "'simple'");
    expect(shellQuote("it's ok"), r"'it'\''s ok'");
    expect(shellQuote(r'$(touch /tmp/pwned)'), r"'$(touch /tmp/pwned)'");
    expect(shellPath('~/work with spaces'), r'"$HOME"/' "'work with spaces'");
    expect(shellPath('/tmp/my dir'), "'/tmp/my dir'");
    expect(() => tmuxTarget(';rm -rf /'), throwsArgumentError);
    expect(() => tmuxTarget('-dangerous'), returnsNormally);
  });

  test('settings store persists host metadata, never SSH secrets', () async {
    final prefs = SettingsPreferences();
    prefs.defaultDirectory = '~/work';
    prefs.showActivity = false;
    prefs.hosts.add(const SshHostDraft(
      id: 'host-1',
      name: 'My host',
      hostname: '127.0.0.1',
      username: 'dev',
      port: 2222,
    ));
    prefs.profiles.add(const AgentProfile(
        id: 'profile-1',
        name: 'Prod Claude',
        hostId: 'host-1',
        agent: Agent.claude));
    prefs.activeProfileId = 'profile-1';
    await SettingsRepository().save(prefs);
    final restored = SettingsPreferences();
    await SettingsRepository().loadInto(restored);
    expect(restored.defaultDirectory, '~/work');
    expect(restored.showActivity, false);
    expect(restored.hosts.single.hostname, '127.0.0.1');
    expect(restored.profiles.single.hostId, 'host-1');
    expect(restored.profiles.single.agent, Agent.claude);
    expect(restored.activeProfileId, 'profile-1');
    expect(restored.encode().contains('password'), false);
    expect(restored.encode().contains('privateKey'), false);
  });

  test('host trust prompts once and rejects changed fingerprints', () async {
    const host = SshHostDraft(
      id: 'trusted',
      name: 'Test',
      hostname: 'localhost',
      username: 'developer',
    );
    const trust = SshHostKeyStore();
    var prompts = 0;
    Future<bool> confirm(String _, String __, String ___) async {
      prompts++;
      return true;
    }

    expect(
      await trust.verify(
        host: host,
        algorithm: 'ssh-ed25519',
        fingerprint: 'SHA256:original',
        confirm: confirm,
      ),
      true,
    );
    expect(
      await trust.verify(
        host: host,
        algorithm: 'ssh-ed25519',
        fingerprint: 'SHA256:original',
        confirm: confirm,
      ),
      true,
    );
    expect(prompts, 1);
    await expectLater(
      trust.verify(
        host: host,
        algorithm: 'ssh-ed25519',
        fingerprint: 'SHA256:changed',
        confirm: confirm,
      ),
      throwsA(isA<HostKeyMismatch>()),
    );
    expect(prompts, 1);
  });
}
