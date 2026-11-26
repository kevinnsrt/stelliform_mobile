import 'package:flutter/foundation.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';
import 'package:stelliform_mobile/features/owner/data/owner_models.dart';
import 'package:stelliform_mobile/features/owner/data/owner_repository.dart';

/// Controller driving [OwnerDashboardScreen] analytics and [UserManagementScreen].
class OwnerController extends ChangeNotifier {
  /// Creates an [OwnerController] backed by [repository].
  OwnerController({required OwnerRepository repository})
    : _repository = repository;

  final OwnerRepository _repository;

  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.thisMonth;
  bool _isRefreshing = false;
  bool _isUsersLoading = false;
  String? _errorMessage;
  ApiException? _lastException;

  /// Selected analytics reporting period.
  AnalyticsPeriod get selectedPeriod => _selectedPeriod;

  /// Whether analytics refresh is currently running.
  bool get isRefreshing => _isRefreshing;

  /// Whether staff user directory is currently loading.
  bool get isUsersLoading => _isUsersLoading;

  /// Latest user administration or analytics error message.
  String? get errorMessage => _errorMessage;

  /// Latest structured [ApiException] for SnackBars and dialogs.
  ApiException? get lastException => _lastException;

  /// Live executive analytics snapshot compiled from store modules.
  OwnerDashboardSnapshot get snapshot =>
      _repository.fetchSnapshot(_selectedPeriod);

  /// Registered employee accounts for User Management.
  List<AuthUser> get staffUsers => _repository.getStaffUsers();

  /// Changes the analytics reporting period and triggers remote sync if enabled.
  void setPeriod(AnalyticsPeriod period) {
    _selectedPeriod = period;
    notifyListeners();
    if (_repository.enableRemoteSync) {
      refreshAnalytics();
    }
  }

  /// Refreshes executive analytics KPIs from backend `/finance/*` endpoints.
  Future<void> refreshAnalytics() async {
    _isRefreshing = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      if (_repository.enableRemoteSync) {
        await _repository.fetchRemoteSnapshot(_selectedPeriod);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
    } catch (_) {
      _errorMessage = 'Gagal memuat analitik eksekutif.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Loads employee directory from `GET /api/v1/sistem/user`.
  Future<void> loadUsers() async {
    if (!_repository.enableRemoteSync) return;
    _isUsersLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.fetchStaffUsers();
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
    } catch (_) {
      _errorMessage = 'Gagal memuat daftar karyawan dari server.';
    } finally {
      _isUsersLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new RBAC employee account.
  Future<bool> addUser({
    required String name,
    required String email,
    required UserRole role,
    required String branchName,
    required String phone,
    String initialPassword = 'password123',
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty) {
      _errorMessage = 'Nama lengkap dan email wajib diisi.';
      notifyListeners();
      return false;
    }

    _isUsersLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.createStaffUser(
        name: name,
        email: email,
        role: role,
        branchName: branchName,
        phone: phone,
        initialPassword: initialPassword,
      );
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } on FormatException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal menambahkan karyawan baru.';
      return false;
    } finally {
      _isUsersLoading = false;
      notifyListeners();
    }
  }

  /// Enables or disables a staff member's access.
  Future<bool> toggleUserActive(AuthUser user) async {
    _errorMessage = null;
    _lastException = null;
    try {
      await _repository.toggleUserActive(user, !user.isActive);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      notifyListeners();
      return false;
    }
  }

  /// Reassigns an employee's [UserRole].
  Future<bool> updateUserRole(AuthUser user, UserRole nextRole) async {
    _errorMessage = null;
    _lastException = null;
    try {
      await _repository.updateUserRole(user, nextRole);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      notifyListeners();
      return false;
    }
  }
}
