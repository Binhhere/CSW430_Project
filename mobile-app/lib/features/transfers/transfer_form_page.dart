part of 'transfer_screens.dart';

class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({
    required this.company,
    this.existing,
    this.returnOf,
    super.key,
  });
  final RelayCompany company;
  final TransferRecord? existing;
  final TransferRecord? returnOf;
  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  final _form = GlobalKey<FormState>();
  final _requestKey = const Uuid().v4();
  late final _reference = TextEditingController(
    text: widget.existing?.reference ?? widget.returnOf?.reference,
  );
  late Future<_FormData> _data;
  CustomerRecord? _customer;
  LocationRecord? _origin;
  LocationRecord? _destination;
  String? _staffId;
  DateTime? _start;
  DateTime? _end;
  List<TransferDraftLine> _lines = [];
  final _dirtyForm = DirtyFormController();
  var _busy = false;
  String? _error;
  String? _initialReference;
  String? _initialCustomerId;
  String? _initialOriginId;
  String? _initialDestinationId;
  String? _initialStaffId;
  DateTime? _initialStart;
  DateTime? _initialEnd;
  String? _initialLines;
  var _initialCaptured = false;

  bool get _isReturn => widget.returnOf != null;

  String get _pageTitle => context.l10n.text(
    _isReturn
        ? 'createReturnTransfer'
        : widget.existing == null
        ? 'newTransfer'
        : 'editTransfer',
  );

  @override
  void initState() {
    super.initState();
    _data = _loadData();
    final source = widget.existing ?? widget.returnOf;
    if (source != null) {
      _customer = source.customer;
      _origin = _isReturn ? source.destination : source.origin;
      _destination = _isReturn ? source.origin : source.destination;
      _staffId = source.assignedStaffId;
      _start = source.startDate;
      _end = source.endDate;
      _lines = [
        for (final line in source.lines)
          TransferDraftLine(
            asset: line.asset,
            quantity: _isReturn ? line.dispatched : line.requested,
          ),
      ];
    }
    _reference.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<_FormData> _loadData() async {
    final access = ref.read(_transferAccessProvider);
    final members = await access.members(widget.company.id);
    return _FormData(members);
  }

  String get _lineSignature =>
      _lines.map((line) => '${line.asset.id}:${line.quantity}').join('|');

  bool get _isDirty =>
      !_initialCaptured ||
      _reference.text.trim() != _initialReference ||
      _customer?.id != _initialCustomerId ||
      _origin?.id != _initialOriginId ||
      _destination?.id != _initialDestinationId ||
      _staffId != _initialStaffId ||
      _start != _initialStart ||
      _end != _initialEnd ||
      _lineSignature != _initialLines;

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    await _dirtyForm.handlePopInvoked(
      context: context,
      didPop: didPop,
      busy: _busy,
      dirty: _isDirty,
      title: context.l10n.text('discardChangesTitle'),
      body: context.l10n.text('transferDraftNotSaved'),
      discardLabel: context.l10n.text('discard'),
      keepEditingLabel: context.l10n.text('keepEditing'),
      keepEditingPrimary: true,
      discardButtonStyle: OutlinedButton.styleFrom(
        foregroundColor: context.relay.danger,
        side: BorderSide(color: context.relay.danger),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onDiscard: () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_FormData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return LedgerPage(
          title: _pageTitle,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return LedgerPage(
          title: _pageTitle,
          child: _Retry(
            message: context.l10n.text('transferPeopleLoadFailed'),
            retry: () {
              final data = _loadData();
              setState(() {
                _data = data;
              });
            },
          ),
        );
      }
      final data = snapshot.data!;
      _staffId ??= widget.company.isOwner
          ? data.members.firstOrNull?.userId
          : ref.read(accessRepositoryProvider).session?.user.id;
      if (!_initialCaptured) {
        _initialReference = _reference.text.trim();
        _initialCustomerId = _customer?.id;
        _initialOriginId = _origin?.id;
        _initialDestinationId = _destination?.id;
        _initialStaffId = _staffId;
        _initialStart = _start;
        _initialEnd = _end;
        _initialLines = _lineSignature;
        _initialCaptured = true;
      }
      return PopScope(
        canPop: _dirtyForm.canPop(busy: _busy, dirty: _isDirty),
        onPopInvokedWithResult: _onPopInvoked,
        child: LedgerPage(
          title: _pageTitle,
          bottom: BusyButton(
            label: context.l10n.text(
              _isReturn ? 'saveReturnTransfer' : 'saveTransfer',
            ),
            busy: _busy,
            icon: Icons.save_outlined,
            onPressed: () => _save(data),
          ),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                TextFormField(
                  controller: _reference,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('referenceOptional'),
                  ),
                ),
                const SizedBox(height: 14),
                _PickerField(
                  label: context.l10n.text('customerLabel'),
                  value: _customer?.name,
                  enabled: !_isReturn,
                  onTap: _isReturn ? null : _selectCustomer,
                ),
                const SizedBox(height: 14),
                _PickerField(
                  label: context.l10n.text('origin'),
                  value: _origin == null
                      ? null
                      : '${_origin!.name} · ${_locationType(context, _origin!)}',
                  enabled: !_isReturn,
                  onTap: _isReturn ? null : () => _selectLocation(origin: true),
                ),
                const SizedBox(height: 14),
                _PickerField(
                  label: context.l10n.text('destination'),
                  value: _destination == null
                      ? null
                      : '${_destination!.name} · ${_locationType(context, _destination!)}',
                  enabled: !_isReturn,
                  onTap: _isReturn
                      ? null
                      : () => _selectLocation(origin: false),
                ),
                const SizedBox(height: 10),
                _DirectionNotice(origin: _origin, destination: _destination),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackDates =
                        constraints.maxWidth < 420 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2;
                    final startField = _DateField(
                      label: _isReturn
                          ? context.l10n.text('pickupReturnDue')
                          : context.l10n.text('deliveryDate'),
                      value: _start,
                      onTap: () => _pickDate(true),
                    );
                    final endField = _DateField(
                      label: _isReturn
                          ? context.l10n.text('returnDue')
                          : context.l10n.text('expectedBack'),
                      value: _end,
                      onTap: () => _pickDate(false),
                    );
                    return stackDates
                        ? Column(
                            children: [
                              startField,
                              const SizedBox(height: 14),
                              endField,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: startField),
                              const SizedBox(width: 10),
                              Expanded(child: endField),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  isExpanded: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  decoration: InputDecoration(
                    labelText: context.l10n.text('assignedStaff'),
                  ),
                  items: [
                    for (final member in data.members.where(
                      (m) =>
                          widget.company.isOwner ||
                          m.userId ==
                              ref
                                  .read(accessRepositoryProvider)
                                  .session
                                  ?.user
                                  .id,
                    ))
                      DropdownMenuItem(
                        value: member.userId,
                        child: Text(member.displayName),
                      ),
                  ],
                  onChanged: widget.company.isOwner
                      ? (value) => setState(() => _staffId = value)
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.text('assetsLabel'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.relay.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  Text(
                    context.l10n.text('transferCreateHelper'),
                    style: TextStyle(color: context.relay.textSecondary),
                  ),
                for (var index = 0; index < _lines.length; index++)
                  _DraftLineRow(
                    line: _lines[index],
                    onRemove: _isReturn
                        ? null
                        : () => setState(() => _lines.removeAt(index)),
                    onQuantity: _isReturn || _lines[index].asset.isSerialized
                        ? null
                        : (value) => setState(
                            () => _lines[index] = _lines[index].copyWith(
                              quantity: value,
                            ),
                          ),
                  ),
                if (!_isReturn) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _origin == null || _start == null || _end == null
                        ? null
                        : _addAsset,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.text('addAsset')),
                  ),
                ],
                if (_isReturn)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.l10n.text('returnPrefillHelper'),
                      style: TextStyle(color: context.relay.textSecondary),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = start ? _start : _end;
    final defaultFirstDate = today.subtract(const Duration(days: 1));
    final firstDate = start
        ? current != null && current.isBefore(defaultFirstDate)
              ? current
              : defaultFirstDate
        : _start ?? defaultFirstDate;
    final lastDate = today.add(const Duration(days: 730));
    final initialDate = current == null || current.isBefore(firstDate)
        ? firstDate
        : current.isAfter(lastDate)
        ? lastDate
        : current;
    final selected = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _start = selected;
        if (_end != null && _end!.isBefore(selected)) {
          _end = null;
        }
      } else {
        _end = selected;
      }
    });
  }

  Future<void> _selectCustomer() async {
    final selected = await Navigator.of(context).push<CustomerRecord>(
      relayRoute(
        builder: (_) => _PagedPickerPage<CustomerRecord>(
          title: context.l10n.text('selectCustomer'),
          searchHint: context.l10n.text('searchCustomers'),
          emptyLabel: context.l10n.text('noCustomersFound'),
          createLabel: context.l10n.text('newCustomer'),
          load: (query, after) => ref
              .read(catalogRepositoryProvider)
              .customers(
                companyId: widget.company.id,
                query: query,
                after: after,
              ),
          titleFor: (item) => item.name,
          subtitleFor: (item) => item.phone,
          onCreate: (pickerContext) =>
              Navigator.of(pickerContext).push<CustomerRecord>(
                relayRoute(
                  builder: (_) =>
                      CustomerFormPage(companyId: widget.company.id),
                ),
              ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _customer = selected);
  }

  Future<void> _selectLocation({required bool origin}) async {
    final otherEndpoint = origin ? _destination : _origin;
    final requiredType = switch (otherEndpoint?.type) {
      LocationType.warehouse => LocationType.deliveryPlace,
      LocationType.deliveryPlace => LocationType.warehouse,
      _ => null,
    };
    final selected = await Navigator.of(context).push<LocationRecord>(
      relayRoute(
        builder: (_) => _PagedPickerPage<LocationRecord>(
          title: origin
              ? context.l10n.text('selectOrigin')
              : context.l10n.text('selectDestination'),
          searchHint: context.l10n.text('searchLocations'),
          emptyLabel: requiredType == null
              ? context.l10n.text('noLocationsFound')
              : context.l10n.text('noCompatibleLocations'),
          createLabel: context.l10n.text('newLocation'),
          load: (query, after) => ref
              .read(catalogRepositoryProvider)
              .locations(
                companyId: widget.company.id,
                query: query,
                type: requiredType,
                after: after,
              ),
          titleFor: (item) => item.name,
          subtitleFor: (item) => _locationType(context, item),
          onCreate: (pickerContext) =>
              Navigator.of(pickerContext).push<LocationRecord>(
                relayRoute(
                  builder: (_) => LocationFormPage(
                    companyId: widget.company.id,
                    initialType: requiredType,
                  ),
                ),
              ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final current = origin ? _origin : _destination;
    if (selected.id == current?.id) return;

    if (transferOriginChangeNeedsAssetReset(
      changingOrigin: origin,
      currentLocationId: current?.id,
      selectedLocationId: selected.id,
      hasAssetLines: _lines.isNotEmpty,
    )) {
      final confirmed = await showRelayDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.text('changeOriginTitle')),
          content: Text(
            context.l10n
                .text('changeOriginBody')
                .replaceAll('{count}', '${_lines.length}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.text('keepCurrentOrigin')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.text('changeRemoveAssets')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      if (origin) {
        _origin = selected;
        _lines = [];
      } else {
        _destination = selected;
      }
    });
  }

  Future<void> _addAsset() async {
    final selected = await Navigator.of(context).push<TransferAssetSummary>(
      relayRoute(
        builder: (_) => _PagedPickerPage<TransferAssetSummary>(
          title: context.l10n.text('addAsset'),
          searchHint: context.l10n.text('searchAssetsAtOrigin'),
          emptyLabel: context.l10n.text('noAssetsAtOrigin'),
          paginated: false,
          load: (query, _) => ref
              .read(transferRepositoryProvider)
              .assetsAtOrigin(
                companyId: widget.company.id,
                originId: _origin!.id,
                query: query,
              ),
          titleFor: (item) => item.name,
          subtitleFor: (item) => item.isSerialized
              ? (item.serialNumber ?? context.l10n.text('serialized'))
              : context.l10n
                    .text('quantityAtOrigin')
                    .replaceAll('{quantity}', '${item.quantity ?? 0}'),
          enabled: (item) => !_lines.any((line) => line.asset.id == item.id),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(
        () => _lines.add(TransferDraftLine(asset: selected, quantity: 1)),
      );
    }
  }

  Future<void> _save(_FormData data) async {
    if (_busy) return;

    final missing = <String>[
      if (_customer == null) context.l10n.text('customerLabel'),
      if (_origin == null) context.l10n.text('origin'),
      if (_destination == null) context.l10n.text('destination'),
      if (_start == null)
        context.l10n.text(_isReturn ? 'pickup' : 'deliveryDate'),
      if (_end == null)
        context.l10n.text(_isReturn ? 'returnDue' : 'expectedBack'),
      if (_staffId == null) context.l10n.text('assignedStaff'),
      if (_lines.isEmpty) context.l10n.text('assets'),
    ];
    if (missing.isNotEmpty) {
      setState(
        () => _error = context.l10n
            .text('completeFields')
            .replaceAll('{fields}', missing.join(', ')),
      );
      return;
    }

    final validRoute =
        (_origin!.type == LocationType.warehouse &&
            _destination!.type == LocationType.deliveryPlace) ||
        (_origin!.type == LocationType.deliveryPlace &&
            _destination!.type == LocationType.warehouse);
    if (!validRoute) {
      setState(() => _error = context.l10n.text('chooseRoute'));
      return;
    }

    if (_end!.isBefore(_start!)) {
      final startLabel = context.l10n.text(
        _isReturn ? 'pickup' : 'deliveryDate',
      );
      final endLabel = context.l10n.text(
        _isReturn ? 'returnDue' : 'expectedBack',
      );
      setState(
        () => _error = context.l10n
            .text('dateOrderInvalid')
            .replaceAll('{endLabel}', endLabel)
            .replaceAll('{endDate}', _shortDate(context, _end!))
            .replaceAll('{startLabel}', startLabel)
            .replaceAll('{startDate}', _shortDate(context, _start!)),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(transferRepositoryProvider);
      String? createdTransferId;
      TransferRecord? savedTransfer;
      if (_isReturn) {
        createdTransferId = await repo.createReturn(
          outbound: widget.returnOf!,
          start: _start!,
          end: _end!,
          staffId: _staffId!,
          requestKey: _requestKey,
        );
      } else if (widget.existing != null) {
        savedTransfer = await repo.update(
          transfer: widget.existing!,
          customerId: _customer!.id,
          originId: _origin!.id,
          destinationId: _destination!.id,
          start: _start!,
          end: _end!,
          reference: _reference.text,
          assignedStaffId: _staffId!,
          lines: _lines,
          requestKey: _requestKey,
        );
      } else {
        createdTransferId = await repo.create(
          customerId: _customer!.id,
          originId: _origin!.id,
          destinationId: _destination!.id,
          start: _start!,
          end: _end!,
          reference: _reference.text,
          assignedStaffId: _staffId!,
          lines: _lines,
          requestKey: _requestKey,
        );
      }
      if (!mounted) return;
      _dirtyForm.allowPop();
      if (createdTransferId != null) {
        final transferId = createdTransferId;
        Navigator.of(context).pushReplacement<void, bool>(
          RelayPageRoute<void>(
            builder: (_) => TransferDetailPage(
              company: widget.company,
              transferId: transferId,
            ),
          ),
          result: true,
        );
      } else if (widget.existing != null) {
        Navigator.pop(context, savedTransfer);
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('transferSaveFailed'),
          );
        });
      }
    }
  }
}
