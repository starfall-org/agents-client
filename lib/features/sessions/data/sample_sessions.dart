import '../models/agent_session.dart';

List<AgentSession> examples() => [
      AgentSession(
          'atlas',
          'Atlas dashboard',
          'Mac Studio',
          '~/projects/atlas-dashboard',
          Agent.claude,
          WorkState.approval,
          'Implementing authentication flow',
          '2m ago',
          [
            ChatLine(
                'Can you build the authentication flow using our existing design system? Keep the API layer typed and add basic tests.',
                true,
                '10:42'),
            ChatLine(
                'Of course. I’ll inspect the current auth patterns, then wire up the sign-in flow, API client, and tests. I’ll keep everything aligned with the existing components.',
                false,
                '10:43'),
          ],
          showActivity: true),
      AgentSession(
          'payments',
          'Payments API',
          'Dev server',
          '~/services/payments-api',
          Agent.codex,
          WorkState.running,
          'Running integration tests',
          '8m ago', [
        ChatLine(
            'Review the payment retry logic and add tests for duplicate webhook deliveries.',
            true,
            '10:16'),
        ChatLine(
            'I found two code paths that can process a repeated webhook. I’ve added idempotency checks and I’m validating the changes with integration tests.',
            false,
            '10:18'),
      ]),
      AgentSession(
          'website',
          'Marketing website',
          'Mac Studio',
          '~/work/marketing-site',
          Agent.opencode,
          WorkState.ready,
          'Ready for your next prompt',
          '18m ago', [
        ChatLine('Update the hero section to match the new brand guidelines.',
            true, '09:52'),
        ChatLine(
            'The hero is updated with new typography, spacing, and mobile breakpoints. Everything is ready for review.',
            false,
            '10:02'),
      ]),
      AgentSession(
          'design',
          'Design system',
          'Mac Studio',
          '~/projects/design-system',
          Agent.claude,
          WorkState.running,
          'Building reusable components',
          '1h ago', [
        ChatLine(
            'Create accessible dropdown and popover primitives with keyboard navigation.',
            true,
            '09:14'),
        ChatLine(
            'The core primitives are in place. I’m checking focus behavior and keyboard interactions before wrapping up.',
            false,
            '09:18'),
      ]),
      AgentSession(
          'internal',
          'Internal tools',
          'Dev server',
          '~/tools/admin-portal',
          Agent.codex,
          WorkState.done,
          'Finished updating table filters',
          'Yesterday', [
        ChatLine('Improve search and filters on the admin users table.', true,
            'Yesterday'),
        ChatLine(
            'Done. The search now supports partial matches, and filter state is persisted in the URL.',
            false,
            'Yesterday'),
      ]),
    ];
