import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/app/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('Relay Daylight uses the approved tokens and readable text', () {
    final theme = relayLightTheme();
    final palette = theme.extension<RelayPalette>()!;

    expect(theme.scaffoldBackgroundColor, RelayColors.lightBackground);
    expect(theme.cardTheme.color, RelayColors.lightSurface);
    expect(palette.textPrimary, RelayColors.lightTextPrimary);
    expect(
      contrast(palette.navigationUnselected, palette.navigationSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(
        palette.navigationSelectedContent,
        palette.navigationSelectedSurface,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.navigationSelectedBorder, palette.navigationSurface),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(palette.textPrimary, RelayColors.lightBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.textSecondary, RelayColors.lightSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.success, palette.successContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.warning, palette.warningContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.info, palette.infoContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.danger, palette.dangerContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(palette.repairFixed, const Color(0xFF6ABF69));
    expect(
      contrast(palette.repairFixed, palette.onRepairFixed),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('Relay Night Shift uses the approved tokens and readable text', () {
    final theme = relayDarkTheme();
    final palette = theme.extension<RelayPalette>()!;

    expect(theme.scaffoldBackgroundColor, RelayColors.darkBackground);
    expect(theme.cardTheme.color, RelayColors.darkSurface);
    expect(palette.textPrimary, RelayColors.darkTextPrimary);
    expect(
      contrast(palette.navigationUnselected, palette.navigationSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(
        palette.navigationSelectedContent,
        palette.navigationSelectedSurface,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.navigationSelectedBorder, palette.navigationSurface),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(palette.textPrimary, RelayColors.darkBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.textSecondary, RelayColors.darkSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.selectedContent, palette.selectionContainer),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(palette.success, palette.successContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.warning, palette.warningContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.info, palette.infoContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.danger, palette.dangerContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(palette.repairFixed, const Color(0xFF6ABF69));
    expect(
      contrast(palette.repairFixed, palette.onRepairFixed),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('theme mode selection persists', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(preferences.getString('relay_theme_mode'), 'dark');
  });
}
