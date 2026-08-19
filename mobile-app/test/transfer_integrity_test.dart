import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/transfers/transfer_models.dart';

void main() {
  test('keeps a transfer visible when related rows are missing', () {
    final transfer = TransferRecord(
      id: 'transfer-1',
      companyId: 'company-1',
      direction: TransferDirection.toCustomer,
      status: TransferStatus.prepare,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 2),
      assignedStaffId: null,
      createdBy: 'user-1',
      integrityIssue: TransferIntegrityIssue.missingRelatedData,
    );

    expect(transfer.integrityIssue, TransferIntegrityIssue.missingRelatedData);
    expect(transfer.displayTitle, 'Transfer');
    expect(transfer.customerName, 'Unavailable');
    expect(transfer.originName, 'Unavailable');
    expect(transfer.destinationName, 'Unavailable');
  });
}
