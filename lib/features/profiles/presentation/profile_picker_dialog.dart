import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../sessions/presentation/agent_visuals.dart';
import '../models/agent_profile.dart';

/// The Sessions dialog ONLY selects a previously configured profile.
/// Creation, editing and deletion belong to Settings → Profiles.
Future<AgentProfile?> showProfilePicker(
  BuildContext context, {
  required List<AgentProfile> profiles,
  required String? currentId,
  required String Function(String hostId) hostLabel,
}) =>
    showShadDialog<AgentProfile>(
      context: context,
      builder: (_) => ShadDialog(
        title: const Text('Select profile'),
        description: const Text('Switch the host and agent session list.'),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(
          width: 390,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .58,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 23),
                      child: Text(
                        'No profiles configured. Add one in Settings → Profiles.',
                        style: TextStyle(
                          color: AppColors.soft,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  for (final profile in profiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: ShadButton.outline(
                        width: double.infinity,
                        height: 68,
                        mainAxisAlignment: MainAxisAlignment.start,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        onPressed: () => Navigator.pop(context, profile),
                        leading: Icon(
                          profile.usesHttp
                              ? Icons.language_rounded
                              : Icons.computer_outlined,
                          color: profile.agent.tone,
                          size: 19,
                        ),
                        child: Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.agent.title +
                                    ' · ' +
                                    (profile.usesHttp
                                        ? 'HTTP · ' + (profile.httpUrl ?? '')
                                        : 'SSH · ' + hostLabel(profile.hostId)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: profile.id == currentId
                            ? const Icon(Icons.check_circle_rounded,
                                size: 18, color: AppColors.mint)
                            : const Icon(Icons.chevron_right_rounded,
                                size: 18, color: AppColors.muted),
                      ),
                    ),
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
        ],
      ),
    );
