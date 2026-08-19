import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/shared/entity_lifecycle_actions.dart';
import 'package:relay_av_demo/shared/entity_lifecycle.dart';

void main() {
  test('blocked lifecycle summary aggregates every reason count', () {
    final message = formatLifecycleBlockedMessage(
      template:
          '{blocked} blocked: {active} active, {history} history, '
          '{dependencies} dependencies',
      blocked: const [
        LifecyclePreview(
          entityType: 'ASSET',
          entityId: 'one',
          entityName: 'One',
          eligible: false,
          activeTransferCount: 2,
          historicalReferenceCount: 3,
          dependencyCount: 4,
        ),
        LifecyclePreview(
          entityType: 'ASSET',
          entityId: 'two',
          entityName: 'Two',
          eligible: false,
          activeTransferCount: 5,
          historicalReferenceCount: 6,
          dependencyCount: 7,
        ),
      ],
    );

    expect(message, '2 blocked: 7 active, 9 history, 11 dependencies');
  });

  testWidgets('lifecycle confirmation returns false when cancelled', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await confirmLifecycleAction(
                  context: context,
                  title: 'Archive records',
                  body: 'Archive the selected records?',
                  confirmLabel: 'Archive',
                  cancelLabel: 'Cancel',
                  exactNameHint: 'Name',
                  exactNameError: 'Name does not match',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('destructive lifecycle confirmation requires exact name', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await confirmLifecycleAction(
                  context: context,
                  title: 'Delete record',
                  body: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                  exactNameHint: 'Type the exact name',
                  exactNameError: 'Name does not match',
                  exactName: 'Camera A',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Camera B');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    expect(find.text('Name does not match'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' Camera A ');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
