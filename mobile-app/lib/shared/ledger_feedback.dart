import 'package:flutter/material.dart';

import '../app/relay_ui.dart';
import '../app/theme.dart';

class RelayNotice extends StatelessWidget {
  const RelayNotice({
    required this.message,
    this.kind = RelayNoticeKind.info,
    super.key,
  });
  final String message;
  final RelayNoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final (color, background, icon) = switch (kind) {
      RelayNoticeKind.success => (
        palette.success,
        palette.successContainer,
        Icons.check_circle_outline,
      ),
      RelayNoticeKind.warning => (
        palette.warning,
        palette.warningContainer,
        Icons.warning_amber_rounded,
      ),
      RelayNoticeKind.danger => (
        palette.danger,
        palette.dangerContainer,
        Icons.error_outline,
      ),
      RelayNoticeKind.info => (
        palette.info,
        palette.infoContainer,
        Icons.info_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum RelayNoticeKind { info, success, warning, danger }

class RelayPressScale extends StatefulWidget {
  const RelayPressScale({
    required this.child,
    this.enabled = true,
    this.pressedScale = .985,
    this.duration = const Duration(milliseconds: 120),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final Duration duration;

  @override
  State<RelayPressScale> createState() => _RelayPressScaleState();
}

class _RelayPressScaleState extends State<RelayPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) {
      if (_pressed) {
        setState(() => _pressed = false);
      }
      return;
    }
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant RelayPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = context.relayAnimationsDisabled;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: widget.enabled && _pressed && !disableAnimations
            ? widget.pressedScale
            : 1,
        duration: disableAnimations ? Duration.zero : widget.duration,
        curve: RelayMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

class RelayTapFeedback extends StatelessWidget {
  const RelayTapFeedback({
    required this.child,
    this.enabled = true,
    this.pressedScale = .992,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  Widget build(BuildContext context) => RelayPressScale(
    enabled: enabled,
    pressedScale: pressedScale,
    child: child,
  );
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => RelayTapFeedback(
    enabled: !busy && onPressed != null,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: SizedBox.square(
        dimension: 20,
        child: Center(
          child: AnimatedSwitcher(
            duration: context.relayAnimationsDisabled
                ? Duration.zero
                : RelayMotion.press,
            switchInCurve: RelayMotion.easeOut,
            switchOutCurve: RelayMotion.easeInOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: busy
                ? const SizedBox.square(
                    key: ValueKey('busy-spinner'),
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    icon ?? Icons.arrow_forward,
                    key: const ValueKey('busy-icon'),
                    size: 20,
                  ),
          ),
        ),
      ),
      label: Text(label),
    ),
  );
}
