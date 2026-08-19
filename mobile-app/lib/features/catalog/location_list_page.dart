part of 'catalog_screens.dart';

class LocationListPage extends ConsumerStatefulWidget {
  const LocationListPage({
    required this.companyId,
    this.isOwner = false,
    super.key,
  });
  final String companyId;
  final bool isOwner;

  @override
  ConsumerState<LocationListPage> createState() => _LocationListPageState();
}

class _LocationListPageState extends ConsumerState<LocationListPage>
    with AppResumeRefreshMixin<LocationListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _debouncer = SearchDebouncer(const Duration(milliseconds: 300));
  late final PagedLoadController<LocationRecord> _page;
  LocationType? _type;
  var _archiveScope = ArchiveScope.working;
  late final SelectionController<String> _selection;
  var _lifecycleBusy = false;
  String? _selectedLocationId;

  bool get _selecting => _selection.selecting;
  Set<String> get _selectedIds => _selection.selectedIds;

  List<LocationRecord> get _items => _page.items;
  bool get _loading => _page.loading;
  bool get _hasMore => _page.hasMore;
  String? get _error =>
      _page.error == null ? null : context.l10n.text('couldNotLoad');
  LocationRecord? get _selectedLocation {
    final selectedId = _selectedLocationId;
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
                CompanyListScopeKey.location,
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
    _page = PagedLoadController<LocationRecord>(
      loadPage: ({required after, required offset}) => ref
          .read(catalogRepositoryProvider)
          .locations(
            companyId: widget.companyId,
            query: _search.text,
            type: _type,
            archiveScope: _archiveScope,
            after: after,
          ),
    )..addListener(_pageChanged);
    _scroll.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  void _pageChanged() {
    _selection.clearMissing(_page.items.map((item) => item.id));
    if (_selectedLocationId != null &&
        _page.items.every((item) => item.id != _selectedLocationId)) {
      _selectedLocationId = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ref
            .read(
              companyListArchiveScopeProvider(
                CompanyListScopeKey.location,
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
        entityType: LifecycleEntityType.location,
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
      debugPrint('location lifecycle failed: ${RelayFailure.from(error).kind}');
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

  Future<void> _openForm([LocationRecord? item]) async {
    final saved = await Navigator.of(context).push<LocationRecord>(
      relayRoute(
        builder: (_) =>
            LocationFormPage(companyId: widget.companyId, existing: item),
      ),
    );
    if (saved == null || !mounted) return;
    if (item != null) {
      _load(reset: true, preserveItems: true);
      if (context.relayIsLargeProductivity) {
        setState(() => _selectedLocationId = saved.id);
      }
      return;
    }
    if (context.relayIsLargeProductivity) {
      setState(() => _selectedLocationId = saved.id);
      await _load(reset: true, preserveItems: true);
      return;
    }
    await Navigator.of(context).push(
      relayRoute(
        builder: (_) => LocationDetailPage(
          companyId: widget.companyId,
          locationId: saved.id,
          initial: saved,
          isOwner: widget.isOwner,
        ),
      ),
    );
    if (mounted) _load(reset: true, preserveItems: true);
  }

  Widget _typeControl(BuildContext context) =>
      RelaySingleSelectMenuButton<LocationType?>(
        label: switch (_type) {
          null => context.l10n.text('all'),
          LocationType.warehouse => context.l10n.text('warehouse'),
          LocationType.deliveryPlace => context.l10n.text('deliveryPlace'),
        },
        tooltip: context.l10n.text('type'),
        selectedValue: _type,
        active: _type != null,
        options: [
          RelayMenuOption<LocationType?>(
            value: null,
            label: context.l10n.text('all'),
          ),
          RelayMenuOption<LocationType?>(
            value: LocationType.warehouse,
            label: context.l10n.text('warehouse'),
          ),
          RelayMenuOption<LocationType?>(
            value: LocationType.deliveryPlace,
            label: context.l10n.text('deliveryPlace'),
          ),
        ],
        onSelected: (type) {
          if (type == _type) return;
          setState(() => _type = type);
          _load(reset: true);
        },
      );

  @override
  Widget build(BuildContext context) => RelayAdaptiveListDetail(
    listPane: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: RelaySearchField(
            controller: _search,
            hintText: context.l10n.text('searchLocations'),
            onChanged: (_) => _debouncer(() => _load(reset: true)),
            onCleared: () => _load(reset: true),
            clearTooltip: context.l10n.text('clear'),
          ),
        ),
        RelayListControlRow(
          children: [
            if (!_selecting) _scopeControl(context),
            _typeControl(context),
          ],
        ),
        if (_selecting)
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
                  tooltip: context.l10n.text('archiveLocation'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.archive),
                  icon: const Icon(Icons.archive_outlined),
                )
              else ...[
                IconButton(
                  tooltip: context.l10n.text('restoreLocation'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.restore),
                  icon: const Icon(Icons.unarchive_outlined),
                ),
                IconButton(
                  tooltip: context.l10n.text('deleteLocation'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.delete),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        Expanded(child: _body(context)),
      ],
    ),
    detailPane: context.relayIsLargeProductivity && _selectedLocation != null
        ? LocationDetailPage(
            key: ValueKey('location-detail-${_selectedLocationId!}'),
            companyId: widget.companyId,
            locationId: _selectedLocationId!,
            initial: _selectedLocation!,
            isOwner: widget.isOwner,
            embedded: true,
            onChanged: () => _load(reset: true, preserveItems: true),
            onCloseRequested: () {
              if (!mounted) return;
              setState(() => _selectedLocationId = null);
              _load(reset: true, preserveItems: true);
            },
          )
        : null,
    placeholder: LedgerScrollSafeCenter(
      key: const ValueKey('location-detail-placeholder'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 40,
            color: context.relay.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.text('locationDetails'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
  );

  Widget _body(BuildContext context) {
    return PagedListBody<LocationRecord>(
      items: _items,
      loading: _loading,
      error: _error,
      hasMore: _hasMore,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        relayListActionBottomPadding,
      ),
      onRefresh: () => _load(reset: true, preserveItems: true),
      onRetry: () => _load(reset: true),
      emptyBuilder: (context) => _EmptyState(
        title: context.l10n.text(
          _archiveScope == ArchiveScope.archived
              ? 'noArchivedLocations'
              : 'noLocations',
        ),
        action: context.l10n.text('addLocation'),
        icon: Icons.warehouse_outlined,
        onAction: _archiveScope == ArchiveScope.archived
            ? null
            : () => _openForm(),
      ),
      errorBuilder: (_) =>
          _RetryState(message: _error!, onRetry: () => _load(reset: true)),
      loadMoreBuilder: (_, {required loading, required hasMore}) =>
          _MoreIndicator(show: loading, hasMore: hasMore),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, item) => LedgerRow(
        selected:
            context.relayIsLargeProductivity && item.id == _selectedLocationId,
        leading: _selecting
            ? LifecycleSelectionMark(selected: _selection.contains(item.id))
            : Icon(
                item.type == LocationType.warehouse
                    ? Icons.warehouse_outlined
                    : Icons.place_outlined,
              ),
        title: item.name,
        subtitle: item.type == LocationType.warehouse
            ? context.l10n.text('warehouse')
            : context.l10n.text('deliveryPlace'),
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
            setState(() => _selectedLocationId = item.id);
            return;
          }
          await Navigator.of(context).push(
            relayRoute(
              builder: (_) => LocationDetailPage(
                companyId: widget.companyId,
                locationId: item.id,
                initial: item,
                isOwner: widget.isOwner,
              ),
            ),
          );
          if (mounted) _load(reset: true, preserveItems: true);
        },
      ),
    );
  }
}
