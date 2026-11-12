import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../sessions/models/agent_session.dart';
import '../../../sessions/presentation/agent_visuals.dart';

class ComposerBox extends StatelessWidget {
  const ComposerBox({
    super.key,
    required this.input,
    required this.wide,
    required this.agent,
    required this.onSend,
    required this.onSessions,
  });

  final TextEditingController input;
  final bool wide;
  final Agent agent;
  final VoidCallback onSend, onSessions;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(
            wide ? 40 : 17, 14, wide ? 40 : 17, wide ? 16 : 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ShadInput(
                    controller: input,
                    placeholder: Text('Message ' + agent.title + '…'),
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => onSend(),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      ShadIconButton.ghost(
                        width: 34,
                        height: 34,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add_rounded,
                            size: 20, color: AppColors.soft),
                        onPressed: () => ShadSonner.of(context).show(
                          const ShadToast(
                            title: Text('Attachments are coming soon'),
                            description: Text('This is a UI-only preview.'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadBadge.secondary(
                        backgroundColor: agent.tone.withValues(alpha: .08),
                        foregroundColor: agent.tone,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 12, color: agent.tone),
                            const SizedBox(width: 6),
                            Text(agent.title,
                                style: TextStyle(
                                    color: agent.tone,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (wide)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Text('Enter to send',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 11)),
                        ),
                      ShadIconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                        width: 38,
                        height: 38,
                        onPressed: onSend,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onSessions,
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe_left_alt_rounded,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        wide
                            ? 'Swipe left or tap Sessions to switch conversations'
                            : 'Swipe left to see sessions',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 15,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
