import 'package:agents/app/app.dart';
import 'package:agents/features/conversation/presentation/widgets/composer_box.dart';
import 'package:agents/features/sessions/data/remote_session_repository.dart';
import 'package:agents/features/sessions/models/agent_session.dart';
import 'package:agents/features/settings/data/settings_repository.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
import 'package:agents/features/workspace/presentation/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void mobile(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('chat remains compact and swipe navigation still works',
      (tester) async {
    mobile(tester);
    await tester.pumpWidget(const AgentsApp());
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TopBar)).height, 54);
    expect(tester.getSize(find.byType(ComposerBox)).height, lessThan(90));
    expect(find.text('Swipe left to see sessions'), findsNothing);
    expect(find.text('YOU  ·'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.text('Atlas dashboard'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('Your sessions'), findsOneWidget);
  });

  testWidgets('system insets keep app content away from Android bars',
      (tester) async {
    mobile(tester);
    tester.view.padding = const FakeViewPadding(top: 28, bottom: 32);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const AgentsApp());
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TopBar)).dy, 28);
    expect(
      tester.getBottomLeft(find.byType(ComposerBox)).dy,
      lessThanOrEqualTo(844 - 32),
    );
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.text('Settings')).dy, greaterThanOrEqualTo(28));
  });

  testWidgets('background hides the whole UI; foreground uncovers it',
      (tester) async {
    mobile(tester);
    await tester.pumpWidget(const AgentsApp());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    // The curtain covers Settings and modal routes, not only conversation.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.text('Atlas dashboard'), findsOneWidget);
  });

  testWidgets('Settings is hidden when app becomes inactive', (tester) async {
    mobile(tester);
    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    expect(find.byType(AbsorbPointer), findsWidgets);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('selected session survives app disposal and a cold start',
      (tester) async {
    mobile(tester);
    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments API'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const AgentsApp());
    await tester.pumpAndSettle();

    expect(find.text('Payments API'), findsOneWidget);
    expect(
        find.textContaining('Review the payment retry logic'), findsOneWidget);
  });

  test('rapid selection changes serialize, restoring the newest choice',
      () async {
    final first = SettingsPreferences()..lastSessionIds['demo'] = 'old';
    final second = SettingsPreferences()..lastSessionIds['demo'] = 'new';
    final repository = SettingsRepository();
    await Future.wait([repository.save(first), repository.save(second)]);
    final reloaded = SettingsPreferences();
    await repository.loadInto(reloaded);
    expect(reloaded.lastSessionIds['demo'], 'new');
  });

  test('remote tmux metadata survives restart without private chat text',
      () async {
    final remote = AgentSession(
      'remote-1',
      'Backend',
      'Dev host',
      '/work/project',
      Agent.codex,
      WorkState.available,
      'Current run',
      'Now',
      [ChatLine('TOP_SECRET_NEVER_PERSIST', true, 'Now')],
      remoteHostId: 'ssh-host-1',
      tmuxName: 'agents_codex_abc',
    );
    const repository = RemoteSessionRepository();
    await repository.save([remote]);
    final onDisk =
        await SharedPreferencesAsync().getString('agents.remote.sessions.v1');
    expect(onDisk, isNot(contains('TOP_SECRET_NEVER_PERSIST')));
    final loaded = await repository.read();
    expect(loaded, hasLength(1));
    expect(loaded.single.state, WorkState.disconnected);
    expect(loaded.single.tmuxName, 'agents_codex_abc');
    expect(loaded.single.lines, isEmpty);
  });

  test('saved profile remembers a session ID without storing messages',
      () async {
    final preferences = SettingsPreferences()
      ..lastSessionIds['demo'] = 'session-id';
    expect(preferences.encode(), contains('session-id'));
    expect(preferences.encode(), isNot(contains('TOP_SECRET')));
  });
}
