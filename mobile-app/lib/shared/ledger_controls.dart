import 'package:flutter/material.dart';

import '../app/relay_ui.dart';
import '../app/theme.dart';

const relayListControlHeight = 44.0;
const relayListControlInset = 4.0;

class RelaySearchField extends StatefulWidget {
  const RelaySearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.clearTooltip,
    this.onCleared,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCleared;
  final String clearTooltip;
  final bool autofocus;

  @override
  State<RelaySearchField> createState() => _RelaySearchFieldState();
}

class _RelaySearchFieldState extends State<RelaySearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant RelaySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      maxLines: 1,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        constraints: const BoxConstraints.tightFor(height: 52),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        prefixIconConstraints: const BoxConstraints.tightFor(
          width: 44,
          height: 44,
        ),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 44,
          height: 44,
        ),
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: widget.clearTooltip,
                iconSize: 20,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
      ),
      onChanged: widget.onChanged,
    ),
  );
}

class RelayMenuOption<T> {
  const RelayMenuOption({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.selectedForegroundColor,
    this.selectedBackgroundColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
  final Color? selectedForegroundColor;
  final Color? selectedBackgroundColor;
}

class RelaySegmentedOption<T> {
  const RelaySegmentedOption({
    required this.value,
    required this.label,
    this.selectedForegroundColor,
    this.selectedBackgroundColor,
  });

  final T value;
  final String label;
  final Color? selectedForegroundColor;
  final Color? selectedBackgroundColor;
}

class RelaySingleSelectMenuButton<T> extends StatelessWidget {
  const RelaySingleSelectMenuButton({
    required this.label,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.active = false,
    this.buttonIcon,
    this.buttonIconColor,
    this.buttonIconBackgroundColor,
    this.tooltip,
    this.enabled = true,
    this.expand = false,
    this.maxWidth,
    this.activeForegroundColor,
    this.activeBackgroundColor,
    this.activeBorderColor,
    super.key,
  });

  final String label;
  final T selectedValue;
  final List<RelayMenuOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool active;
  final IconData? buttonIcon;
  final Color? buttonIconColor;
  final Color? buttonIconBackgroundColor;
  final String? tooltip;
  final bool enabled;
  final bool expand;
  final double? maxWidth;
  final Color? activeForegroundColor;
  final Color? activeBackgroundColor;
  final Color? activeBorderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final buttonLeadingColor =
        buttonIconColor ??
        (active ? palette.selectedContent : palette.textSecondary);
    final buttonLeadingBackground =
        buttonIconBackgroundColor ??
        (active ? palette.selectionContainer : palette.surfaceSubtle);
    final button = OutlinedButton(
      onPressed: () {},
      style: relayCompactControlStyle(
        context,
        selected: active,
        selectedForegroundColor: activeForegroundColor,
        selectedBackgroundColor: activeBackgroundColor,
        selectedBorderColor: activeBorderColor,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (buttonIcon != null) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: buttonLeadingBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(buttonIcon, size: 16, color: buttonLeadingColor),
            ),
            const SizedBox(width: 8),
          ],
          if (expand)
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          else
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );

    final selectedIndex = options.indexWhere(
      (option) => option.value == selectedValue,
    );

    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: tooltip ?? label,
      initialValue: selectedIndex >= 0 ? selectedIndex : null,
      position: PopupMenuPosition.under,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.structuralLine),
      ),
      onSelected: (index) => onSelected(options[index].value),
      itemBuilder: (context) => [
        for (var index = 0; index < options.length; index++)
          PopupMenuItem<int>(
            value: index,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _RelayMenuOptionTile<T>(
              option: options[index],
              selected: options[index].value == selectedValue,
            ),
          ),
      ],
      child: IgnorePointer(
        child: SizedBox(
          width: expand ? double.infinity : null,
          child: maxWidth == null
              ? button
              : ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth!),
                  child: button,
                ),
        ),
      ),
    );
  }
}

class RelaySegmentedControl<T> extends StatelessWidget {
  const RelaySegmentedControl({
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.tooltip,
    super.key,
  });

  final T selectedValue;
  final List<RelaySegmentedOption<T>> options;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final child = SizedBox(
      height: relayListControlHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          border: Border.all(color: palette.controlBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.all(relayListControlInset),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                _RelaySegmentButton<T>(
                  option: options[index],
                  selected: options[index].value == selectedValue,
                  onPressed: () => onSelected(options[index].value),
                ),
                if (index != options.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class _RelaySegmentButton<T> extends StatelessWidget {
  const _RelaySegmentButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final RelaySegmentedOption<T> option;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final foregroundColor = selected
        ? (option.selectedForegroundColor ?? palette.textPrimary)
        : palette.textSecondary;
    final backgroundColor = selected
        ? (option.selectedBackgroundColor ?? palette.surfaceRaised)
        : Colors.transparent;
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(0, relayListControlHeight - (relayListControlInset * 2)),
        ),
        maximumSize: const WidgetStatePropertyAll(
          Size(
            double.infinity,
            relayListControlHeight - (relayListControlInset * 2),
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width <= 380 ? 10 : 14,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        backgroundColor: WidgetStatePropertyAll(backgroundColor),
        foregroundColor: WidgetStatePropertyAll(foregroundColor),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge?.copyWith(
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: null,
          ),
        ),
      ),
      child: Text(option.label),
    );
  }
}

class _RelayMenuOptionTile<T> extends StatelessWidget {
  const _RelayMenuOptionTile({required this.option, required this.selected});

  final RelayMenuOption<T> option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final selectedForegroundColor =
        option.selectedForegroundColor ?? palette.selectedContent;
    final selectedBackgroundColor =
        option.selectedBackgroundColor ?? palette.selectionContainer;
    final iconBackground = selected
        ? selectedBackgroundColor
        : palette.surfaceSubtle;
    final iconColor = selected
        ? selectedForegroundColor
        : palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? selectedBackgroundColor.withValues(alpha: .5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (option.icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(option.icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? selectedForegroundColor : null,
                  ),
                ),
                if (option.subtitle?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      option.subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_rounded,
                size: 18,
                color: selectedForegroundColor,
              ),
            ),
        ],
      ),
    );
  }
}

class RelayActiveFilterBar extends StatelessWidget {
  const RelayActiveFilterBar({
    required this.labels,
    required this.clearLabel,
    required this.onClear,
    super.key,
  });

  final List<String> labels;
  final String clearLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final palette = context.relay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final label in labels)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surfaceSubtle,
                      border: Border.all(color: palette.controlBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 18),
            label: Text(clearLabel),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle relayCompactControlStyle(
  BuildContext context, {
  bool selected = false,
  Color? selectedForegroundColor,
  Color? selectedBackgroundColor,
  Color? selectedBorderColor,
}) {
  final palette = context.relay;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, relayListControlHeight)),
    maximumSize: const WidgetStatePropertyAll(
      Size(double.infinity, relayListControlHeight),
    ),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width <= 380 ? 10 : 14,
      ),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return palette.disabledSurface;
      }
      return selected
          ? (selectedBackgroundColor ?? palette.selectionContainer)
          : palette.surface;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return palette.disabledContent;
      }
      return selected
          ? (selectedForegroundColor ?? palette.selectedContent)
          : palette.textPrimary;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return palette.selectionContainer.withValues(alpha: .55);
      }
      return null;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: palette.disabledBorder);
      }
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: palette.controlBorderFocused, width: 2);
      }
      return BorderSide(
        color: selected
            ? (selectedBorderColor ??
                  selectedForegroundColor ??
                  palette.selectedContent)
            : palette.controlBorder,
        width: selected ? 1.5 : 1,
      );
    }),
    textStyle: WidgetStatePropertyAll(
      Theme.of(context).textTheme.labelLarge?.copyWith(
        height: 1.43,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: null,
      ),
    ),
  );
}

/// Keeps list filters intrinsic-width while allowing narrow phones to wrap.
class RelayListControlRow extends StatelessWidget {
  const RelayListControlRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: children.length == 1
            ? WrapAlignment.end
            : WrapAlignment.spaceBetween,
        spacing: MediaQuery.sizeOf(context).width <= 380 ? 8 : 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    ),
  );
}

/// The compact operational control strip used by server-backed lists.
/// It wraps on narrow phones instead of shrinking controls below touch size.
class LedgerActionStrip extends StatelessWidget {
  const LedgerActionStrip({
    required this.children,
    this.alignment = WrapAlignment.start,
    super.key,
  });

  final List<Widget> children;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: alignment,
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    ),
  );
}

class RelayStateSwitcher extends StatelessWidget {
  const RelayStateSwitcher({
    required this.child,
    this.duration = RelayMotion.micro,
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (context.relayAnimationsDisabled) {
      return KeyedSubtree(key: child.key, child: child);
    }
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: RelayMotion.easeOut,
      switchOutCurve: RelayMotion.easeInOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
