import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../app/theme/app_colors.dart';
import '../../sessions/models/agent_session.dart';
import '../../sessions/presentation/agent_visuals.dart';
import '../../sessions/presentation/widgets/agent_icon.dart';
import '../../../shared/widgets/status_elements.dart';
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
      required this.onSessions,
      required this.onApprove,
      required this.onDeny,
      this.showActivity = true,
      this.compactMessages = false,
      this.showCommandPreview = true});
  final AgentSession session;
  final TextEditingController input;
  final bool wide;
  final VoidCallback onSend,
      onTerminal,
      onChanges,
      onFiles,
      onTerminate,
      onSessions,
      onApprove,
      onDeny;
  final bool showActivity, compactMessages, showCommandPreview;
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  bool expanded = false;
  final ScrollController scroll = ScrollController();
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
        padding: EdgeInsets.fromLTRB(widget.wide ? 36 : 19,
            widget.wide ? 23 : 20, widget.wide ? 35 : 12, 20),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AgentIcon(s.agent, size: widget.wide ? 48 : 43),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Flexible(
                      child: Text(s.project,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: widget.wide ? 22 : 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6))),
                  if (widget.wide) ...[
                    const SizedBox(width: 11),
                    StatusPill(s.state.title, s.state.tone),
                  ],
                ]),
                const SizedBox(height: 6),
                Text(s.agent.title + '  ·  ' + s.host,
                    style:
                        const TextStyle(color: AppColors.soft, fontSize: 12)),
                const SizedBox(height: 6),
                Text(s.path,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontFamily: 'monospace',
                        fontSize: 11)),
                if (!widget.wide) ...[
                  const SizedBox(height: 10),
                  StatusPill(s.state.title, s.state.tone)
                ],
              ])),
          ShadIconButton.ghost(
              width: 36,
              height: 36,
              padding: EdgeInsets.zero,
              onPressed: widget.onTerminal,
              icon: const Icon(Icons.terminal_rounded,
                  size: 22, color: AppColors.soft)),
          if (widget.wide)
            ShadIconButton.ghost(
                width: 34,
                height: 36,
                padding: EdgeInsets.zero,
                onPressed: widget.onFiles,
                icon: const Icon(Icons.folder_open_outlined,
                    size: 20, color: AppColors.soft)),
          if (widget.wide)
            ShadIconButton.ghost(
                width: 34,
                height: 36,
                padding: EdgeInsets.zero,
                onPressed: widget.onChanges,
                icon: const Icon(Icons.difference_outlined,
                    size: 20, color: AppColors.soft)),
          ShadIconButton.ghost(
              width: 36,
              height: 36,
              padding: EdgeInsets.zero,
              onPressed: showDetails,
              icon: const Icon(Icons.more_horiz_rounded,
                  size: 22, color: AppColors.soft)),
        ]),
      ),
      Expanded(
          child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
            widget.wide ? 40 : 17, 25, widget.wide ? 40 : 17, 24),
        children: [
          if (s.isRemote)
            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                'SSH / tmux · terminal output is the source of truth. '
                'Chat messages sent here are typed into the remote CLI.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            )
          else
            const Center(child: SmallLabel('TODAY  ·  10:42 AM')),
          const SizedBox(height: 27),
          if (s.lines.isEmpty)
            const EmptyChat()
          else
            ...s.lines.map((line) => Padding(
                  padding:
                      EdgeInsets.only(bottom: widget.compactMessages ? 13 : 26),
                  child: line.byUser
                      ? UserBubble(line)
                      : AgentBubble(line, s.agent),
                )),
          if (s.showActivity) ...[
            if (widget.showActivity) ...[
              Padding(
                padding: const EdgeInsets.only(left: 41),
                child: ActivityCard(
                  expanded: expanded,
                  onToggle: () => setState(() => expanded = !expanded),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 41),
              child: s.resolved
                  ? const ResolvedCard()
                  : ApprovalCard(
                      onApprove: widget.onApprove,
                      onDeny: widget.onDeny,
                      showCommand: widget.showCommandPreview,
                    ),
            ),
            const SizedBox(height: 15),
          ],
        ],
      )),
      ComposerBox(
        input: widget.input,
        wide: widget.wide,
        agent: s.agent,
        onSend: () {
          widget.onSend();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scroll.hasClients) {
              scroll.animateTo(scroll.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut);
            }
          });
        },
        onSessions: widget.onSessions,
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
