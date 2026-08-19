part of 'transfer_screens.dart';

enum _TransferDetailOperation { idle, updating, leavingRoute }

class TransferDetailPage extends ConsumerStatefulWidget {
  const TransferDetailPage({
    required this.company,
    required this.transferId,
    this.embedded = false,
    this.onChanged,
    this.onTransferFocusRequested,
    super.key,
  });
  final RelayCompany company;
  final String transferId;
  final bool embedded;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onTransferFocusRequested;
  @override
  ConsumerState<TransferDetailPage> createState() => _TransferDetailPageState();
}

class _TransferDetailPageState extends ConsumerState<TransferDetailPage>
    with AppResumeRefreshMixin<TransferDetailPage> {
  final _detailRequests = LatestRequestGate();
  final _refreshRequests = LatestRequestGate();
  final _startReturnRequestKey = const Uuid().v4();
  final _fastReturnRequestKeys = _FastReturnRequestKeys();
  late Future<TransferRecord?> _future = _load();
  TransferRecord? _current;
  var _operation = _TransferDetailOperation.idle;
  String? _actionError;

  bool get _actionBusy => _operation == _TransferDetailOperation.updating;
  bool get _leavingRoute => _operation == _TransferDetailOperation.leavingRoute;

  Future<TransferRecord?> _load() async {
    final request = _detailRequests.begin();
    final transfer = await ref
        .read(transferRepositoryProvider)
        .detail(widget.company.id, widget.transferId);
    if (transfer == null || !mounted || !_detailRequests.isCurrent(request)) {
      return transfer;
    }
    _current = transfer;
    return transfer;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final refreshRequest = _refreshRequests.begin();
    final future = _load();
    setState(() {
      _actionError = null;
      _future = future;
    });
    try {
      await future;
    } catch (error) {
      if (mounted &&
          _refreshRequests.isCurrent(refreshRequest) &&
          identical(_future, future)) {
        setState(
          () => _actionError = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('transferRefreshFailedStale'),
          ),
        );
      }
    }
  }

  Future<void> _edit(TransferRecord transfer) async {
    if (_actionBusy || _leavingRoute) return;
    final saved = await Navigator.of(context).push<TransferRecord>(
      relayRoute(
        builder: (_) =>
            TransferFormPage(company: widget.company, existing: transfer),
      ),
    );
    if (saved == null || !mounted) return;
    _detailRequests.invalidate();
    _refreshRequests.invalidate();
    _current = saved;
    setState(() {
      _future = Future.value(saved);
    });
    widget.onChanged?.call();
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_actionBusy || _leavingRoute) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_actionBusy && !_leavingRoute,
    child: FutureBuilder<TransferRecord?>(
      future: _future,
      builder: (context, snapshot) {
        final transfer = snapshot.data ?? _current;
        if (snapshot.connectionState != ConnectionState.done &&
            transfer == null) {
          return LedgerPage(
            title: context.l10n.text('transfer'),
            child: LedgerRefreshView(
              onRefresh: _refresh,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if ((snapshot.hasError || transfer == null) && _current == null) {
          return LedgerPage(
            title: context.l10n.text('transfer'),
            child: LedgerRefreshView(
              onRefresh: _refresh,
              child: _Retry(
                message: context.l10n.text('transferLoadFailed'),
                retry: _refresh,
              ),
            ),
          );
        }
        if (transfer == null) {
          return LedgerPage(
            title: context.l10n.text('transfer'),
            child: Center(child: Text(context.l10n.text('notFoundNoAccess'))),
          );
        }
        final action = _action(transfer);
        final attention = transfer.attention();
        return LedgerPage(
          title: transfer.displayTitle,
          presentation: widget.embedded
              ? LedgerPagePresentation.embedded
              : LedgerPagePresentation.screen,
          actions: transfer.isPrepare
              ? [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: context.l10n.text('editTransfer'),
                    onPressed: () => _edit(transfer),
                  ),
                ]
              : null,
          bottom: action == null
              ? null
              : BusyButton(
                  label: action.$1,
                  icon: action.$2,
                  busy: _actionBusy,
                  onPressed: action.$3,
                ),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_actionError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: RelayNotice(
                      message: _actionError!,
                      kind: RelayNoticeKind.danger,
                    ),
                  ),
                if (transfer.integrityIssue != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: RelayNotice(
                      message: context.l10n.text('transferIntegrityError'),
                      kind: RelayNoticeKind.danger,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transfer.direction == TransferDirection.toCustomer
                                  ? context.l10n.text('toCustomer')
                                  : context.l10n.text('toWarehouse'),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: context.relay.textMuted,
                                    letterSpacing: 1,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              transfer.customerName,
                              style: TextStyle(
                                color: context.relay.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusPill(status: transfer.status),
                          if (attention != TransferAttention.none) ...[
                            const SizedBox(height: 6),
                            _TransferAttentionBadge(attention: attention),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (transfer.origin != null && transfer.destination != null)
                  _RouteStrip(transfer: transfer),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Text(
                    context.l10n.text('assetsLabel'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.relay.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                for (final line in transfer.lines)
                  _TransferLineRow(line: line, transfer: transfer),
                if (transfer.damageCase != null &&
                    transfer.lines.any((line) => line.damaged > 0)) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.text('damageReport'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: context.relay.textSecondary,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),
                        _DamageStatusPill(status: transfer.damageCase!.status),
                      ],
                    ),
                  ),
                  for (final line in transfer.lines.where(
                    (line) => line.damaged > 0,
                  ))
                    LedgerRow(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: context.relay.danger,
                      ),
                      title: line.asset.name,
                      subtitle: line.asset.isSerialized
                          ? '${line.asset.serialNumber ?? context.l10n.text('serialized')} · ${context.l10n.text('damaged').toLowerCase()}'
                          : context.l10n
                                .text('damagedOfReceived')
                                .replaceAll('{damaged}', '${line.damaged}')
                                .replaceAll('{received}', '${line.received}'),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: OutlinedButton.icon(
                      onPressed: _actionBusy
                          ? null
                          : () => _openDamageCase(transfer),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        widget.company.isOwner &&
                                !transfer.damageCase!.isCleared
                            ? context.l10n.text('reviewUpdateDamageStatus')
                            : context.l10n.text('viewDamageHistory'),
                      ),
                    ),
                  ),
                ],
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text(
                    context.l10n.text('evidence'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.relay.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _EvidenceActionRow(
                  icon: Icons.flight_takeoff_outlined,
                  label: context.l10n.text('viewDepartureEvidence'),
                  enabled:
                      transfer.isPrepare ||
                      transfer.isInTransit ||
                      transfer.isDone,
                  onTap: () => _openEvidence(
                    transfer,
                    EvidencePhase.departure,
                    transfer.isPrepare,
                  ),
                ),
                _EvidenceActionRow(
                  icon: Icons.flag_outlined,
                  label: context.l10n.text('viewArrivalEvidence'),
                  enabled:
                      (transfer.isReturn &&
                          (transfer.isInTransit || transfer.isDone)) ||
                      (!transfer.isReturn && transfer.isDone),
                  onTap: () => _openEvidence(
                    transfer,
                    EvidencePhase.arrival,
                    (transfer.isReturn && transfer.isInTransit) ||
                        (!transfer.isReturn && transfer.isDone),
                  ),
                ),
                _EvidenceActionRow(
                  icon: Icons.compare_arrows_outlined,
                  label: context.l10n.text('compareEvidence'),
                  enabled:
                      (transfer.isPrepare ||
                          transfer.isInTransit ||
                          transfer.isDone) &&
                      (transfer.isReturn
                          ? transfer.isInTransit || transfer.isDone
                          : transfer.isDone),
                  onTap: () => _openCompare(transfer),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Text(
                    context.l10n.text('operationalFacts'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.relay.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _FactRow(
                  icon: Icons.calendar_today_outlined,
                  label: transfer.direction == TransferDirection.toCustomer
                      ? context.l10n.text('deliveryExpectedReturn')
                      : context.l10n.text('pickupReturnDue'),
                  value:
                      '${_shortDate(context, transfer.startDate)} – ${_shortDate(context, transfer.endDate)}',
                ),
                _FactRow(
                  icon: Icons.person_outline,
                  label: context.l10n.text('assignedStaff'),
                  value:
                      transfer.assignedStaffName ??
                      context.l10n.text(
                        transfer.assignedStaffId == null
                            ? 'unassigned'
                            : 'staff',
                      ),
                ),
                if (transfer.isDone &&
                    transfer.isReturn &&
                    widget.company.isOwner) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.text('returnedItemsWarehouse'),
                      style: TextStyle(color: context.relay.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _openDamageCase(TransferRecord transfer) async {
    final action = await _showDamageCaseSheet(
      context: context,
      transfer: transfer,
      isOwner: widget.company.isOwner,
    );
    if (action == null || !mounted) return;
    await _runAction(() async {
      final repository = ref.read(transferRepositoryProvider);
      if (action == _DamageCaseAction.markFixed) {
        await repository.markDamageFixed(transfer.id);
      } else {
        await repository.clearDamageAlert(transfer.id);
      }
      await _refresh();
    });
  }

  (String, IconData, VoidCallback)? _action(TransferRecord transfer) {
    if ((transfer.isPrepare || transfer.isInTransit) &&
        transfer.direction == TransferDirection.toCustomer) {
      return (
        transfer.isInTransit
            ? context.l10n.text('continueCompact')
            : context.l10n.text('dispatchCompact'),
        Icons.local_shipping_outlined,
        () => _runAction(() async {
          final changed = await Navigator.of(context).push<bool>(
            relayRoute(
              builder: (_) => TransferOperationPage(
                company: widget.company,
                transfer: transfer,
                returnOperation: false,
              ),
            ),
          );
          if (changed == true && mounted) await _refresh();
        }),
      );
    }
    if (transfer.isPrepare &&
        transfer.direction == TransferDirection.toWarehouse) {
      return (
        context.l10n.text('startReturnCompact'),
        Icons.local_shipping_outlined,
        () => _confirmAndStartReturn(transfer),
      );
    }
    if (transfer.isInTransit &&
        transfer.direction == TransferDirection.toWarehouse) {
      return (
        context.l10n.text('completeReturnCompact'),
        Icons.assignment_turned_in_outlined,
        () => _runAction(() async {
          final changed = await Navigator.of(context).push<bool>(
            relayRoute(
              builder: (_) => TransferOperationPage(
                company: widget.company,
                transfer: transfer,
                returnOperation: true,
              ),
            ),
          );
          if (changed == true && mounted) await _refresh();
        }),
      );
    }
    if (transfer.isDone && transfer.direction == TransferDirection.toCustomer) {
      return (
        _returnActionLabel(context, transfer),
        _returnActionIcon(transfer),
        () => _runAction(() => _startReturnFromDetail(transfer)),
      );
    }
    return null;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionBusy) return;
    _detailRequests.invalidate();
    _refreshRequests.invalidate();
    setState(() {
      _operation = _TransferDetailOperation.updating;
      _actionError = null;
    });
    try {
      await action();
      widget.onChanged?.call();
      if (mounted && !_leavingRoute) {
        setState(() => _operation = _TransferDetailOperation.idle);
      }
    } catch (error) {
      if (mounted && !_leavingRoute) {
        setState(() {
          _operation = _TransferDetailOperation.idle;
          _actionError = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('transferUpdateFailed'),
          );
        });
      }
    }
  }

  Future<void> _confirmAndStartReturn(TransferRecord transfer) async {
    await _runAction(() async {
      final confirmed =
          await showRelayDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.l10n.text('startThisReturn')),
              content: Text(context.l10n.text('startReturnBody')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.l10n.text('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.l10n.text('startReturn')),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;

      final result = await retryFastReturnStart(
        returnId: transfer.id,
        returnTransfer: transfer,
        startReturn: (returnTransfer) => ref
            .read(transferRepositoryProvider)
            .startReturn(returnTransfer, requestKey: _startReturnRequestKey),
      );
      if (!result.started) {
        Error.throwWithStackTrace(
          result.error ?? StateError('Return could not be started.'),
          result.stackTrace ?? StackTrace.current,
        );
      }
      if (!mounted) return;
      await _refresh();
      await RelayHaptics.confirm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('returnStarted'))),
      );
      widget.onChanged?.call();
    });
  }

  Future<void> _startReturnFromDetail(TransferRecord transfer) async {
    final result = await _createAndStartReturnNow(
      context: context,
      ref: ref,
      outbound: transfer,
      requestKeys: _fastReturnRequestKeys,
    );
    if (result == null || !mounted) return;
    if (!result.created || result.returnId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('returnCreateFailed'))),
      );
      return;
    }
    if (!result.started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('returnCreatedNotStarted'))),
      );
    }
    widget.onChanged?.call();
    if (widget.onTransferFocusRequested != null) {
      setState(() => _operation = _TransferDetailOperation.idle);
      widget.onTransferFocusRequested!(result.returnId!);
      return;
    }
    _operation = _TransferDetailOperation.leavingRoute;
    Navigator.of(context).pushReplacement(
      relayRoute(
        builder: (_) => TransferDetailPage(
          company: widget.company,
          transferId: result.returnId!,
        ),
      ),
    );
  }

  Future<void> _openEvidence(
    TransferRecord transfer,
    EvidencePhase phase,
    bool allowCapture,
  ) async {
    await Navigator.of(context).push(
      relayRoute(
        builder: (_) => TransferEvidencePage(
          company: widget.company,
          transfer: transfer,
          phase: phase,
          allowCapture: allowCapture,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openCompare(TransferRecord transfer) async {
    await Navigator.of(context).push(
      relayRoute(
        builder: (_) => TransferCompareAssetPage(
          company: widget.company,
          transfer: transfer,
        ),
      ),
    );
  }
}

class _EvidenceActionRow extends StatelessWidget {
  const _EvidenceActionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: enabled ? onTap : null,
  );
}
