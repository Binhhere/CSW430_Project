part of 'access_flow.dart';

// The company entry pages use approved Tiny World artwork as a visual hero.
// The invitation scanner remains available from the Join Company form.

class CreateCompanyPage extends ConsumerStatefulWidget {
  const CreateCompanyPage({super.key});
  @override
  ConsumerState<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends ConsumerState<CreateCompanyPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: LedgerPage(
      title: context.l10n.text('createCompany'),
      actions: const [PreCompanyLanguageMenu()],
      child: _CompanyEntryLayout(
        kind: _CompanyEntryKind.create,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.text('startCompany'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.text('companyStartsEmpty'),
                style: TextStyle(color: context.relay.textSecondary),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.text('companyName'),
                  prefixIcon: const Icon(Icons.business_outlined, size: 22),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  return length < 2 || length > 120
                      ? context.l10n.text('use2To120Characters')
                      : null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
              ],
              const SizedBox(height: 24),
              BusyButton(
                label: context.l10n.text('createCompany'),
                busy: _busy,
                onPressed: _create,
                icon: Icons.domain_add_outlined,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _create() async {
    if (!_form.currentState!.validate() || _busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(accessRepositoryProvider)
          .createCompany(_name.text);
      if (!mounted) return;
      Navigator.pop<String>(context, id);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.code == '42901'
              ? l10n.text('tryAgainLater')
              : error.code == '23514' &&
                    error.message.toLowerCase().contains('owner limit')
              ? l10n.text('companyOwnerLimitReached')
              : l10n.text('couldNotCreateCompany');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.text('couldNotCreateCompany');
        });
      }
    }
  }
}

class JoinCompanyPage extends ConsumerStatefulWidget {
  const JoinCompanyPage({super.key});
  @override
  ConsumerState<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends ConsumerState<JoinCompanyPage> {
  final _code = TextEditingController();
  InvitationPreview? _preview;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: LedgerPage(
      title: context.l10n.text('joinCompany'),
      actions: const [PreCompanyLanguageMenu()],
      child: _CompanyEntryLayout(
        kind: _CompanyEntryKind.join,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _preview == null
                  ? context.l10n.text('enterInvitationCode')
                  : context.l10n.text('reviewCompany'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _preview == null
                  ? context.l10n.text('enterCodeOrScan')
                  : context.l10n.text('confirmRightCompany'),
              style: TextStyle(color: context.relay.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_preview == null) ...[
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.l10n.text('invitationCode'),
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.key_outlined, size: 22),
                  suffixIcon: IconButton(
                    tooltip: context.l10n.text('scanInvitationQr'),
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _busy ? null : _scan,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(context.l10n.text('scanInvitationQr')),
              ),
            ] else
              LedgerSection(
                title: context.l10n.text('companySettings'),
                children: [
                  LedgerRow(
                    leading: _CompanyGlyph(name: _preview!.companyName),
                    title: _preview!.companyName,
                    subtitle: context.l10n
                        .text('staffRoleExpires')
                        .replaceAll(
                          '{date}',
                          context.l10n.date(_preview!.expiresAt),
                        ),
                  ),
                ],
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
            ],
            const SizedBox(height: 24),
            BusyButton(
              label: _preview == null
                  ? context.l10n.text('reviewInvitation')
                  : context.l10n.text('joinCompany'),
              busy: _busy,
              onPressed: _preview == null ? _previewCode : _accept,
              icon: _preview == null ? Icons.visibility_outlined : Icons.login,
            ),
            if (_preview != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _preview = null;
                        _error = null;
                      }),
                child: Text(context.l10n.text('editCode')),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<String>(relayRoute(builder: (_) => const _InvitationScannerPage()));
    if (result != null && mounted) _code.text = result;
  }

  Future<void> _previewCode() async {
    if (_busy) return;
    final l10n = context.l10n;
    if (_code.text.trim().isEmpty) {
      setState(() => _error = l10n.text('enterInvitationCodeError'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(accessRepositoryProvider)
          .previewInvitation(_code.text);
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = l10n.text('invalidInvitation'));
      } else {
        setState(() => _preview = result);
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.code == '42901'
            ? l10n.text('tryAgainLater')
            : l10n.text('invitationCheckFailed'),
      );
    } catch (_) {
      setState(() => _error = l10n.text('invitationCheckFailedRetry'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final joinedCompanyId = await ref
          .read(accessRepositoryProvider)
          .acceptInvitation(_code.text);
      if (joinedCompanyId == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = l10n.text('invalidInvitation');
          });
        }
        return;
      }
      if (!mounted) return;
      Navigator.pop<String>(context, joinedCompanyId);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _joinError(context, error.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.text('couldNotJoinCompany');
        });
      }
    }
  }
}

enum _CompanyEntryKind { create, join }

class _CompanyEntryLayout extends StatelessWidget {
  const _CompanyEntryLayout({required this.kind, required this.child});

  final _CompanyEntryKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < RelayBreakpoints.compactMax;
      final horizontalPadding = compact ? 16.0 : 24.0;
      final viewportHeight = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : MediaQuery.sizeOf(context).height;
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      final heroHeight = keyboardOpen
          ? (compact ? 88.0 : 112.0)
          : compact
          ? (viewportHeight < 700 ? 96.0 : 136.0)
          : (viewportHeight < 700 ? 112.0 : 176.0);
      final panelRadius = compact ? 8.0 : 12.0;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final heroAsset = switch ((kind, isDark)) {
        (_CompanyEntryKind.create, false) =>
          'assets/company_entry/create_light.png',
        (_CompanyEntryKind.join, false) =>
          'assets/company_entry/join_light.png',
        (_CompanyEntryKind.create, true) =>
          'assets/company_entry/create_dark.png',
        (_CompanyEntryKind.join, true) => 'assets/company_entry/join_dark.png',
      };
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          compact ? 8 : 16,
          horizontalPadding,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.relay.surface,
                borderRadius: BorderRadius.circular(panelRadius),
                border: Border.all(color: context.relay.structuralLine),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 24,
                  0,
                  compact ? 16 : 24,
                  compact ? 20 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      child: SizedBox(
                        height: heroHeight,
                        child: ExcludeSemantics(
                          child: Image.asset(
                            heroAsset,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
