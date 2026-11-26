import 'package:flutter/material.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Feature flags gating frontend capabilities that do not yet have dedicated
/// endpoints in the `andcrst/backend-ERP` Laravel REST API.
abstract final class BackendFeatureFlags {
  /// Optional Bluetooth ESC/POS thermal receipt printer integration.
  static const bool bluetoothThermalPrintSupported = false;

  /// Optional manual multi-warehouse stock synchronization endpoint.
  static const bool optionalStockSyncSupported = false;

  /// Staff payroll disbursement backend endpoints.
  static const bool payrollModuleSupported = false;

  /// Operational expense recording endpoint (`Finance` module is read-only on backend).
  static const bool operationalExpensePostSupported = false;

  /// Standard Indonesian notice shown when clicking any locked feature.
  static const String unsupportedMessage =
      'Fitur ini belum terhubung ke backend dan akan tersedia pada pembaruan berikutnya.';

  /// Displays [unsupportedMessage] as a clean SnackBar (or Dialog when [useDialog] is true).
  static void showUnsupportedFeedback(
    BuildContext context, {
    bool useDialog = false,
  }) {
    final palette = AppColors.of(context);
    if (useDialog) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.lock_outline_rounded,
            color: palette.textSecondary,
            size: 32,
          ),
          title: const Text('Fitur Segera Hadir'),
          content: Text(
            unsupportedMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text(unsupportedMessage)),
          ],
        ),
      ),
    );
  }
}

/// Visually dimmed pill button for backend-unsupported features that still
/// surfaces a friendly explanation SnackBar when tapped.
class LockedFeatureButton extends StatelessWidget {
  /// Creates a [LockedFeatureButton].
  const LockedFeatureButton({
    required this.label,
    super.key,
    this.badgeText = 'Coming Soon',
    this.isFullWidth = true,
    this.useDialog = false,
  });

  /// Button action label shown alongside the lock icon.
  final String label;

  /// Short status badge caption.
  final String badgeText;

  /// Whether the button stretches across available width.
  final bool isFullWidth;

  /// Whether tapping shows a modal dialog instead of a SnackBar.
  final bool useDialog;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    final control = InkWell(
      onTap: () => BackendFeatureFlags.showUnsupportedFeedback(
        context,
        useDialog: useDialog,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: palette.textMuted,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textMuted,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isFullWidth) return control;
    return SizedBox(width: double.infinity, child: control);
  }
}
