part of 'transfer_screens.dart';

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: retry,
          child: Text(context.l10n.text('retry')),
        ),
      ],
    ),
  );
}

class _TransferEmpty extends StatelessWidget {
  const _TransferEmpty({required this.filtered, this.onCreate, this.onClear});

  final bool filtered;
  final VoidCallback? onCreate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => LedgerScrollSafeCenter(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.swap_horiz_outlined, size: 48),
        const SizedBox(height: 12),
        Text(
          filtered
              ? context.l10n.text('noMatchingTransfers')
              : context.l10n.text('noTransfersYet'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.text('createTransferPrompt'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.relay.textSecondary),
        ),
        const SizedBox(height: 18),
        if (filtered)
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            label: Text(context.l10n.text('clearSearchFilters')),
          )
        else
          BusyButton(
            label: context.l10n.text('newTransfer'),
            onPressed: onCreate,
            icon: Icons.add,
          ),
      ],
    ),
  );
}

String _shortDate(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatShortDate(value);
String _statusLabel(BuildContext context, TransferStatus status) =>
    switch (status) {
      TransferStatus.prepare => context.l10n.text('prepareCompact'),
      TransferStatus.inTransit => context.l10n.text('inTransitCompact'),
      TransferStatus.done => context.l10n.text('doneCompact'),
    };
String _locationType(BuildContext context, LocationRecord location) =>
    location.type == LocationType.warehouse
    ? context.l10n.text('warehouseLabel')
    : context.l10n.text('deliveryPlaceLabel');

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
