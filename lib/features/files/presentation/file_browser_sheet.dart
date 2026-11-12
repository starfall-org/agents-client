import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/runtime/remote_runtime.dart';
import '../../../core/runtime/remote_sftp_browser.dart';
import '../../../shared/widgets/status_elements.dart';
import '../../sessions/models/agent_session.dart';

/// Read-only SFTP browser for a connected native SSH host.
Future<void> showFileBrowser(
  BuildContext context,
  RemoteRuntime runtime,
  AgentSession session,
) =>
    showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (_) => ShadSheet(
        title: const Text('Project files'),
        description: const Text('Read-only SFTP browser'),
        isScrollControlled: true,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .66,
          width: double.infinity,
          child: _FileList(runtime: runtime, session: session),
        ),
      ),
    );

class _FileList extends StatefulWidget {
  const _FileList({required this.runtime, required this.session});
  final RemoteRuntime runtime;
  final AgentSession session;
  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  final RemoteSftpBrowser browser = const RemoteSftpBrowser();
  late String path = widget.session.path;
  bool loading = false;
  String? failure;
  List<RemoteFileEntry> entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final value = await browser.list(
        widget.runtime.requireConnection(widget.session.remoteHostId!),
        path,
      );
      if (mounted) setState(() => entries = value);
    } catch (error) {
      if (mounted) {
        setState(() => failure = error.toString());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openFile(RemoteFileEntry entry) async {
    try {
      final body = await browser.readText(
        widget.runtime.requireConnection(widget.session.remoteHostId!),
        entry.path,
      );
      if (!mounted) return;
      await showShadDialog<void>(
        context: context,
        builder: (_) => ShadDialog(
          title: Text(entry.name),
          description:
              Text(entry.path, maxLines: 2, overflow: TextOverflow.ellipsis),
          constraints: const BoxConstraints(maxWidth: 670),
          child: SizedBox(
            width: 610,
            height: MediaQuery.sizeOf(context).height * .54,
            child: ColoredBox(
              color: AppColors.bg,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(15),
                child: SelectableText(
                  body.isEmpty ? '(empty file)' : body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.soft,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ShadSonner.of(context).show(ShadToast(
          title: const Text('Unable to read file'),
          description: Text(error.toString()),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ShadIconButton.ghost(
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              onPressed: () {
                path = browser.parent(path);
                _load();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.soft,
                  fontSize: 12,
                ),
              ),
            ),
            ShadIconButton.ghost(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: loading ? null : _load,
            ),
            const StatusPill('READ ONLY', AppColors.mint, dot: false),
          ]),
          const SizedBox(height: 12),
          if (loading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: AppColors.border,
              color: AppColors.peach,
            ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(failure!,
                  style:
                      const TextStyle(color: AppColors.yellow, fontSize: 12)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: ShadButton.ghost(
                    width: double.infinity,
                    mainAxisAlignment: MainAxisAlignment.start,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 12,
                    ),
                    onPressed: () {
                      if (entry.isDirectory) {
                        path = entry.path;
                        _load();
                      } else {
                        _openFile(entry);
                      }
                    },
                    leading: Icon(
                      entry.isDirectory
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 18,
                      color:
                          entry.isDirectory ? AppColors.peach : AppColors.soft,
                    ),
                    child: Expanded(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Files larger than 256 KiB and binary files cannot be previewed.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      );
}
