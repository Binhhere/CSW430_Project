part of 'access_flow.dart';

const _navSelectionDuration = Duration(milliseconds: 220);

class CompanyShell extends ConsumerStatefulWidget {
  const CompanyShell({required this.company, super.key});
  final RelayCompany company;
  @override
  ConsumerState<CompanyShell> createState() => _CompanyShellState();
}

class _CompanyShellState extends ConsumerState<CompanyShell>
    with AppResumeRefreshMixin<CompanyShell> {
  var _index = 0;
  var _contentVersion = 0;
  var _coverRetryBusy = false;
  static const _settingsIndex = 4;
  static const _destinations = [
    ('transfer', Icons.swap_horiz_outlined),
    ('customer', Icons.people_outline),
    ('location', Icons.warehouse_outlined),
    ('asset', Icons.inventory_2_outlined),
    ('settings', Icons.settings_outlined),
  ];

  @override
  void didUpdateWidget(covariant CompanyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.company.id != widget.company.id) {
      _index = 0;
      _contentVersion = 0;
    }
  }

  @override
  Future<void> refreshAfterAppResume() async {
    ref.invalidate(accessCompaniesProvider);
    try {
      await ref.read(accessCompaniesProvider.future);
    } catch (_) {
      // CompanyGate keeps the last confirmed memberships visible on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerScope = ref.watch(
      companyListArchiveScopeProvider(CompanyListScopeKey.customer),
    );
    final locationScope = ref.watch(
      companyListArchiveScopeProvider(CompanyListScopeKey.location),
    );
    final assetScope = ref.watch(
      companyListArchiveScopeProvider(CompanyListScopeKey.asset),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowSize = RelayAdaptiveSize.fromWidth(constraints.maxWidth);
        final usesRail = windowSize != RelayWindowSize.compact;
        final content = switch (_index) {
          1 => CustomerListPage(
            key: companyContentKey(
              'customers',
              widget.company.id,
              _contentVersion,
            ),
            companyId: widget.company.id,
            isOwner: widget.company.isOwner,
          ),
          2 => LocationListPage(
            key: companyContentKey(
              'locations',
              widget.company.id,
              _contentVersion,
            ),
            companyId: widget.company.id,
            isOwner: widget.company.isOwner,
          ),
          3 => AssetListPage(
            key: companyContentKey(
              'assets',
              widget.company.id,
              _contentVersion,
            ),
            companyId: widget.company.id,
            isOwner: widget.company.isOwner,
          ),
          _settingsIndex => AccountPage(
            key: companyContentKey(
              'settings',
              widget.company.id,
              _contentVersion,
            ),
            embedded: true,
            embeddedSurfaceSafeArea: usesRail,
          ),
          _ => TransferListPage(
            key: companyContentKey(
              'transfers',
              widget.company.id,
              _contentVersion,
            ),
            company: widget.company,
          ),
        };
        final isSettings = _index == _settingsIndex;
        final createLabel = _createLabel(
          context,
          customerScope: customerScope,
          locationScope: locationScope,
          assetScope: assetScope,
        );
        final isList = !isSettings;
        final shellContent = isList
            ? SafeArea(top: true, bottom: false, child: content)
            : content;
        final actionItems = isList
            ? [
                _CompanyListAction(
                  label: createLabel ?? _newLabel(context),
                  icon: Icons.add,
                  color: context.relay.actionPrimary,
                  onPressed: createLabel == null ? null : _createForDestination,
                ),
                _CompanyListAction(
                  label: context.l10n.text('importAssets'),
                  icon: Icons.file_upload_outlined,
                  color: context.relay.info,
                  onPressed:
                      widget.company.isOwner &&
                          assetScope == ArchiveScope.working
                      ? _importAssets
                      : null,
                ),
                _CompanyListAction(
                  label: context.l10n.text('scanAssetQr'),
                  icon: Icons.qr_code_scanner,
                  color: context.relay.success,
                  onPressed: _scanAssets,
                ),
              ]
            : const <_CompanyListAction>[];
        return Scaffold(
          body: usesRail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompanyNavigationRail(
                      destinations: _destinations,
                      selectedIndex: _index,
                      onDestinationSelected: _selectDestination,
                      respectTopSafeArea: true,
                      respectBottomSafeArea: true,
                    ),
                    Expanded(child: shellContent),
                  ],
                )
              : shellContent,
          bottomNavigationBar: usesRail
              ? null
              : _LedgerBottomNavigation(
                  destinations: _destinations,
                  selectedIndex: _index,
                  onSelected: (value) => setState(() => _index = value),
                ),
          floatingActionButton: isList
              ? _CompanyListActionMenu(
                  key: ValueKey('list-actions-$_index'),
                  actions: actionItems,
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  String? _createLabel(
    BuildContext context, {
    required ArchiveScope customerScope,
    required ArchiveScope locationScope,
    required ArchiveScope assetScope,
  }) => switch (_index) {
    0 => context.l10n.text('newTransfer'),
    1 =>
      customerScope == ArchiveScope.archived
          ? null
          : context.l10n.text('newCustomer'),
    2 =>
      locationScope == ArchiveScope.archived
          ? null
          : context.l10n.text('newLocation'),
    3 =>
      assetScope == ArchiveScope.archived
          ? null
          : context.l10n.text('addAsset'),
    _ => null,
  };

  String _newLabel(BuildContext context) => switch (_index) {
    0 => context.l10n.text('newTransfer'),
    1 => context.l10n.text('newCustomer'),
    2 => context.l10n.text('newLocation'),
    3 => context.l10n.text('addAsset'),
    _ => context.l10n.text('newTransfer'),
  };

  void _selectDestination(int value) {
    if (value == _index) return;
    setState(() => _index = value);
  }

  Future<void> _createForDestination() async {
    if (_index == 3) {
      final result = await Navigator.of(context).push<AssetSaveWorkflowResult>(
        relayRoute(builder: (_) => AssetFormPage(companyId: widget.company.id)),
      );
      if (result == null || !mounted) return;

      if (!result.assetSaved) return;
      final retryController = createAssetCoverRetryController(
        result: result,
        repository: ref.read(assetCatalogRepositoryProvider),
      );
      _showAssetSaveResult(result, retryController);
      if (!mounted) return;
      setState(() => _contentVersion++);

      if (result.mergedKeepingExistingCover) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('bulkMergePhotoKept'))),
        );
      }
      final asset = result.asset;
      if (asset == null) return;
      if (context.relayIsLargeProductivity) {
        if (mounted) setState(() => _contentVersion++);
        return;
      }
      await Navigator.of(context).push(
        relayRoute(
          builder: (_) => AssetDetailPage(
            companyId: widget.company.id,
            assetId: asset.id,
            initial: asset,
            isOwner: widget.company.isOwner,
          ),
        ),
      );
      if (mounted) setState(() => _contentVersion++);
      return;
    }

    if (_index == 0) {
      final saved = await Navigator.of(context).push<bool>(
        relayRoute(builder: (_) => TransferFormPage(company: widget.company)),
      );
      if (saved == true && mounted) setState(() => _contentVersion++);
      return;
    }

    if (_index == 1) {
      final customer = await Navigator.of(context).push<CustomerRecord>(
        relayRoute(
          builder: (_) => CustomerFormPage(companyId: widget.company.id),
        ),
      );
      if (customer == null || !mounted) return;
      setState(() => _contentVersion++);
      if (context.relayIsLargeProductivity) {
        if (mounted) setState(() => _contentVersion++);
        return;
      }
      await Navigator.of(context).push(
        relayRoute(
          builder: (_) => CustomerDetailPage(
            companyId: widget.company.id,
            customerId: customer.id,
            initial: customer,
            isOwner: widget.company.isOwner,
          ),
        ),
      );
      if (mounted) setState(() => _contentVersion++);
      return;
    }

    final location = await Navigator.of(context).push<LocationRecord>(
      relayRoute(
        builder: (_) => LocationFormPage(companyId: widget.company.id),
      ),
    );
    if (location == null || !mounted) return;
    setState(() => _contentVersion++);
    if (context.relayIsLargeProductivity) {
      if (mounted) setState(() => _contentVersion++);
      return;
    }
    await Navigator.of(context).push(
      relayRoute(
        builder: (_) => LocationDetailPage(
          companyId: widget.company.id,
          locationId: location.id,
          initial: location,
          isOwner: widget.company.isOwner,
        ),
      ),
    );
    if (mounted) setState(() => _contentVersion++);
  }

  Future<void> _importAssets() async {
    if (!widget.company.isOwner) return;
    final assetScope = ref.read(
      companyListArchiveScopeProvider(CompanyListScopeKey.asset),
    );
    if (assetScope == ArchiveScope.archived) return;
    final imported = await Navigator.of(context).push<bool>(
      relayRoute(builder: (_) => AssetImportPage(companyId: widget.company.id)),
    );
    if (imported == true && mounted) setState(() => _contentVersion++);
  }

  Future<void> _scanAssets() async {
    final asset = await Navigator.of(context).push<AssetRecord>(
      relayRoute(builder: (_) => AssetQrScanPage(companyId: widget.company.id)),
    );
    if (asset == null || !mounted) return;
    await Navigator.of(context).push<void>(
      relayRoute(
        builder: (_) => AssetDetailPage(
          companyId: widget.company.id,
          assetId: asset.id,
          initial: asset,
          isOwner: widget.company.isOwner,
        ),
      ),
    );
    if (mounted) setState(() => _contentVersion++);
  }

  void _showAssetSaveResult(
    AssetSaveWorkflowResult result,
    AssetCoverRetryController? retryController,
  ) {
    if (result.hasRefreshFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('assetRefreshFailedStale'))),
      );
    }
    if (!result.hasCoverFailure) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.text('assetSavedCoverFailed')),
        action: retryController == null
            ? null
            : SnackBarAction(
                label: context.l10n.text('retry'),
                onPressed: () => _retryAssetCover(retryController),
              ),
      ),
    );
  }

  Future<void> _retryAssetCover(AssetCoverRetryController controller) async {
    if (!mounted || _coverRetryBusy) return;
    setState(() => _coverRetryBusy = true);
    try {
      final retried = await controller.retry();
      if (!mounted) return;
      setState(() => _contentVersion++);
      _showAssetSaveResult(retried, controller);
    } finally {
      if (mounted) setState(() => _coverRetryBusy = false);
    }
  }
}
