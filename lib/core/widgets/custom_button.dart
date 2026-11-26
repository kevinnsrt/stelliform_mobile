import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/theme_controller.dart';

/// Visual variant supported by [CustomButton].
enum CustomButtonVariant { primary, secondary, outline, danger }

/// Reusable flat ERP action button aligned with minimalist Light & Dark themes.
class CustomButton extends StatelessWidget {
  /// Creates a [CustomButton].
  const CustomButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.variant = CustomButtonVariant.primary,
  });

  /// Button caption text.
  final String label;

  /// Callback triggered when tapped; disabled when `null` or [isLoading] is true.
  final VoidCallback? onPressed;

  /// Optional leading icon displayed before [label].
  final IconData? icon;

  /// Whether a spinner should replace the button content.
  final bool isLoading;

  /// Whether the button expands to fill available horizontal width.
  final bool isFullWidth;

  /// Visual style variant.
  final CustomButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == CustomButtonVariant.outline ||
                        variant == CustomButtonVariant.secondary
                    ? palette.primary
                    : Colors.white,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final Widget button = switch (variant) {
      CustomButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      CustomButtonVariant.primary => ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: child,
      ),
      CustomButtonVariant.secondary => ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.surfaceMuted,
          foregroundColor: palette.textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(color: palette.border),
        ),
        child: child,
      ),
      CustomButtonVariant.danger => ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.danger,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: child,
      ),
    };

    if (!isFullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

/// Minimalist Sun/Moon icon button toggling Light and Dark themes.
class ThemeToggleButton extends StatelessWidget {
  /// Creates a [ThemeToggleButton].
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController?>();
    if (themeController == null) {
      return const SizedBox.shrink();
    }
    final isDark = themeController.isDarkMode;
    final palette = AppColors.of(context);

    return IconButton(
      key: const ValueKey('theme_toggle_button'),
      tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
      onPressed: themeController.toggleTheme,
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: palette.textPrimary,
        size: 20,
      ),
    );
  }
}
