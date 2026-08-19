part of 'catalog_screens.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({
    required this.companyId,
    required this.customerId,
    required this.initial,
    this.isOwner = false,
    this.embedded = false,
    this.onCloseRequested,
    this.onChanged,
    super.key,
  });
  final String companyId;
  final String customerId;
  final CustomerRecord initial;
  final bool isOwner;
  final bool embedded;
  final VoidCallback? onCloseRequested;
  final VoidCallback? onChanged;

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage>
    with AppResumeRefreshMixin<CustomerDetailPage> {
  final _requests = LatestRequestGate();
  late CustomerRecord _current = widget.initial;
  late Future<CustomerRecord?> _customer = _load();

  Future<CustomerRecord?> _load() async {
    final request = _requests.begin();
    final customer = await ref
        .read(catalogRepositoryProvider)
        .customer(widget.companyId, widget.customerId);
    if (customer != null && mounted && _requests.isCurrent(request)) {
      _current = customer;
    }
    return customer;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _customer = future;
    });
    try {
      await future;
    } catch (_) {
      // Keep the last confirmed Customer visible while showing the warning.
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<CustomerRecord>(
      relayRoute(
        builder: (_) =>
            CustomerFormPage(companyId: widget.companyId, existing: _current),
      ),
    );
    if (saved != null && mounted) {
      _requests.invalidate();
      _current = saved;
      setState(() {
        _customer = Future.value(saved);
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
        entityType: LifecycleEntityType.customer,
        selectedIds: [widget.customerId],
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
          LifecycleOperation.archive => 'customerArchived',
          LifecycleOperation.restore => 'customerRestored',
          _ => 'customerDeleted',
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
    title: context.l10n.text('customerDetails'),
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
          tooltip: context.l10n.text('archiveCustomer'),
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => _runLifecycle(LifecycleOperation.archive),
        ),
      if (widget.isOwner && _current.isArchived) ...[
        IconButton(
          tooltip: context.l10n.text('restoreCustomer'),
          icon: const Icon(Icons.unarchive_outlined),
          onPressed: () => _runLifecycle(LifecycleOperation.restore),
        ),
        IconButton(
          tooltip: context.l10n.text('deleteCustomer'),
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _runLifecycle(LifecycleOperation.delete),
        ),
      ],
    ],
    child: FutureBuilder<CustomerRecord?>(
      future: _customer,
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
                title: context.l10n.text('customerDetails'),
                children: [
                  LedgerRow(
                    title: item.name,
                    leading: const Icon(Icons.person_outline),
                  ),
                  if (item.contactName?.isNotEmpty == true)
                    LedgerRow(
                      title: context.l10n.text('contactName'),
                      subtitle: item.contactName,
                    ),
                  if (item.phone?.isNotEmpty == true)
                    LedgerRow(
                      title: context.l10n.text('phone'),
                      subtitle: item.phone,
                    ),
                  if (item.email?.isNotEmpty == true)
                    LedgerRow(
                      title: context.l10n.text('email'),
                      subtitle: item.email,
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
