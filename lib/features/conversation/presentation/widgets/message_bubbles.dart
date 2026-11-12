import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../sessions/models/agent_session.dart';

/// Long-press to copy without taking horizontal drag gestures from the
/// PageView (left/right swipes must always switch conversation and sessions).
class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 38),
        child: Center(
          child: Text(
            'No messages yet',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      );
}

class UserBubble extends StatelessWidget {
  const UserBubble(this.line, {super.key});
  final ChatLine line;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(14),
            ),
            child: GestureDetector(
              onLongPress: () => Clipboard.setData(
                ClipboardData(text: line.content),
              ),
              child: Text(
                line.content,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  height: 1.48,
                ),
              ),
            ),
          ),
        ),
      );
}

class AgentBubble extends StatelessWidget {
  const AgentBubble(this.line, this.agent, {super.key});
  final ChatLine line;
  final Agent agent;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: GestureDetector(
              onLongPress: () => Clipboard.setData(
                ClipboardData(text: line.content),
              ),
              child: Text(
                line.content,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ),
      );
}
