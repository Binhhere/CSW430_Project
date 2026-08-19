part of 'transfer_screens.dart';

class _TransferRoute extends StatelessWidget {
  const _TransferRoute({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _line(context, label: '${context.l10n.text('from')}:', value: origin),
      const SizedBox(height: 4),
      _line(context, label: '${context.l10n.text('to')}:', value: destination),
    ],
  );

  Widget _line(
    BuildContext context, {
    required String label,
    required String value,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      SizedBox(
        width: 52,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.relay.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.relay.textSecondary),
        ),
      ),
    ],
  );
}

class _TransferMeta extends StatelessWidget {
  const _TransferMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: context.relay.textMuted),
      const SizedBox(width: 5),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.relay.textSecondary),
      ),
    ],
  );
}

class _DamageStatusButton extends StatelessWidget {
  const _DamageStatusButton({
    required this.status,
    required this.busy,
    required this.onPressed,
    this.prominent = false,
  });

  final TransferDamageStatus status;
  final bool busy;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.text(
      status == TransferDamageStatus.open
          ? 'openDamageReport'
          : 'openFixedDamageReport',
    ),
    child: SizedBox(
      width: prominent ? double.infinity : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: RelayMotion.press,
          child: busy
              ? SizedBox(
                  key: const ValueKey('damage-busy'),
                  width: prominent ? double.infinity : 78,
                  height: prominent ? 40 : 30,
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _DamageStatusPill(
                  key: ValueKey(status),
                  status: status,
                  prominent: prominent,
                ),
        ),
      ),
    ),
  );
}

class _DamageStatusPill extends StatelessWidget {
  const _DamageStatusPill({
    required this.status,
    this.prominent = false,
    super.key,
  });

  final TransferDamageStatus status;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == TransferDamageStatus.open;
    final isFixed = status == TransferDamageStatus.fixed;
    final fixedForeground = Theme.of(context).brightness == Brightness.dark
        ? context.relay.repairFixed
        : context.relay.onRepairFixed;
    final background = isOpen
        ? context.relay.dangerContainer
        : isFixed
        ? context.relay.repairFixedContainer
        : context.relay.surfaceSubtle;
    final foreground = isOpen
        ? context.relay.danger
        : isFixed
        ? fixedForeground
        : context.relay.textSecondary;
    final border = isOpen
        ? context.relay.danger
        : isFixed
        ? context.relay.repairFixed
        : context.relay.controlBorder;
    final icon = isOpen
        ? Icons.warning_amber_rounded
        : isFixed
        ? Icons.handyman_outlined
        : Icons.notifications_off_outlined;
    final label = isOpen
        ? context.l10n.text('damaged')
        : isFixed
        ? context.l10n.text('fixed')
        : context.l10n.text('cleared');
    return Container(
      width: prominent ? double.infinity : null,
      constraints: prominent ? const BoxConstraints(minHeight: 40) : null,
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 10 : 8,
        vertical: prominent ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: prominent
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.prominent = false});

  final TransferStatus status;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = switch (status) {
      TransferStatus.prepare => (
        context.relay.warning,
        context.relay.warningContainer,
        Icons.assignment_outlined,
      ),
      TransferStatus.inTransit => (
        context.relay.info,
        context.relay.infoContainer,
        Icons.local_shipping_outlined,
      ),
      _ => (
        context.relay.success,
        context.relay.successContainer,
        Icons.check_circle_outline,
      ),
    };
    final label = _statusLabel(context, status);
    return Semantics(
      container: true,
      label: label,
      child: Container(
        width: prominent ? double.infinity : null,
        constraints: prominent ? const BoxConstraints(minHeight: 40) : null,
        padding: EdgeInsets.symmetric(
          horizontal: prominent ? 12 : 8,
          vertical: prominent ? 8 : 5,
        ),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(prominent ? 8 : 999),
        ),
        child: prominent
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      height: 1.27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
      ),
    );
  }
}

String _attentionLabel(BuildContext context, TransferAttention attention) {
  return switch (attention) {
    TransferAttention.dispatchOverdue => context.l10n.text('dispatchOverdue'),
    TransferAttention.deliveryOverdue => context.l10n.text('deliveryOverdue'),
    TransferAttention.returnPickupOverdue => context.l10n.text(
      'returnPickupOverdue',
    ),
    TransferAttention.returnOverdue => context.l10n.text('returnOverdue'),
    TransferAttention.none => '',
  };
}

class _TransferAttentionBadge extends StatelessWidget {
  const _TransferAttentionBadge({required this.attention});

  final TransferAttention attention;

  @override
  Widget build(BuildContext context) {
    if (attention == TransferAttention.none) return const SizedBox.shrink();
    final (color, background, icon) = switch (attention) {
      TransferAttention.dispatchOverdue => (
        context.relay.warning,
        context.relay.warningContainer,
        Icons.local_shipping_outlined,
      ),
      TransferAttention.deliveryOverdue => (
        context.relay.danger,
        context.relay.dangerContainer,
        Icons.location_on_outlined,
      ),
      TransferAttention.returnPickupOverdue => (
        context.relay.warning,
        context.relay.warningContainer,
        Icons.move_to_inbox_outlined,
      ),
      TransferAttention.returnOverdue => (
        context.relay.danger,
        context.relay.dangerContainer,
        Icons.keyboard_return,
      ),
      TransferAttention.none => throw StateError('No attention badge'),
    };
    return Semantics(
      container: true,
      label: _attentionLabel(context, attention),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              context.l10n.text('overdueCompact'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
