part of 'transfer_screens.dart';

final _transferAccessProvider = Provider<AccessRepository>(
  (_) => AccessRepository.local(
    CourseApiClient(AppConfig.current.apiBaseUrl),
  ),
);

enum FastReturnFailureStage { create, detail, start }

class FastReturnResult {
  const FastReturnResult({
    required this.created,
    required this.returnId,
    required this.started,
    this.failureStage,
    this.error,
    this.stackTrace,
    this.returnTransfer,
  }) : assert(!created || returnId != null);

  final bool created;
  final String? returnId;
  final bool started;
  final FastReturnFailureStage? failureStage;
  final Object? error;
  final StackTrace? stackTrace;
  final TransferRecord? returnTransfer;
}

class _FastReturnRequestKeys {
  _FastReturnRequestKeys()
    : createReturn = const Uuid().v4(),
      startReturn = const Uuid().v4();

  final String createReturn;
  final String startReturn;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isEarlyReturn(TransferRecord transfer) {
  final today = _dateOnly(DateTime.now());
  return today.isBefore(_dateOnly(transfer.endDate));
}

String _returnActionLabel(BuildContext context, TransferRecord transfer) =>
    context.l10n.text(
      _isEarlyReturn(transfer) ? 'returnEarlyCompact' : 'returnCompact',
    );

IconData _returnActionIcon(TransferRecord transfer) =>
    _isEarlyReturn(transfer) ? Icons.history_toggle_off : Icons.keyboard_return;

Future<FastReturnResult?> _createAndStartReturnNow({
  required BuildContext context,
  required WidgetRef ref,
  required TransferRecord outbound,
  required _FastReturnRequestKeys requestKeys,
}) async {
  final today = _dateOnly(DateTime.now());
  final scheduledDue = _dateOnly(outbound.endDate);
  final returnDue = scheduledDue.isBefore(today) ? today : scheduledDue;
  final earlyReturn = _isEarlyReturn(outbound);
  final confirmed = await showRelayDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        earlyReturn
            ? context.l10n.text('returnEquipmentEarly')
            : context.l10n.text('startEquipmentReturn'),
      ),
      content: Text(
        context.l10n
            .text('createReturnNowBody')
            .replaceAll('{from}', outbound.destinationName)
            .replaceAll('{to}', outbound.originName)
            .replaceAll('{pickup}', _shortDate(context, today))
            .replaceAll('{due}', _shortDate(context, returnDue)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.l10n.text('cancel')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.keyboard_return),
          label: Text(context.l10n.text('createAndStart')),
        ),
      ],
    ),
  );
  if (confirmed != true) return null;

  final repository = ref.read(transferRepositoryProvider);
  return runFastReturnWorkflow(
    createReturn: () async {
      final staffId =
          outbound.assignedStaffId ??
          ref.read(_transferAccessProvider).session?.user.id;
      if (staffId == null) {
        throw StateError('A Staff member is required to start a return.');
      }
      return repository.createReturn(
        outbound: outbound,
        start: today,
        end: returnDue,
        staffId: staffId,
        requestKey: requestKeys.createReturn,
      );
    },
    loadReturn: (returnId) => repository.detail(outbound.companyId, returnId),
    startReturn: (returnTransfer) => repository.startReturn(
      returnTransfer,
      requestKey: requestKeys.startReturn,
    ),
  );
}

Future<FastReturnResult> runFastReturnWorkflow({
  required Future<String> Function() createReturn,
  required Future<TransferRecord?> Function(String returnId) loadReturn,
  required Future<void> Function(TransferRecord returnTransfer) startReturn,
}) async {
  String? returnId;
  try {
    returnId = await createReturn();
  } catch (error, stackTrace) {
    _logFastReturnFailure(
      stage: FastReturnFailureStage.create,
      returnId: returnId,
      error: error,
      stackTrace: stackTrace,
    );
    return FastReturnResult(
      created: false,
      returnId: null,
      started: false,
      failureStage: FastReturnFailureStage.create,
      error: error,
      stackTrace: stackTrace,
    );
  }

  TransferRecord? returnTransfer;
  try {
    returnTransfer = await loadReturn(returnId);
    if (returnTransfer == null) {
      throw StateError('Created Return could not be loaded.');
    }
  } catch (error, stackTrace) {
    _logFastReturnFailure(
      stage: FastReturnFailureStage.detail,
      returnId: returnId,
      error: error,
      stackTrace: stackTrace,
    );
    return FastReturnResult(
      created: true,
      returnId: returnId,
      started: false,
      failureStage: FastReturnFailureStage.detail,
      error: error,
      stackTrace: stackTrace,
    );
  }

  try {
    await startReturn(returnTransfer);
    return FastReturnResult(
      created: true,
      returnId: returnId,
      started: true,
      returnTransfer: returnTransfer,
    );
  } catch (error, stackTrace) {
    _logFastReturnFailure(
      stage: FastReturnFailureStage.start,
      returnId: returnId,
      error: error,
      stackTrace: stackTrace,
    );
    return FastReturnResult(
      created: true,
      returnId: returnId,
      started: false,
      failureStage: FastReturnFailureStage.start,
      error: error,
      stackTrace: stackTrace,
      returnTransfer: returnTransfer,
    );
  }
}

Future<FastReturnResult> retryFastReturnStart({
  required String returnId,
  required TransferRecord returnTransfer,
  required Future<void> Function(TransferRecord returnTransfer) startReturn,
}) async {
  try {
    await startReturn(returnTransfer);
    return FastReturnResult(
      created: true,
      returnId: returnId,
      started: true,
      returnTransfer: returnTransfer,
    );
  } catch (error, stackTrace) {
    _logFastReturnFailure(
      stage: FastReturnFailureStage.start,
      returnId: returnId,
      error: error,
      stackTrace: stackTrace,
    );
    return FastReturnResult(
      created: true,
      returnId: returnId,
      started: false,
      failureStage: FastReturnFailureStage.start,
      error: error,
      stackTrace: stackTrace,
      returnTransfer: returnTransfer,
    );
  }
}

void _logFastReturnFailure({
  required FastReturnFailureStage stage,
  required String? returnId,
  required Object error,
  required StackTrace stackTrace,
}) {
  debugPrint(
    'Fast Return failed at ${stage.name}; '
    'returnId=${returnId ?? 'none'}; error=$error',
  );
  debugPrintStack(stackTrace: stackTrace);
}

bool transferOriginChangeNeedsAssetReset({
  required bool changingOrigin,
  required String? currentLocationId,
  required String selectedLocationId,
  required bool hasAssetLines,
}) =>
    changingOrigin && hasAssetLines && currentLocationId != selectedLocationId;

enum _DamageCaseAction { markFixed, clear }

Future<_DamageCaseAction?> _showDamageCaseSheet({
  required BuildContext context,
  required TransferRecord transfer,
  required bool isOwner,
}) {
  final damageCase = transfer.damageCase;
  if (damageCase == null) {
    return Future<_DamageCaseAction?>.value();
  }
  final damagedLines = transfer.lines
      .where((line) => line.damaged > 0)
      .toList();
  return showRelaySheet<_DamageCaseAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sheetContext.l10n.text('damageReportTitle'),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                _DamageStatusPill(status: damageCase.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sheetContext.l10n.text('damageReportBody'),
              style: TextStyle(color: sheetContext.relay.textSecondary),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: damagedLines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final line = damagedLines[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      line.asset.isSerialized
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_outlined,
                      color: context.relay.danger,
                    ),
                    title: Text(line.asset.name),
                    subtitle: Text(
                      line.asset.isSerialized
                          ? '${line.asset.serialNumber ?? sheetContext.l10n.text('serialized')} · ${sheetContext.l10n.text('damaged').toLowerCase()}'
                          : sheetContext.l10n
                                .text('damagedOfReceived')
                                .replaceAll('{damaged}', '${line.damaged}')
                                .replaceAll('{received}', '${line.received}'),
                    ),
                  );
                },
              ),
            ),
            if (damageCase.isFixed && damageCase.fixedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                sheetContext.l10n
                    .text('markedFixedAt')
                    .replaceAll(
                      '{date}',
                      _shortDateTime(sheetContext, damageCase.fixedAt!),
                    ),
                style: TextStyle(color: sheetContext.relay.textSecondary),
              ),
            ],
            if (damageCase.isCleared && damageCase.clearedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                sheetContext.l10n
                    .text('alertClearedAt')
                    .replaceAll(
                      '{date}',
                      _shortDateTime(sheetContext, damageCase.clearedAt!),
                    ),
                style: TextStyle(color: sheetContext.relay.textSecondary),
              ),
            ],
            if (isOwner && !damageCase.isCleared) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                style: damageCase.isOpen
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: sheetContext.relay.repairFixed,
                        foregroundColor: sheetContext.relay.onRepairFixed,
                      ),
                onPressed: () => Navigator.pop(
                  sheetContext,
                  damageCase.isOpen
                      ? _DamageCaseAction.markFixed
                      : _DamageCaseAction.clear,
                ),
                icon: Icon(
                  damageCase.isOpen
                      ? Icons.handyman_outlined
                      : Icons.notifications_off_outlined,
                ),
                label: Text(
                  sheetContext.l10n.text(
                    damageCase.isOpen ? 'markFixed' : 'clearAlert',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _shortDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_shortDate(context, local)} $hour:$minute';
}
