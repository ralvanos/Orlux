import 'package:flutter/material.dart';

/// Night navy with aurora gold (UTC) and ice (local time).
class OrluxColors {
  OrluxColors._();

  static const Color ink = Color(0xFF070B12);
  static const Color inkElevated = Color(0xFF0E141E);
  static const Color surface = Color(0xFF141B28);
  static const Color card = Color(0xFF1A2333);
  static const Color aurora = Color(0xFFE6C07B);
  static const Color ice = Color(0xFF8BB8F0);
  static const Color mint = Color(0xFF7EC8A3);
  static const Color danger = Color(0xFFE85D5D);
  static const Color onInk = Color(0xFFF3F1EA);
}

class OrluxTheme {
  OrluxTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: OrluxColors.aurora,
      secondary: OrluxColors.ice,
      tertiary: OrluxColors.mint,
      surface: OrluxColors.ink,
      error: OrluxColors.danger,
      onPrimary: Color(0xFF1A1408),
      onSecondary: Color(0xFF071018),
      onSurface: OrluxColors.onInk,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: OrluxColors.ink,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: OrluxColors.onInk,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OrluxColors.surface,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        prefixIconColor: OrluxColors.ice,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OrluxColors.aurora),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: OrluxColors.aurora,
        backgroundColor: OrluxColors.surface,
        labelStyle: const TextStyle(color: OrluxColors.onInk),
        secondaryLabelStyle: const TextStyle(color: Color(0xFF1A1408)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: OrluxColors.aurora,
          foregroundColor: const Color(0xFF1A1408),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OrluxColors.inkElevated,
        indicatorColor: OrluxColors.aurora.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? OrluxColors.aurora : const Color(0x99F3F1EA),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? OrluxColors.aurora : const Color(0x99F3F1EA),
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: OrluxColors.card,
        contentTextStyle: const TextStyle(color: OrluxColors.onInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: OrluxColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: OrluxColors.card,
        hourMinuteColor: OrluxColors.surface,
        hourMinuteTextColor: OrluxColors.onInk,
        dialBackgroundColor: OrluxColors.surface,
        dialHandColor: OrluxColors.aurora,
        dialTextColor: OrluxColors.onInk,
        entryModeIconColor: OrluxColors.aurora,
        helpTextStyle: TextStyle(color: OrluxColors.aurora),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: OrluxColors.inkElevated,
        selectedItemColor: OrluxColors.aurora,
        unselectedItemColor: Color(0x99F3F1EA),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(0),
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
        interactive: false,
      ),
    );
  }
}
