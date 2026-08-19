part of 'transfer_screens.dart';

class TransferListRow extends StatelessWidget {
  const TransferListRow({
    required this.transfer,
    required this.onTap,
    this.onReturnEarly,
    this.onDamageTap,
    this.returnBusy = false,
    this.damageBusy = false,
    this.selected = false,
    super.key,
  });

  final TransferRecord transfer;
  final VoidCallback onTap;
  final VoidCallback? onReturnEarly;
  final VoidCallback? onDamageTap;
  final bool returnBusy;
  final bool damageBusy;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasReference = transfer.reference?.trim().isNotEmpty == true;
    final attention = transfer.attention();
    return AnimatedContainer(
      duration: context.relayAnimationsDisabled
          ? Duration.zero
          : RelayMotion.micro,
      curve: RelayMotion.easeOut,
      color: selected
          ? context.relay.selectionContainer.withValues(alpha: .5)
          : null,
      child: Semantics(
        button: true,
        selected: selected,
        label: context.l10n
            .text('openTransferSemantics')
            .replaceAll('{title}', transfer.displayTitle)
            .replaceAll(
              '{attention}',
              attention == TransferAttention.none
                  ? ''
                  : ', ${_attentionLabel(context, attention)}',
            ),
        child: RelayTapFeedback(
          pressedScale: .996,
          child: InkWell(
            onTap: onTap,
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.displayTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (hasReference) ...[
                        const SizedBox(height: 2),
                        Text(
                          context.l10n
                              .text('customerName')
                              .replaceAll('{name}', transfer.customerName),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.relay.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 7),
                      _TransferRoute(
                        origin: transfer.originName,
                        destination: transfer.destinationName,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _TransferMeta(
                            icon: Icons.calendar_today_outlined,
                            label: _shortDate(context, transfer.startDate),
                          ),
                          _TransferMeta(
                            icon: Icons.person_outline,
                            label:
                                transfer.assignedStaffName ??
                                context.l10n.text('staff'),
                          ),
                        ],
                      ),
                    ],
                  );
                  final actions = _TransferActionRail(
                    transfer: transfer,
                    attention: attention,
                    onReturnEarly: onReturnEarly,
                    onDamageTap: onDamageTap,
                    returnBusy: returnBusy,
                    damageBusy: damageBusy,
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [details, const SizedBox(height: 12), actions],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      SizedBox(width: 156, child: actions),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferActionRail extends StatelessWidget {
  const _TransferActionRail({
    required this.transfer,
    required this.attention,
    required this.onReturnEarly,
    required this.onDamageTap,
    required this.returnBusy,
    required this.damageBusy,
  });

  final TransferRecord transfer;
  final TransferAttention attention;
  final VoidCallback? onReturnEarly;
  final VoidCallback? onDamageTap;
  final bool returnBusy;
  final bool damageBusy;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (transfer.integrityIssue != null)
        Text(
          context.l10n.text('transferIntegrityError'),
          style: TextStyle(color: context.relay.danger, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      _StatusPill(status: transfer.status, prominent: true),
      if (attention != TransferAttention.none)
        _TransferAttentionBadge(attention: attention),
      if (onDamageTap != null)
        _DamageStatusButton(
          status: transfer.damageCase!.status,
          busy: damageBusy,
          prominent: true,
          onPressed: onDamageTap!,
        ),
      if (onReturnEarly != null)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.relay.interactiveText,
            side: BorderSide(color: context.relay.controlBorder),
            minimumSize: const Size.fromHeight(40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: returnBusy ? null : onReturnEarly,
          icon: returnBusy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_returnActionIcon(transfer), size: 16),
          label: Text(_returnActionLabel(context, transfer)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          children[index],
        ],
      ],
    );
  }
}
