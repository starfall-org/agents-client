import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/runtime/remote_runtime.dart';
import '../../../core/security/ssh_credential_store.dart';
import 'dialogs/ssh_connect_dialog.dart';
import '../../../shared/widgets/status_elements.dart';
import '../../sessions/models/agent_session.dart';
import '../../sessions/presentation/agent_visuals.dart';
import '../../sessions/presentation/widgets/agent_icon.dart';
import '../models/settings_preferences.dart';
import '../../profiles/models/agent_profile.dart';
import '../../profiles/presentation/profile_editor_dialog.dart';
import '../../profiles/data/opencode_password_store.dart';
import 'widgets/settings_widgets.dart';

enum SettingsSection {
  general,
  profiles,
  connections,
  agents,
  notifications,
  about
}

extension SettingsSectionView on SettingsSection {
  String get label => switch (this) {
        SettingsSection.general => 'General',
        SettingsSection.connections => 'Connections',
        SettingsSection.profiles => 'Profiles',
        SettingsSection.agents => 'AI agents',
        SettingsSection.notifications => 'Notifications',
        SettingsSection.about => 'About',
      };

  IconData get icon => switch (this) {
        SettingsSection.general => Icons.tune_rounded,
        SettingsSection.connections => Icons.dns_outlined,
        SettingsSection.profiles => Icons.manage_accounts_outlined,
        SettingsSection.agents => Icons.auto_awesome_outlined,
        SettingsSection.notifications => Icons.notifications_none_rounded,
        SettingsSection.about => Icons.info_outline_rounded,
      };
}

/// Feature-first settings screen. Profiles/preferences persist locally; SSH
/// secrets only enter the native secure credential vault when opted in.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.runtime,
    required this.onSave,
  });
  final SettingsPreferences preferences;
  final RemoteRuntime runtime;
  final Future<void> Function() onSave;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsSection current = SettingsSection.general;
  late final TextEditingController directory =
      TextEditingController(text: widget.preferences.defaultDirectory);

  SettingsPreferences get settings => widget.preferences;
  final Set<String> connecting = {};
  final Map<String, RemoteCapabilities> detected = {};

  @override
  void initState() {
    super.initState();
    widget.runtime.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.runtime.removeListener(_refresh);
    directory.dispose();
    super.dispose();
  }

  void _save() => unawaited(widget.onSave().catchError((Object error) {
        if (!mounted) return;
        ShadSonner.of(context).show(const ShadToast(
          title: Text('Could not save preferences'),
          description: Text('Please check local storage permissions.'),
        ));
      }));

  void update(VoidCallback change) {
    setState(change);
    _save();
  }

  Future<void> _connect(SshHostDraft host) async {
    if (kIsWeb) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Direct SSH needs the native app'),
        description: Text('Browsers require a trusted SSH WebSocket gateway. '
            'This preview never sends credentials.'),
      ));
      return;
    }
    final request = await showSshConnectDialog(context, host);
    if (!mounted || request == null) return;
    setState(() => connecting.add(host.id));
    try {
      await widget.runtime.connect(
        host,
        request.credentials,
        approveHostKey: (hostPort, algorithm, fingerprint) async {
          if (!mounted) return false;
          final allowed = await showShadDialog<bool>(
            context: context,
            builder: (ctx) => ShadDialog.alert(
              title: const Text('Trust SSH host key?'),
              description: Text(hostPort + '  ·  ' + algorithm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compare this fingerprint with the host through a '
                    'trusted channel. Accept only when it matches.',
                    style: TextStyle(fontSize: 12, color: AppColors.soft),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(fingerprint,
                      style: const TextStyle(
                        color: AppColors.peach,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      )),
                ],
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Reject'),
                ),
                ShadButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Trust this key'),
                ),
              ],
            ),
          );
          return allowed == true;
        },
      );
      if (request.remember) {
        await const SshCredentialStore().save(host.id, request.credentials);
      } else {
        await const SshCredentialStore().delete(host.id);
      }
      final capabilities = await widget.runtime.detect(host.id);
      if (!mounted) return;
      setState(() => detected[host.id] = capabilities);
      ShadSonner.of(context).show(ShadToast(
        title: const Text('SSH connected'),
        description: Text(host.name +
            ' · ' +
            (capabilities.tmux ? 'tmux available' : 'tmux not installed')),
      ));
    } catch (error) {
      if (!mounted) return;
      ShadSonner.of(context).show(ShadToast(
        title: const Text('SSH connection failed'),
        description: Text(error.toString()),
      ));
    } finally {
      if (mounted) setState(() => connecting.remove(host.id));
    }
  }

  Future<void> _deleteHost(SshHostDraft host) async {
    final allowed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Remove SSH host?'),
        description: Text('Remove ' +
            host.name +
            ' and its saved credentials? Persistent tmux sessions will '
                'continue running on the host.'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove host'),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    await widget.runtime.disconnect(host.id);
    await const SshCredentialStore().delete(host.id);
    update(() => settings.hosts.removeWhere((item) => item.id == host.id));
  }

  Future<void> editHost([SshHostDraft? existing]) async {
    final result = await showShadDialog<SshHostDraft>(
      context: context,
      builder: (_) => _SshHostDialog(existing: existing),
    );
    if (!mounted || result == null) return;
    if (existing != null) await widget.runtime.disconnect(existing.id);
    update(() {
      if (existing != null) settings.hosts.remove(existing);
      settings.hosts.add(result.withId(
        existing?.id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      ));
    });
  }

  Future<void> _editProfile([AgentProfile? existing]) async {
    final result = await showProfileEditor(
      context,
      hosts: settings.hosts,
      existing: existing,
    );
    if (!mounted || result == null) return;

    try {
      const store = OpenCodePasswordStore();
      if (result.password != null) {
        await store.save(result.profile.id, result.password!);
      } else if (existing?.usesHttp == true &&
          (!result.profile.usesHttp ||
              existing!.httpUrl != result.profile.httpUrl ||
              existing.httpUsername != result.profile.httpUsername)) {
        // Never reuse Basic-auth credentials with a different origin or user.
        await store.delete(result.profile.id);
      }
      if (!mounted) return;
      update(() {
        settings.profiles.removeWhere((p) => p.id == result.profile.id);
        settings.profiles.add(result.profile);
      });
    } catch (error) {
      if (!mounted) return;
      ShadSonner.of(context).show(ShadToast(
        title: const Text('Unable to save HTTP credentials'),
        description: Text(error.toString()),
      ));
    }
  }

  Future<void> _deleteProfile(AgentProfile profile) async {
    final allowed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('Remove profile?'),
        description: Text(
          'Remove "' +
              profile.name +
              '" from this device? Remote conversations remain untouched.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove profile'),
          ),
        ],
      ),
    );
    if (!mounted || allowed != true) return;
    try {
      await const OpenCodePasswordStore().delete(profile.id);
      if (!mounted) return;
      update(() {
        settings.profiles.removeWhere((p) => p.id == profile.id);
        if (settings.activeProfileId == profile.id) {
          settings.activeProfileId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ShadSonner.of(context).show(ShadToast(
        title: const Text('Could not remove profile'),
        description: Text(error.toString()),
      ));
    }
  }

  String _profileDestination(AgentProfile profile) {
    if (profile.usesHttp) return 'HTTP API · ' + (profile.httpUrl ?? '');
    final hosts = settings.hosts.where((h) => h.id == profile.hostId);
    return 'SSH · ' + (hosts.isEmpty ? 'Host removed' : hosts.first.name);
  }

  Widget _profiles() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionTitle(
            title: 'Configured profiles',
            subtitle: 'Each profile selects a coding agent and its connection.',
            trailing: SettingsAction(
              label: 'Add profile',
              icon: Icons.add_rounded,
              onPressed: _editProfile,
            ),
          ),
          if (settings.profiles.isEmpty)
            ShadCard(
              backgroundColor: AppColors.raised,
              padding: const EdgeInsets.all(23),
              child: const Column(
                children: [
                  Icon(Icons.manage_accounts_outlined,
                      color: AppColors.peach, size: 35),
                  SizedBox(height: 13),
                  Text('No profiles yet',
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  SizedBox(height: 7),
                  Text('Add a profile here, then switch profiles in Sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.soft, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          for (final profile in settings.profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: ShadCard(
                backgroundColor: AppColors.raised,
                padding: const EdgeInsets.all(17),
                radius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      AgentIcon(profile.agent, size: 42),
                      const SizedBox(width: 13),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(profile.agent.title,
                              style: const TextStyle(
                                  color: AppColors.soft, fontSize: 11)),
                        ],
                      )),
                      if (settings.activeProfileId == profile.id)
                        const StatusPill('ACTIVE', AppColors.mint, dot: false),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(
                          profile.usesHttp
                              ? Icons.language_rounded
                              : Icons.dns_outlined,
                          size: 17,
                          color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        _profileDestination(profile),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12, height: 1.45),
                      )),
                    ]),
                    const SizedBox(height: 15),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        leading: const Icon(Icons.edit_outlined, size: 15),
                        onPressed: () => _editProfile(profile),
                        child: const Text('Edit'),
                      ),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        leading:
                            const Icon(Icons.delete_outline_rounded, size: 15),
                        onPressed: () => _deleteProfile(profile),
                        child: const Text('Remove'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const PreviewHint(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 780;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.7, -.85),
            radius: 1.4,
            colors: [Color(0xff1d2630), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1080),
              margin: EdgeInsets.symmetric(
                  horizontal: wide ? 24 : 0, vertical: wide ? 22 : 0),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(wide ? 24 : 0),
                border: wide ? Border.all(color: AppColors.border) : null,
                boxShadow: wide
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .22),
                          blurRadius: 42,
                          offset: const Offset(0, 18),
                        )
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _pageTop(wide),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              _desktopNavigation(),
                              const ShadSeparator.vertical(
                                color: AppColors.border,
                                margin: EdgeInsets.zero,
                              ),
                              Expanded(child: _sectionBody(true)),
                            ],
                          )
                        : Column(
                            children: [
                              _mobileNavigation(),
                              const ShadSeparator.horizontal(
                                color: AppColors.border,
                                margin: EdgeInsets.zero,
                              ),
                              Expanded(child: _sectionBody(false)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageTop(bool wide) => Container(
        height: wide ? 76 : 65,
        padding: EdgeInsets.symmetric(horizontal: wide ? 26 : 17),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            ShadIconButton.ghost(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 9),
            Container(
              width: 33,
              height: 33,
              decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.settings_outlined,
                  color: AppColors.peach, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Settings',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4)),
            const Spacer(),
            if (wide)
              const StatusPill('SSH CLIENT', AppColors.mint, dot: false),
            if (!wide)
              const Icon(Icons.tune_rounded, color: AppColors.muted, size: 20),
          ],
        ),
      );

  Widget _desktopNavigation() => SizedBox(
        width: 252,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 28, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 13, bottom: 17),
                child: SettingsSmallHeading('PREFERENCES'),
              ),
              for (final section in SettingsSection.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: ShadButton.raw(
                    variant: current == section
                        ? ShadButtonVariant.secondary
                        : ShadButtonVariant.ghost,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    mainAxisAlignment: MainAxisAlignment.start,
                    backgroundColor: current == section
                        ? AppColors.hover
                        : Colors.transparent,
                    onPressed: () => update(() => current = section),
                    leading: Icon(section.icon,
                        size: 18,
                        color: current == section
                            ? AppColors.peach
                            : AppColors.soft),
                    child: Text(
                      section.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: current == section
                              ? FontWeight.w800
                              : FontWeight.w500),
                    ),
                  ),
                ),
              const Spacer(),
              const ShadSeparator.horizontal(color: AppColors.border),
              const SizedBox(height: 15),
              const Row(
                children: [
                  Icon(Icons.cloud_off_outlined,
                      color: AppColors.muted, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('No live host connected',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.muted))),
                ],
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 26),
                child: Text('v1.0.0 · UI prototype',
                    style: TextStyle(color: AppColors.muted, fontSize: 10)),
              ),
            ],
          ),
        ),
      );

  Widget _mobileNavigation() => SizedBox(
        height: 67,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            for (final section in SettingsSection.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShadButton.raw(
                  variant: current == section
                      ? ShadButtonVariant.secondary
                      : ShadButtonVariant.outline,
                  backgroundColor:
                      current == section ? AppColors.hover : AppColors.raised,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  onPressed: () => update(() => current = section),
                  leading: Icon(section.icon,
                      size: 16,
                      color: current == section
                          ? AppColors.peach
                          : AppColors.soft),
                  child:
                      Text(section.label, style: const TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      );

  Widget _sectionBody(bool wide) => ListView(
        key: ValueKey(current),
        padding: EdgeInsets.fromLTRB(
          wide ? 34 : 18,
          wide ? 36 : 24,
          wide ? 34 : 18,
          55,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        current.label,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: wide ? 29 : 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.9),
                      ),
                    ),
                    const StatusPill('BETA', AppColors.peach, dot: false),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sectionDescription(),
                  style: const TextStyle(
                      color: AppColors.soft, fontSize: 13, height: 1.55),
                ),
                const SizedBox(height: 23),
                if (current == SettingsSection.general) _general(),
                if (current == SettingsSection.connections) _connections(),
                if (current == SettingsSection.profiles) _profiles(),
                if (current == SettingsSection.agents) _agents(),
                if (current == SettingsSection.notifications) _notifications(),
                if (current == SettingsSection.about) _about(),
                const SizedBox(height: 22),
                const PreviewHint(),
              ],
            ),
          ),
        ],
      );

  String _sectionDescription() => switch (current) {
        SettingsSection.general =>
          'Fine-tune your coding workspace and session behavior.',
        SettingsSection.connections =>
          'Manage the machines where your coding agents run.',
        SettingsSection.profiles =>
          'Configure a named agent connection, then select it from Sessions.',
        SettingsSection.agents =>
          'Choose your preferred agents and workspace defaults.',
        SettingsSection.notifications =>
          'Decide which agent events deserve your attention.',
        SettingsSection.about =>
          'A little more about Agents and the current build.',
      };

  Widget _general() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 19, 18, 20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff30251f), Color(0xff1b202a)]),
                border:
                    Border.all(color: AppColors.peach.withValues(alpha: .19)),
                borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                      color: AppColors.peach.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.peach, size: 25),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your workspace, your flow.',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Keep the conversation at the center of everything.',
                          style: TextStyle(
                              color: AppColors.soft,
                              fontSize: 12,
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const SettingsSectionTitle(
            title: 'Interface',
            subtitle: 'Set how conversations and activity appear.',
          ),
          SettingsCard(children: [
            SettingsRow(
              icon: Icons.view_agenda_outlined,
              title: 'Compact messages',
              description: 'Use tighter spacing in conversations.',
              trailing: ShadSwitch(
                value: settings.compactMessages,
                onChanged: (v) => update(() => settings.compactMessages = v),
              ),
            ),
            SettingsRow(
              icon: Icons.code_rounded,
              title: 'Show tool activity',
              description: 'Include command and file activity in chat.',
              trailing: ShadSwitch(
                value: settings.showActivity,
                onChanged: (v) => update(() => settings.showActivity = v),
              ),
            ),
            SettingsRow(
              icon: Icons.security_outlined,
              title: 'Show commands before approval',
              description: 'Required to prevent blind approvals.',
              trailing: ShadSwitch(
                value: true,
                enabled: false,
              ),
            ),
          ]),
          const SizedBox(height: 29),
          const SettingsSectionTitle(
            title: 'Session lifecycle',
            subtitle: 'Defaults for disconnects and returning to work.',
          ),
          SettingsCard(children: [
            SettingsRow(
              icon: Icons.sync_rounded,
              title: 'Auto reconnect',
              description: 'Attempt to restore a dropped connection.',
              tint: AppColors.mint,
              trailing: ShadSwitch(
                value: settings.autoReconnect,
                onChanged: (v) => update(() => settings.autoReconnect = v),
              ),
            ),
            SettingsRow(
              icon: Icons.terminal_rounded,
              title: 'Persistent tmux sessions',
              description: 'Required for reliable SSH session reconnect.',
              tint: AppColors.mint,
              trailing: ShadSwitch(
                value: true,
                enabled: false,
              ),
            ),
          ]),
        ],
      );

  Widget _connections() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionTitle(
            title: 'SSH hosts',
            subtitle: 'Add a computer or server with SSH enabled.',
            trailing: SettingsAction(
              label: 'Add host',
              icon: Icons.add_rounded,
              onPressed: editHost,
            ),
          ),
          if (settings.hosts.isEmpty)
            ShadCard(
              backgroundColor: AppColors.raised,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 31),
              child: const Column(
                children: [
                  Icon(Icons.dns_outlined, size: 34, color: AppColors.muted),
                  SizedBox(height: 12),
                  Text('No SSH hosts saved',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      )),
                  SizedBox(height: 7),
                  Text(
                    'Add your development machine to start a real session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          for (final host in settings.hosts)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: ShadCard(
                backgroundColor: AppColors.raised,
                radius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.dns_outlined,
                            color: AppColors.blue, size: 21),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(host.name,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                              host.username +
                                  '@' +
                                  host.hostname +
                                  ':' +
                                  host.port.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        widget.runtime.isConnected(host.id)
                            ? 'CONNECTED'
                            : 'OFFLINE',
                        widget.runtime.isConnected(host.id)
                            ? AppColors.mint
                            : AppColors.muted,
                        dot: false,
                      ),
                    ]),
                    if (detected[host.id] != null) ...[
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        children: [
                          StatusPill(
                            detected[host.id]!.tmux ? 'tmux ✓' : 'tmux missing',
                            detected[host.id]!.tmux
                                ? AppColors.mint
                                : AppColors.yellow,
                            dot: false,
                          ),
                          for (final agent in Agent.values)
                            StatusPill(
                              agent.title +
                                  (detected[host.id]!.agents[agent] == true
                                      ? ' ✓'
                                      : ' —'),
                              detected[host.id]!.agents[agent] == true
                                  ? AppColors.mint
                                  : AppColors.muted,
                              dot: false,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ShadButton(
                          size: ShadButtonSize.sm,
                          enabled: !connecting.contains(host.id),
                          leading: Icon(
                            widget.runtime.isConnected(host.id)
                                ? Icons.sync_rounded
                                : Icons.link_rounded,
                            size: 15,
                          ),
                          onPressed: () {
                            if (widget.runtime.isConnected(host.id)) {
                              widget.runtime.detect(host.id).then((cap) {
                                if (mounted) {
                                  setState(() => detected[host.id] = cap);
                                }
                              });
                            } else {
                              _connect(host);
                            }
                          },
                          child: Text(connecting.contains(host.id)
                              ? 'Connecting…'
                              : widget.runtime.isConnected(host.id)
                                  ? 'Check tools'
                                  : 'Connect'),
                        ),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: () => editHost(host),
                          leading: const Icon(Icons.edit_outlined, size: 14),
                          child: const Text('Edit'),
                        ),
                        if (widget.runtime.isConnected(host.id))
                          ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: () => widget.runtime.disconnect(host.id),
                            child: const Text('Disconnect'),
                          ),
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () => _deleteHost(host),
                          leading: const Icon(Icons.delete_outline_rounded,
                              size: 14),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 25),
          const SettingsSectionTitle(
            title: 'Connection security',
            subtitle: 'New server fingerprints must be verified first.',
          ),
          SettingsCard(children: [
            const SettingsRow(
              icon: Icons.verified_user_outlined,
              title: 'SSH host key verification',
              description:
                  'Unknown keys require your approval. Changed keys are rejected.',
              tint: AppColors.mint,
              trailing: StatusPill('ENFORCED', AppColors.mint, dot: false),
            ),
            const SettingsRow(
              icon: Icons.key_outlined,
              title: 'Saved credentials',
              description:
                  'Optional OS secure vault on native. Never stored on web.',
              trailing: Icon(Icons.lock_outline_rounded,
                  color: AppColors.muted, size: 19),
            ),
          ]),
        ],
      );

  Widget _agents() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsSectionTitle(
            title: 'Preferred agent',
            subtitle: 'Used as the default for newly created sessions.',
          ),
          SettingsCard(children: [
            SettingsRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Default coding agent',
              description: 'Choose which agent to suggest first.',
              tint: AppColors.peach,
              trailing: ShadSelect<Agent>(
                key: ValueKey(settings.defaultAgent),
                minWidth: 165,
                initialValue: settings.defaultAgent,
                selectedOptionBuilder: (context, value) =>
                    Text(value.title, style: const TextStyle(fontSize: 12)),
                options: Agent.values
                    .map((agent) => ShadOption<Agent>(
                          value: agent,
                          child: Text(agent.title),
                        ))
                    .toList(),
                onChanged: (agent) {
                  if (agent != null)
                    update(() => settings.defaultAgent = agent);
                },
              ),
            ),
          ]),
          const SizedBox(height: 27),
          const SettingsSectionTitle(
            title: 'Available agents',
            subtitle:
                'Installed CLIs will be detected once a host is connected.',
          ),
          for (final agent in Agent.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ShadCard(
                backgroundColor: AppColors.raised,
                radius: BorderRadius.circular(13),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AgentIcon(agent, size: 40),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(agent.title,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          const SizedBox(height: 5),
                          const Text('Connect a host to detect this CLI',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const StatusPill('PREVIEW', AppColors.muted, dot: false),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const SettingsSectionTitle(
            title: 'Workspace directory',
            subtitle: 'Base path suggested when you create a new session.',
          ),
          ShadCard(
            backgroundColor: AppColors.raised,
            padding: const EdgeInsets.all(17),
            radius: BorderRadius.circular(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsSmallHeading('DEFAULT PROJECT ROOT'),
                const SizedBox(height: 12),
                ShadInput(
                  controller: directory,
                  placeholder: const Text('~/projects'),
                  onChanged: (value) {
                    settings.defaultDirectory = value;
                    _save();
                  },
                  leading: const Icon(Icons.folder_outlined,
                      size: 17, color: AppColors.muted),
                ),
                const SizedBox(height: 9),
                const Text(
                    'A suggested path on the remote machine — not validated yet.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      );

  Widget _notifications() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsSectionTitle(
            title: 'Agent notifications',
            subtitle: 'Stay informed when a session needs your attention.',
          ),
          SettingsCard(children: [
            SettingsRow(
              icon: Icons.shield_outlined,
              title: 'Approval requests',
              description: 'Get notified when an agent needs permission.',
              tint: AppColors.yellow,
              trailing: ShadSwitch(
                value: settings.approvalNotifications,
                onChanged: (v) =>
                    update(() => settings.approvalNotifications = v),
              ),
            ),
            SettingsRow(
              icon: Icons.task_alt_rounded,
              title: 'Task completed',
              description: 'Know when a remote run has finished.',
              tint: AppColors.mint,
              trailing: ShadSwitch(
                value: settings.completionNotifications,
                onChanged: (v) =>
                    update(() => settings.completionNotifications = v),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          ShadCard(
            backgroundColor: AppColors.raised,
            padding: const EdgeInsets.all(18),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_off_outlined,
                    color: AppColors.muted, size: 21),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Push delivery is not enabled',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 7),
                      Text(
                        'Push delivery while the app is closed requires a companion service or relay. Notification preferences are saved, but delivery is not connected yet.',
                        style: TextStyle(
                            color: AppColors.soft, fontSize: 12, height: 1.55),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      );

  Widget _about() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadCard(
            backgroundColor: AppColors.raised,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                      color: AppColors.peach,
                      borderRadius: BorderRadius.circular(17)),
                  child: const Icon(Icons.hub_rounded,
                      size: 29, color: AppColors.bg),
                ),
                const SizedBox(height: 16),
                const Text('agents',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1)),
                const SizedBox(height: 5),
                const Text('Remote coding, one conversation at a time.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.soft, height: 1.5)),
                const SizedBox(height: 16),
                const StatusPill('DESIGN PREVIEW  ·  1.0.0+1', AppColors.peach,
                    dot: false),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SettingsSectionTitle(
            title: 'Built for your workflow',
            subtitle: 'One interface for your favorite coding agents.',
          ),
          SettingsCard(children: [
            const SettingsRow(
              icon: Icons.smartphone_rounded,
              title: 'Flutter',
              description: 'Mobile-first across web and native platforms.',
              trailing:
                  Icon(Icons.check_rounded, color: AppColors.mint, size: 18),
            ),
            const SettingsRow(
              icon: Icons.dashboard_customize_outlined,
              title: 'shadcn_ui',
              description: 'Shared design system for all UI controls.',
              trailing:
                  Icon(Icons.check_rounded, color: AppColors.mint, size: 18),
            ),
            const SettingsRow(
              icon: Icons.terminal_rounded,
              title: 'SSH-first',
              description: 'Remote transport planned — not connected.',
              trailing: StatusPill('PLANNED', AppColors.muted, dot: false),
            ),
          ]),
        ],
      );
}

class _SshHostDialog extends StatefulWidget {
  const _SshHostDialog({this.existing});
  final SshHostDraft? existing;

  @override
  State<_SshHostDialog> createState() => _SshHostDialogState();
}

class _SshHostDialogState extends State<_SshHostDialog> {
  late final TextEditingController name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController hostname =
      TextEditingController(text: widget.existing?.hostname ?? '');
  late final TextEditingController username =
      TextEditingController(text: widget.existing?.username ?? '');
  late final TextEditingController port =
      TextEditingController(text: (widget.existing?.port ?? 22).toString());
  String? validationError;

  @override
  void dispose() {
    name.dispose();
    hostname.dispose();
    username.dispose();
    port.dispose();
    super.dispose();
  }

  void submit() {
    final parsedPort = int.tryParse(port.text.trim());
    if (name.text.trim().isEmpty ||
        hostname.text.trim().isEmpty ||
        username.text.trim().isEmpty ||
        parsedPort == null ||
        parsedPort < 1 ||
        parsedPort > 65535) {
      setState(() => validationError =
          'Enter a name, hostname, username and port (1–65535).');
      return;
    }

    Navigator.pop(
      context,
      SshHostDraft(
        name: name.text.trim(),
        hostname: hostname.text.trim(),
        username: username.text.trim(),
        port: parsedPort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ShadDialog(
        title: Text(widget.existing == null ? 'Add SSH host' : 'Edit SSH host'),
        description:
            const Text('Local preview only. No SSH connection will be made.'),
        constraints: const BoxConstraints(maxWidth: 450),
        child: SizedBox(
          width: 390,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field('DISPLAY NAME', name, 'My workstation'),
              _field('HOSTNAME / IP', hostname, 'dev.example.com'),
              _field('USERNAME', username, 'developer'),
              _field('PORT', port, '22'),
              if (validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(validationError!,
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
            onPressed: submit,
            child: const Text('Save host'),
          ),
        ],
      );

  Widget _field(String label, TextEditingController controller, String hint) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSmallHeading(label),
            const SizedBox(height: 7),
            ShadInput(
              controller: controller,
              placeholder: Text(hint),
            ),
          ],
        ),
      );
}
