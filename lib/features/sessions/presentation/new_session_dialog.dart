import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/status_elements.dart';
import '../../settings/models/settings_preferences.dart';
import '../../profiles/models/agent_profile.dart';
import '../models/agent_session.dart';
import 'agent_visuals.dart';

class SessionDraft {
  const SessionDraft({
    required this.project,
    required this.agent,
    required this.directory,
    this.hostId,
  });
  final String project, directory;
  final Agent agent;
  final String? hostId;
}

/// Offers a real connected host when available; keeps demo mode explicit.
Future<SessionDraft?> showNewSessionDialog(
  BuildContext context, {
  Agent initialAgent = Agent.claude,
  List<SshHostDraft> connectedHosts = const [],
  String defaultDirectory = '~/projects',
  AgentProfile? lockedProfile,
}) =>
    showShadDialog<SessionDraft>(
      context: context,
      builder: (_) => _NewSessionDialog(
        initialAgent: initialAgent,
        connectedHosts: connectedHosts,
        defaultDirectory: defaultDirectory,
        lockedProfile: lockedProfile,
      ),
    );

class _NewSessionDialog extends StatefulWidget {
  const _NewSessionDialog({
    required this.initialAgent,
    required this.connectedHosts,
    required this.defaultDirectory,
    this.lockedProfile,
  });
  final Agent initialAgent;
  final List<SshHostDraft> connectedHosts;
  final String defaultDirectory;
  final AgentProfile? lockedProfile;

  @override
  State<_NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<_NewSessionDialog> {
  final TextEditingController name = TextEditingController();
  late final TextEditingController directory =
      TextEditingController(text: widget.defaultDirectory);
  late Agent choice = widget.initialAgent;
  late String target = widget.lockedProfile?.usesHttp == true
      ? 'http'
      : widget.lockedProfile?.hostId ??
          (widget.connectedHosts.isNotEmpty
              ? widget.connectedHosts.first.id
              : 'demo');
  String? validation;

  @override
  void dispose() {
    name.dispose();
    directory.dispose();
    super.dispose();
  }

  void create() {
    if (name.text.trim().isEmpty ||
        (target != 'demo' &&
            target != 'http' &&
            directory.text.trim().isEmpty)) {
      setState(() => validation = 'Enter project name and directory.');
      return;
    }
    Navigator.pop(
      context,
      SessionDraft(
        project: name.text.trim(),
        agent: widget.lockedProfile?.agent ?? choice,
        directory: directory.text.trim(),
        hostId:
            widget.lockedProfile?.hostId ?? (target == 'demo' ? null : target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ShadDialog(
        title: const Text('New session'),
        description: const Text('Choose a coding agent and execution target.'),
        constraints: const BoxConstraints(maxWidth: 450),
        child: SizedBox(
          width: 390,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SmallLabel('PROJECT NAME'),
              const SizedBox(height: 10),
              ShadInput(
                controller: name,
                autofocus: true,
                placeholder: const Text('e.g. My next project'),
                onSubmitted: (_) => create(),
              ),
              const SizedBox(height: 18),
              const SmallLabel('CODING AGENT'),
              const SizedBox(height: 10),
              if (widget.lockedProfile != null)
                Text(widget.lockedProfile!.agent.title,
                    style: const TextStyle(
                        color: AppColors.peach,
                        fontSize: 14,
                        fontWeight: FontWeight.w700))
              else
                ShadSelect<Agent>(
                  key: ValueKey(choice),
                  initialValue: choice,
                  selectedOptionBuilder: (context, selected) =>
                      Text(selected.title),
                  options: Agent.values
                      .map((agent) => ShadOption<Agent>(
                            value: agent,
                            child: Text(agent.title),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => choice = value);
                  },
                ),
              const SizedBox(height: 18),
              const SmallLabel('EXECUTION TARGET'),
              const SizedBox(height: 10),
              if (widget.lockedProfile?.usesHttp == true)
                Text(
                    'OpenCode HTTP API · ' +
                        (widget.lockedProfile!.httpUrl ?? ''),
                    style:
                        const TextStyle(color: AppColors.peach, fontSize: 12))
              else if (widget.lockedProfile != null)
                Text(widget.connectedHosts.first.name + ' · selected profile',
                    style:
                        const TextStyle(color: AppColors.peach, fontSize: 13))
              else
                ShadSelect<String>(
                  key: ValueKey(target),
                  initialValue: target,
                  selectedOptionBuilder: (context, selected) => Text(
                    selected == 'demo'
                        ? 'Demo (no remote execution)'
                        : widget.connectedHosts
                            .firstWhere((host) => host.id == selected)
                            .name,
                  ),
                  options: [
                    const ShadOption<String>(
                      value: 'demo',
                      child: Text('Demo (no remote execution)'),
                    ),
                    for (final host in widget.connectedHosts)
                      ShadOption<String>(
                        value: host.id,
                        child: Text(host.name + ' · SSH connected'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => target = value);
                  },
                ),
              if (target != 'demo' && target != 'http') ...[
                const SizedBox(height: 18),
                const SmallLabel('REMOTE WORKING DIRECTORY'),
                const SizedBox(height: 10),
                ShadInput(
                  controller: directory,
                  placeholder: const Text('~/projects/my-project'),
                  leading: const Icon(Icons.folder_outlined,
                      size: 17, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 15),
              Text(
                target == 'demo'
                    ? 'Demo only · no SSH command is executed.'
                    : 'Creates a tmux session and launches the selected CLI. '
                        'No permission bypass flags are used.',
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 11, height: 1.5),
              ),
              if (validation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(validation!,
                      style: const TextStyle(
                          color: AppColors.yellow, fontSize: 11)),
                ),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: create,
            child: const Text('Create session'),
          ),
        ],
      );
}
