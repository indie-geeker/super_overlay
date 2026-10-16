import 'package:flutter/material.dart';

class ShowcaseColors {
  const ShowcaseColors._();

  static const background = Color(0xFFF5F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFF0F4F2);
  static const codeSurface = Color(0xFFE8EFEB);
  static const border = Color(0xFFDCE4E0);
  static const muted = Color(0xFF52635C);
  static const text = Color(0xFF1C2923);
  static const primary = Color(0xFF236B58);
  static const info = Color(0xFF3867A1);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFBE123C);
  static const violet = Color(0xFF75638D);
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
        scrolledUnderElevation: 0,
        backgroundColor: ShowcaseColors.background,
        foregroundColor: ShowcaseColors.text,
      ),
      cardTheme: CardThemeData(
        color: ShowcaseColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: ShowcaseColors.text,
          side: const BorderSide(color: ShowcaseColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(
            BorderSide(color: ShowcaseColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ShowcaseColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: Typography.blackMountainView.apply(
        bodyColor: ShowcaseColors.text,
        displayColor: ShowcaseColors.text,
      ),
    );
  }
}
