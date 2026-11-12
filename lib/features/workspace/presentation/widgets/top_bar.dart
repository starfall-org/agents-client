import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/status_elements.dart';

class TopBar extends StatelessWidget {
  const TopBar(
      {super.key,
      required this.page,
      required this.count,
      required this.wide,
      required this.chat,
      required this.listing,
      required this.onSettings});
  final int page, count;
  final bool wide;
  final VoidCallback chat, listing, onSettings;

  @override
  Widget build(BuildContext context) => Container(
        height: wide ? 74 : 65,
        padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 19),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          InkWell(
            onTap: chat,
            borderRadius: BorderRadius.circular(12),
            child: Row(children: [
              Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.peach,
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.hub_rounded,
                    color: AppColors.bg, size: 21),
              ),
              const SizedBox(width: 11),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('agents',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.8,
                            height: 1)),
                    if (wide) ...[
                      const SizedBox(height: 5),
                      const SmallLabel('REMOTE CODING WORKSPACE'),
                    ],
                  ]),
            ]),
          ),
          const Spacer(),
          if (wide) ...[
            const StatusPill('UI PREVIEW', AppColors.muted, dot: false),
            const SizedBox(width: 18),
            Container(width: 1, height: 24, color: AppColors.border),
            const SizedBox(width: 16),
          ],
          ShadIconButton.ghost(
            width: 34,
            height: 34,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: onSettings,
          ),
          const SizedBox(width: 3),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            backgroundColor: page == 1
                ? AppColors.peach.withValues(alpha: .10)
                : AppColors.raised,
            onPressed: page == 0 ? listing : chat,
            leading: Icon(
              page == 0 ? Icons.view_sidebar_rounded : Icons.arrow_back_rounded,
              size: 17,
              color: page == 1 ? AppColors.peach : AppColors.soft,
            ),
            child: Text(
              page == 0 ? 'Sessions' : 'Chat',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ]),
      );
}
