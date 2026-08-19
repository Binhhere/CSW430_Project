part of 'access_flow.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.sessionEnded = false, this.initialNotice, super.key});
  final bool sessionEnded;
  final String? initialNotice;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _notice = widget.initialNotice;
    if (widget.initialNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref.read(pendingAuthNoticeProvider) != widget.initialNotice) {
          return;
        }
        ref.read(pendingAuthNoticeProvider.notifier).state = null;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: _AuthEntryLayout(
        register: _register,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _register
                    ? context.l10n.text('createYourAccount')
                    : context.l10n.text('signIn'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (_register) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.text('chooseOrJoinCompanyAfterAccount'),
                  style: TextStyle(color: context.relay.textSecondary),
                ),
              ],
              const SizedBox(height: 24),
              if (widget.sessionEnded && _notice == null) ...[
                RelayNotice(
                  message: context.l10n.text('sessionEnded'),
                  kind: RelayNoticeKind.warning,
                ),
                const SizedBox(height: 16),
              ],
              if (_register) ...[
                _AuthTextField(
                  key: const ValueKey('auth-name'),
                  label: context.l10n.text('displayName'),
                  controller: _name,
                  hintText: context.l10n.text('yourName'),
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    return length < 1 || length > 120
                        ? context.l10n.text('use1To120Characters')
                        : null;
                  },
                ),
                const SizedBox(height: 20),
              ],
              _AuthTextField(
                key: ValueKey('auth-email-$_register'),
                label: context.l10n.text('email'),
                controller: _email,
                hintText: context.l10n.text('emailHint'),
                prefixIcon: Icons.mail_outline,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) => (value?.contains('@') ?? false)
                    ? null
                    : context.l10n.text('enterValidEmail'),
              ),
              const SizedBox(height: 20),
              _AuthTextField(
                key: ValueKey('auth-password-$_register'),
                label: context.l10n.text('password'),
                controller: _password,
                hintText: context.l10n.text('enterPassword'),
                prefixIcon: Icons.lock_outline,
                obscureText: _obscure,
                autofillHints: _register
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  tooltip: context.l10n.text(
                    _obscure ? 'showPassword' : 'hidePassword',
                  ),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (value) => (value?.length ?? 0) < 8
                    ? context.l10n.text('useAtLeast8Characters')
                    : null,
              ),
              if (_register) ...[
                const SizedBox(height: 8),
                LegalConsentFields(
                  termsAccepted: _termsAccepted,
                  privacyAccepted: _privacyAccepted,
                  onTermsChanged: (value) =>
                      setState(() => _termsAccepted = value),
                  onPrivacyChanged: (value) =>
                      setState(() => _privacyAccepted = value),
                ),
              ],
              if (_error != null || _notice != null) ...[
                const SizedBox(height: 16),
                RelayNotice(
                  message: _error ?? _notice!,
                  kind: _error == null
                      ? RelayNoticeKind.success
                      : RelayNoticeKind.danger,
                ),
              ],
              const SizedBox(height: 24),
              BusyButton(
                label: context.l10n.text(
                  _register ? 'createAccount' : 'signIn',
                ),
                busy: _busy,
                onPressed: _register && (!_termsAccepted || !_privacyAccepted)
                    ? null
                    : _submit,
                icon: _register ? Icons.person_add_alt_1_outlined : Icons.login,
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        ref
                                .read(
                                  pendingLegalAcceptanceMethodProvider.notifier,
                                )
                                .state =
                            null;
                        _termsAccepted = false;
                        _privacyAccepted = false;
                        _error = null;
                        _notice = null;
                      }),
                child: Text(
                  _register
                      ? context.l10n.text('alreadyHaveAccount')
                      : context.l10n.text('newToRelay'),
                ),
              ),
              if (!_register)
                TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: Text(context.l10n.text('forgotPassword')),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_register && (!_termsAccepted || !_privacyAccepted)) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final repo = ref.read(accessRepositoryProvider);
      if (_register) {
        ref.read(pendingLegalAcceptanceMethodProvider.notifier).state =
            'email_password';
        final result = await repo.register(
          _name.text,
          _email.text,
          _password.text,
        );
        if (!result && mounted) {
          // The consent cannot be recorded until the local backend has created an
          // authenticated session. Ask again after the user verifies email
          // and signs in instead of carrying this flag to another session.
          ref.read(pendingLegalAcceptanceMethodProvider.notifier).state = null;
          setState(() => _notice = l10n.text('verifyEmailThenSignIn'));
        }
      } else {
        await repo.signIn(_email.text, _password.text);
      }
    } on BackendAuthException catch (error) {
      ref.read(pendingLegalAcceptanceMethodProvider.notifier).state = null;
      _setError(_friendlyAuthError(l10n, error.message));
    } catch (_) {
      ref.read(pendingLegalAcceptanceMethodProvider.notifier).state = null;
      _setError(l10n.text('requestCouldNotComplete'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    final l10n = context.l10n;
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _setError(l10n.text('enterEmailFirst'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(accessRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        setState(() => _notice = l10n.text('passwordResetSent'));
      }
    } catch (_) {
      _setError(l10n.text('passwordResetCouldNotSend'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String value) {
    if (mounted) setState(() => _error = value);
  }
}

class _AuthEntryLayout extends StatelessWidget {
  const _AuthEntryLayout({required this.register, required this.child});

  final bool register;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < RelayBreakpoints.compactMax;
      final viewportHeight = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : MediaQuery.sizeOf(context).height;
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      final heroHeight = keyboardOpen
          ? (compact ? 76.0 : 104.0)
          : compact
          ? (register
                ? (viewportHeight < 700 ? 76.0 : 96.0)
                : (viewportHeight < 700 ? 92.0 : 120.0))
          : (register ? 168.0 : 188.0);
      final panelRadius = compact ? 10.0 : 12.0;
      final horizontalPadding = compact ? 16.0 : 24.0;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final heroAsset = register
          ? (isDark
                ? 'assets/auth_entry/register_dark.png'
                : 'assets/auth_entry/register_light.png')
          : (isDark
                ? 'assets/auth_entry/signin_dark.png'
                : 'assets/auth_entry/signin_light.png');

      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          keyboardOpen ? 12 : (compact ? 24 : 40),
          horizontalPadding,
          (keyboardOpen ? 16 : 12) + MediaQuery.viewInsetsOf(context).bottom,
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
                    const Align(
                      alignment: Alignment.centerRight,
                      child: PreCompanyLanguageMenu(),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      child: SizedBox(
                        height: heroHeight,
                        child: Image.asset(
                          heroAsset,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 20),
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

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: controller.text,
    validator: validator,
    builder: (state) {
      final inputTheme = Theme.of(context).inputDecorationTheme;
      final hasError = state.hasError;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthFieldLabel(label),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            textCapitalization: textCapitalization,
            obscureText: obscureText,
            onSubmitted: onFieldSubmitted,
            onChanged: (value) {
              final hadError = state.hasError;
              state.didChange(value);
              if (hadError) state.validate();
            },
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(prefixIcon, size: 22),
              suffixIcon: suffixIcon,
              enabledBorder: hasError ? inputTheme.errorBorder : null,
              focusedBorder: hasError
                  ? inputTheme.focusedErrorBorder ?? inputTheme.errorBorder
                  : null,
            ),
          ),
          if (state.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: context.relay.danger,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

@visibleForTesting
Key companyShellKey(String companyId) => ValueKey('company-shell-$companyId');

@visibleForTesting
Key companyContentKey(String section, String companyId, int version) =>
    ValueKey('$section-$companyId-$version');

class UpdatePasswordPage extends ConsumerStatefulWidget {
  const UpdatePasswordPage({super.key});
  @override
  ConsumerState<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends ConsumerState<UpdatePasswordPage> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.text('setNewPassword')),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth >= 720
                        ? 560
                        : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.text('passwordRecoveryHelp'),
                        style: TextStyle(color: context.relay.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        autofocus: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        decoration: InputDecoration(
                          labelText: l10n.text('newPassword'),
                          helperText: l10n.text('useAtLeast8Characters'),
                          prefixIcon: const Icon(Icons.lock_outline, size: 22),
                          suffixIcon: IconButton(
                            tooltip: l10n.text(
                              _obscure ? 'showPassword' : 'hidePassword',
                            ),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        RelayNotice(
                          message: _error!,
                          kind: RelayNoticeKind.danger,
                        ),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 16),
                        RelayNotice(
                          message: _notice!,
                          kind: RelayNoticeKind.success,
                        ),
                      ],
                      const SizedBox(height: 24),
                      BusyButton(
                        label: l10n.text('savePassword'),
                        busy: _busy,
                        onPressed: _save,
                        icon: Icons.lock_reset,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_password.text.length < 8) {
      setState(() {
        _error = context.l10n.text('useAtLeast8Characters');
        _notice = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final repository = ref.read(accessRepositoryProvider);
      await repository.updatePassword(_password.text);
      if (mounted) {
        FocusScope.of(context).unfocus();
        final notice = context.l10n.text('passwordUpdated');
        ref.read(pendingAuthNoticeProvider.notifier).state = notice;
        setState(() => _notice = notice);
        await repository.signOut();
      }
    } catch (_) {
      ref.read(pendingAuthNoticeProvider.notifier).state = null;
      if (mounted) {
        setState(
          () => _error = context.l10n.text('passwordUpdateCouldNotSave'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
