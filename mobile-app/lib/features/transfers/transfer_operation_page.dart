part of 'transfer_screens.dart';

class TransferOperationPage extends ConsumerStatefulWidget {
  const TransferOperationPage({
    required this.company,
    required this.transfer,
    required this.returnOperation,
    super.key,
  });
  final RelayCompany company;
  final TransferRecord transfer;
  final bool returnOperation;
  @override
  ConsumerState<TransferOperationPage> createState() =>
      _TransferOperationPageState();
}

class _TransferOperationPageState extends ConsumerState<TransferOperationPage> {
  final _requestKey = const Uuid().v4();
  late final Map<String, TextEditingController> _quantities = {
    for (final line in widget.transfer.lines)
      line.id: TextEditingController(
        text: '${widget.returnOperation ? line.requested : line.requested}',
      ),
  };
  late final Map<String, TextEditingController> _damaged = {
    for (final line in widget.transfer.lines)
      line.id: TextEditingController(text: '0'),
  };
  var _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final controller in [..._quantities.values, ..._damaged.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: LedgerPage(
      title: widget.returnOperation
          ? context.l10n.text('completeReturn')
          : context.l10n.text('dispatch'),
      bottom: BusyButton(
        label: widget.returnOperation
            ? context.l10n.text('completeReturnCompact')
            : context.l10n.text('dispatchCompact'),
        busy: _busy,
        icon: widget.returnOperation
            ? Icons.assignment_turned_in_outlined
            : Icons.local_shipping_outlined,
        onPressed: _save,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Text(
            widget.returnOperation
                ? context.l10n.text('returnReceivedInstructions')
                : context.l10n.text('dispatchInstructions'),
            style: TextStyle(color: context.relay.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final line in widget.transfer.lines)
            _OperationLine(
              line: line,
              quantity: _quantities[line.id]!,
              damaged: widget.returnOperation ? _damaged[line.id] : null,
            ),
          if (widget.returnOperation)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: RelayNotice(
                message: context.l10n.text('damagedReceivedInstructions'),
                kind: RelayNoticeKind.warning,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: RelayNotice(
                message: _error!,
                kind: RelayNoticeKind.danger,
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (_busy) return;
    final values = <String, int>{
      for (final entry in _quantities.entries)
        entry.key: int.tryParse(entry.value.text) ?? -1,
    };
    if (values.values.any((value) => value < 0)) {
      setState(() => _error = context.l10n.text('wholeQuantitiesOnly'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.returnOperation) {
        final result = <String, ({int received, int damaged})>{};
        for (final line in widget.transfer.lines) {
          final received = values[line.id]!;
          final damaged = int.tryParse(_damaged[line.id]!.text) ?? -1;
          if (damaged < 0 || damaged > received || received > line.requested) {
            throw const FormatException();
          }
          result[line.id] = (received: received, damaged: damaged);
        }
        await ref
            .read(transferRepositoryProvider)
            .completeReturn(widget.transfer, result, requestKey: _requestKey);
      } else {
        for (final line in widget.transfer.lines) {
          if (values[line.id]! < 0 || values[line.id]! > line.requested) {
            throw const FormatException();
          }
        }
        if (values.values.every((value) => value == 0)) {
          throw const FormatException();
        }
        await ref
            .read(transferRepositoryProvider)
            .dispatch(widget.transfer, values, requestKey: _requestKey);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('transfer operation failed: ${RelayFailure.from(error).kind}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.text('transferOperationFailed');
        });
      }
    }
  }
}
