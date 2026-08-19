import 'package:flutter/material.dart';

class LifecycleSelectionBar extends StatelessWidget {
  const LifecycleSelectionBar({
    required this.selectedCount,
    required this.selectedLabel,
    required this.cancelLabel,
    required this.onCancel,
    required this.actions,
    super.key,
  });

  final int selectedCount;
  final String selectedLabel;
  final String cancelLabel;
  final VoidCallback onCancel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: cancelLabel,
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                selectedLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    ),
  );
}

class LifecycleSelectionMark extends StatelessWidget {
  const LifecycleSelectionMark({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: Checkbox(value: selected, onChanged: null),
  );
}
