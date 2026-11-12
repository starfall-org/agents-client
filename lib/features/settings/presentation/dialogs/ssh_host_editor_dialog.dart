import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/security/ssh_websocket_header_store.dart';
import '../../models/settings_preferences.dart';
import '../widgets/settings_widgets.dart';

class SshHostEditResult {
  const SshHostEditResult(this.host, this.headers);
  final SshHostDraft host;
  final Map<String, String> headers;
}

Future<SshHostEditResult?> showSshHostEditor(
  BuildContext context, {
  SshHostDraft? existing,
}) =>
    showShadDialog<SshHostEditResult>(
      context: context,
      builder: (_) => _SshHostEditor(existing: existing),
    );

class _HeaderRow {
  _HeaderRow(String name, String value)
      : name = TextEditingController(text: name),
        value = TextEditingController(text: value);
  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _SshHostEditor extends StatefulWidget {
  const _SshHostEditor({this.existing});
  final SshHostDraft? existing;

  @override
  State<_SshHostEditor> createState() => _SshHostEditorState();
}

class _SshHostEditorState extends State<_SshHostEditor> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final hostname =
      TextEditingController(text: widget.existing?.hostname ?? '');
  late final username =
      TextEditingController(text: widget.existing?.username ?? '');
  late final port =
      TextEditingController(text: (widget.existing?.port ?? 22).toString());
  late final wsUrl =
      TextEditingController(text: widget.existing?.websocketUrl ?? '');
  late SshTransportMode transport =
      widget.existing?.transport ?? SshTransportMode.direct;
  final List<_HeaderRow> headers = [];
  bool headersLoading = false;
  bool reveal = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    if (widget.existing?.usesWebSocket == true) {
      headersLoading = true;
      _loadHeaders();
    }
  }

  Future<void> _loadHeaders() async {
    try {
      final saved =
          await const SshWebSocketHeaderStore().read(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        for (final key in widget.existing!.websocketHeaderNames) {
          headers.add(_HeaderRow(key, saved[key] ?? ''));
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => validationError =
            'Could not read saved WebSocket headers. Check secure storage.');
      }
    } finally {
      if (mounted) setState(() => headersLoading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    hostname.dispose();
    username.dispose();
    port.dispose();
    wsUrl.dispose();
    for (final header in headers) {
      header.dispose();
    }
    super.dispose();
  }

  void addHeader() {
    if (headers.length >= 32) {
      setState(() => validationError = 'Maximum 32 custom headers.');
      return;
    }
    setState(() {
      headers.add(_HeaderRow('', ''));
      validationError = null;
    });
  }

  void removeHeader(int index) {
    setState(() {
      final removed = headers.removeAt(index);
      // Dispose after the current build (controllers may still be mounted).
      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
    });
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
          'Enter a name, SSH hostname, username and port (1–65535).');
      return;
    }
    final values = <String, String>{};
    if (transport == SshTransportMode.websocket) {
      final invalidUrl = SshHostDraft.validateWebSocketUrl(wsUrl.text);
      if (invalidUrl != null) {
        setState(() => validationError = invalidUrl);
        return;
      }
      for (final header in headers) {
        final field = header.name.text.trim();
        final value = header.value.text;
        final invalid = SshHostDraft.validateHeaderName(field) ??
            SshHostDraft.validateHeaderValue(value);
        if (invalid != null) {
          setState(() => validationError = invalid);
          return;
        }
        if (value.length > 8192) {
          setState(() => validationError =
              'A single header value cannot exceed 8192 characters.');
          return;
        }
        if (values.keys
            .any((name) => name.toLowerCase() == field.toLowerCase())) {
          setState(() => validationError = 'Duplicate header: $field');
          return;
        }
        values[field] = value;
      }
    }
    final result = SshHostDraft(
      id: widget.existing?.id ?? '',
      name: name.text.trim(),
      hostname: hostname.text.trim(),
      username: username.text.trim(),
      port: parsedPort,
      transport: transport,
      websocketUrl:
          transport == SshTransportMode.websocket ? wsUrl.text.trim() : null,
      websocketHeaderNames: List.unmodifiable(values.keys),
    );
    Navigator.pop(context, SshHostEditResult(result, values));
  }

  Widget field(String label, TextEditingController value, String hint) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSmallHeading(label),
            const SizedBox(height: 8),
            ShadInput(
              controller: value,
              placeholder: Text(hint),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ShadDialog(
        title: Text(widget.existing == null ? 'Add SSH host' : 'Edit SSH host'),
        description: const Text(
          'SSH runs over direct TCP or a WebSocket proxy that forwards raw binary SSH.',
        ),
        constraints: const BoxConstraints(maxWidth: 510),
        child: SizedBox(
          width: 455,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .58,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field('DISPLAY NAME', name, 'My workstation'),
                  field('SSH HOSTNAME / IP', hostname, 'dev.example.com'),
                  field('SSH USERNAME', username, 'developer'),
                  field('SSH PORT', port, '22'),
                  const SettingsSmallHeading('SSH TRANSPORT'),
                  const SizedBox(height: 8),
                  ShadSelect<SshTransportMode>(
                    key: ValueKey(transport),
                    initialValue: transport,
                    selectedOptionBuilder: (context, mode) => Text(
                      mode == SshTransportMode.direct
                          ? 'Direct TCP'
                          : 'WebSocket proxy',
                    ),
                    options: const [
                      ShadOption(
                        value: SshTransportMode.direct,
                        child: Text('Direct TCP'),
                      ),
                      ShadOption(
                        value: SshTransportMode.websocket,
                        child: Text('WebSocket proxy'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) setState(() => transport = mode);
                    },
                  ),
                  if (transport == SshTransportMode.websocket) ...[
                    const SizedBox(height: 20),
                    field('WEBSOCKET PROXY URL', wsUrl,
                        'wss://gateway.example.com/ssh'),
                    const Text(
                      'The proxy must forward raw SSH bytes to the intended host. '
                      'The SSH host and port above identify the server for host-key trust.',
                      style: TextStyle(
                          color: AppColors.soft, fontSize: 11, height: 1.6),
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      const Expanded(
                        child: Text(
                          'HTTP UPGRADE HEADERS',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        leading: const Icon(Icons.add_rounded, size: 14),
                        onPressed: headersLoading ? null : addHeader,
                        child: const Text('Add header'),
                      ),
                    ]),
                    const SizedBox(height: 9),
                    const Text(
                      'Add arbitrary headers such as Authorization, Cookie, '
                      'Origin, Cloudflare-Access-Client-Id or X-*. '
                      'WebSocket protocol headers are managed automatically.',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 11, height: 1.5),
                    ),
                    if (headersLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: LinearProgressIndicator(
                          color: AppColors.peach,
                          minHeight: 2,
                        ),
                      ),
                    for (var index = 0; index < headers.length; index++)
                      Container(
                        key: ValueKey(headers[index]),
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.raised,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                child: ShadInput(
                                  controller: headers[index].name,
                                  placeholder: const Text('Header name'),
                                ),
                              ),
                              const SizedBox(width: 5),
                              ShadIconButton.ghost(
                                width: 34,
                                height: 34,
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded,
                                    size: 17, color: AppColors.muted),
                                onPressed: () => removeHeader(index),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ShadInput(
                              controller: headers[index].value,
                              obscureText: !reveal,
                              placeholder: const Text('Header value'),
                            ),
                          ],
                        ),
                      ),
                    if (headers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () => setState(() => reveal = !reveal),
                          leading: Icon(
                            reveal
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                          ),
                          child: Text(reveal ? 'Hide values' : 'Show values'),
                        ),
                      ),
                    const SizedBox(height: 13),
                    Text(
                      kIsWeb
                          ? 'Browsers cannot set custom WebSocket handshake '
                              'headers. For these headers, use the native app.'
                          : 'Header values are stored in the OS secure vault, '
                              'not in app preferences.',
                      style: const TextStyle(
                        color: AppColors.yellow,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(validationError!,
                        style: const TextStyle(
                            color: AppColors.yellow, fontSize: 11)),
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
            onPressed: headersLoading ? null : submit,
            child: const Text('Save host'),
          ),
        ],
      );
}
