import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:relay_av_demo/shared/ledger_widgets.dart';

void main() {
  testWidgets(
    'scroll-safe centered state remains reachable in a keyboard-reduced viewport',
    (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: SizedBox(
              height: 180,
              child: LedgerScrollSafeCenter(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('No matching Transfers'),
                    const SizedBox(height: 4),
                    const Text(
                      'Create a Transfer when equipment needs to move.',
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () => cleared = true,
                      child: const Text('Clear search and filters'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Clear search and filters'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Clear search and filters'));

      expect(cleared, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh view works even when content is shorter than the screen',
    (tester) async {
      var refreshCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: LedgerRefreshView(
                onRefresh: () async {
                  refreshCount++;
                },
                child: const Center(child: Text('Short content')),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Short content'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
