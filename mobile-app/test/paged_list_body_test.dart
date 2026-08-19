import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/shared/paged_list_body.dart';

void main() {
  Widget host({
    List<int> items = const [],
    bool loading = false,
    Object? error,
  }) => MaterialApp(
    home: SizedBox(
      height: 400,
      child: PagedListBody<int>(
        items: items,
        loading: loading,
        error: error,
        hasMore: true,
        onRefresh: () async {},
        onRetry: () {},
        errorBuilder: (_) => const Text('error-state'),
        emptyBuilder: (_) => const Text('empty-state'),
        itemBuilder: (_, item) => Text('item-$item'),
        loadMoreBuilder: (_, {required loading, required hasMore}) =>
            const Text('load-more'),
      ),
    ),
  );

  testWidgets('renders loading, error, empty, and items', (tester) async {
    await tester.pumpWidget(host(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(host(error: StateError('network')));
    expect(find.text('error-state'), findsOneWidget);
    await tester.pumpWidget(host());
    expect(find.text('empty-state'), findsOneWidget);
    await tester.pumpWidget(host(items: [1, 2]));
    expect(find.text('item-1'), findsOneWidget);
    expect(find.text('load-more'), findsOneWidget);
  });
}
