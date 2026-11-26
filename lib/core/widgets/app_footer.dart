import 'package:flutter/material.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Compact enterprise version and copyright footer used across auth and drawer views.
class AppFooter extends StatelessWidget {
  /// Creates an [AppFooter].
  const AppFooter({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  /// Surrounding spacing around the footer label.
  final EdgeInsetsGeometry padding;

  /// Current semantic application version.
  static const String versionLabel = 'v1.0.0 • © 2026 Dobrak Mandiri ERP';

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Text(
        versionLabel,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: palette.textMuted,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
