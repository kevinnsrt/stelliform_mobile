import 'package:flutter/material.dart';

/// Semantic theme palette extension providing adaptive Light & Dark tokens.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Creates an [AppPalette] for either Light or Dark mode.
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.primary,
    required this.primaryDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Clean minimalist Light Mode palette.
  static const AppPalette light = AppPalette(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceMuted: AppColors.lightSurfaceMuted,
    primary: AppColors.lightPrimary,
    primaryDark: AppColors.lightPrimaryDark,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: Color(0xFF94A3B8),
    border: AppColors.lightBorder,
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF0284C7),
  );

  /// Deep obsidian Dark Mode palette.
  static const AppPalette dark = AppPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceMuted: AppColors.darkSurfaceMuted,
    primary: AppColors.darkPrimary,
    primaryDark: AppColors.darkPrimaryDark,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: Color(0xFF64748B),
    border: AppColors.darkBorder,
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
  );

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color primary;
  final Color primaryDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Soft translucent fill for active emerald highlights.
  Color get primarySoft => primary.withValues(alpha: 0.12);

  /// Soft translucent fill for success badges.
  Color get successSoft => success.withValues(alpha: 0.12);

  /// Soft translucent fill for warning badges.
  Color get warningSoft => warning.withValues(alpha: 0.12);

  /// Soft translucent fill for danger alerts.
  Color get dangerSoft => danger.withValues(alpha: 0.12);

  /// Soft translucent fill for informational banners.
  Color get infoSoft => info.withValues(alpha: 0.12);

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? primary,
    Color? primaryDark,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

/// Brand and adaptive Light/Dark color tokens for Dobrak Mandiri ERP.
abstract final class AppColors {
  // Light Theme Palette
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF1F5F9);
  static const Color lightPrimary = Color(0xFF0D9488);
  static const Color lightPrimaryDark = Color(0xFF0F766E);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF151C2C);
  static const Color darkSurfaceMuted = Color(0xFF1C2538);
  static const Color darkPrimary = Color(0xFF10B981);
  static const Color darkPrimaryDark = Color(0xFF059669);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF1E293B);

  // Shared semantic tokens for non-BuildContext models
  static const Color primary = lightPrimary;
  static const Color primaryDark = lightPrimaryDark;
  static const Color accent = lightPrimary;
  static const Color secondary = Color(0xFF0F766E);
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color surfaceMuted = lightSurfaceMuted;
  static const Color border = lightBorder;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0284C7);

  /// Returns the active [AppPalette] matching the current [ThemeData.brightness].
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }
}
