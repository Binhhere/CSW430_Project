part of 'access_flow.dart';

enum _AccountOperation {
  idle,
  editingProfile,
  signingOut,
  deleting,
  routingToAuth,
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({
    super.key,
    this.openDeletion = false,
    this.embedded = false,
    this.embeddedSurfaceSafeArea = false,
  });

  final bool openDeletion;
  final bool embedded;
  final bool embeddedSurfaceSafeArea;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage>
    with AppResumeRefreshMixin<AccountPage> {
  late Future<String?> _profile;
  late Future<PackageInfo> _packageInfo;
  final _profileRequests = LatestRequestGate();
  String? _currentProfile;
  var _operation = _AccountOperation.idle;
  String? _error;
  String? _notice;

  bool get _profileBusy => _operation == _AccountOperation.editingProfile;
  bool get _signingOut =>
      _operation == _AccountOperation.signingOut ||
      _operation == _AccountOperation.routingToAuth;
  bool get _routingToAuth => _operation == _AccountOperation.routingToAuth;
  bool get _deleting => _operation == _AccountOperation.deleting;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
    _packageInfo = PackageInfo.fromPlatform();
    if (widget.openDeletion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _deleteAccount();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accessAuthProvider, (_, next) {
      final authState = next.asData?.value;
      if (_signingOut && authState?.session == null) {
        _finishSignedOut();
      }
    });
    final activeId = ref.watch(activeCompanyIdProvider);
    final mutationRunning = _profileBusy || _signingOut || _deleting;
    return PopScope(
      canPop: !mutationRunning || _routingToAuth,
      child: LedgerPage(
        title: context.l10n.text(widget.embedded ? 'settings' : 'account'),
        presentation: widget.embedded
            ? LedgerPagePresentation.embedded
            : LedgerPagePresentation.screen,
        embeddedSurfaceSafeArea: widget.embeddedSurfaceSafeArea,
        showEmbeddedHeader: !widget.embedded,
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
              FutureBuilder<String?>(
                future: _profile,
                builder: (context, snapshot) {
                  final profileName = _signingOut
                      ? null
                      : snapshot.data ?? _currentProfile;
                  final ready =
                      !_signingOut &&
                      (profileName != null ||
                          (snapshot.connectionState == ConnectionState.done &&
                              !snapshot.hasError));
                  return LedgerSection(
                    title: context.l10n.text('account'),
                    uppercaseTitle: false,
                    children: [
                      LedgerRow(
                        leading: const Icon(Icons.person_outline),
                        leadingBackground: context.relay.selectionContainer,
                        leadingColor: context.relay.selectedContent,
                        title: snapshot.hasError && profileName == null
                            ? context.l10n.text('couldNotLoadProfile')
                            : profileName?.trim().isNotEmpty == true
                            ? profileName!
                            : ready
                            ? context.l10n.text('profile')
                            : context.l10n.text('loadingProfile'),
                        subtitle: snapshot.hasError && profileName == null
                            ? context.l10n.text('tapToTryAgain')
                            : ref.read(accessRepositoryProvider).session?.user.email ?? '',
                        trailing: _profileBusy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                snapshot.hasError
                                    ? Icons.refresh
                                    : Icons.edit_outlined,
                                color: context.relay.selectedContent,
                              ),
                        onTap: _profileBusy
                            ? null
                            : snapshot.hasError && profileName == null
                            ? _refresh
                            : ready
                            ? () => _editName(profileName ?? '')
                            : null,
                      ),
                    ],
                  );
                },
              ),
              LedgerSection(
                title: context.l10n.text('app'),
                uppercaseTitle: false,
                children: [
                  LedgerRow(
                    leading: const Icon(Icons.contrast),
                    leadingBackground: context.relay.selectionContainer,
                    leadingColor: context.relay.selectedContent,
                    title: context.l10n.text('theme'),
                    subtitle: _themeLabel(
                      context,
                      ref.watch(themeModeProvider),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: context.relay.textMuted,
                    ),
                    onTap: _chooseTheme,
                  ),
                  LedgerRow(
                    leading: const Icon(Icons.language_outlined),
                    leadingBackground: context.relay.selectionContainer,
                    leadingColor: context.relay.selectedContent,
                    title: context.l10n.text('language'),
                    subtitle: _languageLabel(
                      context,
                      ref.watch(relayLocaleProvider),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: context.relay.textMuted,
                    ),
                    onTap: _chooseLanguage,
                  ),
                ],
              ),
              if (activeId != null)
                LedgerSection(
                  title: context.l10n.text('company'),
                  uppercaseTitle: false,
                  children: [
                    LedgerRow(
                      leading: const Icon(Icons.business_outlined),
                      leadingBackground: context.relay.selectionContainer,
                      leadingColor: context.relay.selectedContent,
                      title: context.l10n.text('companySettings'),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.relay.textMuted,
                      ),
                      onTap: () async {
                        await _push(
                          context,
                          CompanySettingsPage(companyId: activeId),
                        );

                        if (!mounted) return;
                        ref.invalidate(accessCompaniesProvider);
                      },
                    ),
                    LedgerRow(
                      leading: const Icon(Icons.swap_horiz_outlined),
                      leadingBackground: context.relay.selectionContainer,
                      leadingColor: context.relay.selectedContent,
                      title: context.l10n.text('switchCompany'),
                      subtitle: context.l10n.text('selectAnotherCompany'),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.relay.textMuted,
                      ),
                      onTap: _switchBackToCompanyGateway,
                    ),
                  ],
                ),
              LedgerSection(
                title: context.l10n.text('session'),
                uppercaseTitle: false,
                children: [
                  LedgerRow(
                    leading: const Icon(Icons.logout_outlined),
                    leadingBackground: context.relay.selectionContainer,
                    leadingColor: context.relay.selectedContent,
                    title: _signingOut
                        ? context.l10n.text('signingOut')
                        : context.l10n.text('signOut'),
                    trailing: _signingOut
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _signingOut || _deleting ? null : _signOut,
                  ),
                ],
              ),
              FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final packageInfo = snapshot.data;
                  if (packageInfo == null) return const SizedBox.shrink();
                  final version =
                      '${packageInfo.version}+${packageInfo.buildNumber}';
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      context.l10n
                          .text('appVersion')
                          .replaceAll('{version}', version),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.relay.textMuted,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _loadProfile() async {
    final request = _profileRequests.begin();
    final value = await ref.read(accessRepositoryProvider).profileName();
    if (mounted && !_signingOut && _profileRequests.isCurrent(request)) {
      _currentProfile = value;
    }
    return value;
  }

  Future<void> _refresh() async {
    if (_profileBusy || _signingOut || _deleting) return;
    final next = _loadProfile();
    setState(() {
      _error = null;
      _profile = next;
    });
    try {
      await next;
    } catch (error) {
      if (mounted && identical(_profile, next)) {
        setState(
          () => _error = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('couldNotLoadProfile'),
          ),
        );
      }
    }
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_profileBusy || _signingOut || _deleting) return;
    await _refresh();
  }

  Future<void> _editName(String initial) async {
    var draft = initial;

    final next = await showRelayDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.text('displayName')),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.l10n.text('displayName'),
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

    final value = next?.trim();
    if (value == null || value.isEmpty || value.length > 120 || _profileBusy) {
      return;
    }
    setState(() {
      _operation = _AccountOperation.editingProfile;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(accessRepositoryProvider).updateProfileName(value);
      if (!mounted) return;
      _profileRequests.invalidate();
      _currentProfile = value;
      setState(() {
        _profile = Future<String?>.value(value);
        _notice = context.l10n.text('displayNameUpdated');
      });
      await RelayHaptics.success();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('displayNameUpdateFailed'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _operation = _AccountOperation.idle);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut || _deleting) return;
    _profileRequests.invalidate();
    setState(() {
      _operation = _AccountOperation.signingOut;
      _error = null;
      _notice = null;
    });
    final repository = ref.read(accessRepositoryProvider);
    try {
      await repository.signOut().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (repository.session == null) {
        _finishSignedOut(refreshAuth: true);
        return;
      }
      throw StateError('The local session was not cleared.');
    } catch (error) {
      if (!mounted) return;
      if (repository.session == null) {
        _finishSignedOut(refreshAuth: true);
        return;
      }
      setState(() {
        _operation = _AccountOperation.idle;
        _error = RelayFailure.from(error).message(
          l10n: context.l10n,
          fallback: context.l10n.text('signOutFailed'),
        );
      });
    }
  }

  void _finishSignedOut({bool refreshAuth = false}) {
    if (!mounted || !_signingOut || _routingToAuth) return;
    _profileRequests.invalidate();
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    setState(() => _operation = _AccountOperation.routingToAuth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
      if (refreshAuth) container.invalidate(accessAuthProvider);
    });
  }

  void _switchBackToCompanyGateway() {
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(activeCompanyIdProvider.notifier).state = null;
    });
  }

  Future<void> _deleteAccount() async {
    if (_deleting || _signingOut || _profileBusy) return;
    setState(() {
      _operation = _AccountOperation.deleting;
      _error = null;
      _notice = null;
    });
    var sessionClosed = false;
    try {
      final repository = ref.read(accessRepositoryProvider);
      final preview = await repository.previewAccountDeletion();
      if (!mounted) return;

      if (preview.isBlockedByActiveAssignment) {
        await _showDeletionMessage(
          title: context.l10n.text('completeActiveWorkFirst'),
          message: _deletionReasonsText(
            context,
            preview.reasons,
            fallbackKey: 'completeOrReassignWork',
          ),
        );
        return;
      }

      final deletingCompany = preview.canDeleteNow && preview.companyCount > 0;
      final requestOnly = preview.needsManualHandling;
      final confirmed =
          await showRelayDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                requestOnly
                    ? context.l10n.text('sendDeletionRequest')
                    : deletingCompany
                    ? context.l10n.text('deleteCompanyAndAccount')
                    : context.l10n.text('deleteAccountConfirm'),
              ),
              content: Text(
                requestOnly
                    ? context.l10n
                          .text('manualDeletionRequestBody')
                          .replaceAll(
                            '{reasons}',
                            _deletionReasonsText(
                              context,
                              preview.reasons,
                              fallbackKey: 'accountDeletionHelp',
                            ),
                          )
                    : deletingCompany
                    ? context.l10n.text('deleteCompanyAndAccountBody')
                    : context.l10n.text('deleteAccountConfirmBody'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.text('cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.relay.danger,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    requestOnly
                        ? context.l10n.text('sendRequest')
                        : deletingCompany
                        ? context.l10n.text('deleteCompanyButton')
                        : context.l10n.text('deleteAccount'),
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;

      final result = await repository.deleteAccount().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted) return;
      if (result.deleted) {
        _profileRequests.invalidate();
        setState(() {
          _operation = _AccountOperation.signingOut;
          _error = null;
          _notice = null;
        });
        try {
          await repository.signOut().timeout(const Duration(seconds: 20));
        } catch (_) {
          // The Auth account is already gone; this only clears local state.
        }
        sessionClosed = true;
        _finishSignedOut(refreshAuth: true);
        return;
      }
      if (result.requestReceived) {
        await _showDeletionMessage(
          title: context.l10n.text('deletionRequestReceived'),
          message: context.l10n.text('deletionRequestMessage'),
        );
        return;
      }
      await _showDeletionMessage(
        title: context.l10n.text('completeActiveWorkFirst'),
        message: _deletionReasonsText(
          context,
          result.reasons,
          fallbackKey: 'completeOrReassignWork',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('account deletion failed: $error\n$stackTrace');
      if (mounted) {
        await _showDeletionMessage(
          title: context.l10n.text('accountDeletionUnavailable'),
          message: error is AccountDeletionFailure
              ? context.l10n.text(error.userMessageKey)
              : context.l10n.text('accountDeletionHelp'),
        );
      }
    } finally {
      if (mounted && !sessionClosed) {
        setState(() => _operation = _AccountOperation.idle);
      }
    }
  }

  Future<void> _showDeletionMessage({
    required String title,
    required String message,
  }) => showRelayDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.text('ok')),
        ),
      ],
    ),
  );

  Future<void> _chooseTheme() async {
    final selected = await showRelaySheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeLabel(context, mode)),
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }

  Future<void> _chooseLanguage() async {
    final locale = await showRelaySheet<Locale>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.l10n.text('english')),
              onTap: () => Navigator.pop(context, const Locale('en')),
            ),
            ListTile(
              title: Text(context.l10n.text('spanish')),
              onTap: () => Navigator.pop(context, const Locale('es')),
            ),
            ListTile(
              title: Text(context.l10n.text('japanese')),
              onTap: () => Navigator.pop(context, const Locale('ja')),
            ),
          ],
        ),
      ),
    );
    if (locale != null) {
      await ref.read(relayLocaleProvider.notifier).setLocale(locale);
    }
  }
}

String _languageLabel(BuildContext context, Locale locale) =>
    switch (locale.languageCode) {
      'es' => context.l10n.text('spanish'),
      'ja' => context.l10n.text('japanese'),
      _ => context.l10n.text('english'),
    };
