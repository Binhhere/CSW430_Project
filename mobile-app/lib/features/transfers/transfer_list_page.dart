part of 'transfer_screens.dart';

class TransferListPage extends ConsumerStatefulWidget {
  const TransferListPage({required this.company, super.key});
  final RelayCompany company;

  @override
  ConsumerState<TransferListPage> createState() => _TransferListPageState();
}

class _TransferListPageState extends ConsumerState<TransferListPage>
    with AppResumeRefreshMixin<TransferListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _debouncer = SearchDebouncer(const Duration(milliseconds: 300));
  late final PagedLoadController<TransferRecord> _page;
  TransferStatus? _status;
  String? _staffId;
  String? _staffLabel;
  var _membersLoading = false;
  List<RelayMember> _members = const [];
  String? _returningTransferId;
  String? _damageBusyTransferId;
  String? _selectedTransferId;
  final _returnRequestKeys = <String, _FastReturnRequestKeys>{};

  List<TransferRecord> get _items => _page.items;
  bool get _loading => _page.loading;
  bool get _hasMore => _page.hasMore;
  String? get _error =>
      _page.error == null ? null : context.l10n.text('transfersLoadFailed');

  (Color, Color) _statusFilterColors(
    BuildContext context,
    TransferStatus status,
  ) {
    final palette = context.relay;
    return switch (status) {
      TransferStatus.prepare => (palette.warning, palette.warningContainer),
      TransferStatus.inTransit => (palette.info, palette.infoContainer),
      TransferStatus.done => (palette.success, palette.successContainer),
    };
  }

  List<String> _activeFilterLabels(BuildContext context) {
    final labels = <String>[];
    final query = _search.text.trim();
    if (query.isNotEmpty) labels.add(query);
    if (_status != null) labels.add(_statusLabel(context, _status!));
    if (_staffId != null) {
      labels.add(_staffLabel ?? context.l10n.text('staff'));
    }
    return labels;
  }

  @override
  void initState() {
    super.initState();
    _page = PagedLoadController<TransferRecord>(
      loadPage: ({required after, required offset}) => ref
          .read(transferRepositoryProvider)
          .list(
            companyId: widget.company.id,
            status: _status,
            staffId: _staffId,
            query: _search.text,
            offset: offset,
          ),
    )..addListener(_pageChanged);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 260) _load();
    });
    _load(reset: true);
    _loadMembers();
  }

  void _pageChanged() {
    if (_selectedTransferId != null &&
        _page.items.every((item) => item.id != _selectedTransferId)) {
      _selectedTransferId = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _page.dispose();
    _search.dispose();
    _scroll.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false, bool preserveItems = false}) async {
    await _page.load(reset: reset, preserveItems: preserveItems);
  }

  @override
  Future<void> refreshAfterAppResume() async {
    await _load(reset: true, preserveItems: true);
    await _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (_membersLoading) return;
    setState(() => _membersLoading = true);
    try {
      final members = await ref
          .read(_transferAccessProvider)
          .members(widget.company.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _staffLabel = members
            .where((member) => member.userId == _staffId)
            .firstOrNull
            ?.displayName;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _returningTransferId == null && _damageBusyTransferId == null,
    child: RelayAdaptiveListDetail(
      listPane: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: RelaySearchField(
                    controller: _search,
                    hintText: context.l10n.text('searchTransfers'),
                    onChanged: (_) => _debouncer(() => _load(reset: true)),
                    onCleared: () => _load(reset: true),
                    clearTooltip: context.l10n.text('clear'),
                  ),
                ),
              ],
            ),
          ),
          LedgerActionStrip(
            alignment: WrapAlignment.end,
            children: [
              RelaySingleSelectMenuButton<TransferStatus?>(
                label: _status == null
                    ? context.l10n.text('status')
                    : _statusLabel(context, _status!),
                tooltip: context.l10n.text('status'),
                selectedValue: _status,
                active: _status != null,
                activeForegroundColor: _status == null
                    ? null
                    : _statusFilterColors(context, _status!).$1,
                activeBackgroundColor: _status == null
                    ? null
                    : _statusFilterColors(context, _status!).$2,
                activeBorderColor: _status == null
                    ? null
                    : _statusFilterColors(
                        context,
                        _status!,
                      ).$1.withValues(alpha: .42),
                options: [
                  RelayMenuOption<TransferStatus?>(
                    value: null,
                    label: context.l10n.text('all'),
                  ),
                  for (final value in const [
                    TransferStatus.prepare,
                    TransferStatus.inTransit,
                    TransferStatus.done,
                  ])
                    RelayMenuOption<TransferStatus?>(
                      value: value,
                      label: _statusLabel(context, value),
                      selectedForegroundColor: _statusFilterColors(
                        context,
                        value,
                      ).$1,
                      selectedBackgroundColor: _statusFilterColors(
                        context,
                        value,
                      ).$2,
                    ),
                ],
                onSelected: (choice) {
                  if (choice == _status) return;
                  setState(() => _status = choice);
                  _load(reset: true);
                },
              ),
              RelaySingleSelectMenuButton<String?>(
                label: _staffId == null
                    ? context.l10n.text('staff')
                    : (_staffLabel ?? context.l10n.text('staff')),
                tooltip: context.l10n.text('staff'),
                selectedValue: _staffId,
                active: _staffId != null,
                enabled: !_membersLoading,
                maxWidth: 220,
                options: [
                  RelayMenuOption<String?>(
                    value: null,
                    label: context.l10n.text('all'),
                  ),
                  for (final member in _members)
                    RelayMenuOption<String?>(
                      value: member.userId,
                      label: member.displayName,
                      subtitle: context.l10n.text(
                        member.isOwner ? 'owner' : 'staff',
                      ),
                    ),
                ],
                onSelected: (choice) {
                  if (choice == _staffId) return;
                  setState(() {
                    _staffId = choice;
                    _staffLabel = _members
                        .where((member) => member.userId == choice)
                        .firstOrNull
                        ?.displayName;
                  });
                  _load(reset: true);
                },
              ),
            ],
          ),
          RelayActiveFilterBar(
            labels: _activeFilterLabels(context),
            clearLabel: context.l10n.text('clearSearchFilters'),
            onClear: () {
              _search.clear();
              setState(() {
                _status = null;
                _staffId = null;
                _staffLabel = null;
              });
              _load(reset: true);
            },
          ),
          const Divider(height: 1),
          Expanded(child: _body(context)),
        ],
      ),
      detailPane:
          context.relayIsLargeProductivity && _selectedTransferId != null
          ? TransferDetailPage(
              key: ValueKey('transfer-detail-${_selectedTransferId!}'),
              company: widget.company,
              transferId: _selectedTransferId!,
              embedded: true,
              onChanged: () => _load(reset: true, preserveItems: true),
              onTransferFocusRequested: (transferId) {
                if (!mounted) return;
                setState(() => _selectedTransferId = transferId);
                _load(reset: true, preserveItems: true);
              },
            )
          : null,
      placeholder: LedgerScrollSafeCenter(
        key: const ValueKey('transfer-detail-placeholder'),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_outlined,
              size: 40,
              color: context.relay.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.text('transfer'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final hasActiveQuery =
        _search.text.trim().isNotEmpty || _status != null || _staffId != null;
    return PagedListBody<TransferRecord>(
      items: _items,
      loading: _loading,
      error: _error,
      hasMore: _hasMore,
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: relayListActionBottomPadding),
      onRefresh: () => _load(reset: true, preserveItems: true),
      onRetry: () => _load(reset: true),
      emptyBuilder: (_) => _TransferEmpty(
        filtered: hasActiveQuery,
        onCreate: hasActiveQuery
            ? null
            : () async {
                final saved = await Navigator.of(context).push<bool>(
                  relayRoute(
                    builder: (_) => TransferFormPage(company: widget.company),
                  ),
                );
                if (saved == true && mounted) _load(reset: true);
              },
        onClear: hasActiveQuery
            ? () {
                _search.clear();
                setState(() {
                  _status = null;
                  _staffId = null;
                  _staffLabel = null;
                });
                _load(reset: true);
              }
            : null,
      ),
      errorBuilder: (_) =>
          _Retry(message: _error!, retry: () => _load(reset: true)),
      loadMoreBuilder: (_, {required loading, required hasMore}) => SizedBox(
        height: 56,
        child: Center(
          child: loading && hasMore
              ? const CircularProgressIndicator()
              : const SizedBox(),
        ),
      ),
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, item) => TransferListRow(
        transfer: item,
        selected:
            context.relayIsLargeProductivity && item.id == _selectedTransferId,
        returnBusy: _returningTransferId == item.id,
        damageBusy: _damageBusyTransferId == item.id,
        onReturnEarly: item.isDone && !item.isReturn
            ? () => _startReturnFromList(item)
            : null,
        onDamageTap: item.hasVisibleDamageAlert
            ? () => _openDamageFromList(item)
            : null,
        onTap: () async {
          if (context.relayIsLargeProductivity) {
            setState(() => _selectedTransferId = item.id);
            return;
          }
          await Navigator.of(context).push(
            relayRoute(
              builder: (_) => TransferDetailPage(
                company: widget.company,
                transferId: item.id,
              ),
            ),
          );
          if (mounted) _load(reset: true, preserveItems: true);
        },
      ),
    );
  }

  Future<void> _openDamageFromList(TransferRecord summary) async {
    if (_damageBusyTransferId != null || _returningTransferId != null) return;
    setState(() => _damageBusyTransferId = summary.id);
    try {
      final transfer = await ref
          .read(transferRepositoryProvider)
          .detail(widget.company.id, summary.id);
      if (transfer == null || !mounted) return;
      final action = await _showDamageCaseSheet(
        context: context,
        transfer: transfer,
        isOwner: widget.company.isOwner,
      );
      if (action == null || !mounted) return;
      final repository = ref.read(transferRepositoryProvider);
      if (action == _DamageCaseAction.markFixed) {
        await repository.markDamageFixed(transfer.id);
      } else {
        await repository.clearDamageAlert(transfer.id);
      }
      if (mounted) await _load(reset: true, preserveItems: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.text('damageStatusUpdateFailed')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _damageBusyTransferId = null);
    }
  }

  Future<void> _startReturnFromList(TransferRecord transfer) async {
    if (_returningTransferId != null || _damageBusyTransferId != null) return;
    setState(() => _returningTransferId = transfer.id);
    final requestKeys = _returnRequestKeys.putIfAbsent(
      transfer.id,
      _FastReturnRequestKeys.new,
    );
    try {
      final result = await _createAndStartReturnNow(
        context: context,
        ref: ref,
        outbound: transfer,
        requestKeys: requestKeys,
      );
      _returnRequestKeys.remove(transfer.id);
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
      await Navigator.of(context).push(
        relayRoute(
          builder: (_) => TransferDetailPage(
            company: widget.company,
            transferId: result.returnId!,
          ),
        ),
      );
      if (mounted) _load(reset: true, preserveItems: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('returnCreateFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _returningTransferId = null);
    }
  }
}
