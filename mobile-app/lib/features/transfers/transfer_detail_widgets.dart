part of 'transfer_screens.dart';

class _RouteStrip extends StatelessWidget {
  const _RouteStrip({required this.transfer});
  final TransferRecord transfer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: _RouteEndpoint(
            label: context.l10n.text('from'),
            icon: Icons.warehouse_outlined,
            location: transfer.origin!,
          ),
        ),
        const Icon(Icons.arrow_forward),
        Expanded(
          child: _RouteEndpoint(
            label: context.l10n.text('to'),
            icon: Icons.place_outlined,
            location: transfer.destination!,
            end: true,
          ),
        ),
      ],
    ),
  );
}

class _RouteEndpoint extends StatelessWidget {
  const _RouteEndpoint({
    required this.label,
    required this.icon,
    required this.location,
    this.end = false,
  });
  final String label;
  final IconData icon;
  final LocationRecord location;
  final bool end;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Icon(icon, color: context.relay.textSecondary),
      const SizedBox(height: 6),
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.relay.textSecondary,
          letterSpacing: 1,
        ),
      ),
      Text(
        location.name,
        textAlign: end ? TextAlign.end : TextAlign.start,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

class _TransferLineRow extends StatelessWidget {
  const _TransferLineRow({required this.line, required this.transfer});
  final TransferLineRecord line;
  final TransferRecord transfer;
  @override
  Widget build(BuildContext context) {
    final actual = transfer.isReturn ? line.received : line.dispatched;
    final label = transfer.isReturn
        ? '${context.l10n.text('expectedQuantity').replaceFirst('{quantity}', '${line.requested}')} Â· ${context.l10n.text('actuallyReceived')} $actual'
        : '${context.l10n.text('reservedQuantity').replaceFirst('{quantity}', '${line.requested}')}${actual > 0 ? ' Â· ${context.l10n.text('dispatchedQuantity').replaceFirst('{quantity}', '$actual')}' : ''}';
    return LedgerRow(
      leading: Icon(
        line.asset.isSerialized
            ? Icons.barcode_reader
            : Icons.inventory_2_outlined,
      ),
      title: line.asset.name,
      subtitle:
          '${line.asset.isSerialized ? line.asset.serialNumber ?? context.l10n.text('serialized') : label}${line.asset.isSerialized ? '\n$label' : ''}',
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(label), subtitle: Text(value));
}
