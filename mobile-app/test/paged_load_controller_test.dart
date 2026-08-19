import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/shared/paged_load_controller.dart';

void main() {
  test('refresh replaces items while preserve keeps them visible', () async {
    var pages = <List<int>>[
      [1, 2],
      [3],
    ];
    final controller = PagedLoadController<int>(
      pageSize: 2,
      loadPage: ({required after, required offset}) async => pages.removeAt(0),
    );

    await controller.load(reset: true);
    expect(controller.items, [1, 2]);
    expect(controller.hasMore, isTrue);

    final refresh = controller.load(reset: true, preserveItems: true);
    expect(controller.items, [1, 2]);
    expect(controller.loading, isTrue);

    await refresh;
    expect(controller.items, [3]);
    expect(controller.hasMore, isFalse);
  });

  test('load next passes both cursor and offset', () async {
    final requests = <({int? after, int offset})>[];
    final controller = PagedLoadController<int>(
      pageSize: 2,
      loadPage: ({required after, required offset}) async {
        requests.add((after: after, offset: offset));
        return requests.length == 1 ? [4, 5] : [6];
      },
    );

    await controller.load(reset: true);
    await controller.load();

    expect(requests, [(after: null, offset: 0), (after: 5, offset: 2)]);
    expect(controller.items, [4, 5, 6]);
  });

  test('a stale refresh cannot overwrite the latest result', () async {
    final first = Completer<List<int>>();
    final second = Completer<List<int>>();
    var request = 0;
    final controller = PagedLoadController<int>(
      loadPage: ({required after, required offset}) {
        request++;
        return request == 1 ? first.future : second.future;
      },
    );

    final oldRefresh = controller.load(reset: true);
    final newRefresh = controller.load(reset: true);
    second.complete([2]);
    await newRefresh;
    first.complete([1]);
    await oldRefresh;

    expect(controller.items, [2]);
    expect(controller.loading, isFalse);
  });

  test('load-more failure preserves confirmed items and can retry', () async {
    var request = 0;
    final controller = PagedLoadController<int>(
      pageSize: 2,
      loadPage: ({required after, required offset}) async {
        request++;
        if (request == 1) return [1, 2];
        if (request == 2) throw StateError('network');
        return [3];
      },
    );

    await controller.load(reset: true);
    await controller.load();
    expect(controller.items, [1, 2]);
    expect(controller.error, isA<StateError>());

    await controller.load();
    expect(controller.items, [1, 2, 3]);
    expect(controller.error, isNull);
  });
}
