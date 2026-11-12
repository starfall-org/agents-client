import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../app/theme/app_colors.dart';

class SmallLabel extends StatelessWidget {
  const SmallLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
        ),
      );
}

/// Reusable status indicator implemented using the shared shadcn badge.
class StatusPill extends StatelessWidget {
  const StatusPill(this.title, this.tone, {super.key, this.dot = true});
  final String title;
  final Color tone;
  final bool dot;

  @override
  Widget build(BuildContext context) => ShadBadge.outline(
        backgroundColor: tone.withValues(alpha: .09),
        foregroundColor: tone,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(title,
              style: TextStyle(
                color: tone,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              )),
        ]),
      );
}
