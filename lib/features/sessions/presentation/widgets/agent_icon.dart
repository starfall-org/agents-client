import 'package:flutter/material.dart';
import '../agent_visuals.dart';
import '../../models/agent_session.dart';

class AgentIcon extends StatelessWidget {
  const AgentIcon(this.agent, {super.key, this.size = 43});
  final Agent agent;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: agent.tone.withValues(alpha: .12),
          border: Border.all(color: agent.tone.withValues(alpha: .22)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(agent.glyph,
            style: TextStyle(
                color: agent.tone,
                fontSize: size * .52,
                height: 1,
                fontWeight: FontWeight.w800)),
      );
}
