import 'package:flutter/material.dart';

class ShowcaseColors {
  const ShowcaseColors._();

  static const background = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFF1F5F9);
  static const codeSurface = Color(0xFFEFF4FA);
  static const border = Color(0xFFCBD5E1);
  static const muted = Color(0xFF475569);
  static const text = Color(0xFF0F172A);
  static const primary = Color(0xFF0F766E);
  static const info = Color(0xFF2563EB);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFBE123C);
  static const violet = Color(0xFF7C3AED);
  static const shadow = Color(0x1A0F172A);
  static const scrim = Color(0x990F172A);
}

class ShowcaseTheme {
  const ShowcaseTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: ShowcaseColors.primary,
      brightness: Brightness.light,
      surface: ShowcaseColors.surface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: ShowcaseColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: ShowcaseColors.background,
        foregroundColor: ShowcaseColors.text,
      ),
      cardTheme: CardThemeData(
        color: ShowcaseColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ShowcaseColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ShowcaseColors.border,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: ShowcaseColors.text,
          side: const BorderSide(color: ShowcaseColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(
            BorderSide(color: ShowcaseColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? ShowcaseColors.primary
              : ShowcaseColors.border;
        }),
      ),
      textTheme: Typography.blackMountainView.apply(
        bodyColor: ShowcaseColors.text,
        displayColor: ShowcaseColors.text,
      ),
    );
  }
}
