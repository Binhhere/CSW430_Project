import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/relay_localizations.dart';
import '../../shared/entity_lifecycle.dart';
import '../../shared/entity_lifecycle_actions.dart';
import 'catalog_repository.dart';

String lifecycleOperationLabel(
  BuildContext context,
  LifecycleEntityType entity,
  LifecycleOperation operation,
) {
  final prefix = entity == LifecycleEntityType.location
      ? 'Location'
      : 'Customer';
  final key = switch (operation) {
    LifecycleOperation.archive => 'archive$prefix',
    LifecycleOperation.restore => 'restore$prefix',
    LifecycleOperation.delete => 'delete$prefix',
  };
  return context.l10n.text(key);
}

String catalogLifecycleBody(
  BuildContext context,
  LifecycleEntityType entity,
  LifecycleOperation operation,
) {
  final key = switch ((entity, operation)) {
    (LifecycleEntityType.customer, LifecycleOperation.archive) =>
      'archiveCustomerBody',
    (LifecycleEntityType.customer, LifecycleOperation.restore) =>
      'restoreCustomerBody',
    (LifecycleEntityType.customer, LifecycleOperation.delete) =>
      'deleteCustomerBody',
    (LifecycleEntityType.location, LifecycleOperation.archive) =>
      'archiveLocationBody',
    (LifecycleEntityType.location, LifecycleOperation.restore) =>
      'restoreLocationBody',
    (LifecycleEntityType.location, LifecycleOperation.delete) =>
      'deleteLocationBody',
    _ => 'lifecycleConfirm',
  };
  return context.l10n.text(key);
}

String catalogBlockedMessage(
  BuildContext context,
  List<LifecyclePreview> blocked,
) => formatLifecycleBlockedMessage(
  template: context.l10n.text('lifecycleBlockedCount'),
  blocked: blocked,
);

void showCatalogLifecycleSnackBar(BuildContext context, String message) =>
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

Future<int?> executeCatalogLifecycle({
  required BuildContext context,
  required WidgetRef ref,
  required LifecycleEntityType entityType,
  required List<String> selectedIds,
  required LifecycleOperation operation,
  String? exactName,
  bool useOperationTitle = false,
}) => runLifecycleAction(
  context: context,
  loadPreview: () => ref
      .read(catalogRepositoryProvider)
      .previewLifecycle(
        entityType: entityType,
        ids: selectedIds,
        operation: operation,
      ),
  apply: (eligibleIds) => ref
      .read(catalogRepositoryProvider)
      .applyLifecycle(
        entityType: entityType,
        ids: eligibleIds,
        operation: operation,
      ),
  ownerOnlyMessage: context.l10n.text('lifecycleOwnerOnly'),
  nothingEligibleMessage: context.l10n.text('lifecycleNothingEligible'),
  confirmTitle: useOperationTitle
      ? lifecycleOperationLabel(context, entityType, operation)
      : context.l10n.text('lifecycleConfirm'),
  confirmationBody: (blocked) => blocked.isEmpty
      ? catalogLifecycleBody(context, entityType, operation)
      : '${catalogBlockedMessage(context, blocked)}\n\n'
            '${context.l10n.text('lifecycleContinueEligible')}',
  confirmLabel: lifecycleOperationLabel(context, entityType, operation),
  cancelLabel: context.l10n.text('cancel'),
  exactNameHint: context.l10n.text('lifecycleNameHint'),
  exactNameError: context.l10n.text('lifecycleNameMismatch'),
  exactName: exactName,
);
