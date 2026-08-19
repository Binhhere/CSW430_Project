part of 'asset_screens.dart';

class AssetDetailPage extends ConsumerStatefulWidget {
  const AssetDetailPage({
    required this.companyId,
    required this.assetId,
    required this.initial,
    required this.isOwner,
    this.embedded = false,
    this.onCloseRequested,
    this.onChanged,
    super.key,
  });
  final String companyId;
  final String assetId;
  final AssetRecord initial;
  final bool isOwner;
  final bool embedded;
  final VoidCallback? onCloseRequested;
  final VoidCallback? onChanged;

  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage>
    with AppResumeRefreshMixin<AssetDetailPage> {
  final _requests = LatestRequestGate();
  final _refreshRequests = LatestRequestGate();
  late Future<AssetRecord?> _asset = _load();
  late AssetRecord? _current = widget.initial;
  var _busy = false;
  String? _actionError;

  Future<AssetRecord?> _load() async {
    final request = _requests.begin();
    final item = await ref
        .read(assetCatalogRepositoryProvider)
        .asset(widget.companyId, widget.assetId);
    if (item == null || !mounted || !_requests.isCurrent(request)) return item;
    _current = item;
    return item;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final refreshRequest = _refreshRequests.begin();
    final future = _load();
    setState(() {
      _actionError = null;
      _asset = future;
    });
    try {
      await future;
    } catch (error) {
      if (mounted &&
          _refreshRequests.isCurrent(refreshRequest) &&
          identical(_asset, future)) {
        setState(
          () => _actionError = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('assetRefreshFailedStale'),
          ),
        );
      }
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    final result = await Navigator.of(context).push<AssetSaveWorkflowResult>(
      relayRoute(
        builder: (_) => AssetFormPage(
          companyId: widget.companyId,
          existing: _current ?? widget.initial,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (!result.assetSaved) return;
    final retryController = createAssetCoverRetryController(
      result: result,
      repository: ref.read(assetCatalogRepositoryProvider),
    );
    _showAssetSaveResult(result, retryController);
    if (result.mergedKeepingExistingCover) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('bulkMergePhotoKept'))),
      );
    }
    _requests.invalidate();
    _refreshRequests.invalidate();
    final updated = result.asset;
    if (updated != null) {
      _current = updated;
      setState(() => _asset = Future.value(updated));
    }
    widget.onChanged?.call();
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
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final retried = await controller.retry();
      if (!mounted) return;
      final updated = retried.asset;
      if (updated != null) {
        _current = updated;
        _requests.invalidate();
        _refreshRequests.invalidate();
        setState(() => _asset = Future.value(updated));
      }
      _showAssetSaveResult(retried, controller);
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_busy) return;
    await _refresh();
  }

  Future<void> _archive() async {
    if (_busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showRelayDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.text('archiveAsset')),
        content: Text(l10n.text('archiveAssetBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.text('archiveAsset')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _requests.invalidate();
    _refreshRequests.invalidate();
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final saved = await ref
          .read(assetCatalogRepositoryProvider)
          .archiveAsset(companyId: widget.companyId, assetId: widget.assetId);
      if (!mounted) return;
      _current = saved;
      _requests.invalidate();
      setState(() {
        _asset = Future.value(saved);
      });
      await RelayHaptics.confirm();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.text('assetArchived'))),
      );
      widget.onChanged?.call();
      widget.onCloseRequested?.call();
    } catch (error) {
      if (mounted) {
        setState(
          () => _actionError = RelayFailure.from(
            error,
          ).message(l10n: l10n, fallback: l10n.text('couldNotArchive')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showRelayDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.text('restoreAsset')),
        content: Text(l10n.text('restoreAssetBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.text('cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.unarchive_outlined),
            label: Text(l10n.text('restoreAsset')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _requests.invalidate();
    _refreshRequests.invalidate();
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final saved = await ref
          .read(assetCatalogRepositoryProvider)
          .restoreAsset(companyId: widget.companyId, assetId: widget.assetId);
      if (!mounted) return;
      _current = saved;
      _requests.invalidate();
      setState(() {
        _asset = Future.value(saved);
      });
      await RelayHaptics.confirm();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.text('assetRestored'))),
      );
      widget.onChanged?.call();
      widget.onCloseRequested?.call();
    } catch (error) {
      if (mounted) {
        setState(
          () => _actionError = RelayFailure.from(
            error,
          ).message(l10n: l10n, fallback: l10n.text('couldNotRestore')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final item = _current ?? widget.initial;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final applied = await executeAssetLifecycle(
        context: context,
        ref: ref,
        selectedIds: [widget.assetId],
        operation: LifecycleOperation.delete,
        exactName: item.name,
        useOperationTitle: true,
        showUnavailable: (message) {
          if (mounted) setState(() => _actionError = message);
        },
      );
      if (applied == null || !mounted) return;
      if (applied > 0) {
        await RelayHaptics.destructiveConfirm();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.text('assetDeleted'))),
        );
        widget.onChanged?.call();
        if (widget.onCloseRequested != null) {
          widget.onCloseRequested!.call();
        } else {
          Navigator.pop(context);
        }
      } else {
        setState(() => _actionError = l10n.text('lifecycleNothingEligible'));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _actionError = RelayFailure.from(
            error,
          ).message(l10n: l10n, fallback: l10n.text('couldNotSave')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: FutureBuilder<AssetRecord?>(
      future: _asset,
      builder: (context, snapshot) {
        final item = snapshot.data ?? _current;
        final canManage = item != null && widget.isOwner && !item.isArchived;
        final canRestore = item != null && widget.isOwner && item.isArchived;
        final canDelete = canRestore;

        Widget child;
        if (snapshot.connectionState != ConnectionState.done && item == null) {
          child = LedgerRefreshView(
            onRefresh: _refresh,
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if ((snapshot.hasError || item == null) && _current == null) {
          child = LedgerRefreshView(
            onRefresh: _refresh,
            child: _AssetRetry(
              message: context.l10n.text('couldNotLoad'),
              onRetry: _refresh,
            ),
          );
        } else {
          final visible = item!;
          child = RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_actionError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: RelayNotice(
                      message: _actionError!,
                      kind: RelayNoticeKind.danger,
                    ),
                  ),
                if (visible.isArchived)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: RelayNotice(
                      message: context.l10n.text('archivedAssetReadOnly'),
                      kind: RelayNoticeKind.warning,
                    ),
                  ),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _AssetCover(storagePath: visible.storagePath),
                ),
                LedgerSection(
                  title: context.l10n.text('assetDetails'),
                  children: [
                    LedgerRow(
                      title: visible.name,
                      leading: const Icon(Icons.inventory_2_outlined),
                    ),
                    LedgerRow(
                      title: context.l10n.text('mode'),
                      subtitle: visible.isSerialized
                          ? context.l10n.text('serialized')
                          : context.l10n.text('bulk'),
                    ),
                    if (visible.isSerialized)
                      LedgerRow(
                        title: context.l10n.text('serialNumber'),
                        subtitle: visible.serialNumber,
                      ),
                    if (!visible.isSerialized)
                      LedgerRow(
                        title: context.l10n.text('physicalQuantity'),
                        subtitle:
                            '${visible.quantity} ${context.l10n.text('units')}',
                      ),
                    LedgerRow(
                      title: context.l10n.text('warehouse'),
                      subtitle: visible.locationName,
                    ),
                    LedgerRow(
                      title: context.l10n.text('workingState'),
                      subtitle: _stateLabel(context, visible),
                    ),
                    if (visible.qrToken != null)
                      LedgerRow(
                        title: context.l10n.text('qrReady'),
                        subtitle: context.l10n.text('qrReadyBody'),
                      ),
                  ],
                ),
                if (visible.qrToken != null)
                  LedgerSection(
                    title: context.l10n.text('qrIdentity'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(14),
                              child: QrImageView(
                                data: visible.qrToken!,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                                size: 184,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!visible.isArchived)
                              FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  relayRoute(
                                    builder: (_) =>
                                        AssetQrLabelPage(asset: visible),
                                  ),
                                ),
                                icon: const Icon(Icons.print_outlined),
                                label: Text(context.l10n.text('printQrLabel')),
                              )
                            else
                              Text(
                                context.l10n.text('restoreBeforePrintingQr'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.relay.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }

        return LedgerPage(
          title: context.l10n.text('assetDetails'),
          presentation: widget.embedded
              ? LedgerPagePresentation.embedded
              : LedgerPagePresentation.screen,
          actions: [
            if (canManage)
              IconButton(
                tooltip: context.l10n.text('edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy ? null : _edit,
              ),
            if (canManage)
              IconButton(
                tooltip: context.l10n.text('archiveAsset'),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined),
                onPressed: _busy ? null : _archive,
              ),
            if (canRestore)
              IconButton(
                tooltip: context.l10n.text('restoreAsset'),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.unarchive_outlined),
                onPressed: _busy ? null : _restore,
              ),
            if (canDelete)
              IconButton(
                tooltip: context.l10n.text('deleteAsset'),
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy ? null : _delete,
              ),
          ],
          child: child,
        );
      },
    ),
  );
}
