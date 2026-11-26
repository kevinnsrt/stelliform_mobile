import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Tracks live backend API reachability based on Dio request outcomes.
class ConnectivityController extends ChangeNotifier {
  bool _isOffline = false;
  String? _lastErrorDetail;
  bool _isChecking = false;

  /// Whether the backend server is currently unreachable.
  bool get isOffline => _isOffline;

  /// Whether a manual connectivity check is running.
  bool get isChecking => _isChecking;

  /// Optional technical summary of the connectivity failure.
  String? get lastErrorDetail => _lastErrorDetail;

  /// Marks backend connectivity as healthy and hides [OfflineBanner].
  void markOnline() {
    if (!_isOffline && _lastErrorDetail == null) return;
    _isOffline = false;
    _lastErrorDetail = null;
    notifyListeners();
  }

  /// Marks backend connectivity as disconnected with optional [detail].
  void markOffline([String? detail]) {
    final changed = !_isOffline || detail != _lastErrorDetail;
    _isOffline = true;
    _lastErrorDetail = detail;
    if (changed) {
      notifyListeners();
    }
  }

  /// Runs an external [probe] callback (such as `/api/v1/health`) to verify connectivity.
  Future<bool> retryConnection(Future<bool> Function() probe) async {
    if (_isChecking) return !_isOffline;
    _isChecking = true;
    notifyListeners();

    try {
      final online = await probe();
      if (online) {
        markOnline();
      } else {
        markOffline('Server belum merespons.');
      }
      return online;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}

/// Top connectivity strip alerting users when backend requests fail or time out.
class OfflineBanner extends StatelessWidget {
  /// Creates an [OfflineBanner] with an optional manual [onRetry] action.
  const OfflineBanner({super.key, this.onRetry});

  /// Optional retry callback invoked when the user taps `Coba Lagi`.
  final VoidCallback? onRetry;

  /// Exact standard offline status label.
  static const String offlineLabel =
      'Koneksi Backend Terputus / Working Offline';

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityController?>();
    if (connectivity == null || !connectivity.isOffline) {
      return const SizedBox.shrink();
    }

    final palette = AppColors.of(context);

    return Material(
      color: palette.warningSoft,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: palette.warning.withValues(alpha: 0.4)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 17, color: palette.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offlineLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: connectivity.isChecking ? null : onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.warning,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    connectivity.isChecking ? 'Memeriksa...' : 'Coba Lagi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
