import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:xterm/xterm.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/transport/remote_executor.dart';
import '../../sessions/models/agent_session.dart';
import '../../../shared/widgets/status_elements.dart';

/// A real PTY and terminal emulator for SSH/tmux sessions.
/// Closing this sheet only detaches the client, not the tmux session.
Future<void> showTerminalSheet(
  BuildContext context,
  AgentSession selected, {
  Future<RemoteTerminalChannel> Function()? attach,
}) =>
    showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (sheetContext) => ShadSheet(
        title: const Text('Terminal'),
        description: Text(selected.host + ' · ' + selected.path),
        isScrollControlled: true,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .6,
          width: double.infinity,
          child: _TerminalSheetBody(attach: attach),
        ),
      ),
    );

class _TerminalSheetBody extends StatefulWidget {
  const _TerminalSheetBody({required this.attach});
  final Future<RemoteTerminalChannel> Function()? attach;

  @override
  State<_TerminalSheetBody> createState() => _TerminalSheetBodyState();
}

class _TerminalSheetBodyState extends State<_TerminalSheetBody> {
  final Terminal terminal = Terminal(maxLines: 5000);
  RemoteTerminalChannel? channel;
  StreamSubscription<String>? outputSubscription;
  bool connecting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.attach == null) {
      terminal.write(
        'Demo terminal · connect an SSH host to access a live PTY.\r\n'
        'No remote command has been executed.\r\n\r\n',
      );
    } else {
      connecting = true;
      terminal.write('Attaching to remote tmux session...\r\n');
      unawaited(_connect());
    }
  }

  Future<void> _connect() async {
    try {
      final result = await widget.attach!();
      if (!mounted) {
        result.close();
        return;
      }
      channel = result;
      terminal.onOutput = result.write;
      terminal.onResize =
          (columns, rows, _, __) => result.resize(columns, rows);
      result.resize(terminal.viewWidth, terminal.viewHeight);
      outputSubscription = result.output.listen(
        terminal.write,
        onError: (Object failure) {
          terminal.write('\r\nSSH terminal error: ' + failure.toString());
        },
        onDone: () {
          terminal.write('\r\n[Remote PTY detached]\r\n');
          if (mounted) setState(() {});
        },
      );
      setState(() => connecting = false);
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        error = failure.toString();
        connecting = false;
      });
      terminal.write('\r\nUnable to attach: ' + error! + '\r\n');
    }
  }

  @override
  void dispose() {
    terminal.onOutput = null;
    terminal.onResize = null;
    unawaited(outputSubscription?.cancel());
    channel?.close();
    super.dispose();
  }

  void sendKey(String key) {
    channel?.write(key);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded,
                  color: AppColors.peach, size: 19),
              const SizedBox(width: 10),
              const Text('Remote shell',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.text,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusPill(
                widget.attach == null
                    ? 'DEMO'
                    : connecting
                        ? 'CONNECTING'
                        : error == null && channel != null
                            ? 'ATTACHED'
                            : 'OFFLINE',
                channel == null ? AppColors.muted : AppColors.mint,
                dot: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: AppColors.bg,
                child: TerminalView(
                  terminal,
                  autofocus: true,
                  backgroundOpacity: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ShadButton.outline(
                size: ShadButtonSize.sm,
                enabled: channel != null,
                onPressed: () => sendKey('\x03'),
                child: const Text('Ctrl+C'),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                enabled: channel != null,
                onPressed: () => sendKey('\x1b'),
                child: const Text('Esc'),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                enabled: channel != null,
                onPressed: () => sendKey('\t'),
                child: const Text('Tab'),
              ),
              const Spacer(),
              Text('Close to detach',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ],
      );
}
