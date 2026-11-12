import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:agents/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('settings opens from the conversation and returns home',
      (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AgentsApp());
    expect(find.text('Atlas dashboard'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Interface'), findsOneWidget);
    expect(find.text('Auto reconnect'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(-170, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections').first);
    await tester.pumpAndSettle();
    expect(find.text('SSH hosts'), findsOneWidget);
    expect(find.text('No SSH hosts saved'), findsOneWidget);

    await tester.tap(find.text('Add host'));
    await tester.pumpAndSettle();
    expect(find.text('DISPLAY NAME'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Atlas dashboard'), findsOneWidget);
  });

  testWidgets('settings is navigable on a wide viewport', (tester) async {
    tester.view.physicalSize = const Size(1280, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('AI agents').first);
    await tester.pumpAndSettle();

    expect(find.text('Preferred agent'), findsOneWidget);
    expect(find.text('Workspace directory'), findsOneWidget);
  });
}
