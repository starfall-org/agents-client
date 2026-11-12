import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../sessions/models/agent_session.dart';
import '../../../sessions/presentation/agent_visuals.dart';

/// Compact composer; top bar and gestures already navigate sessions.
/// Do not waste reading space on placeholder buttons or decorative badges.
class ComposerBox extends StatelessWidget {
  const ComposerBox({
    super.key,
    required this.input,
    required this.wide,
    required this.agent,
    required this.onSend,
    this.sending = false,
    this.enabled = true,
  });

  final TextEditingController input;
  final bool wide;
  final Agent agent;
  final VoidCallback onSend;
  final bool sending, enabled;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          wide ? 28 : 12,
          10,
          wide ? 28 : 12,
          10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ShadInput(
                controller: input,
                enabled: enabled,
                placeholder: Text('Message ' + agent.title + '…'),
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) {
                  if (enabled && !sending) onSend();
                },
              ),
            ),
            const SizedBox(width: 8),
            ShadIconButton(
              icon: sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.bg,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 20),
              width: 42,
              height: 42,
              enabled: enabled && !sending,
              onPressed: onSend,
            ),
          ],
        ),
      );
}
