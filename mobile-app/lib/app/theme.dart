import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'relay_ui.dart';

abstract final class RelayColors {
  // Light semantic palette.
  static const lightBackground = Color(0xFFEDF2F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFE3EBE7);
  static const lightNavigationSurface = Color(0xFF112019);
  static const lightNavigationSelectedSurface = Color(0xFF223A30);
  static const lightNavigationSelectedContent = Color(0xFFC4EA4A);
  static const lightNavigationSelectedBorder = Color(0xFFB9E342);
  static const lightNavigationUnselected = Color(0xFFB9C9C1);
  static const lightSelectionContainer = Color(0xFFE3F2E9);
  static const lightTextPrimary = Color(0xFF112019);
  static const lightTextSecondary = Color(0xFF42544C);
  static const lightTextMuted = Color(0xFF61726A);
  static const lightActionPrimary = Color(0xFF155A48);
  static const lightOnActionPrimary = Color(0xFFFFFFFF);
  static const lightInteractiveText = Color(0xFF00796F);
  static const lightFocusRing = Color(0xFF5D810E);
  static const lightSelectedContent = Color(0xFF155A48);
  static const lightControlBorder = Color(0xFF7E9187);
  static const lightSeparator = Color(0xFFC8D4CD);
  static const lightStructuralLine = Color(0xFFAABAB1);
  static const lightSuccess = Color(0xFF146345);
  static const lightSuccessContainer = Color(0xFFE2F3E9);
  static const lightWarning = Color(0xFF654B14);
  static const lightWarningContainer = Color(0xFFF4ECD8);
  static const lightInfo = Color(0xFF155A87);
  static const lightInfoContainer = Color(0xFFE5F1FC);
  static const lightDanger = Color(0xFFB02A43);
  static const lightDangerContainer = Color(0xFFFCE4E8);
  // Repair-complete accent. #6ABF69 is intentionally reserved for the
  // FIXED damage state, never primary actions or generic success.
  static const lightRepairFixed = Color(0xFF6ABF69);
  static const lightOnRepairFixed = Color(0xFF142416);
  static const lightRepairFixedContainer = Color(0xFFE3F4E1);
  static const lightDisabledContent = Color(0xFF75837B);
  static const lightDisabledSurface = Color(0xFFE3EAE6);
  static const lightDisabledBorder = Color(0xFFBDCBC3);

  // Dark semantic palette.
  static const darkBackground = Color(0xFF151916);
  static const darkSurface = Color(0xFF1D2420);
  static const darkSurfaceRaised = Color(0xFF2D3730);
  static const darkSurfaceSubtle = Color(0xFF252E28);
  static const darkNavigationSurface = Color(0xFF1D2420);
  static const darkNavigationSelectedSurface = Color(0xFF2B3D1D);
  static const darkNavigationSelectedContent = Color(0xFFC4EA4A);
  static const darkNavigationSelectedBorder = Color(0xFF7EAD18);
  static const darkNavigationUnselected = Color(0xFFB7C3BC);
  static const darkSelectionContainer = Color(0xFF2B3D1D);
  static const darkTextPrimary = Color(0xFFF5F7F2);
  static const darkTextSecondary = Color(0xFFC4CBC5);
  static const darkTextMuted = Color(0xFF969F98);
  static const darkActionPrimary = Color(0xFFB9E342);
  static const darkOnActionPrimary = Color(0xFF17211B);
  static const darkInteractiveText = Color(0xFF8AD7CA);
  static const darkFocusRing = Color(0xFFC9EB5E);
  static const darkSelectedContent = Color(0xFFC4EA4A);
  static const darkControlBorder = Color(0xFF66736A);
  static const darkSeparator = Color(0xFF39443C);
  static const darkStructuralLine = Color(0xFF4E5C53);
  static const darkSuccess = Color(0xFF72D6A6);
  static const darkSuccessContainer = Color(0xFF17372B);
  static const darkWarning = Color(0xFFF3D58A);
  static const darkWarningContainer = Color(0xFF382F1F);
  static const darkInfo = Color(0xFF8DD0FF);
  static const darkInfoContainer = Color(0xFF182F40);
  static const darkDanger = Color(0xFFFF7085);
  static const darkDangerContainer = Color(0xFF3A1D23);
  static const darkRepairFixed = Color(0xFF6ABF69);
  static const darkOnRepairFixed = Color(0xFF142416);
  static const darkRepairFixedContainer = Color(0xFF203A22);
  static const darkDisabledContent = Color(0xFF78837C);
  static const darkDisabledSurface = Color(0xFF29322C);
  static const darkDisabledBorder = Color(0xFF49564E);
}

@immutable
class RelayPalette extends ThemeExtension<RelayPalette> {
  const RelayPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSubtle,
    required this.navigationSurface,
    required this.navigationSelectedSurface,
    required this.navigationSelectedContent,
    required this.navigationSelectedBorder,
    required this.navigationUnselected,
    required this.selectionContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.actionPrimary,
    required this.onActionPrimary,
    required this.interactiveText,
    required this.focusRing,
    required this.selectedContent,
    required this.controlBorder,
    required this.separator,
    required this.structuralLine,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.danger,
    required this.dangerContainer,
    required this.repairFixed,
    required this.onRepairFixed,
    required this.repairFixedContainer,
    required this.disabledContent,
    required this.disabledSurface,
    required this.disabledBorder,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSubtle;
  final Color navigationSurface;
  final Color navigationSelectedSurface;
  final Color navigationSelectedContent;
  final Color navigationSelectedBorder;
  final Color navigationUnselected;
  final Color selectionContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color actionPrimary;
  final Color onActionPrimary;
  final Color interactiveText;
  final Color focusRing;
  final Color selectedContent;
  final Color controlBorder;
  final Color separator;
  final Color structuralLine;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color danger;
  final Color dangerContainer;
  final Color repairFixed;
  final Color onRepairFixed;
  final Color repairFixedContainer;
  final Color disabledContent;
  final Color disabledSurface;
  final Color disabledBorder;

  // Intentional semantic aliases. They share swatches but remain distinct roles.
  Color get textInverse => onActionPrimary;
  Color get controlBorderFocused => focusRing;
  Color get progressTrack => separator;
  Color get navSurface => navigationSurface;
  Color get navSelected => navigationSelectedContent;
  Color get navSelectedIndicator => navigationSelectedSurface;
  Color get navSelectedBorder => navigationSelectedBorder;
  Color get navUnselected => navigationUnselected;

  static const daylight = RelayPalette(
    background: RelayColors.lightBackground,
    surface: RelayColors.lightSurface,
    surfaceRaised: RelayColors.lightSurfaceRaised,
    surfaceSubtle: RelayColors.lightSurfaceSubtle,
    navigationSurface: RelayColors.lightNavigationSurface,
    navigationSelectedSurface: RelayColors.lightNavigationSelectedSurface,
    navigationSelectedContent: RelayColors.lightNavigationSelectedContent,
    navigationSelectedBorder: RelayColors.lightNavigationSelectedBorder,
    navigationUnselected: RelayColors.lightNavigationUnselected,
    selectionContainer: RelayColors.lightSelectionContainer,
    textPrimary: RelayColors.lightTextPrimary,
    textSecondary: RelayColors.lightTextSecondary,
    textMuted: RelayColors.lightTextMuted,
    actionPrimary: RelayColors.lightActionPrimary,
    onActionPrimary: RelayColors.lightOnActionPrimary,
    interactiveText: RelayColors.lightInteractiveText,
    focusRing: RelayColors.lightFocusRing,
    selectedContent: RelayColors.lightSelectedContent,
    controlBorder: RelayColors.lightControlBorder,
    separator: RelayColors.lightSeparator,
    structuralLine: RelayColors.lightStructuralLine,
    success: RelayColors.lightSuccess,
    successContainer: RelayColors.lightSuccessContainer,
    warning: RelayColors.lightWarning,
    warningContainer: RelayColors.lightWarningContainer,
    info: RelayColors.lightInfo,
    infoContainer: RelayColors.lightInfoContainer,
    danger: RelayColors.lightDanger,
    dangerContainer: RelayColors.lightDangerContainer,
    repairFixed: RelayColors.lightRepairFixed,
    onRepairFixed: RelayColors.lightOnRepairFixed,
    repairFixedContainer: RelayColors.lightRepairFixedContainer,
    disabledContent: RelayColors.lightDisabledContent,
    disabledSurface: RelayColors.lightDisabledSurface,
    disabledBorder: RelayColors.lightDisabledBorder,
  );

  static const nightShift = RelayPalette(
    background: RelayColors.darkBackground,
    surface: RelayColors.darkSurface,
    surfaceRaised: RelayColors.darkSurfaceRaised,
    surfaceSubtle: RelayColors.darkSurfaceSubtle,
    navigationSurface: RelayColors.darkNavigationSurface,
    navigationSelectedSurface: RelayColors.darkNavigationSelectedSurface,
    navigationSelectedContent: RelayColors.darkNavigationSelectedContent,
    navigationSelectedBorder: RelayColors.darkNavigationSelectedBorder,
    navigationUnselected: RelayColors.darkNavigationUnselected,
    selectionContainer: RelayColors.darkSelectionContainer,
    textPrimary: RelayColors.darkTextPrimary,
    textSecondary: RelayColors.darkTextSecondary,
    textMuted: RelayColors.darkTextMuted,
    actionPrimary: RelayColors.darkActionPrimary,
    onActionPrimary: RelayColors.darkOnActionPrimary,
    interactiveText: RelayColors.darkInteractiveText,
    focusRing: RelayColors.darkFocusRing,
    selectedContent: RelayColors.darkSelectedContent,
    controlBorder: RelayColors.darkControlBorder,
    separator: RelayColors.darkSeparator,
    structuralLine: RelayColors.darkStructuralLine,
    success: RelayColors.darkSuccess,
    successContainer: RelayColors.darkSuccessContainer,
    warning: RelayColors.darkWarning,
    warningContainer: RelayColors.darkWarningContainer,
    info: RelayColors.darkInfo,
    infoContainer: RelayColors.darkInfoContainer,
    danger: RelayColors.darkDanger,
    dangerContainer: RelayColors.darkDangerContainer,
    repairFixed: RelayColors.darkRepairFixed,
    onRepairFixed: RelayColors.darkOnRepairFixed,
    repairFixedContainer: RelayColors.darkRepairFixedContainer,
    disabledContent: RelayColors.darkDisabledContent,
    disabledSurface: RelayColors.darkDisabledSurface,
    disabledBorder: RelayColors.darkDisabledBorder,
  );

  @override
  RelayPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSubtle,
    Color? navigationSurface,
    Color? navigationSelectedSurface,
    Color? navigationSelectedContent,
    Color? navigationSelectedBorder,
    Color? navigationUnselected,
    Color? selectionContainer,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? actionPrimary,
    Color? onActionPrimary,
    Color? interactiveText,
    Color? focusRing,
    Color? selectedContent,
    Color? controlBorder,
    Color? separator,
    Color? structuralLine,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? danger,
    Color? dangerContainer,
    Color? repairFixed,
    Color? onRepairFixed,
    Color? repairFixedContainer,
    Color? disabledContent,
    Color? disabledSurface,
    Color? disabledBorder,
  }) => RelayPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    navigationSurface: navigationSurface ?? this.navigationSurface,
    navigationSelectedSurface:
        navigationSelectedSurface ?? this.navigationSelectedSurface,
    navigationSelectedContent:
        navigationSelectedContent ?? this.navigationSelectedContent,
    navigationSelectedBorder:
        navigationSelectedBorder ?? this.navigationSelectedBorder,
    navigationUnselected: navigationUnselected ?? this.navigationUnselected,
    selectionContainer: selectionContainer ?? this.selectionContainer,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    actionPrimary: actionPrimary ?? this.actionPrimary,
    onActionPrimary: onActionPrimary ?? this.onActionPrimary,
    interactiveText: interactiveText ?? this.interactiveText,
    focusRing: focusRing ?? this.focusRing,
    selectedContent: selectedContent ?? this.selectedContent,
    controlBorder: controlBorder ?? this.controlBorder,
    separator: separator ?? this.separator,
    structuralLine: structuralLine ?? this.structuralLine,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
    danger: danger ?? this.danger,
    dangerContainer: dangerContainer ?? this.dangerContainer,
    repairFixed: repairFixed ?? this.repairFixed,
    onRepairFixed: onRepairFixed ?? this.onRepairFixed,
    repairFixedContainer: repairFixedContainer ?? this.repairFixedContainer,
    disabledContent: disabledContent ?? this.disabledContent,
    disabledSurface: disabledSurface ?? this.disabledSurface,
    disabledBorder: disabledBorder ?? this.disabledBorder,
  );

  @override
  RelayPalette lerp(covariant RelayPalette? other, double t) {
    if (other == null) return this;
    return RelayPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      navigationSurface: Color.lerp(
        navigationSurface,
        other.navigationSurface,
        t,
      )!,
      navigationSelectedSurface: Color.lerp(
        navigationSelectedSurface,
        other.navigationSelectedSurface,
        t,
      )!,
      navigationSelectedContent: Color.lerp(
        navigationSelectedContent,
        other.navigationSelectedContent,
        t,
      )!,
      navigationSelectedBorder: Color.lerp(
        navigationSelectedBorder,
        other.navigationSelectedBorder,
        t,
      )!,
      navigationUnselected: Color.lerp(
        navigationUnselected,
        other.navigationUnselected,
        t,
      )!,
      selectionContainer: Color.lerp(
        selectionContainer,
        other.selectionContainer,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      actionPrimary: Color.lerp(actionPrimary, other.actionPrimary, t)!,
      onActionPrimary: Color.lerp(onActionPrimary, other.onActionPrimary, t)!,
      interactiveText: Color.lerp(interactiveText, other.interactiveText, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      selectedContent: Color.lerp(selectedContent, other.selectedContent, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      structuralLine: Color.lerp(structuralLine, other.structuralLine, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      repairFixed: Color.lerp(repairFixed, other.repairFixed, t)!,
      onRepairFixed: Color.lerp(onRepairFixed, other.onRepairFixed, t)!,
      repairFixedContainer: Color.lerp(
        repairFixedContainer,
        other.repairFixedContainer,
        t,
      )!,
      disabledContent: Color.lerp(disabledContent, other.disabledContent, t)!,
      disabledSurface: Color.lerp(disabledSurface, other.disabledSurface, t)!,
      disabledBorder: Color.lerp(disabledBorder, other.disabledBorder, t)!,
    );
  }
}

extension RelayThemeContext on BuildContext {
  RelayPalette get relay => Theme.of(this).extension<RelayPalette>()!;
}

ThemeData relayLightTheme() =>
    _relayTheme(brightness: Brightness.light, palette: RelayPalette.daylight);

ThemeData relayDarkTheme() =>
    _relayTheme(brightness: Brightness.dark, palette: RelayPalette.nightShift);

ThemeData _relayTheme({
  required Brightness brightness,
  required RelayPalette palette,
}) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.actionPrimary,
        brightness: brightness,
      ).copyWith(
        primary: palette.actionPrimary,
        onPrimary: palette.onActionPrimary,
        primaryContainer: palette.selectionContainer,
        onPrimaryContainer: palette.selectedContent,
        secondary: palette.interactiveText,
        onSecondary: palette.textInverse,
        secondaryContainer: palette.surfaceSubtle,
        onSecondaryContainer: palette.textPrimary,
        tertiary: palette.info,
        onTertiary: palette.textInverse,
        tertiaryContainer: palette.infoContainer,
        onTertiaryContainer: palette.info,
        error: palette.danger,
        onError: palette.textInverse,
        errorContainer: palette.dangerContainer,
        onErrorContainer: palette.danger,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
        surfaceContainerLowest: palette.surface,
        surfaceContainerLow: palette.surface,
        surfaceContainer: palette.surface,
        surfaceContainerHigh: palette.surfaceRaised,
        surfaceContainerHighest: palette.surfaceSubtle,
        outline: palette.controlBorder,
        outlineVariant: palette.separator,
        surfaceTint: Colors.transparent,
      );

  final rounded8 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );
  final rounded10 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    disabledColor: palette.disabledContent,
    focusColor: palette.focusRing.withValues(alpha: .18),
    hoverColor: palette.selectionContainer.withValues(alpha: .45),
    highlightColor: palette.selectionContainer.withValues(alpha: .35),
    fontFamily: 'RelaySans',
    extensions: [palette],
    // Shared semantic type scale for both compact phone and large layouts.
    // Layouts change at window-width breakpoints; text roles do not inflate
    // merely because the available window is wider.
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: palette.textPrimary,
        fontFamily: 'RelayDisplay',
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        color: palette.textPrimary,
        fontFamily: 'RelayDisplay',
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: palette.textPrimary,
        fontFamily: 'RelayDisplay',
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: palette.textPrimary,
        fontFamily: 'RelaySans',
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: palette.textPrimary,
        fontFamily: 'RelaySans',
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: palette.textPrimary,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: palette.textPrimary,
        fontSize: 14,
        height: 20 / 14,
      ),
      bodySmall: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        height: 16 / 12,
      ),
      labelLarge: TextStyle(
        color: palette.textPrimary,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: .2,
      ),
      labelMedium: TextStyle(
        color: palette.textSecondary,
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: .3,
      ),
      labelSmall: TextStyle(
        color: palette.textSecondary,
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: .3,
      ),
    ).apply(
      fontFamilyFallback: const ['Noto Sans CJK JP', 'Noto Sans JP', 'sans-serif'],
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 56,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontFamily: 'RelayDisplay',
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: const [
          'Noto Sans CJK JP',
          'Noto Sans JP',
          'sans-serif',
        ],
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded10.copyWith(
        side: BorderSide(color: palette.structuralLine),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      constraints: const BoxConstraints(minHeight: 56),
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: palette.controlBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: palette.controlBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: palette.controlBorderFocused, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: palette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: palette.danger, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: palette.disabledBorder),
      ),
      labelStyle: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: palette.textMuted,
        fontSize: 16,
        height: 1.375,
        fontWeight: FontWeight.w400,
      ),
      helperStyle: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        height: 1.33,
      ),
      errorStyle: TextStyle(color: palette.danger, fontSize: 12, height: 1.33),
      prefixIconColor: palette.textSecondary,
      suffixIconColor: palette.textSecondary,
      prefixIconConstraints: const BoxConstraints.tightFor(
        width: 48,
        height: 48,
      ),
      suffixIconConstraints: const BoxConstraints.tightFor(
        width: 48,
        height: 48,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: palette.actionPrimary,
        foregroundColor: palette.onActionPrimary,
        disabledBackgroundColor: palette.disabledSurface,
        disabledForegroundColor: palette.disabledContent,
        shape: rounded10,
        iconSize: 20,
        animationDuration: RelayMotion.micro,
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.43,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        iconSize: const WidgetStatePropertyAll(20),
        animationDuration: RelayMotion.micro,
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.disabledContent;
          }
          if (states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return palette.interactiveText;
          }
          return palette.textPrimary;
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
          return BorderSide(color: palette.controlBorder);
        }),
        shape: WidgetStatePropertyAll(rounded10),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        animationDuration: RelayMotion.micro,
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w600),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.disabledContent;
          }
          return palette.interactiveText;
        }),
        overlayColor: WidgetStatePropertyAll(
          palette.selectionContainer.withValues(alpha: .55),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        iconSize: const WidgetStatePropertyAll(22),
        animationDuration: RelayMotion.micro,
        tapTargetSize: MaterialTapTargetSize.padded,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.disabledContent;
          }
          if (states.contains(WidgetState.selected)) {
            return palette.selectedContent;
          }
          return palette.textSecondary;
        }),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceSubtle,
      selectedColor: palette.selectionContainer,
      disabledColor: palette.disabledSurface,
      shape: rounded8,
      side: BorderSide(color: palette.controlBorder),
      labelStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.separator, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.navSurface,
      indicatorColor: palette.navSelectedIndicator,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? palette.navSelected
              : palette.navUnselected,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.navSelected
              : palette.navUnselected,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.navSurface,
      indicatorColor: palette.navSelectedIndicator,
      selectedIconTheme: IconThemeData(color: palette.navSelected),
      unselectedIconTheme: IconThemeData(color: palette.navUnselected),
      selectedLabelTextStyle: TextStyle(
        color: palette.navSelected,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: palette.navUnselected),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return palette.disabledContent;
        }
        if (states.contains(WidgetState.selected)) {
          return palette.selectedContent;
        }
        return palette.textMuted;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return palette.disabledSurface;
        }
        if (states.contains(WidgetState.selected)) {
          return palette.actionPrimary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(palette.onActionPrimary),
      side: BorderSide(color: palette.controlBorder),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.actionPrimary,
      linearTrackColor: palette.progressTrack,
      circularTrackColor: palette.progressTrack,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.focusRing,
      selectionColor: palette.selectionContainer,
      selectionHandleColor: palette.focusRing,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.controlBorder),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? palette.surfaceRaised : palette.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: TextStyle(
        color: isDark ? palette.textPrimary : palette.textInverse,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: isDark ? palette.interactiveText : palette.surface,
      disabledActionTextColor: palette.disabledContent,
    ),
  );
}
