import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/status_elements.dart';

class ApprovalCard extends StatelessWidget {
  const ApprovalCard(
      {super.key,
      required this.onApprove,
      required this.onDeny,
      this.showCommand = true});
  final VoidCallback onApprove, onDeny;
  final bool showCommand;
  @override
  Widget build(BuildContext context) => ShadCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: const Color(0xff231f1b),
        radius: BorderRadius.circular(14),
        border: ShadBorder.all(color: AppColors.yellow.withValues(alpha: .38)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.shield_outlined, color: AppColors.yellow, size: 20),
            SizedBox(width: 9),
            Expanded(
                child: Text('Permission needed',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800))),
            StatusPill('ACTION', AppColors.yellow),
          ]),
          const SizedBox(height: 12),
          const Text('Claude wants to run a command in your project.',
              style:
                  TextStyle(color: AppColors.soft, fontSize: 12, height: 1.5)),
          const SizedBox(height: 11),
          if (showCommand)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.border)),
              child: const Text(r'$ npm install',
                  style: TextStyle(
                      color: AppColors.text,
                      fontFamily: 'monospace',
                      fontSize: 12)),
            ),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(
              child: ShadButton.outline(
                width: double.infinity,
                onPressed: onDeny,
                child: const Text('Deny',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ShadButton(
                width: double.infinity,
                onPressed: onApprove,
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.bg,
                leading: const Icon(Icons.check_rounded, size: 17),
                child: const Text('Approve',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      );
}

class ResolvedCard extends StatelessWidget {
  const ResolvedCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: .08),
            border: Border.all(color: AppColors.mint.withValues(alpha: .24)),
            borderRadius: BorderRadius.circular(13)),
        child: const Row(children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppColors.mint, size: 19),
          SizedBox(width: 10),
          Expanded(
              child: Text('Decision recorded in UI preview',
                  style: TextStyle(color: AppColors.mint, fontSize: 12))),
        ]),
      );
}
