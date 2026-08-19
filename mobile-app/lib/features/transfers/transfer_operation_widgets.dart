part of 'transfer_screens.dart';

class _OperationLine extends StatelessWidget {
  const _OperationLine({
    required this.line,
    required this.quantity,
    required this.damaged,
  });
  final TransferLineRecord line;
  final TextEditingController quantity;
  final TextEditingController? damaged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.asset.name, style: Theme.of(context).textTheme.titleMedium),
        Text(
          line.asset.isSerialized
              ? line.asset.serialNumber ?? context.l10n.text('serialized')
              : context.l10n
                    .text('expectedQuantity')
                    .replaceFirst('{quantity}', '${line.requested}'),
          style: TextStyle(color: context.relay.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: damaged == null
                      ? context.l10n.text('actuallyDispatched')
                      : context.l10n.text('actuallyReceived'),
                ),
              ),
            ),
            if (damaged != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: damaged,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('damagedAmongReceived'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
