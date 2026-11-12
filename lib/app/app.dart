import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'theme/app_colors.dart';
import '../features/workspace/presentation/workspace_page.dart';

/// The entire app uses the same system-bar colors and privacy protection,
/// including Settings, dialogs and routes pushed above the workspace.
class AgentsApp extends StatefulWidget {
  const AgentsApp({super.key});

  @override
  State<AgentsApp> createState() => _AgentsAppState();
}

class _AgentsAppState extends State<AgentsApp> with WidgetsBindingObserver {
  bool _privacyCurtain = false;

  static const systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.panel,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: AppColors.panel,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final hide = state != AppLifecycleState.resumed;
    if (hide != _privacyCurtain) {
      setState(() => _privacyCurtain = hide);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadApp.custom(
        themeMode: ThemeMode.dark,
        theme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadSlateColorScheme.dark(
            background: AppColors.bg,
            foreground: AppColors.text,
            card: AppColors.raised,
            cardForeground: AppColors.text,
            popover: AppColors.raised,
            popoverForeground: AppColors.text,
            primary: AppColors.peach,
            primaryForeground: AppColors.bg,
            secondary: AppColors.hover,
            secondaryForeground: AppColors.text,
            muted: AppColors.raised,
            mutedForeground: AppColors.muted,
            accent: AppColors.hover,
            accentForeground: AppColors.text,
            border: AppColors.border,
            input: AppColors.border,
            ring: AppColors.peach,
          ),
          radius: BorderRadius.circular(12),
        ),
        appBuilder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemBars,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Agents · Remote coding workspace',
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.panel,
              colorScheme: const ColorScheme.dark(
                primary: AppColors.peach,
                surface: AppColors.panel,
              ),
              useMaterial3: true,
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: AppColors.text),
              ),
            ),
            builder: (context, child) => Stack(
              fit: StackFit.expand,
              children: [
                ShadSonner(
                  alignment: Alignment.bottomCenter,
                  child: child ?? const SizedBox.shrink(),
                ),
                if (_privacyCurtain)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: AppColors.panel,
                        child: Center(
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 28,
                            color: AppColors.muted,
                            semanticLabel: 'Application content hidden',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            home: const Workspace(),
          ),
        ),
      );
}
