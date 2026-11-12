import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../app/theme/app_colors.dart';

class FilterBadge extends StatelessWidget {
  const FilterBadge(this.name, this.count, this.selected, this.onTap,
      {super.key});
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ShadButton.raw(
        variant:
            selected ? ShadButtonVariant.secondary : ShadButtonVariant.outline,
        size: ShadButtonSize.sm,
        backgroundColor: selected
            ? AppColors.peach.withValues(alpha: .13)
            : AppColors.raised,
        foregroundColor: selected ? AppColors.peach : AppColors.soft,
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name,
                style: TextStyle(
                    color: selected ? AppColors.peach : AppColors.soft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('$count',
                style: TextStyle(
                    color: selected ? AppColors.peach : AppColors.muted,
                    fontSize: 11)),
          ],
        ),
      );
}
