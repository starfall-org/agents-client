import 'dart:convert';

import 'package:agents/features/profiles/data/opencode_http_session_source.dart';
import 'package:agents/features/profiles/models/agent_profile.dart';
import 'package:agents/features/sessions/models/agent_session.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const profile = AgentProfile(
    id: 'http_profile',
    name: 'OpenCode HTTP',
    agent: Agent.opencode,
    protocol: ProfileProtocol.http,
    httpUrl: 'https://dev.example.com/api',
    httpUsername: 'opencode',
  );

  test('HTTP profile persists endpoint but not password or SSH host', () {
    final preferences = SettingsPreferences()
      ..profiles.add(profile)
      ..activeProfileId = profile.id;
    final encoded = preferences.encode();
    expect(encoded, contains('dev.example.com'));
    expect(encoded, isNot(contains('password')));
    expect(encoded, isNot(contains('secret')));
    final restored = SettingsPreferences()..loadFromJson(preferences.toJson());
    expect(restored.activeProfileId, profile.id);
    expect(restored.profiles.single.usesHttp, isTrue);
    expect(restored.profiles.single.hostId, isEmpty);
    expect(restored.profiles.single.httpUsername, 'opencode');
  });

  test('old SSH profiles remain compatible', () {
    final restored = AgentProfile.fromJson({
      'id': 'legacy',
      'name': 'Codex via SSH',
      'hostId': 'host1',
      'agent': 'codex',
    });
    expect(restored.protocol, ProfileProtocol.ssh);
    expect(restored.hostId, 'host1');
  });

  test('HTTP URL validation protects credentials', () {
    expect(
        AgentProfile.validateHttpUrl('https://dev.example.com:4096'), isNull);
    expect(AgentProfile.validateHttpUrl('http://localhost:4096'), isNull);
    expect(AgentProfile.validateHttpUrl('http://192.168.1.9:4096'), isNotNull);
    expect(AgentProfile.validateHttpUrl('https://user:secret@host.test'),
        isNotNull);
    expect(AgentProfile.validateHttpUrl('ftp://host.test'), isNotNull);
  });

  test('HTTP list uses OpenCode endpoint and Basic auth', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '[{"id":"ses_abc123","title":"Fix login",'
        '"directory":"/projects/my-app","time":{"updated":1763000000000}}]',
        200,
      );
    });
    final sessions = await const OpenCodeHttpSessionSource().list(
      profile,
      password: 's3cret',
      client: client,
    );
    expect(sessions, hasLength(1));
    expect(sessions.single.providerSessionId, 'ses_abc123');
    expect(sessions.single.httpProfileId, profile.id);
    expect(sessions.single.remoteHostId, isNull);
    expect(sessions.single.isHttpRemote, isTrue);
    expect(
        requests.single.url.toString(), 'https://dev.example.com/api/session');
    expect(requests.single.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('opencode:s3cret'))}');
  });

  test('HTTP message history uses official session message endpoint', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/session/ses_test123/message');
      expect(request.url.queryParameters['limit'], '40');
      return http.Response(
        '[{"info":{"role":"user"},'
        '"parts":[{"type":"text","text":"Hello"}]},'
        '{"info":{"role":"assistant"},'
        '"parts":[{"type":"text","text":"Hi!"}]}]',
        200,
      );
    });
    final lines = await const OpenCodeHttpSessionSource().messages(
      profile,
      'ses_test123',
      client: client,
    );
    expect(lines, hasLength(2));
    expect(lines.first.byUser, isTrue);
    expect(lines.last.content, 'Hi!');
  });

  test('HTTP create and prompt call native OpenCode API', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' && request.url.path == '/api/session') {
        expect(jsonDecode(request.body)['title'], 'New idea');
        return http.Response(
          '{"id":"ses_new12","title":"New idea","directory":"/work/app"}',
          200,
        );
      }
      expect(request.url.path, '/api/session/ses_new12/prompt_async');
      expect(
          jsonDecode(request.body)['parts'][0]['text'], 'Make the tests pass');
      return http.Response('', 204);
    });
    final source = const OpenCodeHttpSessionSource();
    final session = await source.createSession(
      profile,
      'New idea',
      client: client,
    );
    expect(session.providerSessionId, 'ses_new12');
    await source.sendPrompt(
      profile,
      session.providerSessionId!,
      'Make the tests pass',
      client: client,
    );
    expect(requests, hasLength(2));
  });

  test('HTTP auth failure and cross-origin redirect fail closed', () async {
    final unauth = MockClient((_) async => http.Response('', 401));
    await expectLater(
      const OpenCodeHttpSessionSource().list(
        profile,
        password: 'wrong',
        client: unauth,
      ),
      throwsStateError,
    );
    final redirect = MockClient(
      (_) async => http.Response('', 302,
          headers: {'location': 'https://evil.example/steal'}),
    );
    await expectLater(
      const OpenCodeHttpSessionSource().list(
        profile,
        password: 'secret',
        client: redirect,
      ),
      throwsStateError,
    );
  });
}
