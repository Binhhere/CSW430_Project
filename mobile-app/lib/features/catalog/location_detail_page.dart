part of 'catalog_screens.dart';

class LocationDetailPage extends ConsumerStatefulWidget {
  const LocationDetailPage({
    required this.companyId,
    required this.locationId,
    required this.initial,
    this.isOwner = false,
    this.embedded = false,
    this.onCloseRequested,
    this.onChanged,
    super.key,
  });
  final String companyId;
  final String locationId;
  final LocationRecord initial;
  final bool isOwner;
  final bool embedded;
  final VoidCallback? onCloseRequested;
  final VoidCallback? onChanged;

  @override
  ConsumerState<LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends ConsumerState<LocationDetailPage>
    with AppResumeRefreshMixin<LocationDetailPage> {
  final _requests = LatestRequestGate();
  late LocationRecord _current = widget.initial;
  late Future<LocationRecord?> _location = _load();

  Future<LocationRecord?> _load() async {
    final request = _requests.begin();
    final location = await ref
        .read(catalogRepositoryProvider)
        .location(widget.companyId, widget.locationId);
    if (location != null && mounted && _requests.isCurrent(request)) {
      _current = location;
    }
    return location;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _location = future;
    });
    try {
      await future;
    } catch (_) {
      // Keep the last confirmed Location visible while showing the warning.
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<LocationRecord>(
      relayRoute(
        builder: (_) =>
            LocationFormPage(companyId: widget.companyId, existing: _current),
      ),
    );
    if (saved != null && mounted) {
      _requests.invalidate();
      _current = saved;
      setState(() {
        _location = Future.value(saved);
      });
      widget.onChanged?.call();
    }
  }

  Future<void> _runLifecycle(LifecycleOperation operation) async {
    final l10n = context.l10n;
    try {
      final applied = await executeCatalogLifecycle(
        context: context,
        ref: ref,
        entityType: LifecycleEntityType.location,
        selectedIds: [widget.locationId],
        operation: operation,
        exactName: operation == LifecycleOperation.delete
            ? _current.name
            : null,
        useOperationTitle: true,
      );
      if (applied == null || !mounted) return;
      if (applied > 0) {
        if (operation == LifecycleOperation.delete) {
          await RelayHaptics.destructiveConfirm();
        } else {
          await RelayHaptics.confirm();
        }
        if (!mounted) return;
        final key = switch (operation) {
          LifecycleOperation.archive => 'locationArchived',
          LifecycleOperation.restore => 'locationRestored',
          _ => 'locationDeleted',
        };
        showCatalogLifecycleSnackBar(context, l10n.text(key));
        widget.onChanged?.call();
        if (widget.onCloseRequested != null) {
          widget.onCloseRequested!.call();
        } else {
          Navigator.pop(context);
        }
      } else {
        showCatalogLifecycleSnackBar(
          context,
          l10n.text('lifecycleNothingEligible'),
        );
      }
    } catch (error) {
      if (mounted) {
        showCatalogLifecycleSnackBar(
          context,
          RelayFailure.from(
            error,
          ).message(l10n: l10n, fallback: l10n.text('couldNotSave')),
        );
      }
    }
  }

  @override
  Future<void> refreshAfterAppResume() => _refresh();

  @override
  Widget build(BuildContext context) => LedgerPage(
    title: context.l10n.text('locationDetails'),
    presentation: widget.embedded
        ? LedgerPagePresentation.embedded
        : LedgerPagePresentation.screen,
    actions: [
      if (widget.isOwner && !_current.isArchived)
        IconButton(
          tooltip: context.l10n.text('edit'),
          icon: const Icon(Icons.edit_outlined),
          onPressed: _edit,
        ),
      if (widget.isOwner && !_current.isArchived)
        IconButton(
          tooltip: context.l10n.text('archiveLocation'),
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => _runLifecycle(LifecycleOperation.archive),
        ),
      if (widget.isOwner && _current.isArchived) ...[
        IconButton(
          tooltip: context.l10n.text('restoreLocation'),
          icon: const Icon(Icons.unarchive_outlined),
          onPressed: () => _runLifecycle(LifecycleOperation.restore),
        ),
        IconButton(
          tooltip: context.l10n.text('deleteLocation'),
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _runLifecycle(LifecycleOperation.delete),
        ),
      ],
    ],
    child: FutureBuilder<LocationRecord?>(
      future: _location,
      builder: (context, snapshot) {
        final item = snapshot.data ?? _current;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: RelayNotice(
                    message: context.l10n.text('couldNotLoad'),
                    kind: RelayNoticeKind.warning,
                  ),
                ),
              LedgerSection(
                title: context.l10n.text('locationDetails'),
                children: [
                  LedgerRow(
                    leading: Icon(
                      item.type == LocationType.warehouse
                          ? Icons.warehouse_outlined
                          : Icons.place_outlined,
                    ),
                    title: item.name,
                    subtitle: item.type == LocationType.warehouse
                        ? context.l10n.text('warehouse')
                        : context.l10n.text('deliveryPlace'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
