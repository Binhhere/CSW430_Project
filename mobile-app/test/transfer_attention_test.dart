import 'package:flutter_test/flutter_test.dart';

import 'package:relay_av_demo/features/transfers/transfer_models.dart';

void main() {
  final today = DateTime(2026, 7, 26);

  test('outbound prepare becomes dispatch overdue after its start date', () {
    expect(
      deriveTransferAttention(
        direction: TransferDirection.toCustomer,
        status: TransferStatus.prepare,
        startDate: DateTime(2026, 7, 25),
        endDate: DateTime(2026, 7, 30),
        today: today,
      ),
      TransferAttention.dispatchOverdue,
    );
  });

  test('outbound in transit becomes delivery overdue after delivery date', () {
    expect(
      deriveTransferAttention(
        direction: TransferDirection.toCustomer,
        status: TransferStatus.inTransit,
        startDate: DateTime(2026, 7, 25),
        endDate: DateTime(2026, 7, 30),
        today: today,
      ),
      TransferAttention.deliveryOverdue,
    );
  });

  test('return in transit becomes return overdue after due-back date', () {
    expect(
      deriveTransferAttention(
        direction: TransferDirection.toWarehouse,
        status: TransferStatus.inTransit,
        startDate: DateTime(2026, 7, 24),
        endDate: DateTime(2026, 7, 25),
        today: today,
      ),
      TransferAttention.returnOverdue,
    );
  });

  test('done outbound without a return becomes return overdue', () {
    expect(
      deriveTransferAttention(
        direction: TransferDirection.toCustomer,
        status: TransferStatus.done,
        startDate: DateTime(2026, 7, 20),
        endDate: DateTime(2026, 7, 25),
        today: today,
      ),
      TransferAttention.returnOverdue,
    );
  });

  test('a due date is not overdue until the following day', () {
    expect(
      deriveTransferAttention(
        direction: TransferDirection.toCustomer,
        status: TransferStatus.inTransit,
        startDate: today,
        endDate: DateTime(2026, 7, 30),
        today: today,
      ),
      TransferAttention.none,
    );
  });
}
