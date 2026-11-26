import 'package:flutter/material.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Minimalist enterprise Material 3 theme generator for Light and Dark modes.
abstract final class AppTheme {
  /// Clean off-white Light Theme using Emerald accents.
  static ThemeData get lightTheme => _buildTheme(
    base: ThemeData.light(useMaterial3: true),
    brightness: Brightness.light,
    palette: AppPalette.light,
  );

  /// Deep obsidian Dark Theme using Emerald accents.
  static ThemeData get darkTheme => _buildTheme(
    base: ThemeData.dark(useMaterial3: true),
    brightness: Brightness.dark,
    palette: AppPalette.dark,
  );

  static ThemeData _buildTheme({
    required ThemeData base,
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: Colors.white,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer: palette.primary,
      secondary: palette.primaryDark,
      onSecondary: Colors.white,
      secondaryContainer: palette.surfaceMuted,
      onSecondaryContainer: palette.textPrimary,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      error: palette.danger,
      onError: Colors.white,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: palette.border, width: 1)),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 13.5),
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border, width: 1),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.primarySoft,
        secondarySelectedColor: palette.primarySoft,
        checkmarkColor: palette.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: palette.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.primary
              : palette.surfaceMuted;
        }),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
    );
  }
}
