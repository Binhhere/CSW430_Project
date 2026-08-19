import 'package:flutter/material.dart';

import '../app/relay_ui.dart';
import 'entity_lifecycle.dart';

typedef LifecyclePreviewLoader = Future<List<LifecyclePreview>> Function();
typedef LifecycleApplier =
    Future<List<LifecycleResult>> Function(List<String> eligibleIds);

Future<int?> runLifecycleAction({
  required BuildContext context,
  required LifecyclePreviewLoader loadPreview,
  required LifecycleApplier apply,
  required String ownerOnlyMessage,
  required String nothingEligibleMessage,
  required String confirmTitle,
  required String Function(List<LifecyclePreview> blocked) confirmationBody,
  required String confirmLabel,
  required String cancelLabel,
  required String exactNameHint,
  required String exactNameError,
  String? exactName,
  void Function(String message)? showUnavailable,
}) async {
  final previews = await loadPreview();
  if (!context.mounted) return null;

  final eligible = previews.where((item) => item.eligible).toList();
  final blocked = previews.where((item) => !item.eligible).toList();
  if (eligible.isEmpty) {
    final message = blocked.any((item) => item.reason == 'OWNER_ONLY')
        ? ownerOnlyMessage
        : nothingEligibleMessage;
    if (showUnavailable != null) {
      showUnavailable(message);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return null;
  }

  final confirmed = await confirmLifecycleAction(
    context: context,
    title: confirmTitle,
    body: confirmationBody(blocked),
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    exactNameHint: exactNameHint,
    exactNameError: exactNameError,
    exactName: exactName,
  );
  if (!confirmed || !context.mounted) return null;

  final results = await apply(
    eligible.map((item) => item.entityId).toList(growable: false),
  );
  return results.where((item) => item.applied).length;
}

String formatLifecycleBlockedMessage({
  required String template,
  required List<LifecyclePreview> blocked,
}) {
  final active = blocked.fold<int>(
    0,
    (sum, item) => sum + item.activeTransferCount,
  );
  final history = blocked.fold<int>(
    0,
    (sum, item) => sum + item.historicalReferenceCount,
  );
  final dependencies = blocked.fold<int>(
    0,
    (sum, item) => sum + item.dependencyCount,
  );
  return template
      .replaceAll('{blocked}', '${blocked.length}')
      .replaceAll('{active}', '$active')
      .replaceAll('{history}', '$history')
      .replaceAll('{dependencies}', '$dependencies');
}

Future<bool> confirmLifecycleAction({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  required String exactNameHint,
  required String exactNameError,
  String? exactName,
}) async {
  final confirmed = await showRelayDialog<bool>(
    context: context,
    builder: (context) => _LifecycleConfirmationDialog(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      exactNameHint: exactNameHint,
      exactNameError: exactNameError,
      exactName: exactName,
    ),
  );
  return confirmed == true;
}

class _LifecycleConfirmationDialog extends StatefulWidget {
  const _LifecycleConfirmationDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.exactNameHint,
    required this.exactNameError,
    required this.exactName,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final String exactNameHint;
  final String exactNameError;
  final String? exactName;

  @override
  State<_LifecycleConfirmationDialog> createState() =>
      _LifecycleConfirmationDialogState();
}

class _LifecycleConfirmationDialogState
    extends State<_LifecycleConfirmationDialog> {
  TextEditingController? _controller;
  late bool _matches;

  @override
  void initState() {
    super.initState();
    _matches = widget.exactName == null;
    if (widget.exactName != null) {
      _controller = TextEditingController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.body),
        if (_controller != null) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.exactNameHint,
              errorText: _matches ? null : widget.exactNameError,
            ),
            onChanged: (value) => setState(() {
              _matches = value.trim() == widget.exactName;
            }),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: _matches ? () => Navigator.pop(context, true) : null,
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
