import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'theme/app_colors.dart';
import '../features/workspace/presentation/workspace_page.dart';

/// Shadcn supplies all interactive components and their shared theme.
/// MaterialApp remains only for Flutter navigation, scaffolds, and platform
/// localization while the prototype is migrated to shadcn components.
class AgentsApp extends StatelessWidget {
  const AgentsApp({super.key});

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
        appBuilder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Agents · Remote coding workspace',
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.bg,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.peach,
              surface: AppColors.panel,
            ),
            useMaterial3: true,
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: AppColors.text),
            ),
          ),
          builder: (context, child) => ShadSonner(
            alignment: Alignment.bottomCenter,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Workspace(),
        ),
      );
}
