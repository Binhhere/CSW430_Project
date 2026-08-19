part of 'catalog_screens.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({
    required this.companyId,
    this.isOwner = false,
    super.key,
  });
  final String companyId;
  final bool isOwner;

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage>
    with AppResumeRefreshMixin<CustomerListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _debouncer = SearchDebouncer(const Duration(milliseconds: 300));
  late final PagedLoadController<CustomerRecord> _page;
  var _archiveScope = ArchiveScope.working;
  late final SelectionController<String> _selection;
  var _lifecycleBusy = false;
  String? _selectedCustomerId;

  bool get _selecting => _selection.selecting;
  Set<String> get _selectedIds => _selection.selectedIds;

  List<CustomerRecord> get _items => _page.items;
  bool get _loading => _page.loading;
  bool get _hasMore => _page.hasMore;
  String? get _error =>
      _page.error == null ? null : context.l10n.text('couldNotLoad');
  CustomerRecord? get _selectedCustomer {
    final selectedId = _selectedCustomerId;
    if (selectedId == null) return null;
    for (final item in _items) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  void _syncArchiveScope() {
    ref
            .read(
              companyListArchiveScopeProvider(
                CompanyListScopeKey.customer,
              ).notifier,
            )
            .state =
        _archiveScope;
  }

  void _setArchiveScope(ArchiveScope scope) {
    if (scope == _archiveScope) return;
    _cancelSelection();
    setState(() => _archiveScope = scope);
    _syncArchiveScope();
    _load(reset: true);
  }

  @override
  void initState() {
    super.initState();
    _syncArchiveScope();
    _selection = SelectionController<String>()..addListener(_pageChanged);
    _page = PagedLoadController<CustomerRecord>(
      loadPage: ({required after, required offset}) => ref
          .read(catalogRepositoryProvider)
          .customers(
            companyId: widget.companyId,
            query: _search.text,
            archiveScope: _archiveScope,
            after: after,
          ),
    )..addListener(_pageChanged);
    _scroll.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  void _pageChanged() {
    _selection.clearMissing(_page.items.map((item) => item.id));
    if (_selectedCustomerId != null &&
        _page.items.every((item) => item.id != _selectedCustomerId)) {
      _selectedCustomerId = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ref
            .read(
              companyListArchiveScopeProvider(
                CompanyListScopeKey.customer,
              ).notifier,
            )
            .state =
        ArchiveScope.working;
    _selection.dispose();
    _page.dispose();
    _search.dispose();
    _scroll.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < 240) _load();
  }

  Future<void> _load({bool reset = false, bool preserveItems = false}) async {
    await _page.load(reset: reset, preserveItems: preserveItems);
  }

  @override
  Future<void> refreshAfterAppResume() =>
      _load(reset: true, preserveItems: true);

  void _startSelection(String id) {
    if (!widget.isOwner) return;
    _selection.start(id);
  }

  void _toggleSelection(String id) => _selection.toggle(id);

  void _cancelSelection() => _selection.cancel();

  Future<void> _runLifecycle(LifecycleOperation operation) async {
    if (_lifecycleBusy || _selectedIds.isEmpty) return;
    setState(() => _lifecycleBusy = true);
    try {
      final applied = await executeCatalogLifecycle(
        context: context,
        ref: ref,
        entityType: LifecycleEntityType.customer,
        selectedIds: _selectedIds.toList(),
        operation: operation,
      );
      if (applied == null || !mounted) return;
      showCatalogLifecycleSnackBar(
        context,
        context.l10n
            .text('lifecycleAppliedCount')
            .replaceAll('{applied}', '$applied'),
      );
      _cancelSelection();
      await _load(reset: true, preserveItems: true);
    } catch (error, stackTrace) {
      debugPrint('customer lifecycle failed: ${RelayFailure.from(error).kind}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        showCatalogLifecycleSnackBar(
          context,
          context.l10n.text('couldNotSave'),
        );
      }
    } finally {
      if (mounted) setState(() => _lifecycleBusy = false);
    }
  }

  Widget _scopeControl(BuildContext context) =>
      RelaySegmentedControl<ArchiveScope>(
        tooltip: context.l10n.text('workingState'),
        selectedValue: _archiveScope,
        options: [
          RelaySegmentedOption<ArchiveScope>(
            value: ArchiveScope.working,
            label: context.l10n.text('workingRecords'),
            selectedForegroundColor: context.relay.success,
            selectedBackgroundColor: context.relay.successContainer,
          ),
          RelaySegmentedOption<ArchiveScope>(
            value: ArchiveScope.archived,
            label: context.l10n.text('archivedRecords'),
            selectedForegroundColor: context.relay.warning,
            selectedBackgroundColor: context.relay.warningContainer,
          ),
        ],
        onSelected: (scope) {
          _setArchiveScope(scope);
        },
      );

  Future<void> _openForm([CustomerRecord? item]) async {
    final saved = await Navigator.of(context).push<CustomerRecord>(
      relayRoute(
        builder: (_) =>
            CustomerFormPage(companyId: widget.companyId, existing: item),
      ),
    );
    if (saved == null || !mounted) return;
    if (item != null) {
      _load(reset: true, preserveItems: true);
      if (context.relayIsLargeProductivity) {
        setState(() => _selectedCustomerId = saved.id);
      }
      return;
    }
    if (context.relayIsLargeProductivity) {
      setState(() => _selectedCustomerId = saved.id);
      await _load(reset: true, preserveItems: true);
      return;
    }
    await Navigator.of(context).push(
      relayRoute(
        builder: (_) => CustomerDetailPage(
          companyId: widget.companyId,
          customerId: saved.id,
          initial: saved,
          isOwner: widget.isOwner,
        ),
      ),
    );
    if (mounted) _load(reset: true, preserveItems: true);
  }

  @override
  Widget build(BuildContext context) => RelayAdaptiveListDetail(
    listPane: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: RelaySearchField(
            controller: _search,
            hintText: context.l10n.text('searchCustomers'),
            onChanged: (_) => _debouncer(() => _load(reset: true)),
            onCleared: () => _load(reset: true),
            clearTooltip: context.l10n.text('clear'),
          ),
        ),
        if (widget.isOwner && !_selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [_scopeControl(context)]),
          )
        else if (_selecting)
          LifecycleSelectionBar(
            selectedCount: _selectedIds.length,
            selectedLabel: context.l10n
                .text('selectedCount')
                .replaceAll('{count}', '${_selectedIds.length}'),
            cancelLabel: context.l10n.text('cancelSelection'),
            onCancel: _cancelSelection,
            actions: [
              if (_archiveScope == ArchiveScope.working)
                IconButton(
                  tooltip: context.l10n.text('archiveCustomer'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.archive),
                  icon: const Icon(Icons.archive_outlined),
                )
              else ...[
                IconButton(
                  tooltip: context.l10n.text('restoreCustomer'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.restore),
                  icon: const Icon(Icons.unarchive_outlined),
                ),
                IconButton(
                  tooltip: context.l10n.text('deleteCustomer'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.delete),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _scopeControl(context),
          ),
        Expanded(child: _body(context)),
      ],
    ),
    detailPane: context.relayIsLargeProductivity && _selectedCustomer != null
        ? CustomerDetailPage(
            key: ValueKey('customer-detail-${_selectedCustomerId!}'),
            companyId: widget.companyId,
            customerId: _selectedCustomerId!,
            initial: _selectedCustomer!,
            isOwner: widget.isOwner,
            embedded: true,
            onChanged: () => _load(reset: true, preserveItems: true),
            onCloseRequested: () {
              if (!mounted) return;
              setState(() => _selectedCustomerId = null);
              _load(reset: true, preserveItems: true);
            },
          )
        : null,
    placeholder: LedgerScrollSafeCenter(
      key: const ValueKey('customer-detail-placeholder'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 40, color: context.relay.textMuted),
          const SizedBox(height: 12),
          Text(
            context.l10n.text('customerDetails'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
  );

  Widget _body(BuildContext context) {
    return PagedListBody<CustomerRecord>(
      items: _items,
      loading: _loading,
      error: _error,
      hasMore: _hasMore,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        relayListActionBottomPadding,
      ),
      onRefresh: () => _load(reset: true, preserveItems: true),
      onRetry: () => _load(reset: true),
      emptyBuilder: (context) => _EmptyState(
        title: context.l10n.text(
          _archiveScope == ArchiveScope.archived
              ? 'noArchivedCustomers'
              : 'noCustomers',
        ),
        action: context.l10n.text('addCustomer'),
        icon: Icons.people_outline,
        onAction: _archiveScope == ArchiveScope.archived
            ? null
            : () => _openForm(),
      ),
      errorBuilder: (_) =>
          _RetryState(message: _error!, onRetry: () => _load(reset: true)),
      loadMoreBuilder: (_, {required loading, required hasMore}) =>
          _MoreIndicator(show: loading, hasMore: hasMore),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, item) {
        final detail = [
          if (item.phone?.isNotEmpty == true) item.phone!,
          if (item.contactName?.isNotEmpty == true) item.contactName!,
        ].join(' · ');
        return LedgerRow(
          selected:
              context.relayIsLargeProductivity &&
              item.id == _selectedCustomerId,
          leading: _selecting
              ? LifecycleSelectionMark(selected: _selection.contains(item.id))
              : const Icon(Icons.person_outline),
          title: item.name,
          subtitle: detail.isEmpty
              ? '${item.activeTransferCount} ${context.l10n.text('activeTransfers')}'
              : '$detail\n${item.activeTransferCount} ${context.l10n.text('activeTransfers')}',
          trailing: _archiveScope == ArchiveScope.archived
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 18,
                      color: context.relay.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                )
              : const Icon(Icons.chevron_right),
          onLongPress: widget.isOwner ? () => _startSelection(item.id) : null,
          onTap: () async {
            if (_selecting) {
              _toggleSelection(item.id);
              return;
            }
            if (context.relayIsLargeProductivity) {
              setState(() => _selectedCustomerId = item.id);
              return;
            }
            await Navigator.of(context).push(
              relayRoute(
                builder: (_) => CustomerDetailPage(
                  companyId: widget.companyId,
                  customerId: item.id,
                  initial: item,
                  isOwner: widget.isOwner,
                ),
              ),
            );
            if (mounted) _load(reset: true, preserveItems: true);
          },
        );
      },
    );
  }
}
