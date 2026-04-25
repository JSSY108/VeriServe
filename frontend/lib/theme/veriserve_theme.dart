import 'package:flutter/material.dart';
import 'veriserve_colors.dart';

/// VeriServe Design System — ThemeData
/// Corporate / Modern — High-Contrast Functionalism.
class VeriServeTheme {
  VeriServeTheme._();

  static ThemeData get light {
    final colorScheme = VeriServeColors.colorScheme;
    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VeriServeColors.background,
      textTheme: textTheme,
      fontFamily: 'Inter',

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: VeriServeColors.surfaceContainerLowest,
        foregroundColor: VeriServeColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineMedium,
        shape: const Border(
          bottom: BorderSide(color: VeriServeColors.outlineVariant, width: 1),
        ),
      ),

      // Cards: white, 8px radius, 1px border, no heavy shadow
      cardTheme: CardThemeData(
        color: VeriServeColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side:
              const BorderSide(color: VeriServeColors.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button: Deep Navy
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VeriServeColors.deepNavy,
          foregroundColor: VeriServeColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
          ),
        ),
      ),

      // Outlined Button: transparent + 1px slate gray
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VeriServeColors.onSurface,
          side: const BorderSide(color: VeriServeColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VeriServeColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VeriServeColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VeriServeColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: VeriServeColors.deepNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VeriServeColors.error),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
          color: VeriServeColors.onSurfaceVariant,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: VeriServeColors.outlineVariant,
        thickness: 1,
        space: 0,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: VeriServeColors.surfaceContainerHighest,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: VeriServeColors.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  /// Build the 7-level VeriServe typography scale.
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      // display-xl: 36/44, 700, -0.02em
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 44 / 36,
        letterSpacing: -0.72,
      ),
      // headline-lg: 24/32, 600, -0.01em
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.24,
      ),
      // headline-md: 20/28, 600
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      ),
      // body-base: 16/24, 400
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      ),
      // body-sm: 14/20, 400
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
      // label-caps: 12/16, 600, 0.05em
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.6,
      ),
      // mono-log: 13/18, 500, -0.01em
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 18 / 13,
        letterSpacing: -0.13,
      ),
    );
  }
}
