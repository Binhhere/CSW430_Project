part of 'access_flow.dart';

class _AnnouncementBellButton extends StatefulWidget {
  const _AnnouncementBellButton({
    required this.unreadCount,
    required this.tooltip,
    required this.onPressed,
  });

  final int unreadCount;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_AnnouncementBellButton> createState() =>
      _AnnouncementBellButtonState();
}

class _AnnouncementBellButtonState extends State<_AnnouncementBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncPulse(bool shouldPulse) {
    if (shouldPulse) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
      return;
    }
    if (_controller.isAnimating) {
      _controller.stop();
    }
    if (_controller.value != 0) {
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldPulse = widget.unreadCount > 0 && !disableAnimations;
    _syncPulse(shouldPulse);
    final badgeLabel = widget.unreadCount > 99
        ? '99+'
        : widget.unreadCount.toString();
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.02).animate(
        CurvedAnimation(parent: _controller, curve: RelayMotion.easeInOut),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: context.relay.surface,
            elevation: 2,
            borderRadius: BorderRadius.circular(18),
            child: RelayTapFeedback(
              enabled: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onPressed,
                child: Semantics(
                  button: true,
                  label: widget.tooltip,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(
                      Icons.notifications_outlined,
                      color: context.relay.textPrimary,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.unreadCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.relay.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: context.relay.onActionPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeveloperAnnouncementsSheet extends ConsumerStatefulWidget {
  const _DeveloperAnnouncementsSheet();

  @override
  ConsumerState<_DeveloperAnnouncementsSheet> createState() =>
      _DeveloperAnnouncementsSheetState();
}

class _DeveloperAnnouncementsSheetState
    extends ConsumerState<_DeveloperAnnouncementsSheet> {
  bool _markingAllSeen = false;
  String? _busyAnnouncementId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(developerAnnouncementsProvider);
    final status = ref.watch(developerAnnouncementStatusProvider);
    final unreadCount = status.maybeWhen(
      data: (value) => value.unreadCount,
      orElse: () => 0,
    );
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.text('announcements'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _markingAllSeen ? null : _markAllSeen,
                      child: _markingAllSeen
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.l10n.text('seenAll')),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: RelayNotice(
                  message: _error!,
                  kind: RelayNoticeKind.danger,
                ),
              ),
            Expanded(
              child: announcements.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_outlined,
                              size: 36,
                              color: context.relay.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.text('noAnnouncements'),
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.l10n.text('noAnnouncementsBody'),
                              style: TextStyle(
                                color: context.relay.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final languageCode = Localizations.localeOf(
                    context,
                  ).languageCode;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final busy = _busyAnnouncementId == item.id;
                      return Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: busy ? null : () => _openAnnouncement(item),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  item.isUnread
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_none_outlined,
                                  color: item.isUnread
                                      ? context.relay.danger
                                      : context.relay.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.titleFor(languageCode),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: item.isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.l10n.date(item.publishedAt),
                                        style: TextStyle(
                                          color: context.relay.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.bodyFor(languageCode),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.relay.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                busy
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: items.length,
                  );
                },
                loading: () => Center(
                  child: Text(context.l10n.text('loadingAnnouncements')),
                ),
                error: (_, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      context.l10n.text('announcementsLoadFailed'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllSeen() async {
    if (_markingAllSeen) return;
    setState(() {
      _markingAllSeen = true;
      _error = null;
    });
    var remoteSucceeded = false;
    try {
      final repository = ref.read(accessRepositoryProvider);
      await repository.markAllDeveloperAnnouncementsSeen();
      remoteSucceeded = true;
      final userId = repository.session?.user.id;
      if (userId != null) {
        await markAllBundledAnnouncementsSeen(userId);
      }
      _invalidateDeveloperAnnouncementProviders(ref);
    } catch (_) {
      if (remoteSucceeded) {
        _invalidateDeveloperAnnouncementProviders(ref);
      }
      if (mounted) {
        setState(() {
          _error = context.l10n.text('announcementsSeenAllFailed');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _markingAllSeen = false);
      }
    }
  }

  Future<void> _openAnnouncement(DeveloperAnnouncement announcement) async {
    if (_busyAnnouncementId != null) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    final repository = ref.read(accessRepositoryProvider);
    setState(() {
      _busyAnnouncementId = announcement.id;
      _error = null;
    });
    try {
      if (announcement.isUnread) {
        if (announcement.isBundled) {
          final userId = repository.session?.user.id;
          if (userId == null) {
            throw StateError('Session expired');
          }
          await markBundledAnnouncementSeen(
            userId,
            announcement.announcementKey,
          );
        } else {
          await repository.markDeveloperAnnouncementSeen(announcement.id);
        }
        _invalidateDeveloperAnnouncementProviders(ref);
      }
      if (!mounted) return;
      await showRelayDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(announcement.titleFor(languageCode)),
          content: SingleChildScrollView(
            child: Text(announcement.bodyFor(languageCode)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.text('ok')),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.text('announcementMarkSeenFailed');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busyAnnouncementId = null);
      }
    }
  }
}

void _invalidateDeveloperAnnouncementProviders(WidgetRef ref) {
  ref.invalidate(developerAnnouncementsProvider);
  ref.invalidate(developerAnnouncementStatusProvider);
}
