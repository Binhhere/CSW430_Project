part of 'transfer_screens.dart';

class _DraftLineRow extends StatelessWidget {
  const _DraftLineRow({required this.line, this.onRemove, this.onQuantity});
  final TransferDraftLine line;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onQuantity;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: context.relay.structuralLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              line.asset.isSerialized
                  ? Icons.barcode_reader
                  : Icons.inventory_2_outlined,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.asset.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    line.asset.isSerialized
                        ? (line.asset.serialNumber ??
                              context.l10n.text('serialized'))
                        : context.l10n
                              .text('quantityAtOrigin')
                              .replaceAll(
                                '{quantity}',
                                '${line.asset.quantity ?? 0}',
                              ),
                    style: TextStyle(color: context.relay.textSecondary),
                  ),
                ],
              ),
            ),
            if (onQuantity != null)
              SizedBox(
                width: 66,
                child: DropdownButton<int>(
                  value: line.quantity,
                  isExpanded: true,
                  items: [
                    for (
                      var value = 1;
                      value <= ((line.asset.quantity ?? 1).clamp(1, 20));
                      value++
                    )
                      DropdownMenuItem(value: value, child: Text('$value')),
                  ],
                  onChanged: (value) {
                    if (value != null) onQuantity!(value);
                  },
                ),
              ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                tooltip: context.l10n.text('removeAsset'),
              ),
          ],
        ),
      ),
    ),
  );
}
