import 'package:flutter/material.dart';

import '../app/relay_ui.dart';

class DirtyFormController {
  bool _allowPop = false;

  bool canPop({required bool busy, required bool dirty}) =>
      _allowPop || (!busy && !dirty);

  void allowPop() {
    _allowPop = true;
  }

  Future<void> handlePopInvoked({
    required BuildContext context,
    required bool didPop,
    required bool busy,
    required bool dirty,
    required String title,
    required String body,
    required String discardLabel,
    required String keepEditingLabel,
    required VoidCallback onDiscard,
    bool keepEditingPrimary = false,
    ButtonStyle? discardButtonStyle,
  }) async {
    if (didPop || busy || !dirty) return;
    final discard =
        await showRelayDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: keepEditingPrimary
                ? [
                    OutlinedButton(
                      style: discardButtonStyle,
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(discardLabel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(keepEditingLabel),
                    ),
                  ]
                : [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(keepEditingLabel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(discardLabel),
                    ),
                  ],
          ),
        ) ??
        false;
    if (!discard || !context.mounted) return;
    _allowPop = true;
    onDiscard();
  }
}
