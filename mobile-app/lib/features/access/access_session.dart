part of 'access_flow.dart';

class AccessSessionGate extends ConsumerWidget {
  const AccessSessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(accessAuthProvider, (previous, next) {
      final previousSession = previous?.asData?.value.session;
      final nextState = next.asData?.value;

      if (previousSession != null &&
          nextState != null &&
          nextState.session == null) {
        ref.read(activeCompanyIdProvider.notifier).state = null;
        ref.read(pendingLegalAcceptanceMethodProvider.notifier).state = null;
      }
    });

    final auth = ref.watch(accessAuthProvider);

    return auth.when(
      loading: () =>
          _SessionState(message: context.l10n.text('restoringSession')),
      error: (_, _) => _SessionState(
        message: context.l10n.text('couldNotRestoreSession'),
        action: context.l10n.text('retry'),
        onAction: () => ref.invalidate(accessAuthProvider),
      ),
      data: (state) {
        if (state.session == null) {
          return AuthPage(
            sessionEnded: state.event == LocalAuthEvent.signedOut,
            initialNotice: ref.watch(pendingAuthNoticeProvider),
          );
        }

        return LegalAcceptanceGate(
          key: ValueKey(state.session!.user.id),
          pendingMethod: ref.watch(pendingLegalAcceptanceMethodProvider),
        );
      },
    );
  }
}

class LegalAcceptanceGate extends ConsumerStatefulWidget {
  const LegalAcceptanceGate({required this.pendingMethod, super.key});

  final String? pendingMethod;

  @override
  ConsumerState<LegalAcceptanceGate> createState() =>
      _LegalAcceptanceGateState();
}

enum _LegalGateState { loading, accepted, requiresAcceptance, failed }

class _LegalAcceptanceGateState extends ConsumerState<LegalAcceptanceGate> {
  final _requests = LatestRequestGate();
  var _gateState = _LegalGateState.loading;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LegalAcceptanceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingMethod != widget.pendingMethod) {
      setState(() => _gateState = _LegalGateState.loading);
      _resolve();
    }
  }

  @override
  void dispose() {
    _requests.invalidate();
    super.dispose();
  }

  Future<void> _resolve() async {
    final request = _requests.begin();
    final pendingMethod = widget.pendingMethod;
    try {
      final repository = ref.read(accessRepositoryProvider);
      if (await repository.hasCurrentLegalAcceptance()) {
        if (mounted && _requests.isCurrent(request)) {
          setState(() => _gateState = _LegalGateState.accepted);
        }
        return;
      }

      if (pendingMethod != null) {
        await repository.recordCurrentLegalAcceptance(pendingMethod);
        if (!mounted || !_requests.isCurrent(request)) return;
        final pending = ref.read(pendingLegalAcceptanceMethodProvider.notifier);
        if (pending.state == pendingMethod) pending.state = null;
        setState(() => _gateState = _LegalGateState.accepted);
        return;
      }

      if (mounted && _requests.isCurrent(request)) {
        setState(() => _gateState = _LegalGateState.requiresAcceptance);
      }
    } catch (error) {
      if (mounted && _requests.isCurrent(request)) {
        setState(() => _gateState = _LegalGateState.failed);
      }
    }
  }

  Future<void> _acceptFromGate() async {
    try {
      await ref
          .read(accessRepositoryProvider)
          .recordCurrentLegalAcceptance('existing_session');
      ref.read(pendingLegalAcceptanceMethodProvider.notifier).state = null;
      if (mounted) setState(() => _gateState = _LegalGateState.accepted);
    } catch (error) {
      if (mounted) setState(() => _gateState = _LegalGateState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gateState == _LegalGateState.accepted) return const CompanyGate();
    if (_gateState == _LegalGateState.loading) {
      return _SessionState(message: context.l10n.text('restoringSession'));
    }
    if (_gateState == _LegalGateState.failed) {
      return _SessionState(
        message: context.l10n.text('couldNotRestoreSession'),
        action: context.l10n.text('retry'),
        onAction: () {
          setState(() => _gateState = _LegalGateState.loading);
          _resolve();
        },
      );
    }
    return LegalConsentPage(onAccepted: _acceptFromGate);
  }
}
