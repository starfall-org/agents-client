import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../sessions/models/agent_session.dart';
import '../../sessions/presentation/agent_visuals.dart';
import '../../settings/models/settings_preferences.dart';
import '../models/agent_profile.dart';

class ProfileEditorResult {
  const ProfileEditorResult(this.profile, {this.password});
  final AgentProfile profile;

  /// Ephemeral only: must be handed directly to the secure credential store,
  /// never to SettingsPreferences, a log, or the shared-preferences database.
  final String? password;
}

/// Dedicated create/edit dialog used exclusively from Settings → Profiles.
Future<ProfileEditorResult?> showProfileEditor(
  BuildContext context, {
  required List<SshHostDraft> hosts,
  AgentProfile? existing,
}) =>
    showShadDialog<ProfileEditorResult>(
      context: context,
      builder: (_) => _ProfileEditor(hosts: hosts, existing: existing),
    );

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.hosts, this.existing});
  final List<SshHostDraft> hosts;
  final AgentProfile? existing;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final url = TextEditingController(text: widget.existing?.httpUrl ?? '');
  late final username = TextEditingController(
    text: widget.existing?.httpUsername ?? 'opencode',
  );
  final password = TextEditingController();

  late Agent agent = widget.existing?.agent ?? Agent.claude;
  late ProfileProtocol protocol =
      widget.existing?.protocol ?? ProfileProtocol.ssh;
  late String? hostId = widget.existing?.hostId.isNotEmpty == true
      ? widget.existing!.hostId
      : (widget.hosts.isNotEmpty ? widget.hosts.first.id : null);
  String? error;
  bool showPassword = false;

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void save() {
    final title = name.text.trim();
    if (title.isEmpty) {
      setState(() => error = 'Enter a profile name.');
      return;
    }
    final isHttp = agent == Agent.opencode && protocol == ProfileProtocol.http;
    if (isHttp) {
      final invalid = AgentProfile.validateHttpUrl(url.text);
      if (invalid != null) {
        setState(() => error = invalid);
        return;
      }
      if (username.text.trim().isEmpty) {
        setState(() => error = 'Enter a username (usually opencode).');
        return;
      }
    } else if (hostId == null ||
        !widget.hosts.any((host) => host.id == hostId)) {
      setState(() => error = 'Add and select an SSH host first.');
      return;
    }

    final profile = AgentProfile(
      id: widget.existing?.id ??
          'profile_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: title,
      agent: agent,
      protocol: isHttp ? ProfileProtocol.http : ProfileProtocol.ssh,
      hostId: isHttp ? '' : hostId!,
      httpUrl: isHttp ? url.text.trim() : null,
      httpUsername: isHttp ? username.text.trim() : 'opencode',
    );
    Navigator.pop(
      context,
      ProfileEditorResult(
        profile,
        password: isHttp && password.text.isNotEmpty ? password.text : null,
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isHttp = agent == Agent.opencode && protocol == ProfileProtocol.http;
    return ShadDialog(
      title: Text(widget.existing == null ? 'New profile' : 'Edit profile'),
      description: const Text('Choose the coding agent and its connection.'),
      constraints: const BoxConstraints(maxWidth: 460),
      child: SizedBox(
        width: 400,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .58,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('PROFILE NAME'),
                ShadInput(
                  controller: name,
                  placeholder: const Text('e.g. OpenCode · Production'),
                ),
                const SizedBox(height: 19),
                _label('CODING AGENT'),
                ShadSelect<Agent>(
                  key: ValueKey(agent),
                  initialValue: agent,
                  selectedOptionBuilder: (context, value) => Text(value.title),
                  options: Agent.values
                      .map((value) => ShadOption<Agent>(
                            value: value,
                            child: Text(value.title),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        agent = value;
                        if (agent != Agent.opencode) {
                          protocol = ProfileProtocol.ssh;
                        }
                        error = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 19),
                _label('CONNECTION PROTOCOL'),
                if (agent == Agent.opencode)
                  ShadSelect<ProfileProtocol>(
                    key: ValueKey(protocol),
                    initialValue: protocol,
                    selectedOptionBuilder: (context, value) =>
                        Text(value == ProfileProtocol.ssh ? 'SSH' : 'HTTP API'),
                    options: const [
                      ShadOption<ProfileProtocol>(
                        value: ProfileProtocol.ssh,
                        child: Text('SSH'),
                      ),
                      ShadOption<ProfileProtocol>(
                        value: ProfileProtocol.http,
                        child: Text('HTTP API'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          protocol = value;
                          error = null;
                        });
                      }
                    },
                  )
                else
                  const Text(
                    'SSH',
                    style: TextStyle(
                        color: AppColors.peach,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 19),
                if (isHttp) ...[
                  _label('SERVER URL'),
                  ShadInput(
                    controller: url,
                    placeholder: const Text('https://dev.example.com:4096'),
                    keyboardType: TextInputType.url,
                    leading: const Icon(
                      Icons.language_rounded,
                      color: AppColors.muted,
                      size: 17,
                    ),
                  ),
                  const SizedBox(height: 17),
                  _label('USERNAME'),
                  ShadInput(
                    controller: username,
                    placeholder: const Text('opencode'),
                  ),
                  const SizedBox(height: 17),
                  _label('PASSWORD'),
                  ShadInput(
                    controller: password,
                    obscureText: !showPassword,
                    placeholder: Text(widget.existing == null
                        ? 'Password (if configured)'
                        : 'Leave blank to keep existing password'),
                    trailing: ShadIconButton.ghost(
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.muted,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => showPassword = !showPassword),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    kIsWeb
                        ? 'On web, the password is kept in memory for this visit only. The OpenCode server must allow your browser origin via CORS.'
                        : 'The password is saved separately in the OS secure vault; never in the profile settings.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For security, use HTTPS on remote servers. Plain HTTP is allowed only on localhost.',
                    style: TextStyle(
                      color: AppColors.yellow,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ] else ...[
                  _label('SSH HOST'),
                  if (widget.hosts.isEmpty)
                    const Text(
                      'No SSH hosts saved. Add one under Settings → Connections.',
                      style: TextStyle(
                        color: AppColors.yellow,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    )
                  else
                    ShadSelect<String>(
                      key: ValueKey(hostId),
                      initialValue: widget.hosts.any((h) => h.id == hostId)
                          ? hostId
                          : null,
                      selectedOptionBuilder: (context, value) {
                        final host =
                            widget.hosts.firstWhere((item) => item.id == value);
                        return Text(host.name);
                      },
                      options: widget.hosts
                          .map((host) => ShadOption<String>(
                                value: host.id,
                                child: Text(host.name + ' · ' + host.hostname),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => hostId = value),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 13),
                  Text(
                    error!,
                    style:
                        const TextStyle(color: AppColors.yellow, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: save,
          child:
              Text(widget.existing == null ? 'Create profile' : 'Save changes'),
        ),
      ],
    );
  }
}
