import 'package:flutter/material.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';

/// Centered loading indicator with an optional descriptive message.
class LoadingIndicator extends StatelessWidget {
  /// Creates a [LoadingIndicator].
  const LoadingIndicator({super.key, this.message, this.compact = false});

  /// Optional status caption displayed beneath the spinner.
  final String? message;

  /// Whether to render a compact inline spinner without vertical padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: palette.primary,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return content;
    }

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

/// Inline dismissible or retryable API error banner for ERP screens.
class ApiErrorBanner extends StatelessWidget {
  /// Creates an [ApiErrorBanner].
  const ApiErrorBanner({
    required this.message,
    super.key,
    this.onRetry,
    this.onDismiss,
  });

  /// Error description shown to the employee.
  final String message;

  /// Optional retry action callback.
  final VoidCallback? onRetry;

  /// Optional dismiss callback.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: palette.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.danger,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: palette.danger,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Coba Lagi'),
            ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: palette.danger),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// Shared UI feedback helpers for displaying HTTP & timeout errors consistently.
abstract final class ApiErrorFeedback {
  /// Shows a floating SnackBar for [error] (or fallback [fallbackMessage]).
  static void showSnackBar(
    BuildContext context,
    Object? error, {
    String fallbackMessage = 'Terjadi kesalahan saat memproses permintaan.',
    VoidCallback? onRetry,
  }) {
    final palette = AppColors.of(context);
    final message = error is ApiException
        ? error.detailedMessage
        : (error?.toString() ?? fallbackMessage);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: palette.danger,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Ulangi',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Presents an error dialog for critical failures (timeouts, 401, 400, 500).
  static Future<void> showErrorDialog(
    BuildContext context, {
    required Object error,
    VoidCallback? onRetry,
  }) {
    final palette = AppColors.of(context);
    final title = error is ApiException
        ? error.dialogTitle
        : 'Terjadi Kesalahan';
    final message = error is ApiException
        ? error.detailedMessage
        : error.toString();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: palette.danger,
          size: 36,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRetry();
              },
              child: const Text('Coba Lagi'),
            ),
        ],
      ),
    );
  }
}
