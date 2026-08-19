part of 'access_flow.dart';

class _CompanyListAction {
  const _CompanyListAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
}

class _CompanyListActionMenu extends StatefulWidget {
  const _CompanyListActionMenu({required this.actions, super.key})
    : assert(actions.length == 3);

  final List<_CompanyListAction> actions;

  @override
  State<_CompanyListActionMenu> createState() => _CompanyListActionMenuState();
}

class _CompanyListActionMenuState extends State<_CompanyListActionMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  final _intervals = const [
    Interval(0, .72, curve: RelayMotion.easeOut),
    Interval(.14, .86, curve: RelayMotion.easeOut),
    Interval(.28, 1, curve: RelayMotion.easeOut),
  ];
  var _menuOpen = false;

  bool get _open => _menuOpen;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _menuOpen = !_menuOpen);
    if (context.relayAnimationsDisabled) {
      _controller.value = _menuOpen ? 1 : 0;
      return;
    }
    if (_menuOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return AnimatedContainer(
      duration: context.relayAnimationsDisabled
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: RelayMotion.easeOut,
      width: open ? 240 : 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < widget.actions.length; index++)
              _buildAction(context, widget.actions[index], index),
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                button: true,
                label: context.l10n.text('listActions'),
                toggled: open,
                child: Tooltip(
                  message: context.l10n.text('listActions'),
                  child: _circleButton(
                    context,
                    background: context.relay.actionPrimary,
                    foreground: context.relay.onActionPrimary,
                    onPressed: _toggle,
                    child: RotationTransition(
                      turns: Tween<double>(begin: 0, end: .125).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: RelayMotion.easeOut,
                        ),
                      ),
                      child: const Icon(Icons.add, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    _CompanyListAction action,
    int index,
  ) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: _intervals[index],
    );
    final distance = (index + 1) * 60.0;
    final enabled = action.onPressed != null;
    return Positioned(
      right: 68 + index * 60,
      bottom: 4,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => IgnorePointer(
          ignoring: !enabled || animation.value < .5,
          child: Semantics(
            hidden: animation.value < .5,
            button: enabled,
            label: action.label,
            child: Tooltip(
              message: action.label,
              child: Transform.translate(
                offset: Offset(distance * (1 - animation.value), 0),
                child: Opacity(
                  opacity: animation.value,
                  child: Transform.scale(
                    scale: .72 + .28 * animation.value,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
        child: _circleButton(
          context,
          background: context.relay.surface,
          foreground: enabled ? action.color : context.relay.disabledContent,
          border: context.relay.structuralLine,
          onPressed: action.onPressed,
          dimension: 48,
          child: Icon(action.icon, size: 23),
        ),
      ),
    );
  }

  Widget _circleButton(
    BuildContext context, {
    required Color background,
    required Color foreground,
    required VoidCallback? onPressed,
    required Widget child,
    double dimension = 56,
    Color? border,
  }) => Material(
    color: background,
    elevation: 2,
    shadowColor: context.relay.textPrimary.withValues(alpha: .18),
    shape: CircleBorder(
      side: border == null ? BorderSide.none : BorderSide(color: border),
    ),
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: dimension,
        child: IconTheme(
          data: IconThemeData(color: foreground, size: 24),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _CompanyNavigationRail extends StatelessWidget {
  const _CompanyNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.respectTopSafeArea,
    required this.respectBottomSafeArea,
  });

  final List<(String, IconData)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool respectTopSafeArea;
  final bool respectBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final width = (MediaQuery.sizeOf(context).width * .16)
        .clamp(112.0, 136.0)
        .toDouble();
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    final itemExtent = MediaQuery.textScalerOf(context).scale(12) > 14
        ? 84.0
        : 76.0;
    const itemGap = 8.0;
    final indicatorOffset = selectedIndex * (itemExtent + itemGap);
    final selectionDuration = context.relayAnimationsDisabled
        ? Duration.zero
        : _navSelectionDuration;
    return SafeArea(
      top: respectTopSafeArea,
      bottom: respectBottomSafeArea,
      left: false,
      right: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.navSurface,
          border: Border(right: BorderSide(color: palette.separator)),
        ),
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: SizedBox(
              height:
                  destinations.length * itemExtent +
                  (destinations.length - 1) * itemGap,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: selectionDuration,
                    curve: RelayMotion.easeOut,
                    top: indicatorOffset,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.navSelectedIndicator,
                          border: Border.all(color: palette.navSelectedBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox(height: itemExtent),
                      ),
                    ),
                  ),
                  for (var index = 0; index < destinations.length; index++)
                    Positioned(
                      top: index * (itemExtent + itemGap),
                      left: 0,
                      right: 0,
                      child: _RailDestinationButton(
                        label: context.l10n.text(destinations[index].$1),
                        icon: destinations[index].$2,
                        selected: index == selectedIndex,
                        itemExtent: itemExtent,
                        labelStyle: labelStyle,
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDestinationButton extends StatelessWidget {
  const _RailDestinationButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.itemExtent,
    required this.labelStyle,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final double itemExtent;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = context.relay.navSelected;
    final unselectedColor = context.relay.navUnselected;
    final duration = context.relayAnimationsDisabled
        ? Duration.zero
        : _navSelectionDuration;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: itemExtent,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      begin: selected ? unselectedColor : selectedColor,
                      end: selected ? selectedColor : unselectedColor,
                    ),
                    duration: duration,
                    curve: RelayMotion.easeOut,
                    builder: (context, color, child) =>
                        Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: RelayMotion.easeOut,
                    style: (labelStyle ?? const TextStyle()).copyWith(
                      color: selected ? selectedColor : unselectedColor,
                    ),
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerBottomNavigation extends StatelessWidget {
  const _LedgerBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(String, IconData)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.textScalerOf(context).scale(12) > 18
        ? 80.0
        : 72.0;
    final selectionDuration = context.relayAnimationsDisabled
        ? Duration.zero
        : _navSelectionDuration;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.relay.navSurface,
          border: Border(top: BorderSide(color: context.relay.separator)),
        ),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / destinations.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: selectionDuration,
                    curve: RelayMotion.easeOut,
                    top: 4,
                    bottom: 4,
                    left: selectedIndex * slotWidth,
                    width: slotWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.relay.navSelectedIndicator,
                            border: Border.all(
                              color: context.relay.navSelectedBorder,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        Expanded(
                          child: _BottomNavDestination(
                            label: context.l10n.text(destinations[index].$1),
                            icon: destinations[index].$2,
                            selected: index == selectedIndex,
                            textTheme: theme.textTheme,
                            onTap: () => onSelected(index),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavDestination extends StatelessWidget {
  const _BottomNavDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = context.relay.navSelected;
    final unselectedColor = context.relay.navUnselected;
    final duration = context.relayAnimationsDisabled
        ? Duration.zero
        : _navSelectionDuration;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          overlayColor: WidgetStatePropertyAll(
            context.relay.navSelectedBorder.withValues(alpha: .14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: selected ? unselectedColor : selectedColor,
                    end: selected ? selectedColor : unselectedColor,
                  ),
                  duration: duration,
                  curve: RelayMotion.easeOut,
                  builder: (context, color, child) =>
                      Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: RelayMotion.easeOut,
                  style: (textTheme.labelLarge ?? const TextStyle()).copyWith(
                    color: selected ? selectedColor : unselectedColor,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  child: Text(label, maxLines: 2, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
