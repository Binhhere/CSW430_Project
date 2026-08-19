import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/transfers/transfer_models.dart';
import 'package:relay_av_demo/features/transfers/transfer_screens.dart';

void main() {
  final returnTransfer = TransferRecord(
    id: 'return-1',
    companyId: 'company-1',
    direction: TransferDirection.toWarehouse,
    status: TransferStatus.prepare,
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 2),
    assignedStaffId: 'staff-1',
    createdBy: 'owner-1',
  );

  test('create failure does not load or start a Return', () async {
    var createCalls = 0;
    var detailCalls = 0;
    var startCalls = 0;

    final result = await runFastReturnWorkflow(
      createReturn: () async {
        createCalls++;
        throw StateError('create failed');
      },
      loadReturn: (_) async {
        detailCalls++;
        return returnTransfer;
      },
      startReturn: (_) async => startCalls++,
    );

    expect(result.created, isFalse);
    expect(result.returnId, isNull);
    expect(result.started, isFalse);
    expect(result.failureStage, FastReturnFailureStage.create);
    expect(result.error, isA<StateError>());
    expect(result.stackTrace, isNotNull);
    expect(createCalls, 1);
    expect(detailCalls, 0);
    expect(startCalls, 0);
  });

  test(
    'detail failure preserves the created Return for opening or retry',
    () async {
      var createCalls = 0;
      var detailCalls = 0;
      var startCalls = 0;

      final result = await runFastReturnWorkflow(
        createReturn: () async {
          createCalls++;
          return returnTransfer.id;
        },
        loadReturn: (_) async {
          detailCalls++;
          throw StateError('detail failed');
        },
        startReturn: (_) async => startCalls++,
      );

      expect(result.created, isTrue);
      expect(result.returnId, returnTransfer.id);
      expect(result.started, isFalse);
      expect(result.failureStage, FastReturnFailureStage.detail);
      expect(result.error, isA<StateError>());
      expect(result.stackTrace, isNotNull);
      expect(result.returnTransfer, isNull);
      expect(createCalls, 1);
      expect(detailCalls, 1);
      expect(startCalls, 0);
    },
  );

  test(
    'start failure can retry start without creating a second Return',
    () async {
      var createCalls = 0;
      var detailCalls = 0;
      var startCalls = 0;
      var failFirstStart = true;

      final result = await runFastReturnWorkflow(
        createReturn: () async {
          createCalls++;
          return returnTransfer.id;
        },
        loadReturn: (_) async {
          detailCalls++;
          return returnTransfer;
        },
        startReturn: (_) async {
          startCalls++;
          if (failFirstStart) {
            failFirstStart = false;
            throw StateError('start failed');
          }
        },
      );

      expect(result.created, isTrue);
      expect(result.returnId, returnTransfer.id);
      expect(result.started, isFalse);
      expect(result.failureStage, FastReturnFailureStage.start);
      expect(result.returnTransfer, same(returnTransfer));
      expect(createCalls, 1);
      expect(detailCalls, 1);
      expect(startCalls, 1);

      final retry = await retryFastReturnStart(
        returnId: result.returnId!,
        returnTransfer: result.returnTransfer!,
        startReturn: (transfer) async {
          expect(transfer, same(returnTransfer));
          await Future<void>.value();
          startCalls++;
        },
      );

      expect(retry.created, isTrue);
      expect(retry.returnId, returnTransfer.id);
      expect(retry.started, isTrue);
      expect(retry.failureStage, isNull);
      expect(createCalls, 1);
      expect(detailCalls, 1);
      expect(startCalls, 2);
    },
  );

  test(
    'successful Return creation, detail, and start keeps the success result',
    () async {
      var createCalls = 0;
      var detailCalls = 0;
      var startCalls = 0;

      final result = await runFastReturnWorkflow(
        createReturn: () async {
          createCalls++;
          return returnTransfer.id;
        },
        loadReturn: (_) async {
          detailCalls++;
          return returnTransfer;
        },
        startReturn: (_) async => startCalls++,
      );

      expect(result.created, isTrue);
      expect(result.returnId, returnTransfer.id);
      expect(result.started, isTrue);
      expect(result.failureStage, isNull);
      expect(result.error, isNull);
      expect(result.stackTrace, isNull);
      expect(createCalls, 1);
      expect(detailCalls, 1);
      expect(startCalls, 1);
    },
  );
}
