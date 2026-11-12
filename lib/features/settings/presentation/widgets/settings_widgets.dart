import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../app/theme/app_colors.dart';

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            letterSpacing: -.35,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12, height: 1.5)),
                  ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      );
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ShadCard(
        backgroundColor: AppColors.raised,
        padding: EdgeInsets.zero,
        radius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const ShadSeparator.horizontal(
                    color: AppColors.border, margin: EdgeInsets.zero),
              children[index],
            ],
          ],
        ),
      );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.trailing,
    this.tint = AppColors.soft,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget trailing;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 440;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tint, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class PreviewHint extends StatelessWidget {
  const PreviewHint({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(compact ? 13 : 16),
        decoration: BoxDecoration(
          color: AppColors.peach.withValues(alpha: .055),
          border: Border.all(color: AppColors.peach.withValues(alpha: .19)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.peach),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Settings and SSH host profiles are saved locally. Direct SSH works on native platforms; browsers require a gateway. Push notifications are not active yet.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.soft, height: 1.55),
              ),
            ),
          ],
        ),
      );
}

class SettingsSmallHeading extends StatelessWidget {
  const SettingsSmallHeading(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) => Text(
        value.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      );
}

class SettingsAction extends StatelessWidget {
  const SettingsAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ShadButton.outline(
        onPressed: onPressed,
        size: ShadButtonSize.sm,
        leading: Icon(icon, size: 15),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );
}
