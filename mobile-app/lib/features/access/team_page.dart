part of 'access_flow.dart';

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({required this.company, super.key});

  final RelayCompany company;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

enum _MemberManagementAction {
  transferOwnership,
  cancelOwnershipTransfer,
  removeAccess,
}

class _TeamPageState extends ConsumerState<TeamPage>
    with AppResumeRefreshMixin<TeamPage> {
  final _memberRequests = LatestRequestGate();
  final _invitationRequests = LatestRequestGate();
  final _ownerTransferRequests = LatestRequestGate();
  List<RelayMember>? _members;
  String? _membersError;
  bool _membersLoading = true;

  InvitationStatus? _invitationStatus;
  String? _invitationStatusError;
  bool _invitationStatusLoading = false;
  InvitationCode? _invitation;

  List<CompanyOwnerTransferRequest>? _ownerTransferRequestItems;
  String? _ownerTransferRequestsError;
  bool _ownerTransferRequestsLoading = false;

  bool _busy = false;
  String? _busyMemberId;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadAll);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && _busyMemberId == null,
    child: LedgerPage(
      title: context.l10n.text('team'),
      child: LedgerRefreshView(
        onRefresh: _refresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
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
            _buildMembersSection(context),
            _buildOwnerTransferSection(context),
            if (widget.company.isOwner) _buildInvitationSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );

  Widget _buildMembersSection(BuildContext context) {
    if (_membersLoading && _members == null) {
      return LedgerSection(
        title: context.l10n.text('currentTeam'),
        uppercaseTitle: false,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_members == null) {
      return LedgerSection(
        title: context.l10n.text('currentTeam'),
        uppercaseTitle: false,
        children: [
          LedgerRow(
            leading: const Icon(Icons.error_outline),
            title: context.l10n.text('teamLoadFailed'),
            subtitle: _membersError ?? context.l10n.text('tapToTryAgain'),
            trailing: const Icon(Icons.refresh),
            onTap: _loadMembers,
          ),
        ],
      );
    }

    final currentUserId = ref.read(accessRepositoryProvider).session?.user.id;
    return LedgerSection(
      title: context.l10n.text('currentTeam'),
      uppercaseTitle: false,
      children: [
        for (var index = 0; index < _members!.length; index++) ...[
          Builder(
            builder: (context) {
              final member = _members![index];
              final isSelf = member.userId == currentUserId;
              final canManage =
                  widget.company.isOwner && !member.isOwner && !isSelf;
              final initial = member.displayName.trim().isEmpty
                  ? '?'
                  : member.displayName.characters.first.toUpperCase();
              return LedgerRow(
                leading: CircleAvatar(
                  backgroundColor: context.relay.selectionContainer,
                  foregroundColor: context.relay.selectedContent,
                  child: Text(initial),
                ),
                title: isSelf ? context.l10n.text('you') : member.displayName,
                subtitle:
                    context.l10n.text(member.isOwner ? 'owner' : 'staff') +
                    (canManage
                        ? ' Â· ${context.l10n.text('tapToManage')}'
                        : ''),
                trailing: _busyMemberId == member.userId
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : canManage
                    ? const Icon(Icons.chevron_right_rounded)
                    : null,
                onTap: canManage && _busyMemberId == null && !_busy
                    ? () => _manageMember(member)
                    : null,
              );
            },
          ),
          if (index < _members!.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _buildOwnerTransferSection(BuildContext context) {
    final requests = _ownerTransferRequestItems;
    final latestRequest = requests == null || requests.isEmpty
        ? null
        : requests.first;
    final shouldShowSection =
        widget.company.isOwner ||
        latestRequest != null ||
        _ownerTransferRequestsLoading ||
        _ownerTransferRequestsError != null;
    if (!shouldShowSection) {
      return const SizedBox.shrink();
    }

    if (_ownerTransferRequestsLoading && requests == null) {
      return LedgerSection(
        title: context.l10n.text('ownershipTransfer'),
        uppercaseTitle: false,
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (requests == null && _ownerTransferRequestsError != null) {
      return LedgerSection(
        title: context.l10n.text('ownershipTransfer'),
        uppercaseTitle: false,
        children: [
          LedgerRow(
            leading: const Icon(Icons.error_outline),
            title: context.l10n.text('teamLoadFailed'),
            subtitle: context.l10n.text('tapToTryAgain'),
            trailing: const Icon(Icons.refresh),
            onTap: _loadOwnerTransferRequests,
          ),
        ],
      );
    }

    final children = <Widget>[
      LedgerRow(
        leading: const Icon(Icons.swap_horiz_outlined),
        leadingBackground: context.relay.selectionContainer,
        leadingColor: context.relay.selectedContent,
        title: context.l10n.text('ownershipTransfer'),
        subtitle: latestRequest == null
            ? context.l10n.text('ownershipTransferDescription')
            : _ownerTransferSummary(context, latestRequest),
      ),
    ];

    if (latestRequest?.canCancel == true) {
      children.add(
        LedgerRow(
          leading: Icon(Icons.close_outlined, color: context.relay.danger),
          leadingBackground: context.relay.danger.withValues(alpha: .12),
          leadingColor: context.relay.danger,
          title: context.l10n.text('cancelOwnershipTransfer'),
          titleColor: context.relay.danger,
          subtitle: _ownerTransferSummary(context, latestRequest!),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy || _busyMemberId != null
              ? null
              : () => _cancelOwnerTransfer(latestRequest),
        ),
      );
    }

    if (latestRequest?.canAccept == true) {
      children.add(
        LedgerRow(
          leading: const Icon(Icons.shield_outlined),
          leadingBackground: context.relay.selectionContainer,
          leadingColor: context.relay.selectedContent,
          title: context.l10n.text('acceptOwnership'),
          subtitle: _ownerTransferSummary(context, latestRequest!),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy || _busyMemberId != null
              ? null
              : () => _acceptOwnerTransfer(latestRequest),
        ),
      );
    }

    return LedgerSection(
      title: context.l10n.text('ownershipTransfer'),
      uppercaseTitle: false,
      children: children,
    );
  }

  Widget _buildInvitationSection(BuildContext context) {
    final actionsBlocked = _busy || _busyMemberId != null;
    final status = _invitationStatus;
    final active = _invitation != null || status?.active == true;
    final expiresAt = _invitation?.expiresAt ?? status?.expiresAt;
    final children = <Widget>[];

    if (_invitation != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: QrImageView(data: _invitation!.code, size: 180)),
              const SizedBox(height: 12),
              SelectableText(
                _invitation!.code,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontFamily: 'RelayMono'),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n
                    .text('expiresOn')
                    .replaceAll(
                      '{date}',
                      context.l10n.date(_invitation!.expiresAt),
                    ),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.relay.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: actionsBlocked ? null : _copyInvitation,
                icon: const Icon(Icons.copy_outlined),
                label: Text(context.l10n.text('copyCode')),
              ),
            ],
          ),
        ),
      );
    } else if (_invitationStatusLoading && status == null) {
      children.add(
        LedgerRow(
          leading: const Icon(Icons.key_outlined),
          title: context.l10n.text('loadingInvitationStatus'),
          trailing: const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_invitationStatusError != null && status == null) {
      children.add(
        LedgerRow(
          leading: const Icon(Icons.error_outline),
          title: context.l10n.text('invitationStatusLoadFailed'),
          subtitle: context.l10n.text('tapToTryAgain'),
          trailing: const Icon(Icons.refresh),
          onTap: _loadInvitationStatus,
        ),
      );
    } else {
      children.add(
        LedgerRow(
          leading: Icon(
            active ? Icons.key_outlined : Icons.key_off_outlined,
            color: active ? context.relay.selectedContent : null,
          ),
          leadingBackground: active ? context.relay.selectionContainer : null,
          title: context.l10n.text(
            active ? 'activeInvitation' : 'noActiveInvitation',
          ),
          subtitle: active
              ? expiresAt == null
                    ? context.l10n.text('rotateRevealCode')
                    : context.l10n
                          .text('validUntilRotate')
                          .replaceAll('{date}', context.l10n.date(expiresAt))
              : context.l10n.text('createPrivateInvitationCode'),
        ),
      );
    }

    children.add(
      LedgerRow(
        leading: Icon(active ? Icons.refresh_outlined : Icons.add_link),
        leadingBackground: context.relay.selectionContainer,
        leadingColor: context.relay.selectedContent,
        title: context.l10n.text(
          active ? 'rotateInvitationCode' : 'createInvitationCode',
        ),
        subtitle: active
            ? context.l10n.text('previousCodeStops')
            : context.l10n.text('newCodeSevenDays'),
        trailing: const Icon(Icons.chevron_right),
        onTap: actionsBlocked ? null : _rotate,
      ),
    );
    if (active) {
      children.add(
        LedgerRow(
          leading: Icon(Icons.block_outlined, color: context.relay.danger),
          leadingBackground: context.relay.danger.withValues(alpha: .12),
          leadingColor: context.relay.danger,
          title: context.l10n.text('revokeInvitation'),
          titleColor: context.relay.danger,
          subtitle: context.l10n.text('revokeInvitationBody'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: actionsBlocked ? null : _revoke,
        ),
      );
    }

    return LedgerSection(
      title: context.l10n.text('invitation'),
      uppercaseTitle: false,
      children: children,
    );
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadMembers(),
      _loadOwnerTransferRequests(),
      if (widget.company.isOwner) _loadInvitationStatus(),
    ]);
  }

  Future<void> _refresh() async {
    if (_busy || _busyMemberId != null) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    await _loadAll();
  }

  Future<void> _loadMembers() async {
    final request = _memberRequests.begin();
    if (mounted) {
      setState(() {
        _membersLoading = true;
        _membersError = null;
      });
    }
    try {
      final members = await ref
          .read(accessRepositoryProvider)
          .members(widget.company.id);
      if (mounted && _memberRequests.isCurrent(request)) {
        setState(() => _members = members);
      }
    } catch (_) {
      if (mounted && _memberRequests.isCurrent(request)) {
        setState(() {
          if (_members == null) {
            _membersError = context.l10n.text('pullOrTapRetry');
          } else {
            _error = context.l10n.text('teamRefreshFailed');
          }
        });
      }
    } finally {
      if (mounted && _memberRequests.isCurrent(request)) {
        setState(() => _membersLoading = false);
      }
    }
  }

  Future<void> _loadOwnerTransferRequests() async {
    final request = _ownerTransferRequests.begin();
    if (mounted) {
      setState(() {
        _ownerTransferRequestsLoading = true;
        _ownerTransferRequestsError = null;
      });
    }
    try {
      final items = await ref
          .read(accessRepositoryProvider)
          .ownerTransferRequests(widget.company.id);
      if (mounted && _ownerTransferRequests.isCurrent(request)) {
        setState(() => _ownerTransferRequestItems = items);
      }
    } catch (_) {
      if (mounted && _ownerTransferRequests.isCurrent(request)) {
        setState(() {
          if (_ownerTransferRequestItems == null) {
            _ownerTransferRequestsError = context.l10n.text('pullOrTapRetry');
          } else {
            _error = context.l10n.text('teamRefreshFailed');
          }
        });
      }
    } finally {
      if (mounted && _ownerTransferRequests.isCurrent(request)) {
        setState(() => _ownerTransferRequestsLoading = false);
      }
    }
  }

  CompanyOwnerTransferRequest? _pendingOwnerTransferForMember(String userId) {
    for (final item
        in _ownerTransferRequestItems ??
            const <CompanyOwnerTransferRequest>[]) {
      if (item.targetUserId == userId && item.isPending) {
        return item;
      }
    }
    return null;
  }

  String _ownerTransferSummary(
    BuildContext context,
    CompanyOwnerTransferRequest request,
  ) {
    return switch (request.state) {
      CompanyOwnerTransferRequestState.pending =>
        request.canAccept
            ? context.l10n
                  .text('ownershipTransferPendingFrom')
                  .replaceAll('{member}', request.requestedByDisplayName)
                  .replaceAll('{date}', context.l10n.date(request.expiresAt))
            : context.l10n
                  .text('ownershipTransferPendingFor')
                  .replaceAll('{member}', request.targetDisplayName)
                  .replaceAll('{date}', context.l10n.date(request.expiresAt)),
      CompanyOwnerTransferRequestState.accepted => context.l10n.text(
        'ownershipTransferAcceptedState',
      ),
      CompanyOwnerTransferRequestState.cancelled => context.l10n.text(
        'ownershipTransferCancelledState',
      ),
      CompanyOwnerTransferRequestState.expired => context.l10n.text(
        'ownershipTransferExpiredState',
      ),
    };
  }

  Future<void> _manageMember(RelayMember member) async {
    if (_busy || _busyMemberId != null) return;
    final pendingRequest = _pendingOwnerTransferForMember(member.userId);
    final action = await showRelayDialog<_MemberManagementAction>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(member.displayName),
        children: [
          if (pendingRequest?.canCancel == true)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                dialogContext,
                _MemberManagementAction.cancelOwnershipTransfer,
              ),
              child: Text(context.l10n.text('cancelOwnershipTransfer')),
            )
          else
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                dialogContext,
                _MemberManagementAction.transferOwnership,
              ),
              child: Text(context.l10n.text('transferOwnership')),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogContext,
              _MemberManagementAction.removeAccess,
            ),
            child: Text(
              context.l10n.text('removeAccess'),
              style: TextStyle(color: context.relay.danger),
            ),
          ),
        ],
      ),
    );
    if (action == null) return;
    if (action == _MemberManagementAction.transferOwnership) {
      await _requestOwnerTransfer(member);
      return;
    }
    if (action == _MemberManagementAction.cancelOwnershipTransfer) {
      if (pendingRequest != null) {
        await _cancelOwnerTransfer(pendingRequest);
      }
      return;
    }
    await _removeMember(member);
  }

  Future<void> _requestOwnerTransfer(RelayMember member) async {
    if (_busy || _busyMemberId != null) return;
    final confirmed =
        await showRelayDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.text('transferOwnershipTitle')),
            content: Text(
              context.l10n
                  .text('transferOwnershipBody')
                  .replaceAll('{member}', member.displayName)
                  .replaceAll('{company}', widget.company.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.text('transferOwnership')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    _ownerTransferRequests.invalidate();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(accessRepositoryProvider)
          .requestCompanyOwnerTransfer(widget.company.id, member.userId);
      await _loadOwnerTransferRequests();
      if (!mounted) return;
      setState(() {
        _notice = context.l10n
            .text('ownershipTransferRequestSent')
            .replaceAll('{member}', member.displayName);
      });
      await RelayHaptics.success();
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = _ownerTransferRequestError(context, error));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.l10n.text('ownershipTransferRequestFailed'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelOwnerTransfer(CompanyOwnerTransferRequest request) async {
    if (_busy || _busyMemberId != null) return;
    final confirmed =
        await showRelayDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.text('cancelOwnershipTransferTitle')),
            content: Text(
              context.l10n
                  .text('cancelOwnershipTransferBody')
                  .replaceAll('{member}', request.targetDisplayName),
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
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.text('cancelOwnershipTransfer')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    _ownerTransferRequests.invalidate();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(accessRepositoryProvider)
          .cancelCompanyOwnerTransferRequest(request.requestId);
      await _loadOwnerTransferRequests();
      if (!mounted) return;
      setState(() {
        _notice = context.l10n.text('ownershipTransferCancelled');
      });
      await RelayHaptics.confirm();
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = _ownerTransferRequestError(context, error));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.l10n.text('cancelOwnershipTransferFailed'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptOwnerTransfer(CompanyOwnerTransferRequest request) async {
    if (_busy || _busyMemberId != null) return;
    final confirmed =
        await showRelayDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.text('acceptOwnershipTitle')),
            content: Text(
              context.l10n
                  .text('acceptOwnershipBody')
                  .replaceAll('{company}', widget.company.name)
                  .replaceAll('{member}', request.requestedByDisplayName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.text('acceptOwnership')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    _ownerTransferRequests.invalidate();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(accessRepositoryProvider)
          .acceptCompanyOwnerTransferRequest(request.requestId);
      ref.invalidate(accessCompaniesProvider);
      if (!mounted) return;
      Navigator.pop(context, context.l10n.text('ownershipTransferredToYou'));
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = _ownerTransferAcceptError(context, error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.text('acceptOwnershipFailed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadInvitationStatus() async {
    if (!widget.company.isOwner) return;
    final request = _invitationRequests.begin();
    if (mounted) {
      setState(() {
        _invitationStatusLoading = true;
        _invitationStatusError = null;
      });
    }
    try {
      final status = await ref
          .read(accessRepositoryProvider)
          .invitationStatus(widget.company.id);
      if (mounted && _invitationRequests.isCurrent(request)) {
        setState(() => _invitationStatus = status);
      }
    } catch (_) {
      if (mounted && _invitationRequests.isCurrent(request)) {
        setState(() {
          if (_invitationStatus == null) {
            _invitationStatusError = context.l10n.text('statusLoadFailed');
          } else {
            _error = context.l10n.text('invitationStatusRefreshFailed');
          }
        });
      }
    } finally {
      if (mounted && _invitationRequests.isCurrent(request)) {
        setState(() => _invitationStatusLoading = false);
      }
    }
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_busy || _busyMemberId != null) return;
    await _refresh();
  }

  Future<void> _rotate() async {
    if (_busy || _busyMemberId != null) return;
    final active = _invitation != null || _invitationStatus?.active == true;
    if (active) {
      final confirmed =
          await showRelayDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.text('rotateInvitationTitle')),
              content: Text(context.l10n.text('rotateInvitationWarning')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.text('keepCurrentCode')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.text('rotateCode')),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    _invitationRequests.invalidate();
    setState(() {
      _busy = true;
      _invitationStatusLoading = false;
      _error = null;
      _notice = null;
    });
    try {
      final invitation = await ref
          .read(accessRepositoryProvider)
          .rotateInvitation(widget.company.id);
      if (mounted) {
        setState(() {
          _invitation = invitation;
          _invitationStatus = InvitationStatus(
            active: true,
            expiresAt: invitation.expiresAt,
          );
          _notice = context.l10n.text(
            active ? 'invitationCodeRotated' : 'invitationCodeCreated',
          );
        });
        await RelayHaptics.success();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == '23514'
              ? context.l10n.text('noCompanySeat')
              : context.l10n.text('invitationCreateFailed'),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.text('invitationCreateFailed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInvitation() async {
    if (_busy || _busyMemberId != null) return;
    final invitation = _invitation;
    if (invitation == null) return;
    await Clipboard.setData(ClipboardData(text: invitation.code));
    if (!mounted) return;
    setState(() {
      _error = null;
      _notice = context.l10n.text('invitationCodeCopied');
    });
  }

  Future<void> _revoke() async {
    if (_busy || _busyMemberId != null) return;
    final confirmed =
        await showRelayDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.text('revokeInvitationTitle')),
            content: Text(
              context.l10n
                  .text('revokeCompanyInvitationBody')
                  .replaceAll('{company}', widget.company.name),
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
                child: Text(context.l10n.text('revokeInvitation')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    _invitationRequests.invalidate();
    setState(() {
      _busy = true;
      _invitationStatusLoading = false;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(accessRepositoryProvider)
          .revokeInvitation(widget.company.id);
      if (mounted) {
        setState(() {
          _invitation = null;
          _invitationStatus = const InvitationStatus(active: false);
          _notice = context.l10n.text('invitationRevoked');
        });
        await RelayHaptics.confirm();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.text('invitationRevokeFailed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(RelayMember member) async {
    if (_busy || _busyMemberId != null) return;
    final confirmed =
        await showRelayDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.text('removeStaffTitle')),
            content: Text(
              context.l10n
                  .text('removeStaffBody')
                  .replaceAll('{member}', member.displayName)
                  .replaceAll('{company}', widget.company.name),
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
                child: Text(context.l10n.text('removeAccess')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    _memberRequests.invalidate();
    setState(() {
      _busyMemberId = member.userId;
      _membersLoading = false;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(accessRepositoryProvider)
          .removeStaffMember(widget.company.id, member.userId);
      if (!mounted) return;
      setState(() {
        _members = [
          for (final item in _members ?? const <RelayMember>[])
            if (item.userId != member.userId) item,
        ];
        _notice = context.l10n
            .text('staffRemoved')
            .replaceAll('{member}', member.displayName);
      });
      await RelayHaptics.confirm();
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = _removeMemberError(context, error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.text('removeStaffFailed'));
      }
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }
}
