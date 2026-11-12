import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../app/theme/app_colors.dart';
import '../../sessions/models/agent_session.dart';
import '../../sessions/presentation/agent_visuals.dart';
import 'widgets/message_bubbles.dart';
import 'widgets/activity_card.dart';
import 'widgets/approval_card.dart';
import 'widgets/composer_box.dart';

class ConversationView extends StatefulWidget {
  const ConversationView(
      {super.key,
      required this.session,
      required this.input,
      required this.wide,
      required this.onSend,
      required this.onTerminal,
      required this.onChanges,
      required this.onFiles,
      required this.onTerminate,
      required this.onApprove,
      required this.onDeny,
      this.showActivity = true,
      this.compactMessages = false,
      this.showCommandPreview = true,
      this.sending = false});
  final AgentSession session;
  final TextEditingController input;
  final bool wide;
  final VoidCallback onSend,
      onTerminal,
      onChanges,
      onFiles,
      onTerminate,
      onApprove,
      onDeny;
  final bool showActivity, compactMessages, showCommandPreview, sending;
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  bool expanded = false;
  final ScrollController scroll = ScrollController();
  late int _lastMessageCount;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.session.lines.length;
  }

  @override
  void didUpdateWidget(covariant ConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.lines.length != _lastMessageCount ||
        widget.session.id != oldWidget.session.id) {
      _lastMessageCount = widget.session.lines.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> showDetails() => showShadDialog<void>(
        context: context,
        builder: (ctx) => ShadDialog(
          title: const Text('Session details'),
          description: const Text('About the current conversation'),
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Details('Agent', widget.session.agent.title),
              Details('Host', widget.session.host),
              Details('Directory', widget.session.path),
              Details('Status', widget.session.state.title),
              if (!widget.wide) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: ShadButton.outline(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onFiles();
                    },
                    leading: const Icon(Icons.folder_open_outlined, size: 16),
                    child: const Text('Files'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                      child: ShadButton.outline(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onChanges();
                    },
                    leading: const Icon(Icons.difference_outlined, size: 16),
                    child: const Text('Changes'),
                  )),
                ]),
              ],
              const SizedBox(height: 10),
              Text(
                widget.session.isHttpRemote
                    ? 'OpenCode HTTP session · messages use the remote API (no SSH terminal).'
                    : widget.session.isRemote
                        ? 'Live output is available in Terminal. Structured chat events are not supported.'
                        : 'Demo only · no remote agent is connected.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          actions: widget.session.tmuxName != null
              ? [
                  ShadButton.outline(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  ShadButton.destructive(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onTerminate();
                    },
                    child: const Text('Terminate tmux session'),
                  ),
                ]
              : [],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Column(children: [
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.wide ? 28 : 15,
          vertical: widget.wide ? 13 : 10,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.project,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: widget.wide ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: s.state.tone,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      s.agent.title + ' · ' + s.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.soft,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          if (!s.isHttpRemote)
            ShadIconButton.ghost(
              width: 36,
              height: 36,
              padding: EdgeInsets.zero,
              onPressed: widget.onTerminal,
              icon: const Icon(Icons.terminal_rounded,
                  size: 21, color: AppColors.soft),
            ),
          ShadIconButton.ghost(
            width: 36,
            height: 36,
            padding: EdgeInsets.zero,
            onPressed: showDetails,
            icon: const Icon(Icons.more_horiz_rounded,
                size: 22, color: AppColors.soft),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            widget.wide ? 30 : 14,
            16,
            widget.wide ? 30 : 14,
            16,
          ),
          children: [
            if (s.lines.isEmpty)
              const EmptyChat()
            else
              ...s.lines.map(
                (line) => Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.compactMessages ? 10 : 17,
                  ),
                  child: line.byUser
                      ? UserBubble(line)
                      : AgentBubble(line, s.agent),
                ),
              ),
            if (s.showActivity) ...[
              if (widget.showActivity) ...[
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => setState(() => expanded = !expanded),
                  leading: const Icon(Icons.terminal_outlined,
                      size: 15, color: AppColors.muted),
                  child: Text(
                      expanded ? 'Hide tool activity' : 'View tool activity',
                      style:
                          const TextStyle(color: AppColors.soft, fontSize: 11)),
                ),
                if (expanded) ...[
                  const SizedBox(height: 8),
                  ActivityCard(
                    expanded: true,
                    onToggle: () => setState(() => expanded = false),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              s.resolved
                  ? const ResolvedCard()
                  : ApprovalCard(
                      onApprove: widget.onApprove,
                      onDeny: widget.onDeny,
                      showCommand: widget.showCommandPreview,
                    ),
            ],
          ],
        ),
      ),
      ComposerBox(
        input: widget.input,
        wide: widget.wide,
        agent: s.agent,
        sending: widget.sending,
        enabled: !s.id.startsWith('empty-'),
        onSend: widget.onSend,
      ),
    ]);
  }
}

class Details extends StatelessWidget {
  const Details(this.keyName, this.value, {super.key});
  final String keyName, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 92,
              child: Text(keyName,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: AppColors.text, fontSize: 13))),
        ]),
      );
}
