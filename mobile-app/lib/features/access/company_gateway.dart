part of 'access_flow.dart';

class CompanyGate extends ConsumerWidget {
  const CompanyGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(accessCompaniesProvider);
    final items = companies.value;
    if (items == null) {
      if (companies.hasError) {
        return _SessionState(
          message: context.l10n.text('couldNotLoad'),
          action: context.l10n.text('retry'),
          onAction: () => ref.invalidate(accessCompaniesProvider),
        );
      }
      return _SessionState(message: context.l10n.text('loadingCompanies'));
    }

    final selected = ref.watch(activeCompanyIdProvider);
    RelayCompany? company;
    for (final item in items) {
      if (item.id == selected) {
        company = item;
        break;
      }
    }
    return company == null
        ? CompanyGateway(companies: items)
        : CompanyShell(key: companyShellKey(company.id), company: company);
  }
}

class CompanyGateway extends ConsumerStatefulWidget {
  const CompanyGateway({required this.companies, super.key});
  final List<RelayCompany> companies;

  @override
  ConsumerState<CompanyGateway> createState() => _CompanyGatewayState();
}

class _CompanyGatewayState extends ConsumerState<CompanyGateway>
    with AppResumeRefreshMixin<CompanyGateway> {
  final _refreshRequests = LatestRequestGate();
  bool _signingOut = false;
  String? _error;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_signingOut,
    child: Builder(
      builder: (context) {
        final announcementStatus = ref.watch(
          developerAnnouncementStatusProvider,
        );
        final unreadCount = announcementStatus.maybeWhen(
          data: (value) => value.unreadCount,
          orElse: () => 0,
        );
        return LedgerPage(
          title: context.l10n.text('companies'),
          actions: [
            const PreCompanyLanguageMenu(),
            IconButton(
              tooltip: context.l10n.text('account'),
              icon: const Icon(Icons.person_outline),
              onPressed: () => _push(context, const AccountPage()),
            ),
          ],
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: RelayNotice(
                            message: _error!,
                            kind: RelayNoticeKind.danger,
                          ),
                        ),
                      if (widget.companies.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            MediaQuery.sizeOf(context).width <
                                    RelayBreakpoints.compactMax
                                ? 24
                                : 40,
                            24,
                            12,
                          ),
                          child: const _GatewayEmpty(),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            context.l10n.text('yourCompanies').toUpperCase(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < widget.companies.length;
                                index++
                              ) ...[
                                LedgerRow(
                                  leading: _CompanyGlyph(
                                    name: widget.companies[index].name,
                                  ),
                                  title: widget.companies[index].name,
                                  subtitle: context.l10n.text(
                                    widget.companies[index].isOwner
                                        ? 'owner'
                                        : 'staff',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      ref
                                          .read(
                                            activeCompanyIdProvider.notifier,
                                          )
                                          .state = widget
                                          .companies[index]
                                          .id,
                                ),
                                if (index < widget.companies.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (widget.companies.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: BusyButton(
                            label: context.l10n.text('createCompany'),
                            icon: Icons.domain_add_outlined,
                            onPressed: () =>
                                _openCompanyEntry(const CreateCompanyPage()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openCompanyEntry(const JoinCompanyPage()),
                            icon: const Icon(Icons.group_add_outlined),
                            label: Text(context.l10n.text('joinCompany')),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: TextButton.icon(
                            onPressed: () => _push(
                              context,
                              const AccountPage(openDeletion: true),
                            ),
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.relay.danger,
                            ),
                            label: Text(context.l10n.text('deleteAccount')),
                            style: TextButton.styleFrom(
                              foregroundColor: context.relay.danger,
                            ),
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: context.relay.structuralLine,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                LedgerRow(
                                  leading: const Icon(
                                    Icons.domain_add_outlined,
                                  ),
                                  title: context.l10n.text(
                                    'createAnotherCompany',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openCompanyEntry(
                                    const CreateCompanyPage(),
                                  ),
                                ),
                                const Divider(height: 1),
                                LedgerRow(
                                  leading: const Icon(Icons.group_add_outlined),
                                  title: context.l10n.text(
                                    'joinAnotherCompany',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openCompanyEntry(
                                    const JoinCompanyPage(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: _signingOut ? null : _signOut,
                          icon: _signingOut
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.logout),
                          label: Text(
                            _signingOut
                                ? context.l10n.text('signingOut')
                                : context.l10n.text('signOut'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _AnnouncementBellButton(
                      unreadCount: unreadCount,
                      tooltip: context.l10n.text('announcementsTooltip'),
                      onPressed: _openAnnouncements,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _refresh() async {
    if (_signingOut) return;
    final request = _refreshRequests.begin();
    setState(() => _error = null);
    ref.invalidate(accessCompaniesProvider);
    _invalidateAnnouncements();
    try {
      await ref.read(accessCompaniesProvider.future);
    } catch (_) {
      if (mounted && _refreshRequests.isCurrent(request)) {
        setState(() => _error = context.l10n.text('companiesRefreshFailed'));
      }
    }
  }

  Future<void> _openCompanyEntry(Widget page) async {
    final companyId = await _push<String>(context, page);
    if (companyId == null || !mounted) return;

    // The child route has already left the stack. Refresh membership data
    // before selecting the new Company so CompanyGate cannot rebuild the
    // shell underneath a still-mounted Create/Join route.
    ref.invalidate(accessCompaniesProvider);
    try {
      await ref.read(accessCompaniesProvider.future);
    } catch (_) {
      // The membership was created authoritatively. CompanyGate can retry the
      // membership read without encouraging a duplicate create/join action.
    }
    if (!mounted) return;
    ref.read(activeCompanyIdProvider.notifier).state = companyId;
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_signingOut) return;
    await _refresh();
  }

  void _invalidateAnnouncements() {
    ref.invalidate(developerAnnouncementsProvider);
    ref.invalidate(developerAnnouncementStatusProvider);
  }

  Future<void> _openAnnouncements() async {
    await showRelaySheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DeveloperAnnouncementsSheet(),
    );
    if (!mounted) return;
    _invalidateAnnouncements();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await withRelayRequestTimeout(
        ref.read(accessRepositoryProvider).signOut(),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _signingOut = false;
          _error = context.l10n.text('signOutFailed');
        });
      }
    }
  }
}
