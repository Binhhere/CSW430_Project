import 'package:flutter/material.dart';

import '../app/relay_ui.dart';
import '../app/theme.dart';
import 'ledger_feedback.dart';
import 'request_timeout.dart';

enum LedgerPagePresentation { screen, embedded }

class LedgerPage extends StatelessWidget {
  const LedgerPage({
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.leading,
    this.presentation = LedgerPagePresentation.screen,
    this.embeddedSurfaceSafeArea = false,
    this.showEmbeddedHeader = true,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? leading;
  final LedgerPagePresentation presentation;
  final bool embeddedSurfaceSafeArea;
  final bool showEmbeddedHeader;

  @override
  Widget build(BuildContext context) {
    if (presentation == LedgerPagePresentation.embedded) {
      final safeAreaWrappedPage = DecoratedBox(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Column(
          children: [
            if (showEmbeddedHeader) ...[
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: !embeddedSurfaceSafeArea,
                  bottom: false,
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        leading ?? const SizedBox(width: 16),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).appBarTheme.titleTextStyle,
                            ),
                          ),
                        ),
                        ...?actions,
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: SafeArea(
                top: !embeddedSurfaceSafeArea && !showEmbeddedHeader,
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth >= 840
                            ? 760
                            : double.infinity,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  bottom: !embeddedSurfaceSafeArea,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: bottom,
                  ),
                ),
              ),
          ],
        ),
      );
      return embeddedSurfaceSafeArea
          ? SafeArea(left: false, right: false, child: safeAreaWrappedPage)
          : safeAreaWrappedPage;
    }
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Align(alignment: Alignment.centerLeft, child: Text(title)),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // The reference layouts retain a single readable ledger
                // column on large displays without changing phone density.
                maxWidth: constraints.maxWidth >= 720 ? 760 : double.infinity,
              ),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

class LedgerRefreshView extends StatelessWidget {
  const LedgerRefreshView({
    required this.onRefresh,
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => withRelayRequestTimeout(onRefresh()),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

class LedgerScrollSafeCenter extends StatelessWidget {
  const LedgerScrollSafeCenter({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: Padding(
          padding: padding,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class LedgerSection extends StatelessWidget {
  const LedgerSection({
    required this.title,
    required this.children,
    this.uppercaseTitle = true,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final bool uppercaseTitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          uppercaseTitle ? title.toUpperCase() : title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.relay.textMuted,
            fontWeight: uppercaseTitle ? null : FontWeight.w700,
            letterSpacing: uppercaseTitle ? 1 : .2,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: context.relay.structuralLine),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class LedgerRow extends StatelessWidget {
  const LedgerRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleColor,
    this.leadingBackground,
    this.leadingColor,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? titleColor;
  final Color? leadingBackground;
  final Color? leadingColor;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: context.relayAnimationsDisabled
        ? Duration.zero
        : RelayMotion.micro,
    curve: RelayMotion.easeOut,
    color: selected
        ? context.relay.selectionContainer.withValues(alpha: .5)
        : null,
    child: Material(
      color: Colors.transparent,
      child: RelayPressScale(
        enabled: onTap != null || onLongPress != null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return context.relay.selectionContainer.withValues(alpha: .42);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return context.relay.selectionContainer.withValues(alpha: .24);
            }
            return null;
          }),
          child: Semantics(
            button: onTap != null || onLongPress != null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    _LedgerRowLeading(
                      background: leadingBackground,
                      foreground: leadingColor,
                      child: leading!,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: titleColor),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: context.relay.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LedgerRowLeading extends StatelessWidget {
  const _LedgerRowLeading({
    required this.child,
    this.background,
    this.foreground,
  });
  final Widget child;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    if (child is! Icon) return SizedBox.square(dimension: 40, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? context.relay.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox.square(
        dimension: 40,
        child: IconTheme(
          data: IconThemeData(
            color: foreground ?? context.relay.textSecondary,
            size: 21,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
