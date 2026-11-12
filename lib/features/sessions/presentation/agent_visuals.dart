import 'package:flutter/material.dart';
import '../models/agent_session.dart';
import '../../../app/theme/app_colors.dart';

extension AgentView on Agent {
  String get title => switch (this) {
        Agent.claude => 'Claude Code',
        Agent.codex => 'Codex',
        Agent.opencode => 'OpenCode'
      };
  String get glyph => switch (this) {
        Agent.claude => '✳',
        Agent.codex => '⌘',
        Agent.opencode => '◈'
      };
  Color get tone => switch (this) {
        Agent.claude => AppColors.peach,
        Agent.codex => AppColors.mint,
        Agent.opencode => AppColors.violet
      };
}

extension StateView on WorkState {
  String get title => switch (this) {
        WorkState.running => 'Running',
        WorkState.approval => 'Needs approval',
        WorkState.ready => 'Ready',
        WorkState.available => 'Session alive',
        WorkState.done => 'Completed',
        WorkState.disconnected => 'Disconnected',
      };
  Color get tone => switch (this) {
        WorkState.running => AppColors.mint,
        WorkState.approval => AppColors.yellow,
        WorkState.ready => AppColors.blue,
        WorkState.available => AppColors.mint,
        WorkState.done => AppColors.muted,
        WorkState.disconnected => AppColors.yellow,
      };
}
