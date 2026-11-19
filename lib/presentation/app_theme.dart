import 'package:flutter/material.dart';

abstract final class SpendWiseTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = Color(dark ? 0xff111214 : 0xfff7f7f5);
    final surface = Color(dark ? 0xff1d1e22 : 0xffffffff);
    final ink = Color(dark ? 0xfff2f2f4 : 0xff202124);
    final muted = Color(dark ? 0xffa8a9b1 : 0xff696c75);
    final line = Color(dark ? 0xff33343b : 0xffe8e9ed);
    final scheme = ColorScheme.fromSeed(seedColor: ink, brightness: brightness)
        .copyWith(
          primary: ink,
          onPrimary: background,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outlineVariant: line,
          surfaceContainerLow: background,
          surfaceContainerHigh: surface,
        );
    final base = ThemeData(
      brightness: brightness,
    ).textTheme.apply(fontFamily: 'Roboto', bodyColor: ink, displayColor: ink);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: base.copyWith(
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: ink, width: 1.2),
        ),
        errorBorder: outline.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: background,
          disabledBackgroundColor: line,
          disabledForegroundColor: muted,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: ink.withValues(alpha: 0.15),
        selectionHandleColor: ink,
      ),
    );
  }
}
