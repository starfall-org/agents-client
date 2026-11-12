import 'package:agents/app/app.dart';
import 'package:agents/features/profiles/models/agent_profile.dart';
import 'package:agents/features/sessions/models/agent_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Settings manages profiles and OpenCode HTTP hides SSH host',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profiles').first);
    await tester.pumpAndSettle();
    expect(find.text('Configured profiles'), findsOneWidget);
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    expect(find.text('New profile'), findsOneWidget);
    expect(find.text('SSH HOST'), findsOneWidget);
    expect(find.text('SERVER URL'), findsNothing);

    await tester.tap(find.byType(ShadSelect<Agent>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenCode').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ShadSelect<ProfileProtocol>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTTP API').last);
    await tester.pumpAndSettle();

    expect(find.text('SERVER URL'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('SSH HOST'), findsNothing);

    final inputFields = find.byType(EditableText);
    expect(inputFields, findsNWidgets(4));
    await tester.enterText(inputFields.at(0), 'OpenCode API');
    await tester.enterText(inputFields.at(1), 'https://dev.example.com:4096');
    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();

    expect(find.text('Configured profiles'), findsOneWidget);
    expect(find.text('OpenCode API'), findsOneWidget);
    expect(find.textContaining('HTTP API · https://dev.example.com:4096'),
        findsOneWidget);

    // Settings owns configuration; Sessions' dialog only selects it.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile · Demo (no profile)'));
    await tester.pumpAndSettle();
    expect(find.text('Select profile'), findsOneWidget);
    expect(find.text('OpenCode API'), findsOneWidget);
    expect(find.text('New profile'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Remove'), findsNothing);
  });
}
