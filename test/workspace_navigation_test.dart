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
  testWidgets('home is a conversation, swiping left opens sessions',
      (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AgentsApp());
    expect(find.text('Atlas dashboard'), findsOneWidget);
    expect(find.text('Your sessions'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.text('Your sessions'), findsOneWidget);
    expect(find.text('Payments API'), findsOneWidget);

    // Swiping right returns to the current conversation.
    await tester.dragFrom(const Offset(40, 525), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(find.text('Your sessions'), findsNothing);
    expect(find.text('Atlas dashboard'), findsOneWidget);

    // Reopen the list, then choose a different session.
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments API'));
    await tester.pumpAndSettle();

    expect(find.text('Payments API'), findsOneWidget);
    expect(find.text('Your sessions'), findsNothing);
    expect(
        find.text(
            'Review the payment retry logic and add tests for duplicate webhook deliveries.'),
        findsOneWidget);
  });

  testWidgets('session list is accessible without a swipe', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    expect(find.text('Your sessions'), findsOneWidget);

    await tester.tap(find.text('BACK TO CONVERSATION'));
    await tester.pumpAndSettle();
    expect(find.text('Atlas dashboard'), findsOneWidget);
  });
  testWidgets('session search filters projects and agents', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    expect(find.text('Payments API'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'marketing');
    await tester.pumpAndSettle();
    expect(find.text('Marketing website'), findsOneWidget);
    expect(find.text('Payments API'), findsNothing);
    expect(find.text('Atlas dashboard'), findsNothing);
  });
  testWidgets('sessions profile picker only selects existing profiles',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile · Demo (no profile)'));
    await tester.pumpAndSettle();
    expect(find.text('Select profile'), findsOneWidget);
    expect(find.text('New profile'), findsNothing);
    expect(find.text('SSH HOST'), findsNothing);
    expect(find.text('CODING AGENT'), findsNothing);
    expect(find.textContaining('Settings → Profiles'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
