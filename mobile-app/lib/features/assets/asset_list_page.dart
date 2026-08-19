part of 'asset_screens.dart';

class AssetListPage extends ConsumerStatefulWidget {
  const AssetListPage({
    required this.companyId,
    required this.isOwner,
    super.key,
  });
  final String companyId;
  final bool isOwner;

  @override
  ConsumerState<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends ConsumerState<AssetListPage>
    with AppResumeRefreshMixin<AssetListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _debouncer = SearchDebouncer(const Duration(milliseconds: 300));
  late final PagedLoadController<AssetRecord> _page;
  AssetMode? _mode;
  var _archiveScope = ArchiveScope.working;
  late final SelectionController<String> _selection;
  var _lifecycleBusy = false;
  String? _selectedAssetId;

  bool get _selecting => _selection.selecting;
  Set<String> get _selectedIds => _selection.selectedIds;

  List<AssetRecord> get _items => _page.items;
  bool get _loading => _page.loading;
  bool get _hasMore => _page.hasMore;
  String? get _error =>
      _page.error == null ? null : context.l10n.text('couldNotLoad');
  AssetRecord? get _selectedAsset {
    final selectedId = _selectedAssetId;
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
                CompanyListScopeKey.asset,
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
    _page = PagedLoadController<AssetRecord>(
      loadPage: ({required after, required offset}) => ref
          .read(assetCatalogRepositoryProvider)
          .assets(
            companyId: widget.companyId,
            query: _search.text,
            mode: _mode,
            archiveScope: _archiveScope,
            after: after,
          ),
    )..addListener(_pageChanged);
    _scroll.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  void _pageChanged() {
    _selection.clearMissing(_page.items.map((item) => item.id));
    if (_selectedAssetId != null &&
        _page.items.every((item) => item.id != _selectedAssetId)) {
      _selectedAssetId = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ref
        .read(
          companyListArchiveScopeProvider(CompanyListScopeKey.asset).notifier,
        )
        .state = ArchiveScope
        .working;
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
      final applied = await executeAssetLifecycle(
        context: context,
        ref: ref,
        selectedIds: _selectedIds.toList(),
        operation: operation,
      );
      if (applied == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n
                .text('lifecycleAppliedCount')
                .replaceAll('{applied}', '$applied'),
          ),
        ),
      );
      _cancelSelection();
      await _load(reset: true, preserveItems: true);
    } catch (error, stackTrace) {
      debugPrint('asset lifecycle failed: ${RelayFailure.from(error).kind}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('couldNotSave'))),
        );
      }
    } finally {
      if (mounted) setState(() => _lifecycleBusy = false);
    }
  }

  Future<void> _openDetail(AssetRecord item) async {
    if (context.relayIsLargeProductivity && !_selecting) {
      setState(() => _selectedAssetId = item.id);
      return;
    }
    await Navigator.of(context).push<void>(
      relayRoute(
        builder: (_) => AssetDetailPage(
          companyId: widget.companyId,
          assetId: item.id,
          initial: item,
          isOwner: widget.isOwner,
        ),
      ),
    );
    if (mounted) await _load(reset: true, preserveItems: true);
  }

  Widget _scopeControl(BuildContext context) =>
      RelaySegmentedControl<ArchiveScope>(
        tooltip: context.l10n.text('workingState'),
        selectedValue: _archiveScope,
        options: [
          RelaySegmentedOption<ArchiveScope>(
            value: ArchiveScope.working,
            label: context.l10n.text('workingAssets'),
            selectedForegroundColor: context.relay.success,
            selectedBackgroundColor: context.relay.successContainer,
          ),
          RelaySegmentedOption<ArchiveScope>(
            value: ArchiveScope.archived,
            label: context.l10n.text('archivedAssets'),
            selectedForegroundColor: context.relay.warning,
            selectedBackgroundColor: context.relay.warningContainer,
          ),
        ],
        onSelected: _setArchiveScope,
      );

  Widget _modeControl(BuildContext context) =>
      RelaySingleSelectMenuButton<AssetMode?>(
        label: switch (_mode) {
          null => context.l10n.text('type'),
          AssetMode.serialized => context.l10n.text('serialized'),
          AssetMode.bulk => context.l10n.text('bulk'),
        },
        tooltip: context.l10n.text('mode'),
        selectedValue: _mode,
        active: _mode != null,
        options: [
          RelayMenuOption<AssetMode?>(
            value: null,
            label: context.l10n.text('all'),
          ),
          RelayMenuOption<AssetMode?>(
            value: AssetMode.serialized,
            label: context.l10n.text('serialized'),
          ),
          RelayMenuOption<AssetMode?>(
            value: AssetMode.bulk,
            label: context.l10n.text('bulk'),
          ),
        ],
        onSelected: (mode) {
          if (mode == _mode) return;
          setState(() => _mode = mode);
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
            hintText: context.l10n.text('searchAssets'),
            onChanged: (_) => _debouncer(() => _load(reset: true)),
            onCleared: () => _load(reset: true),
            clearTooltip: context.l10n.text('clear'),
          ),
        ),
        RelayListControlRow(
          children: [
            if (!_selecting) _scopeControl(context),
            _modeControl(context),
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
                  tooltip: context.l10n.text('archiveAsset'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.archive),
                  icon: const Icon(Icons.archive_outlined),
                )
              else ...[
                IconButton(
                  tooltip: context.l10n.text('restoreAsset'),
                  onPressed: _lifecycleBusy || _selectedIds.isEmpty
                      ? null
                      : () => _runLifecycle(LifecycleOperation.restore),
                  icon: const Icon(Icons.unarchive_outlined),
                ),
                IconButton(
                  tooltip: context.l10n.text('deleteAsset'),
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
    detailPane: context.relayIsLargeProductivity && _selectedAsset != null
        ? AssetDetailPage(
            key: ValueKey('asset-detail-${_selectedAssetId!}'),
            companyId: widget.companyId,
            assetId: _selectedAssetId!,
            initial: _selectedAsset!,
            isOwner: widget.isOwner,
            embedded: true,
            onChanged: () => _load(reset: true, preserveItems: true),
            onCloseRequested: () {
              if (!mounted) return;
              setState(() => _selectedAssetId = null);
              _load(reset: true, preserveItems: true);
            },
          )
        : null,
    placeholder: LedgerScrollSafeCenter(
      key: const ValueKey('asset-detail-placeholder'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: context.relay.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.text('assetDetails'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
  );

  Widget _body(BuildContext context) {
    return PagedListBody<AssetRecord>(
      items: _items,
      loading: _loading,
      error: _error,
      hasMore: _hasMore,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        relayListActionBottomPadding,
      ),
      onRefresh: () => _load(reset: true, preserveItems: true),
      onRetry: () => _load(reset: true),
      emptyBuilder: (_) =>
          _AssetEmpty(archived: _archiveScope == ArchiveScope.archived),
      errorBuilder: (_) =>
          _AssetRetry(message: _error!, onRetry: () => _load(reset: true)),
      loadMoreBuilder: (_, {required loading, required hasMore}) =>
          _AssetMore(show: loading, hasMore: hasMore),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, item) => LedgerRow(
        selected:
            context.relayIsLargeProductivity && item.id == _selectedAssetId,
        leading: _selecting
            ? LifecycleSelectionMark(selected: _selection.contains(item.id))
            : _AssetThumb(storagePath: item.storagePath),
        title: item.name,
        subtitle:
            '${item.isSerialized ? item.serialNumber : '${item.quantity} ${context.l10n.text('units')}'}\n${item.locationName} · ${_stateLabel(context, item)}',
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
        onTap: () {
          if (_selecting) {
            _toggleSelection(item.id);
            return;
          }
          _openDetail(item);
        },
      ),
    );
  }
}
