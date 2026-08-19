import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class RelayMotion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration micro = Duration(milliseconds: 130);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration screen = Duration(milliseconds: 220);

  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  static const AnimationStyle sheetStyle = AnimationStyle(
    curve: drawer,
    reverseCurve: drawer,
    duration: screen,
    reverseDuration: standard,
  );

  static const AnimationStyle dialogStyle = AnimationStyle(
    curve: easeInOut,
    reverseCurve: easeInOut,
    duration: standard,
    reverseDuration: micro,
  );
}

const relayListActionBottomPadding = 96.0;

enum RelayWindowSize { compact, medium, expanded, largeProductivity }

abstract final class RelayBreakpoints {
  static const double compactMax = 600;
  static const double expandedMin = 840;
  static const double largeProductivityMin = 1024;
}

extension RelayAdaptiveSize on RelayWindowSize {
  static RelayWindowSize fromWidth(double width) {
    if (width >= RelayBreakpoints.largeProductivityMin) {
      return RelayWindowSize.largeProductivity;
    }
    if (width >= RelayBreakpoints.expandedMin) {
      return RelayWindowSize.expanded;
    }
    if (width >= RelayBreakpoints.compactMax) {
      return RelayWindowSize.medium;
    }
    return RelayWindowSize.compact;
  }
}

bool relayAnimationsDisabledOf(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

extension RelayAdaptiveContext on BuildContext {
  double get relayWidth => MediaQuery.sizeOf(this).width;

  RelayWindowSize get relayWindowSize =>
      RelayAdaptiveSize.fromWidth(relayWidth);

  bool get relayAnimationsDisabled => relayAnimationsDisabledOf(this);

  bool get relayUsesNavigationRail =>
      relayWindowSize != RelayWindowSize.compact;

  bool get relayIsLargeProductivity =>
      relayWindowSize == RelayWindowSize.largeProductivity;
}

Route<T> relayRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) => RelayPageRoute<T>(
  builder: builder,
  settings: settings,
  fullscreenDialog: fullscreenDialog,
);

class RelayPageRoute<T> extends PageRouteBuilder<T> {
  RelayPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: RelayMotion.screen,
         reverseTransitionDuration: RelayMotion.micro,
       );

  final WidgetBuilder builder;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (relayAnimationsDisabledOf(context)) {
      return child;
    }
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return child;
    }
    final begin = switch (RelayAdaptiveSize.fromWidth(
      MediaQuery.sizeOf(context).width,
    )) {
      RelayWindowSize.compact => const Offset(0.02, 0),
      RelayWindowSize.medium => const Offset(0.014, 0),
      RelayWindowSize.expanded => const Offset(0.01, 0),
      RelayWindowSize.largeProductivity => const Offset(0.006, 0),
    };
    final fade = CurvedAnimation(
      parent: animation,
      curve: RelayMotion.easeInOut,
      reverseCurve: RelayMotion.easeInOut,
    );
    final slide = CurvedAnimation(
      parent: animation,
      curve: RelayMotion.easeOut,
      reverseCurve: RelayMotion.easeInOut,
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(slide),
        child: child,
      ),
    );
  }
}

Future<T?> showRelaySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
  bool useRootNavigator = false,
  Color? barrierColor,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  showDragHandle: showDragHandle,
  useRootNavigator: useRootNavigator,
  barrierColor: barrierColor,
  sheetAnimationStyle: context.relayAnimationsDisabled
      ? AnimationStyle.noAnimation
      : RelayMotion.sheetStyle,
  builder: builder,
);

Future<T?> showRelayDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Color? barrierColor,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
  barrierColor: barrierColor,
  animationStyle: context.relayAnimationsDisabled
      ? AnimationStyle.noAnimation
      : RelayMotion.dialogStyle,
  builder: builder,
);

abstract final class RelayHaptics {
  static Future<void> confirm() => HapticFeedback.lightImpact();

  static Future<void> destructiveConfirm() => HapticFeedback.mediumImpact();

  static Future<void> success() => HapticFeedback.selectionClick();
}
