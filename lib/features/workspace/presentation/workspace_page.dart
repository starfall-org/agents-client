import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../app/theme/app_colors.dart';
import '../../sessions/models/agent_session.dart';
import '../../sessions/data/sample_sessions.dart';
import '../../sessions/data/remote_session_repository.dart';
import '../../../core/runtime/remote_runtime.dart';
import '../../../core/security/ssh_credential_store.dart';
import '../../settings/data/settings_repository.dart';
import '../../sessions/presentation/sessions_page.dart';
import '../../sessions/presentation/new_session_dialog.dart';
import '../../terminal/presentation/terminal_sheet.dart';
import '../../files/presentation/file_browser_sheet.dart';
import '../../changes/presentation/git_changes_sheet.dart';
import '../../conversation/presentation/conversation_view.dart';
import '../../settings/models/settings_preferences.dart';
import '../../profiles/models/agent_profile.dart';
import '../../profiles/presentation/profile_picker_dialog.dart';
import '../../profiles/data/opencode_password_store.dart';
import '../../profiles/data/opencode_http_session_source.dart';
import '../../settings/presentation/settings_page.dart';
import 'widgets/top_bar.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  final List<AgentSession> sessions = examples();
  final SettingsPreferences preferences = SettingsPreferences();
  final RemoteRuntime runtime = RemoteRuntime();
  final List<AgentSession> _profileSessions = [];
  AgentSession? _profileSelectedSession;
  bool _profileLoading = false;
  String? _profileError;
  int _loadRevision = 0;
  int _transcriptRevision = 0;

  AgentProfile? get activeProfile {
    for (final profile in preferences.profiles) {
      if (profile.id == preferences.activeProfileId) return profile;
    }
    return null;
  }

  AgentSession get _emptyProfileSession {
    final profile = activeProfile!;
    final host = preferences.hosts.where((h) => h.id == profile.hostId);
    return AgentSession(
      'empty-' + profile.id,
      'Select a session',
      profile.usesHttp
          ? profile.name
          : (host.isNotEmpty ? host.first.name : 'SSH host unavailable'),
      '~',
      profile.agent,
      WorkState.disconnected,
      'Select a saved session from the session list',
      '',
      [],
    );
  }

  List<AgentSession> get visibleSessions =>
      activeProfile == null ? sessions : _profileSessions;

  final SettingsRepository settingsRepository = const SettingsRepository();
  final RemoteSessionRepository sessionRepository =
      const RemoteSessionRepository();

  @override
  void initState() {
    super.initState();
    runtime.addListener(_runtimeChanged);
    runtime.onConnectionLost = (hostId) {
      for (final session
          in sessions.where((item) => item.remoteHostId == hostId)) {
        session.state = WorkState.disconnected;
      }
      if (mounted) setState(() {});
      if (preferences.autoReconnect && !kIsWeb) {
        unawaited(_reconnect(hostId, 0));
      }
    };
    unawaited(_restoreState());
  }

  void _runtimeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreState() async {
    try {
      await settingsRepository.loadInto(preferences);
      final stored = await sessionRepository.read();
      if (!mounted) return;
      setState(() {
        sessions.insertAll(0, stored);
        if (stored.isNotEmpty) active = 0;
      });
      // Only reconnect automatically using credentials that the user
      // explicitly chose to save in the native OS secure vault.
      if (!kIsWeb && preferences.autoReconnect) {
        for (final host in preferences.hosts) {
          try {
            final credentials = await const SshCredentialStore().read(host.id);
            if (credentials == null || !mounted) continue;
            await runtime.connect(
              host,
              credentials,
              // Auto reconnect must NEVER silently trust a new host key.
              approveHostKey: (_, __, ___) async => false,
            );
          } catch (_) {
            // No automatic trust override. Host remains disconnected.
          }
        }
        if (mounted) await refreshRemoteSessions(silent: true);
      }
      if (mounted && activeProfile != null) await loadProfileSessions();
    } catch (_) {
      // UI demo remains usable if local persistence is unavailable.
    }
  }

  Future<void> _reconnect(String hostId, int attempt) async {
    if (attempt > 2 || !mounted || !preferences.autoReconnect) return;
    await Future<void>.delayed(Duration(seconds: 2 << attempt));
    if (!mounted || runtime.isConnected(hostId)) return;
    final hosts = preferences.hosts.where((h) => h.id == hostId);
    if (hosts.isEmpty) return;
    try {
      final credentials = await const SshCredentialStore().read(hostId);
      if (credentials == null || !mounted) return;
      await runtime.connect(
        hosts.first,
        credentials,
        approveHostKey: (_, __, ___) async => false,
      );
      if (mounted) await refreshRemoteSessions(silent: true);
    } catch (_) {
      if (mounted && attempt < 2) {
        unawaited(_reconnect(hostId, attempt + 1));
      }
    }
  }

  Future<void> _saveSettings() => settingsRepository.save(preferences);

  Future<void> _saveSessions() => sessionRepository.save(sessions);
  final PageController pages = PageController();
  final TextEditingController composer = TextEditingController();
  int active = 0;
  int currentPage = 0;
  String filter = 'All';
  String searchQuery = '';
  AgentSession get selected => activeProfile == null
      ? sessions[active]
      : (_profileSelectedSession ?? _emptyProfileSession);

  @override
  void dispose() {
    runtime.removeListener(_runtimeChanged);
    runtime.dispose();
    pages.dispose();
    composer.dispose();
    super.dispose();
  }

  void go(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    pages.animateToPage(page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic);
  }

  void select(AgentSession session) {
    setState(() {
      if (activeProfile != null) {
        _profileSelectedSession = session;
      } else {
        active = sessions.indexOf(session);
      }
    });
    composer.clear();
    go(0);
    if (session.providerSessionId != null) {
      unawaited(_loadTranscript(session));
    }
  }

  Future<void> _loadTranscript(AgentSession session) async {
    final revision = ++_transcriptRevision;
    try {
      final profile = activeProfile;
      if (session.isHttpRemote &&
          (profile == null || profile.id != session.httpProfileId)) return;
      final lines = session.isHttpRemote
          ? await const OpenCodeHttpSessionSource().messages(
              profile!,
              session.providerSessionId!,
              password: await const OpenCodePasswordStore().read(profile.id),
            )
          : await runtime.loadProviderMessages(session);
      if (!mounted ||
          revision != _transcriptRevision ||
          !identical(_profileSelectedSession, session)) return;
      setState(() {
        session.lines
          ..clear()
          ..addAll(lines);
      });
    } catch (_) {
      // A provider may not expose history on this CLI version. The user can
      // still resume the original session in Terminal without fabricated chat.
    }
  }

  Future<void> chooseProfile() async {
    final chosen = await showProfilePicker(
      context,
      profiles: preferences.profiles,
      currentId: preferences.activeProfileId,
      hostLabel: (hostId) {
        for (final host in preferences.hosts) {
          if (host.id == hostId) return host.name;
        }
        return 'Host removed';
      },
    );
    if (!mounted || chosen == null || chosen.id == preferences.activeProfileId)
      return;
    setState(() {
      preferences.activeProfileId = chosen.id;
      _profileSelectedSession = null;
      ++_transcriptRevision;
      ++_loadRevision;
      _profileSessions.clear();
      searchQuery = '';
      filter = 'All';
    });
    unawaited(_saveSettings());
    go(1);
    await loadProfileSessions();
  }

  Future<void> loadProfileSessions() async {
    final profile = activeProfile;
    if (profile == null) return;
    final revision = ++_loadRevision;
    setState(() {
      _profileLoading = true;
      _profileError = null;
      _profileSessions.clear();
      _profileSelectedSession = null;
    });
    try {
      final List<AgentSession> loaded;
      if (profile.usesHttp) {
        loaded = await const OpenCodeHttpSessionSource().list(
          profile,
          password: await const OpenCodePasswordStore().read(profile.id),
        );
      } else {
        final matching = preferences.hosts.where((h) => h.id == profile.hostId);
        if (matching.isEmpty) {
          throw StateError(
            'SSH host was removed. Edit this profile in Settings.',
          );
        }
        final host = matching.first;
        if (kIsWeb) {
          throw StateError(
            'Web cannot connect to raw SSH. Use the native app or a secure gateway.',
          );
        }
        if (!runtime.isConnected(host.id)) {
          throw StateError('Connect to ' +
              host.name +
              ' in Settings → Connections before loading sessions.');
        }
        loaded = await runtime.listProviderSessions(host, profile.agent);
      }
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _profileSessions.addAll(loaded);
        if (loaded.isNotEmpty) _profileSelectedSession = loaded.first;
      });
      if (loaded.isNotEmpty) unawaited(_loadTranscript(loaded.first));
    } catch (error) {
      if (!mounted || revision != _loadRevision) return;
      setState(() => _profileError = error.toString());
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> send() async {
    final message = composer.text.trim();
    if (message.isEmpty) return;
    final target = selected;
    if (activeProfile != null && _profileSelectedSession == null) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Select a saved session first'),
      ));
      go(1);
      return;
    }
    if (target.isHttpRemote) {
      final profile = activeProfile;
      if (profile == null || profile.id != target.httpProfileId) return;
      try {
        await const OpenCodeHttpSessionSource().sendPrompt(
          profile,
          target.providerSessionId!,
          message,
          password: await const OpenCodePasswordStore().read(profile.id),
        );
        if (!mounted) return;
        setState(() {
          target.lines.add(ChatLine(message, true, 'Now'));
          target.summary = 'Prompt sent over OpenCode HTTP';
          target.updated = 'Just now';
        });
        composer.clear();
        ShadSonner.of(context).show(const ShadToast(
          title: Text('Sent to OpenCode HTTP'),
          description: Text('The session continues on the remote server.'),
        ));
      } catch (error) {
        if (mounted) {
          ShadSonner.of(context).show(ShadToast(
            title: const Text('OpenCode HTTP request failed'),
            description: Text(error.toString()),
          ));
        }
      }
      return;
    }
    if (target.isSshRemote) {
      try {
        await runtime.sendPrompt(target, message);
        if (!mounted) return;
        setState(() {
          target.lines.add(ChatLine(message, true, 'Now'));
          target.summary = 'Sent to tmux · see Terminal for output';
          target.updated = 'Just now';
        });
        composer.clear();
        ShadSonner.of(context).show(const ShadToast(
          title: Text('Prompt sent to tmux'),
          description: Text('Open Terminal for live agent output. '
              'Structured chat events are not supported yet.'),
        ));
      } catch (error) {
        if (!mounted) return;
        ShadSonner.of(context).show(ShadToast(
          title: const Text('Could not send prompt'),
          description: Text(error.toString()),
        ));
      }
      return;
    }
    setState(() {
      target.lines.add(ChatLine(message, true, 'Now'));
      target.lines.add(ChatLine(
        'UI demo reply only. Connect an SSH host to control a real agent.',
        false,
        'Now',
      ));
      target.summary = message;
      target.updated = 'Just now';
    });
    composer.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void approval(bool allow) {
    setState(() {
      selected.resolved = true;
      selected.state = allow ? WorkState.running : WorkState.ready;
      selected.summary =
          allow ? 'Continuing implementation' : 'Command declined';
    });
    ShadSonner.of(context).show(
      ShadToast(
        title: Text(allow ? 'Approved in preview' : 'Declined in preview'),
        description: const Text('No command was executed on a remote host.'),
      ),
    );
  }

  Future<void> newSession() async {
    final profile = activeProfile;
    final connected = preferences.hosts
        .where((host) =>
            runtime.isConnected(host.id) &&
            (profile == null || profile.hostId == host.id))
        .toList();
    if (profile != null &&
        !profile.usesHttp &&
        !connected.any((host) => host.id == profile.hostId)) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Connect your profile’s SSH host first'),
        description: Text('Open Settings → Connections to connect.'),
      ));
      return;
    }
    final draft = await showNewSessionDialog(
      context,
      lockedProfile: profile,
      initialAgent: profile?.agent ?? preferences.defaultAgent,
      connectedHosts: connected,
      defaultDirectory: preferences.defaultDirectory,
    );
    if (!mounted || draft == null) return;

    if (profile?.usesHttp == true) {
      try {
        final result = await const OpenCodeHttpSessionSource().createSession(
          profile!,
          draft.project,
          password: await const OpenCodePasswordStore().read(profile.id),
        );
        if (!mounted) return;
        setState(() {
          _profileSessions.insert(0, result);
          _profileSelectedSession = result;
          filter = 'All';
        });
        go(0);
        ShadSonner.of(context).show(const ShadToast(
          title: Text('OpenCode HTTP session created'),
        ));
      } catch (error) {
        if (mounted) {
          ShadSonner.of(context).show(ShadToast(
            title: const Text('Could not create OpenCode session'),
            description: Text(error.toString()),
          ));
        }
      }
      return;
    }
    if (profile != null && !connected.any((h) => h.id == profile.hostId)) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Connect this profile’s host first'),
      ));
      return;
    }
    if (draft.hostId != null || profile != null) {
      try {
        final host = connected
            .firstWhere((h) => h.id == (profile?.hostId ?? draft.hostId));
        final result = await runtime.launch(
          host: host,
          agent: profile?.agent ?? draft.agent,
          project: draft.project,
          directory: draft.directory,
        );
        if (!mounted) return;
        setState(() {
          sessions.insert(0, result);
          active = 0;
          if (profile != null) {
            _profileSessions.insert(0, result);
            _profileSelectedSession = result;
          }
          filter = 'All';
        });
        await _saveSessions();
        if (mounted) {
          go(0);
          ShadSonner.of(context).show(ShadToast(
            title: const Text('Agent session started'),
            description: Text(host.name + ' · open Terminal for live output'),
          ));
        }
      } catch (error) {
        if (!mounted) return;
        ShadSonner.of(context).show(ShadToast(
          title: const Text('Unable to start agent'),
          description: Text(error.toString()),
        ));
      }
      return;
    }

    // Explicit demo target, no SSH commands are performed.
    setState(() {
      sessions.insert(
          0,
          AgentSession(
            DateTime.now().microsecondsSinceEpoch.toString(),
            draft.project,
            'Demo only',
            preferences.defaultDirectory.replaceAll(RegExp(r'/$'), '') +
                '/' +
                draft.project.toLowerCase().replaceAll(' ', '-'),
            draft.agent,
            WorkState.ready,
            'Demo conversation · no remote process',
            'Just now',
            [],
          ));
      active = 0;
      filter = 'All';
    });
    go(0);
  }

  void showTerminal() {
    if (activeProfile?.usesHttp == true || selected.isHttpRemote) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('No SSH terminal for HTTP profiles'),
        description: Text(
          'Use the OpenCode conversation API; HTTP profiles do not use tmux.',
        ),
      ));
      return;
    }
    showTerminalSheet(
      context,
      selected,
      attach: selected.isSshRemote ? () => runtime.attach(selected) : null,
    );
  }

  Future<void> openSettings() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          preferences: preferences,
          runtime: runtime,
          onSave: _saveSettings,
        ),
      ),
    );
    if (mounted) {
      if (activeProfile != null) {
        await loadProfileSessions();
      } else {
        await refreshRemoteSessions(silent: true);
      }
      setState(() {});
    }
  }

  Future<void> refreshRemoteSessions({bool silent = false}) async {
    int present = 0;
    for (final hostId in runtime.connectedHostIds) {
      try {
        final running = await runtime.listSessions(hostId);
        final names = running.map((item) => item.name).toSet();
        for (final session in sessions.where((s) =>
            s.isRemote && s.tmuxName != null && s.remoteHostId == hostId)) {
          session.state = names.contains(session.tmuxName)
              ? WorkState.available
              : WorkState.done;
          if (session.state == WorkState.available) present++;
        }
        // Existing tmux sessions from previous installs are discoverable.
        final host = preferences.hosts.where((h) => h.id == hostId);
        if (host.isEmpty) continue;
        for (final entry in running) {
          if (sessions
              .any((s) => s.tmuxName == entry.name && s.remoteHostId == hostId))
            continue;
          final parts = entry.name.split('_');
          final kind = Agent.values.firstWhere(
            (a) => parts.length > 1 && a.name == parts[1],
            orElse: () => Agent.claude,
          );
          sessions.insert(
              0,
              AgentSession(
                'recovered_' + entry.name,
                'Recovered tmux session',
                host.first.name,
                '~',
                kind,
                WorkState.available,
                'Existing remote session · open Terminal',
                'Discovered',
                [],
                remoteHostId: hostId,
                tmuxName: entry.name,
              ));
          present++;
        }
      } catch (_) {
        // A broken network connection is not evidence of process exit.
      }
    }
    if (!mounted) return;
    setState(() {});
    unawaited(_saveSessions());
    if (!silent) {
      ShadSonner.of(context).show(ShadToast(
        title: const Text('Sessions refreshed'),
        description: Text('$present live tmux sessions detected'),
      ));
    }
  }

  Future<void> terminateSelected() async {
    final target = selected;
    if (!target.isSshRemote || target.tmuxName == null) return;
    final allowed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Terminate remote session?'),
        description: Text('This ends the agent process in tmux on ' +
            target.host +
            '. Detach from Terminal instead to leave it running.'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep running'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
    if (!mounted || allowed != true) return;
    try {
      await runtime.terminate(target);
      if (!mounted) return;
      setState(() {
        target.state = WorkState.done;
        target.summary = 'Remote tmux session terminated';
      });
      unawaited(_saveSessions());
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Remote session terminated'),
      ));
    } catch (error) {
      if (!mounted) return;
      ShadSonner.of(context).show(ShadToast(
        title: const Text('Could not terminate session'),
        description: Text(error.toString()),
      ));
    }
  }

  Future<void> showFiles() async {
    if (!selected.isSshRemote) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Files require a connected remote session'),
        description: Text('Create a session with a connected SSH host.'),
      ));
      return;
    }
    try {
      runtime.requireConnection(selected.remoteHostId!);
      await showFileBrowser(context, runtime, selected);
    } catch (error) {
      if (mounted) {
        ShadSonner.of(context).show(ShadToast(
          title: const Text('Cannot open file browser'),
          description: Text(error.toString()),
        ));
      }
    }
  }

  Future<void> showChanges() async {
    final target = selected;
    if (!target.isSshRemote) {
      ShadSonner.of(context).show(const ShadToast(
        title: Text('Git changes require a remote session'),
      ));
      return;
    }
    try {
      runtime.requireConnection(target.remoteHostId!);
      await showGitChanges(context, runtime, target);
    } catch (error) {
      if (mounted) {
        ShadSonner.of(context).show(ShadToast(
          title: const Text('Cannot open Git changes'),
          description: Text(error.toString()),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
        body: Container(
      decoration: const BoxDecoration(
          gradient: RadialGradient(
        center: Alignment(-.7, -.85),
        radius: 1.4,
        colors: [Color(0xff1d2630), AppColors.bg],
      )),
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
                      color: Colors.black.withValues(alpha: .25),
                      blurRadius: 45,
                      offset: const Offset(0, 17))
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          TopBar(
              page: currentPage,
              count: visibleSessions.length,
              wide: wide,
              chat: () => go(0),
              listing: () => go(1),
              onSettings: openSettings),
          Expanded(
              child: PageView(
            controller: pages,
            onPageChanged: (i) => setState(() => currentPage = i),
            children: [
              ConversationView(
                key: ValueKey(selected.id),
                session: selected,
                input: composer,
                wide: wide,
                onSend: send,
                onTerminal: showTerminal,
                onChanges: showChanges,
                onFiles: showFiles,
                onTerminate: terminateSelected,
                onSessions: () => go(1),
                onApprove: () => approval(true),
                onDeny: () => approval(false),
                showActivity: preferences.showActivity,
                compactMessages: preferences.compactMessages,
                showCommandPreview: preferences.showCommandPreview,
              ),
              SessionList(
                sessions: visibleSessions,
                activeId: selected.id,
                profileLabel: activeProfile?.name ?? 'Demo (no profile)',
                profileLoading: _profileLoading,
                profileError: _profileError,
                onProfilePicker: chooseProfile,
                filter: filter,
                searchQuery: searchQuery,
                onSearch: (value) => setState(() => searchQuery = value),
                wide: wide,
                onFilter: (x) => setState(() => filter = x),
                onSelect: select,
                onNew: newSession,
                onBack: () => go(0),
                onRefresh: () => activeProfile == null
                    ? refreshRemoteSessions()
                    : loadProfileSessions(),
              ),
            ],
          )),
        ]),
      ))),
    ));
  }
}
