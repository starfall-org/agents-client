import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../app/theme/app_colors.dart';
import '../models/agent_session.dart';
import 'widgets/filter_badge.dart';
import 'widgets/session_card.dart';
import '../../../shared/widgets/status_elements.dart';

class SessionList extends StatelessWidget {
  const SessionList(
      {super.key,
      required this.sessions,
      required this.activeId,
      required this.filter,
      required this.searchQuery,
      required this.onSearch,
      required this.wide,
      required this.onFilter,
      required this.onSelect,
      required this.onNew,
      required this.onBack,
      required this.onRefresh,
      required this.onProfilePicker,
      required this.profileLabel,
      required this.profileLoading,
      this.profileError});
  final List<AgentSession> sessions;
  final String activeId, filter, searchQuery;
  final ValueChanged<String> onSearch;
  final bool wide;
  final ValueChanged<String> onFilter;
  final ValueChanged<AgentSession> onSelect;
  final VoidCallback onNew, onBack, onRefresh, onProfilePicker;
  final String profileLabel;
  final bool profileLoading;
  final String? profileError;

  @override
  Widget build(BuildContext context) {
    final visible = sessions.where((s) {
      final query = searchQuery.trim().toLowerCase();
      if (query.isNotEmpty &&
          ![s.project, s.host, s.path, s.agent.name, s.summary]
              .any((value) => value.toLowerCase().contains(query))) {
        return false;
      }
      if (filter == 'Running') return s.state == WorkState.running;
      if (filter == 'Needs input') return s.state == WorkState.approval;
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          wide ? 43 : 21, wide ? 38 : 26, wide ? 43 : 21, 45),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 870),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
                onTap: onBack,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back_rounded,
                      color: AppColors.muted, size: 16),
                  SizedBox(width: 7),
                  SmallLabel('BACK TO CONVERSATION'),
                ])),
            const SizedBox(height: 20),
            ShadButton.outline(
              width: double.infinity,
              mainAxisAlignment: MainAxisAlignment.start,
              onPressed: onProfilePicker,
              leading: const Icon(Icons.manage_accounts_outlined,
                  size: 19, color: AppColors.peach),
              child: Expanded(
                child: Text('Profile · ' + profileLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppColors.soft),
            ),
            if (profileLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: AppColors.peach,
                backgroundColor: AppColors.border,
                minHeight: 2,
              ),
            ],
            if (profileError != null) ...[
              const SizedBox(height: 12),
              Text(profileError!,
                  style: const TextStyle(
                      color: AppColors.yellow, fontSize: 12, height: 1.55)),
            ],
            const SizedBox(height: 30),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Your sessions',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: wide ? 32 : 28,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        sessions.length.toString() +
                            ' conversations · tap to open',
                        style: const TextStyle(
                            color: AppColors.soft, fontSize: 13)),
                  ])),
              ShadIconButton.ghost(
                icon: const Icon(Icons.refresh_rounded, size: 19),
                onPressed: onRefresh,
              ),
              const SizedBox(width: 5),
              ShadButton(
                onPressed: onNew,
                leading: const Icon(Icons.add_rounded, size: 18),
                child: Text(
                  wide ? 'New session' : 'New',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            ShadInput(
              placeholder: const Text('Search sessions, hosts, projects…'),
              leading: const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.muted),
              onChanged: onSearch,
            ),
            const SizedBox(height: 17),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                FilterBadge('All', sessions.length, filter == 'All',
                    () => onFilter('All')),
                const SizedBox(width: 8),
                FilterBadge(
                    'Running',
                    sessions.where((s) => s.state == WorkState.running).length,
                    filter == 'Running',
                    () => onFilter('Running')),
                const SizedBox(width: 8),
                FilterBadge(
                    'Needs input',
                    sessions.where((s) => s.state == WorkState.approval).length,
                    filter == 'Needs input',
                    () => onFilter('Needs input')),
              ]),
            ),
            const SizedBox(height: 30),
            const Row(children: [
              SmallLabel('CONVERSATIONS'),
              Spacer(),
              Icon(Icons.sort_rounded, color: AppColors.muted, size: 17),
              SizedBox(width: 6),
              Text('Recent activity',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ]),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 65),
                child: Center(
                    child: Column(children: [
                  const Icon(Icons.inbox_outlined,
                      size: 43, color: AppColors.muted),
                  const SizedBox(height: 15),
                  const Text('No sessions in this view',
                      style: TextStyle(color: AppColors.soft)),
                  const SizedBox(height: 8),
                  ShadButton.ghost(
                      onPressed: () => onFilter('All'),
                      child: const Text('Show all')),
                ])),
              )
            else
              ...visible.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SessionCard(s,
                      selected: activeId == s.id, onTap: () => onSelect(s)))),
            const SizedBox(height: 23),
            if (profileLabel == 'Demo (no profile)')
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                    color: AppColors.raised,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(13)),
                child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.muted, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Interactive design preview with sample sessions. SSH connections and live agent control are not enabled yet.',
                              style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.55))),
                    ]),
              ),
          ]),
        ),
      ],
    );
  }
}
