import 'package:flutter/foundation.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';
import 'package:stelliform_mobile/features/auth/data/auth_repository.dart';

/// Global authentication and RBAC session controller.
class AuthController extends ChangeNotifier {
  /// Creates an [AuthController] backed by [repository].
  AuthController({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  AuthSession? _session;
  bool _isLoading = false;
  bool _isRestoring = false;
  String? _errorMessage;
  ApiException? _lastException;

  /// Active authenticated session, or `null` when signed out.
  AuthSession? get session => _session;

  /// Currently logged-in user profile, or `null` when unauthenticated.
  AuthUser? get currentUser => _session?.user;

  /// Assigned role of the signed-in employee, or `null` when unauthenticated.
  UserRole? get currentRole => _session?.user.role;

  /// Sanctum Bearer token attached by [AuthInterceptor].
  String? get accessToken => _session?.accessToken;

  /// Whether an active user session exists.
  bool get isAuthenticated => _session != null;

  /// Whether this session is connected to a real backend JWT/Sanctum token.
  bool get isRemoteSession =>
      _session != null && !(_session?.isDemoSession ?? true);

  /// Whether an authentication operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Whether startup session restoration is currently in progress.
  bool get isRestoring => _isRestoring;

  /// Latest user-facing authentication error message.
  String? get errorMessage => _errorMessage;

  /// Latest structured [ApiException], useful for dialogs and SnackBars.
  ApiException? get lastException => _lastException;

  /// Restores any saved Sanctum session from [SharedPreferences] at app launch.
  Future<void> restoreSession() async {
    _isRestoring = true;
    notifyListeners();

    try {
      final restored = await _repository.restoreSession();
      if (restored != null) {
        _session = restored;
      }
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Signs in using [email] and [password], returning `true` on success.
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      _session = await _repository.login(email: email, password: password);
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal masuk ke aplikasi. Silakan coba lagi.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs in immediately using a seeded active demo profile for [role].
  Future<bool> loginAsRole(UserRole role) async {
    _isLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      _session = await _repository.loginWithDemoRole(role);
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the active session (and revokes backend token when applicable).
  Future<void> logout({bool fromUnauthorized = false}) async {
    final wasDemo = _session?.isDemoSession ?? true;
    _session = null;
    _errorMessage = fromUnauthorized
        ? 'Sesi Anda telah berakhir. Silakan login kembali.'
        : null;
    _lastException = null;
    notifyListeners();

    await _repository.logout(revokeRemote: !fromUnauthorized && !wasDemo);
  }

  /// Clears the current [errorMessage] and [lastException].
  void clearError() {
    if (_errorMessage == null && _lastException == null) return;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();
  }

  /// Synchronizes active user details if modified by Owner User Management.
  Future<void> refreshUserFromDirectory() async {
    final active = _session;
    if (active == null) return;

    if (!active.isDemoSession && _repository.enableRemoteSync) {
      try {
        final refreshed = await _repository.fetchCurrentUser();
        if (!refreshed.isActive) {
          await logout();
          return;
        }
        _session = AuthSession(
          user: refreshed,
          accessToken: active.accessToken,
          tokenType: active.tokenType,
          expiresAt: active.expiresAt,
        );
        notifyListeners();
        return;
      } on ApiException {
        return;
      }
    }

    final directory = _repository.getRegisteredUsers();
    final updated = directory.where((u) => u.id == active.user.id).firstOrNull;
    if (updated == null || !updated.isActive) {
      _session = null;
    } else {
      _session = AuthSession(
        user: updated,
        accessToken: active.accessToken,
        expiresAt: active.expiresAt,
        isDemoSession: active.isDemoSession,
      );
    }
    notifyListeners();
  }
}
