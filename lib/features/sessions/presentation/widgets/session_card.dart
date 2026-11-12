import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/status_elements.dart';
import '../../models/agent_session.dart';
import '../agent_visuals.dart';
import 'agent_icon.dart';

class SessionCard extends StatelessWidget {
  const SessionCard(
    this.session, {
    super.key,
    required this.selected,
    required this.onTap,
  });

  final AgentSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: double.infinity,
          child: ShadCard(
            backgroundColor: selected ? AppColors.hover : AppColors.raised,
            radius: BorderRadius.circular(15),
            padding: const EdgeInsets.all(17),
            border: ShadBorder.all(
              color: selected
                  ? AppColors.peach.withValues(alpha: .46)
                  : AppColors.border,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgentIcon(session.agent, size: 42),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.project,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(session.updated,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.agent.title + '  ·  ' + session.host,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        session.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.soft, fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          StatusPill(session.state.title, session.state.tone),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.muted, size: 17),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
