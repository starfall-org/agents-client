import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:agents/app/app.dart';
import 'package:agents/features/conversation/presentation/conversation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('appearance preference is retained when returning to chat',
      (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AgentsApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    // Compact messages, show tool activity, show command preview.
    expect(
        tester.widget<ShadSwitch>(find.byType(ShadSwitch).at(1)).value, isTrue);

    await tester.tap(find.byType(ShadSwitch).at(1));
    await tester.pumpAndSettle();
    expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch).at(1)).value,
        isFalse);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ConversationView>(find.byType(ConversationView))
            .showActivity,
        isFalse);

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch).at(1)).value,
        isFalse);
  });
}
