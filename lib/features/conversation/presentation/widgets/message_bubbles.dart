import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../sessions/models/agent_session.dart';
import '../../../sessions/presentation/agent_visuals.dart';
import '../../../sessions/presentation/widgets/agent_icon.dart';

class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 78),
        child: Column(children: [
          Icon(Icons.bubble_chart_outlined, size: 46, color: AppColors.muted),
          SizedBox(height: 18),
          Text('A fresh start',
              style: TextStyle(
                  fontSize: 20,
                  color: AppColors.text,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 7),
          Text('Send a message to begin this conversation.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ]),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.hover,
                border: Border.all(color: AppColors.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17),
                  bottomLeft: Radius.circular(17),
                  bottomRight: Radius.circular(5),
                ),
              ),
              child: Text(line.content,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 14, height: 1.63)),
            ),
            const SizedBox(height: 7),
            Text('YOU  ·  ' + line.when,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7)),
          ]),
        ),
      );
}

class AgentBubble extends StatelessWidget {
  const AgentBubble(this.line, this.agent, {super.key});
  final ChatLine line;
  final Agent agent;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentIcon(agent, size: 30),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(agent.title,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 9),
                  Text(line.when,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ]),
                const SizedBox(height: 10),
                Text(line.content,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 14, height: 1.68)),
              ])),
        ],
      );
}
