part of 'catalog_screens.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.action,
    required this.icon,
    required this.onAction,
  });
  final String title;
  final String action;
  final IconData icon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => LedgerScrollSafeCenter(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: context.relay.textMuted),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          BusyButton(label: action, onPressed: onAction, icon: Icons.add),
        ],
      ],
    ),
  );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => LedgerScrollSafeCenter(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RelayNotice(message: message, kind: RelayNoticeKind.danger),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.text('retry')),
        ),
      ],
    ),
  );
}

class _MoreIndicator extends StatelessWidget {
  const _MoreIndicator({required this.show, required this.hasMore});
  final bool show;
  final bool hasMore;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: hasMore ? 64 : 16,
    child: show ? const Center(child: CircularProgressIndicator()) : null,
  );
}
