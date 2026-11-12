import 'package:agents/app/app.dart';
import 'package:agents/features/settings/models/settings_preferences.dart';
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

  testWidgets(
      'SSH editor switches between TCP and WebSocket proxy with headers',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add host'));
    await tester.pumpAndSettle();

    expect(find.text('SSH TRANSPORT'), findsOneWidget);
    expect(find.text('WEBSOCKET PROXY URL'), findsNothing);
    await tester.tap(find.byType(ShadSelect<SshTransportMode>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('WebSocket proxy').last);
    await tester.pumpAndSettle();

    expect(find.text('WEBSOCKET PROXY URL'), findsOneWidget);
    expect(find.text('HTTP UPGRADE HEADERS'), findsOneWidget);
    expect(find.text('Add header'), findsOneWidget);
    await tester.ensureVisible(find.text('Add header'));
    await tester.tap(find.text('Add header'));
    await tester.pumpAndSettle();
    expect(find.text('Header name'), findsOneWidget);
    expect(find.text('Header value'), findsOneWidget);

    await tester.tap(find.byType(ShadSelect<SshTransportMode>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direct TCP').last);
    await tester.pumpAndSettle();
    expect(find.text('WEBSOCKET PROXY URL'), findsNothing);
    expect(find.text('Header value'), findsNothing);
  });
}
