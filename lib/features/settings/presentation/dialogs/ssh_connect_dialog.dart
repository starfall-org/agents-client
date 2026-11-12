import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/security/ssh_credential_store.dart';
import '../../../settings/models/settings_preferences.dart';
import '../widgets/settings_widgets.dart';

class CredentialRequest {
  const CredentialRequest(this.credentials, this.remember);
  final SshCredentials credentials;
  final bool remember;
}

Future<CredentialRequest?> showSshConnectDialog(
  BuildContext context,
  SshHostDraft host,
) =>
    showShadDialog<CredentialRequest>(
      context: context,
      builder: (_) => _ConnectDialog(host: host),
    );

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog({required this.host});
  final SshHostDraft host;
  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final password = TextEditingController();
  final privateKey = TextEditingController();
  final passphrase = TextEditingController();
  String method = 'Password';
  bool remember = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    privateKey.dispose();
    passphrase.dispose();
    super.dispose();
  }

  void submit() {
    final creds = method == 'Password'
        ? SshCredentials(password: password.text)
        : SshCredentials(
            privateKeyPem: privateKey.text,
            keyPassphrase: passphrase.text.isEmpty ? null : passphrase.text,
          );
    if (!creds.isValid) {
      setState(() => error = 'Enter a password or paste a private key.');
      return;
    }
    Navigator.pop(context, CredentialRequest(creds, remember));
  }

  @override
  Widget build(BuildContext context) => ShadDialog(
        title: const Text('Connect over SSH'),
        description: Text('Connect securely to ' +
            widget.host.hostname +
            ':' +
            widget.host.port.toString()),
        constraints: const BoxConstraints(maxWidth: 460),
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SettingsSmallHeading('AUTHENTICATION'),
              const SizedBox(height: 9),
              ShadSelect<String>(
                key: ValueKey(method),
                initialValue: method,
                selectedOptionBuilder: (context, value) => Text(value),
                options: const [
                  ShadOption(value: 'Password', child: Text('Password')),
                  ShadOption(
                      value: 'Private key', child: Text('Private key (PEM)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => method = value);
                },
              ),
              const SizedBox(height: 17),
              if (method == 'Password') ...[
                const SettingsSmallHeading('SSH PASSWORD'),
                const SizedBox(height: 9),
                ShadInput(
                  controller: password,
                  obscureText: true,
                  placeholder: const Text('SSH password'),
                ),
              ] else ...[
                const SettingsSmallHeading('PRIVATE KEY PEM'),
                const SizedBox(height: 9),
                ShadTextarea(
                  controller: privateKey,
                  minHeight: 115,
                  maxHeight: 160,
                  resizable: false,
                  placeholder:
                      const Text('-----BEGIN OPENSSH PRIVATE KEY-----'),
                ),
                const SizedBox(height: 12),
                const SettingsSmallHeading('KEY PASSPHRASE (OPTIONAL)'),
                const SizedBox(height: 9),
                ShadInput(
                  controller: passphrase,
                  obscureText: true,
                  placeholder: const Text('Passphrase'),
                ),
              ],
              const SizedBox(height: 15),
              if (!kIsWeb)
                Row(
                  children: [
                    Expanded(
                      child: Text('Remember in OS secure storage',
                          style:
                              TextStyle(color: AppColors.soft, fontSize: 12)),
                    ),
                    ShadSwitch(
                      value: remember,
                      onChanged: (value) => setState(() => remember = value),
                    ),
                  ],
                )
              else
                Text(
                  widget.host.usesWebSocket
                      ? 'The browser connects through the configured WebSocket proxy. '
                          'Browser handshake headers cannot be customized. '
                          'SSH credentials are not saved in web localStorage.'
                      : 'Direct SSH is unavailable in browsers. '
                          'Configure a WebSocket proxy on this SSH host.',
                  style: const TextStyle(
                      color: AppColors.yellow, fontSize: 11, height: 1.5),
                ),
              const SizedBox(height: 13),
              const Text(
                'You will be asked to verify an unknown host key fingerprint '
                'before the first connection.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 11, height: 1.5),
              ),
              if (error != null) ...[
                const SizedBox(height: 9),
                Text(error!,
                    style:
                        const TextStyle(color: AppColors.yellow, fontSize: 11)),
              ],
            ],
          ),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ShadButton(onPressed: submit, child: const Text('Connect')),
        ],
      );
}
