import 'package:flutter/material.dart';

/// VeriServe Design System — Color Tokens
/// Extracted from Stitch project design theme.
class VeriServeColors {
  VeriServeColors._();

  // ── Brand Primaries ──
  static const Color deepNavy = Color(0xFF0A192F);
  static const Color slateGray = Color(0xFF94A3B8);
  static const Color successGreen = Color(0xFF10B981);
  static const Color alertOrange = Color(0xFFF59E0B);

  // ── Material 3 Palette ──
  static const Color primary = Color(0xFF000000);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0D1C32);
  static const Color onPrimaryContainer = Color(0xFF76849F);

  static const Color secondary = Color(0xFF50606F);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD1E1F4);
  static const Color onSecondaryContainer = Color(0xFF556474);

  static const Color tertiary = Color(0xFF000000);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF161C22);
  static const Color onTertiaryContainer = Color(0xFF7E848C);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color surface = Color(0xFFFBF9FB);
  static const Color onSurface = Color(0xFF1B1B1D);
  static const Color surfaceVariant = Color(0xFFE4E2E4);
  static const Color onSurfaceVariant = Color(0xFF44474D);

  static const Color surfaceDim = Color(0xFFDBD9DB);
  static const Color surfaceBright = Color(0xFFFBF9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F3F5);
  static const Color surfaceContainer = Color(0xFFEFEDEF);
  static const Color surfaceContainerHigh = Color(0xFFEAE7EA);
  static const Color surfaceContainerHighest = Color(0xFFE4E2E4);

  static const Color outline = Color(0xFF75777E);
  static const Color outlineVariant = Color(0xFFC5C6CD);

  static const Color inverseSurface = Color(0xFF303032);
  static const Color inverseOnSurface = Color(0xFFF2F0F2);
  static const Color inversePrimary = Color(0xFFB9C7E4);

  static const Color surfaceTint = Color(0xFF515F78);
  static const Color background = Color(0xFFFBF9FB);
  static const Color onBackground = Color(0xFF1B1B1D);

  // ── Fixed Palette ──
  static const Color primaryFixed = Color(0xFFD6E3FF);
  static const Color primaryFixedDim = Color(0xFFB9C7E4);
  static const Color secondaryFixed = Color(0xFFD4E4F6);
  static const Color secondaryFixedDim = Color(0xFFB8C8DA);
  static const Color tertiaryFixed = Color(0xFFDDE3EB);
  static const Color tertiaryFixedDim = Color(0xFFC1C7CF);

  /// Build a Material 3 ColorScheme from VeriServe tokens.
  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: deepNavy,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: inverseSurface,
        onInverseSurface: inverseOnSurface,
        inversePrimary: inversePrimary,
        surfaceTint: surfaceTint,
      );
}
