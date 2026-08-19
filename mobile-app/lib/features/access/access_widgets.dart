part of 'access_flow.dart';

class _SessionState extends StatelessWidget {
  const _SessionState({required this.message, this.action, this.onAction});
  final String message;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onAction, child: Text(action!)),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GatewayEmpty extends StatelessWidget {
  const _GatewayEmpty();
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < RelayBreakpoints.compactMax;
    final short = MediaQuery.sizeOf(context).height < 700;
    final artworkSize = compact ? (short ? 148.0 : 172.0) : 216.0;
    return Column(
      children: [
        SizedBox(
          width: artworkSize,
          height: artworkSize * .82,
          child: Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/company_entry/gateway_dark.png'
                : 'assets/company_entry/gateway_light.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.text('chooseHowToStart'),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CompanyGlyph extends StatelessWidget {
  const _CompanyGlyph({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.relay.selectionContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(color: context.relay.selectedContent),
    ),
  );
}

Future<T?> _push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(relayRoute(builder: (_) => page));

String _themeLabel(BuildContext context, ThemeMode mode) => switch (mode) {
  ThemeMode.light => context.l10n.text('light'),
  ThemeMode.dark => context.l10n.text('dark'),
  ThemeMode.system => context.l10n.text('systemDefault'),
};

String _friendlyAuthError(RelayLocalizations l10n, String message) {
  final lower = message.toLowerCase();
  if (lower.contains('invalid login') ||
      lower.contains('invalid credentials')) {
    return l10n.text('invalidCredentials');
  }
  if (lower.contains('email not confirmed')) {
    return l10n.text('verifyEmailThenSignInShort');
  }
  return l10n.text('signInFailed');
}

String _joinError(BuildContext context, String? code) => switch (code) {
  '23505' => context.l10n.text('alreadyCompanyMember'),
  '23514' => context.l10n.text('noCompanySeat'),
  '22023' => context.l10n.text('invalidInvitation'),
  _ => context.l10n.text('couldNotJoinCompany'),
};

String _removeMemberError(BuildContext context, PostgrestException error) {
  final message = error.message.toLowerCase();
  if (message.contains('pending owner transfer request')) {
    return context.l10n.text('cancelOwnerTransferBeforeRemovingStaff');
  }
  if (message.contains('active assigned transfer')) {
    return context.l10n.text('completeStaffTransfersFirst');
  }
  if (message.contains('owner membership')) {
    return context.l10n.text('ownerCannotBeRemoved');
  }
  if (error.code == '42501') {
    return context.l10n.text('ownerOnlyRemoveStaff');
  }
  if (error.code == '22023') {
    return context.l10n.text('staffNoLongerMember');
  }
  return context.l10n.text('removeStaffFailed');
}

String _ownerTransferRequestError(
  BuildContext context,
  PostgrestException error,
) {
  final message = error.message.toLowerCase();
  if (message.contains('already pending')) {
    return context.l10n.text('ownerTransferAlreadyPending');
  }
  if (message.contains('current staff member')) {
    return context.l10n.text('ownerTransferTargetMustBeStaff');
  }
  if (message.contains('owner limit reached')) {
    return context.l10n.text('ownerTransferOwnerCap');
  }
  if (message.contains('no longer active')) {
    return context.l10n.text('ownerTransferNoLongerActive');
  }
  return context.l10n.text('ownershipTransferRequestFailed');
}

String _ownerTransferAcceptError(
  BuildContext context,
  PostgrestException error,
) {
  final message = error.message.toLowerCase();
  if (message.contains('owner limit reached')) {
    return context.l10n.text('ownerTransferOwnerCap');
  }
  if (message.contains('no longer active')) {
    return context.l10n.text('ownerTransferNoLongerActive');
  }
  return context.l10n.text('acceptOwnershipFailed');
}

String _deletionReasonsText(
  BuildContext context,
  List<DeletionReason> reasons, {
  required String fallbackKey,
}) => reasons.isEmpty
    ? context.l10n.text(fallbackKey)
    : reasons.map((reason) => context.l10n.text(reason.messageKey)).join('\n');
