part of 'access_flow.dart';

enum _CompanySettingsOperation { idle, renaming, deleting, returningToGateway }

class CompanySettingsPage extends ConsumerStatefulWidget {
  const CompanySettingsPage({required this.companyId, super.key});

  final String companyId;

  @override
  ConsumerState<CompanySettingsPage> createState() =>
      _CompanySettingsPageState();
}

class _CompanySettingsPageState extends ConsumerState<CompanySettingsPage>
    with AppResumeRefreshMixin<CompanySettingsPage> {
  final _refreshRequests = LatestRequestGate();
  String? _optimisticName;
  var _operation = _CompanySettingsOperation.idle;
  String? _error;
  String? _notice;

  bool get _renaming => _operation == _CompanySettingsOperation.renaming;
  bool get _deletingCompany => _operation == _CompanySettingsOperation.deleting;
  bool get _returningToCompanyGateway =>
      _operation == _CompanySettingsOperation.returningToGateway;

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(accessCompaniesProvider);
    final items = companies.value;
    if (items == null) {
      if (companies.hasError) {
        return _SessionState(
          message: context.l10n.text('companySettingsLoadFailed'),
          action: context.l10n.text('retry'),
          onAction: () => ref.invalidate(accessCompaniesProvider),
        );
      }
      return _SessionState(
        message: context.l10n.text('loadingCompanySettings'),
      );
    }

    RelayCompany? company;
    for (final item in items) {
      if (item.id == widget.companyId) {
        company = item;
        break;
      }
    }
    if (company == null) {
      _returnToCompanyGateway();
      return _SessionState(
        message: context.l10n.text('companyUnavailable'),
        action: context.l10n.text('back'),
        onAction: () => Navigator.maybePop(context),
      );
    }

    final shownCompany = RelayCompany(
      id: company.id,
      name: _optimisticName ?? company.name,
      role: company.role,
    );

    return PopScope(
      canPop: !_renaming && !_deletingCompany,
      child: LedgerPage(
        title: context.l10n.text('companySettings'),
        child: LedgerRefreshView(
          onRefresh: _refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null || _notice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: RelayNotice(
                    message: _error ?? _notice!,
                    kind: _error == null
                        ? RelayNoticeKind.success
                        : RelayNoticeKind.danger,
                  ),
                ),
              LedgerSection(
                title: context.l10n.text('company'),
                children: [
                  LedgerRow(
                    leading: _CompanyGlyph(name: shownCompany.name),
                    title: shownCompany.name,
                    subtitle: context.l10n.text(
                      shownCompany.isOwner ? 'owner' : 'staff',
                    ),
                    trailing: _renaming
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : shownCompany.isOwner
                        ? const Icon(Icons.edit_outlined)
                        : null,
                    onTap: shownCompany.isOwner && !_renaming
                        ? () => _rename(shownCompany)
                        : null,
                  ),
                  LedgerRow(
                    leading: const Icon(Icons.group_outlined),
                    title: context.l10n.text('team'),
                    subtitle: shownCompany.isOwner
                        ? context.l10n.text('manageStaffMembers')
                        : context.l10n.text('viewCompanyMembers'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final notice = await _push<String>(
                        context,
                        TeamPage(
                          key: ValueKey('team-${shownCompany.id}'),
                          company: shownCompany,
                        ),
                      );
                      if (!mounted || notice == null) return;
                      ref.invalidate(accessCompaniesProvider);
                      setState(() {
                        _error = null;
                        _notice = notice;
                      });
                    },
                  ),
                ],
              ),
              if (shownCompany.isOwner)
                LedgerSection(
                  title: context.l10n.text('dangerZone'),
                  children: [
                    LedgerRow(
                      leading: Icon(
                        Icons.delete_outline,
                        color: context.relay.danger,
                      ),
                      title: context.l10n.text('deleteCompany'),
                      titleColor: context.relay.danger,
                      subtitle: context.l10n.text('deleteCompanyDescription'),
                      trailing: _deletingCompany
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _deletingCompany
                          ? null
                          : () => _deleteCompany(shownCompany),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _returnToCompanyGateway() {
    if (_returningToCompanyGateway) return;
    _operation = _CompanySettingsOperation.returningToGateway;
    final navigator = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _refresh() async {
    if (_renaming || _deletingCompany) return;
    final request = _refreshRequests.begin();
    setState(() {
      _error = null;
      _notice = null;
    });
    ref.invalidate(accessCompaniesProvider);
    try {
      await ref.read(accessCompaniesProvider.future);
      if (mounted && _refreshRequests.isCurrent(request)) {
        setState(() => _optimisticName = null);
      }
    } catch (_) {
      if (mounted && _refreshRequests.isCurrent(request)) {
        setState(
          () => _error = context.l10n.text('companyRefreshPartialFailure'),
        );
      }
    }
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_renaming) return;
    await _refresh();
  }

  Future<void> _rename(RelayCompany company) async {
    if (_renaming || _deletingCompany) return;
    var draft = company.name;

    final value = await showRelayDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.text('companyName')),
        content: TextFormField(
          initialValue: company.name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.l10n.text('companyName'),
          ),
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) {
            Navigator.pop(dialogContext, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draft),
            child: Text(context.l10n.text('saveChanges')),
          ),
        ],
      ),
    );

    final name = value?.trim();
    if (name == null || name.length < 2 || name.length > 120 || _renaming) {
      return;
    }

    _refreshRequests.invalidate();
    setState(() {
      _operation = _CompanySettingsOperation.renaming;
      _error = null;
      _notice = null;
    });

    try {
      await ref.read(accessRepositoryProvider).renameCompany(company.id, name);

      if (!mounted) return;

      setState(() {
        _optimisticName = name;
        _notice = context.l10n.text('companyNameUpdated');
      });
      await RelayHaptics.success();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.text('companyNameUpdateFailed');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _operation = _CompanySettingsOperation.idle;
        });
      }
    }
  }

  Future<void> _deleteCompany(RelayCompany company) async {
    if (_deletingCompany || _renaming) return;
    setState(() {
      _operation = _CompanySettingsOperation.deleting;
      _error = null;
      _notice = null;
    });

    try {
      final repository = ref.read(accessRepositoryProvider);
      final preview = await repository.previewCompanyDeletion(company.id);
      if (!mounted) return;

      if (!preview.canDeleteNow) {
        await _showCompanyDeletionBlocked(preview);
        return;
      }

      final confirmed = await _confirmCompanyDeletion(company);
      if (!confirmed || !mounted) return;

      await repository.deleteCompany(company.id);
      if (!mounted) return;

      // Leave the nested settings/account routes before replacing the
      // company shell. Rebuilding the shell while those routes are popping
      // can give its scrollable children unbounded constraints during the
      // same frame and crash the debug renderer.
      final container = ProviderScope.containerOf(context, listen: false);
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        container.read(activeCompanyIdProvider.notifier).state = null;
        container.invalidate(accessCompaniesProvider);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is CompanyDeletionFailure
              ? _deletionReasonsText(
                  context,
                  error.reasons,
                  fallbackKey: error.userMessageKey,
                )
              : context.l10n.text('companyDeletionUnavailable');
        });
      }
    } finally {
      if (mounted) setState(() => _operation = _CompanySettingsOperation.idle);
    }
  }

  Future<void> _showCompanyDeletionBlocked(CompanyDeletionPreview preview) =>
      showRelayDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.text('companyDeletionBlockedTitle')),
          content: Text(
            _deletionReasonsText(
              context,
              preview.reasons,
              fallbackKey: 'companyDeletionUnavailable',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.text('ok')),
            ),
          ],
        ),
      );

  Future<bool> _confirmCompanyDeletion(RelayCompany company) async {
    final controller = TextEditingController();
    var exactName = false;
    try {
      return await showRelayDialog<bool>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text(context.l10n.text('deleteCompanyConfirmTitle')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${context.l10n.text('deleteCompanyConfirmBody')}\n\n${company.name}',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.text('deleteCompanyNameHint'),
                        ),
                        onChanged: (value) => setDialogState(
                          () => exactName = value.trim() == company.name.trim(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.text('deleteCompanyExactName'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(context.l10n.text('cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.relay.danger,
                    ),
                    onPressed: exactName
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    child: Text(context.l10n.text('deleteCompanyButton')),
                  ),
                ],
              ),
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }
  }
}
