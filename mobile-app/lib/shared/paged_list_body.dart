import 'package:flutter/material.dart';

import 'ledger_widgets.dart';

class PagedListBody<T> extends StatelessWidget {
  const PagedListBody({
    required this.items,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRefresh,
    required this.onRetry,
    required this.errorBuilder,
    required this.emptyBuilder,
    required this.itemBuilder,
    required this.loadMoreBuilder,
    this.controller,
    this.separatorBuilder,
    this.padding,
    super.key,
  });

  final List<T> items;
  final bool loading;
  final Object? error;
  final bool hasMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final WidgetBuilder errorBuilder;
  final WidgetBuilder emptyBuilder;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(
    BuildContext context, {
    required bool loading,
    required bool hasMore,
  })
  loadMoreBuilder;
  final ScrollController? controller;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return RelayStateSwitcher(
        child: _refresh(
          const ValueKey('paged-loading'),
          LedgerRefreshView(
            onRefresh: onRefresh,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    if (error != null && items.isEmpty) {
      return RelayStateSwitcher(
        child: _refresh(
          const ValueKey('paged-error'),
          LedgerRefreshView(
            onRefresh: onRefresh,
            child: Center(child: errorBuilder(context)),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return RelayStateSwitcher(
        child: _refresh(
          const ValueKey('paged-empty'),
          LedgerRefreshView(onRefresh: onRefresh, child: emptyBuilder(context)),
        ),
      );
    }
    final count = items.length + 1;
    return RelayStateSwitcher(
      child: RefreshIndicator(
        key: const ValueKey('paged-content'),
        onRefresh: onRefresh,
        child: ListView.separated(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: count,
          separatorBuilder:
              separatorBuilder ?? (_, _) => const SizedBox.shrink(),
          itemBuilder: (context, index) {
            if (index == items.length) {
              if (error != null) return errorBuilder(context);
              return loadMoreBuilder(
                context,
                loading: loading,
                hasMore: hasMore,
              );
            }
            return itemBuilder(context, items[index]);
          },
        ),
      ),
    );
  }

  Widget _refresh(Key key, Widget child) =>
      KeyedSubtree(key: key, child: child);
}
