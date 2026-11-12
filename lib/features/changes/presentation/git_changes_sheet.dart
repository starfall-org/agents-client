import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/runtime/remote_runtime.dart';
import '../../../shared/widgets/status_elements.dart';
import '../../sessions/models/agent_session.dart';

/// Read-only Git status and tracked-file diff. No git mutation is allowed.
/// Diff is truncated remotely to 128 KiB, including for large repositories.
Future<void> showGitChanges(
  BuildContext context,
  RemoteRuntime runtime,
  AgentSession session,
) =>
    showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (_) => ShadSheet(
        title: const Text('Git changes'),
        description: Text(session.project + ' · read-only'),
        isScrollControlled: true,
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * .64,
          child: _GitChangesView(runtime: runtime, session: session),
        ),
      ),
    );

class _GitChangesView extends StatefulWidget {
  const _GitChangesView({required this.runtime, required this.session});
  final RemoteRuntime runtime;
  final AgentSession session;

  @override
  State<_GitChangesView> createState() => _GitChangesViewState();
}

class _GitChangesViewState extends State<_GitChangesView> {
  String view = 'Changes';
  String? status, diff, error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final statusResult = await widget.runtime.gitChanges(widget.session);
      final diffResult = await widget.runtime.gitDiff(widget.session);
      if (!mounted) return;
      setState(() {
        status = statusResult.trim().isEmpty
            ? 'Working tree is clean'
            : statusResult;
        diff = diffResult.trim().isEmpty
            ? 'No changes to tracked files.\n'
                'Untracked files are listed in the Changes tab.'
            : diffResult;
      });
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = view == 'Changes' ? status : diff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ShadButton.raw(
              variant: view == 'Changes'
                  ? ShadButtonVariant.secondary
                  : ShadButtonVariant.outline,
              size: ShadButtonSize.sm,
              backgroundColor:
                  view == 'Changes' ? AppColors.hover : AppColors.raised,
              onPressed: () => setState(() => view = 'Changes'),
              child: const Text('Changes'),
            ),
            const SizedBox(width: 8),
            ShadButton.raw(
              variant: view == 'Diff'
                  ? ShadButtonVariant.secondary
                  : ShadButtonVariant.outline,
              size: ShadButtonSize.sm,
              backgroundColor:
                  view == 'Diff' ? AppColors.hover : AppColors.raised,
              onPressed: () => setState(() => view = 'Diff'),
              child: const Text('Diff'),
            ),
            const Spacer(),
            const StatusPill('READ ONLY', AppColors.mint, dot: false),
            const SizedBox(width: 8),
            ShadIconButton.ghost(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: loading ? null : _refresh,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.peach,
            backgroundColor: AppColors.border,
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!,
                style: const TextStyle(fontSize: 12, color: AppColors.yellow)),
          ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(
                  _coloredDiff(
                      content ?? (loading ? 'Loading…' : 'No changes')),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: AppColors.soft,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Diff includes tracked changes against HEAD; untracked file '
          'contents are not included. Output is capped at 128 KiB.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  TextSpan _coloredDiff(String value) => TextSpan(
        children: value.split('\n').map((line) {
          final color = line.startsWith('+') && !line.startsWith('+++')
              ? AppColors.mint
              : line.startsWith('-') && !line.startsWith('---')
                  ? AppColors.peach
                  : line.startsWith('@@')
                      ? AppColors.blue
                      : AppColors.soft;
          return TextSpan(text: '$line\n', style: TextStyle(color: color));
        }).toList(),
      );
}
