import '../features/sessions/models/agent_session.dart';

/// Capabilities are used to avoid showing fake structured permissions or
/// conversation events for terminal-only agent integrations.
class AgentCapabilities {
  const AgentCapabilities({
    required this.interactiveTerminal,
    required this.persistentSessions,
    required this.structuredMessages,
    required this.structuredApprovals,
    required this.nativeResume,
    required this.gitChanges,
  });

  final bool interactiveTerminal;
  final bool persistentSessions;
  final bool structuredMessages;
  final bool structuredApprovals;
  final bool nativeResume;
  final bool gitChanges;
}

abstract interface class AgentAdapter {
  Agent get agent;
  String get executable;
  AgentCapabilities get capabilities;
}

/// The first adapter implementation is SSH+tmux. No private agent protocol
/// flags are invented or assumed for Claude Code / Codex / OpenCode.
class TerminalCliAdapter implements AgentAdapter {
  const TerminalCliAdapter(this.agent, this.executable);

  @override
  final Agent agent;

  @override
  final String executable;

  @override
  AgentCapabilities get capabilities => const AgentCapabilities(
        interactiveTerminal: true,
        persistentSessions: true,
        structuredMessages: false,
        structuredApprovals: false,
        nativeResume: false,
        gitChanges: true,
      );
}

class AgentRegistry {
  const AgentRegistry();

  AgentAdapter adapterFor(Agent agent) => switch (agent) {
        Agent.claude => const TerminalCliAdapter(Agent.claude, 'claude'),
        Agent.codex => const TerminalCliAdapter(Agent.codex, 'codex'),
        Agent.opencode => const TerminalCliAdapter(Agent.opencode, 'opencode'),
      };
}
