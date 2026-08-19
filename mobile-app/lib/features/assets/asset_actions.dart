import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/relay_localizations.dart';
import '../../shared/entity_lifecycle.dart';
import '../../shared/entity_lifecycle_actions.dart';
import 'asset_repository.dart';

Future<int?> executeAssetLifecycle({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> selectedIds,
  required LifecycleOperation operation,
  String? exactName,
  bool useOperationTitle = false,
  void Function(String message)? showUnavailable,
}) => runLifecycleAction(
  context: context,
  loadPreview: () => ref
      .read(assetCatalogRepositoryProvider)
      .previewLifecycle(ids: selectedIds, operation: operation),
  apply: (eligibleIds) => ref
      .read(assetCatalogRepositoryProvider)
      .applyLifecycle(ids: eligibleIds, operation: operation),
  ownerOnlyMessage: context.l10n.text('lifecycleOwnerOnly'),
  nothingEligibleMessage: context.l10n.text('lifecycleNothingEligible'),
  confirmTitle: useOperationTitle
      ? context.l10n.text(
          operation == LifecycleOperation.archive
              ? 'archiveAsset'
              : operation == LifecycleOperation.restore
              ? 'restoreAsset'
              : 'deleteAsset',
        )
      : context.l10n.text('lifecycleConfirm'),
  confirmationBody: (blocked) => blocked.isEmpty
      ? context.l10n.text(
          operation == LifecycleOperation.archive
              ? 'archiveAssetBody'
              : operation == LifecycleOperation.restore
              ? 'restoreAssetBody'
              : 'deleteAssetBody',
        )
      : '${formatLifecycleBlockedMessage(template: context.l10n.text('lifecycleBlockedCount'), blocked: blocked)}\n\n'
            '${context.l10n.text('lifecycleContinueEligible')}',
  confirmLabel: context.l10n.text(
    operation == LifecycleOperation.archive
        ? 'archiveAsset'
        : operation == LifecycleOperation.restore
        ? 'restoreAsset'
        : 'deleteAsset',
  ),
  cancelLabel: context.l10n.text('cancel'),
  exactNameHint: context.l10n.text('lifecycleNameHint'),
  exactNameError: context.l10n.text('lifecycleNameMismatch'),
  exactName: exactName,
  showUnavailable: showUnavailable,
);
