import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/status_elements.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard(
      {super.key, required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => ShadCard(
        backgroundColor: AppColors.raised,
        radius: BorderRadius.circular(14),
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.peach, size: 17),
                const SizedBox(width: 9),
                const Expanded(
                    child: Text('Implementation progress',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700))),
                const StatusPill('3 STEPS', AppColors.muted, dot: false),
              ])),
          const ShadSeparator.horizontal(
              color: AppColors.border, margin: EdgeInsets.zero),
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 14, 15, 3),
            child: Column(children: [
              ProgressLine(Icons.check_circle_rounded, AppColors.mint,
                  'Explored authentication files', '6 files'),
              SizedBox(height: 16),
              ProgressLine(Icons.check_circle_rounded, AppColors.mint,
                  'Updated auth_service.dart', '+86  −12'),
              SizedBox(height: 16),
              ProgressLine(Icons.sync_rounded, AppColors.yellow,
                  'Waiting to install dependencies', 'npm install'),
            ]),
          ),
          InkWell(
            onTap: onToggle,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 13),
              child: Row(children: [
                Text(expanded ? 'Hide activity' : 'View activity',
                    style: const TextStyle(
                        color: AppColors.peach,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
                Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.peach,
                    size: 18),
              ]),
            ),
          ),
          if (expanded)
            Container(
              margin: const EdgeInsets.fromLTRB(11, 0, 11, 11),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                  '> inspect src/auth/*\n> edit src/services/auth_service.dart\n> npm install  # pending approval',
                  style: TextStyle(
                      color: AppColors.soft,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.8)),
            ),
        ]),
      );
}

class ProgressLine extends StatelessWidget {
  const ProgressLine(this.icon, this.color, this.label, this.note, {super.key});
  final IconData icon;
  final Color color;
  final String label, note;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.soft, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(note,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 10, fontFamily: 'monospace')),
      ]);
}
