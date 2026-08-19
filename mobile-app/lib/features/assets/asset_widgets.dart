part of 'asset_screens.dart';

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({this.storagePath});
  final String? storagePath;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 32,
    child: _AssetCover(storagePath: storagePath, compact: true),
  );
}

class _AssetCover extends ConsumerWidget {
  const _AssetCover({this.storagePath, this.compact = false});
  final String? storagePath;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (storagePath == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.relay.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2_outlined, color: context.relay.textMuted),
      );
    }
    return FutureBuilder<Uint8List>(
      future: ref.read(assetCatalogRepositoryProvider).coverBytes(storagePath!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(snapshot.data!, fit: BoxFit.cover),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image_outlined),
        );
      },
    );
  }
}

class _AssetFieldLabel extends StatelessWidget {
  const _AssetFieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _AssetModeOption extends StatelessWidget {
  const _AssetModeOption({
    required this.label,
    required this.detail,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: !enabled
        ? context.relay.disabledSurface
        : selected
        ? context.relay.selectionContainer
        : Colors.transparent,
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: !enabled
                ? context.relay.disabledBorder
                : selected
                ? context.relay.selectedContent
                : context.relay.controlBorder,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: !enabled
                  ? context.relay.disabledContent
                  : selected
                  ? context.relay.selectedContent
                  : context.relay.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: enabled
                          ? context.relay.textPrimary
                          : context.relay.disabledContent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: enabled
                          ? context.relay.textSecondary
                          : context.relay.disabledContent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssetEmpty extends StatelessWidget {
  const _AssetEmpty({required this.archived});
  final bool archived;
  @override
  Widget build(BuildContext context) => LedgerScrollSafeCenter(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          archived ? Icons.archive_outlined : Icons.inventory_2_outlined,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          archived
              ? context.l10n.text('noArchivedAssets')
              : context.l10n.text('noAssets'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

class _AssetRetry extends StatelessWidget {
  const _AssetRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => LedgerScrollSafeCenter(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(context.l10n.text('retry')),
        ),
      ],
    ),
  );
}

class _AssetMore extends StatelessWidget {
  const _AssetMore({required this.show, required this.hasMore});
  final bool show;
  final bool hasMore;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Center(
      child: show && hasMore
          ? const CircularProgressIndicator()
          : const SizedBox.shrink(),
    ),
  );
}

String _stateLabel(BuildContext context, AssetRecord asset) =>
    switch (asset.workingState) {
      AssetWorkingState.atWarehouse => context.l10n.text('atWarehouse'),
      AssetWorkingState.assigned => context.l10n.text('assetAssigned'),
      AssetWorkingState.inTransit => context.l10n.text('assetInTransit'),
      AssetWorkingState.archived => context.l10n.text('archivedAssets'),
    };
