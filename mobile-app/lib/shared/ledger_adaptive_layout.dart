import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/relay_ui.dart';
import '../app/theme.dart';
import 'ledger_controls.dart';
import 'ledger_page.dart';

class RelayAdaptiveListDetail extends StatelessWidget {
  const RelayAdaptiveListDetail({
    required this.listPane,
    this.detailPane,
    this.placeholder,
    this.listPaneMaxWidth = 432,
    super.key,
  });

  final Widget listPane;
  final Widget? detailPane;
  final Widget? placeholder;
  final double listPaneMaxWidth;

  @override
  Widget build(BuildContext context) {
    if (!context.relayIsLargeProductivity) {
      return listPane;
    }
    final palette = context.relay;
    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = math.min<double>(
          listPaneMaxWidth,
          math.max<double>(360, constraints.maxWidth * .38),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: paneWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(right: BorderSide(color: palette.separator)),
                ),
                child: listPane,
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(color: palette.background),
                child: RelayStateSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey<Object?>(
                      detailPane?.key ?? 'relay-detail-placeholder',
                    ),
                    child:
                        detailPane ??
                        placeholder ??
                        LedgerScrollSafeCenter(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chevron_left,
                                size: 36,
                                color: palette.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Select a record',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
