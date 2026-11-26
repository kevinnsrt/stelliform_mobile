import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';

/// Internal credential entry pairing a seeded [AuthUser] with its demo password.
class _SeedAccount {
  _SeedAccount({required this.user, required this.password});

  AuthUser user;
  final String password;
}

/// Repository managing Laravel Sanctum authentication, local token persistence,
/// session restoration, and staff directory access.
class AuthRepository {
  /// Creates an [AuthRepository].
  ///
  /// When [enableRemoteSync] is `true` and [apiClient] is provided, [login],
  /// [restoreSession], [fetchCurrentUser], [changePassword], and [logout]
  /// communicate directly with `/api/v1/auth/*` and persist the Sanctum token
  /// inside [SharedPreferences].
  AuthRepository({
    ApiClient? apiClient,
    SharedPreferences? prefs,
    this.enableRemoteSync = true,
  }) : _apiClient = apiClient,
       _prefs = prefs;

  static const String _tokenPrefsKey = 'dm_sanctum_token';
  static const String _sessionPrefsKey = 'dm_auth_session_v1';

  final ApiClient? _apiClient;
  SharedPreferences? _prefs;

  /// Whether authentication calls dispatch to the remote Laravel backend.
  final bool enableRemoteSync;

  final List<_SeedAccount> _accounts = [
    _SeedAccount(
      user: const AuthUser(
        id: 'USR-001',
        name: 'Hendra Wijaya',
        email: 'owner@dobrakmandiri.id',
        role: UserRole.owner,
        branchName: 'TB. Dobrak Mandiri Pusat',
        phone: '0811-2345-8890',
      ),
      password: 'password123',
    ),
    _SeedAccount(
      user: const AuthUser(
        id: 'USR-002',
        name: 'Siti Rahayu',
        email: 'kasir@dobrakmandiri.id',
        role: UserRole.kasir,
        branchName: 'TB. Dobrak Mandiri Pusat',
        phone: '0812-8876-3310',
      ),
      password: 'password123',
    ),
    _SeedAccount(
      user: const AuthUser(
        id: 'USR-003',
        name: 'Budi Santoso',
        email: 'gudang@dobrakmandiri.id',
        role: UserRole.staffGudang,
        branchName: 'Gudang Material Utama',
        phone: '0813-7745-1209',
      ),
      password: 'password123',
    ),
    _SeedAccount(
      user: const AuthUser(
        id: 'USR-004',
        name: 'Dedi Kurniawan',
        email: 'kurir@dobrakmandiri.id',
        role: UserRole.kurir,
        branchName: 'Armada Engkel B 9421 DM',
        phone: '0815-6632-4411',
      ),
      password: 'password123',
    ),
    _SeedAccount(
      user: const AuthUser(
        id: 'USR-005',
        name: 'Nadia Permata',
        email: 'finance@dobrakmandiri.id',
        role: UserRole.finance,
        branchName: 'TB. Dobrak Mandiri Pusat',
        phone: '0817-9901-2234',
      ),
      password: 'password123',
    ),
  ];

  Future<SharedPreferences?> _ensurePrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    return _prefs;
  }

  Future<void> _persistSession(AuthSession session) async {
    if (session.isDemoSession) return;
    final prefs = await _ensurePrefs();
    if (prefs == null) return;
    await prefs.setString(_tokenPrefsKey, session.accessToken);
    await prefs.setString(_sessionPrefsKey, session.toStorageString());
  }

  /// Clears stored token and user profile from [SharedPreferences].
  Future<void> clearPersistedSession() async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return;
    await prefs.remove(_tokenPrefsKey);
    await prefs.remove(_sessionPrefsKey);
  }

  /// Restores any previously persisted Sanctum session and verifies it against `/auth/me`.
  Future<AuthSession?> restoreSession() async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return null;

    final savedToken = prefs.getString(_tokenPrefsKey);
    final cachedSession = AuthSession.fromStorageString(
      prefs.getString(_sessionPrefsKey),
    );
    final token = (savedToken != null && savedToken.isNotEmpty)
        ? savedToken
        : cachedSession?.accessToken;

    if (token == null || token.isEmpty) return null;

    if (enableRemoteSync && _apiClient != null) {
      try {
        final response = await _apiClient.get<Map<String, dynamic>>(
          ApiEndpoints.currentUser,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final payload = ApiClient.unwrapData(response.data);
        if (payload is Map<String, dynamic>) {
          final freshUser = AuthUser.fromJson(payload);
          if (!freshUser.isActive) {
            await clearPersistedSession();
            return null;
          }
          final verified = AuthSession(
            user: freshUser,
            accessToken: token,
            expiresAt:
                cachedSession?.expiresAt ??
                DateTime.now().add(const Duration(days: 7)),
          );
          await _persistSession(verified);
          return verified;
        }
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          await clearPersistedSession();
          return null;
        }
        // Keep cached session on temporary network/timeout failures.
        return cachedSession;
      }
    }

    return cachedSession;
  }

  /// Returns an unmodifiable snapshot of seeded/offline staff accounts.
  List<AuthUser> getRegisteredUsers() =>
      List.unmodifiable(_accounts.map((entry) => entry.user));

  /// Registers a new staff user in the offline directory.
  AuthUser addStaffUser({
    required String name,
    required String email,
    required UserRole role,
    required String branchName,
    required String phone,
    String initialPassword = 'password123',
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final exists = _accounts.any(
      (entry) => entry.user.email.toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw const FormatException('Email karyawan sudah terdaftar.');
    }

    final newUser = AuthUser(
      id: 'USR-${(_accounts.length + 1).toString().padLeft(3, '0')}',
      name: name.trim(),
      email: normalizedEmail,
      role: role,
      branchName: branchName.trim().isEmpty
          ? 'TB. Dobrak Mandiri Pusat'
          : branchName.trim(),
      phone: phone.trim().isEmpty ? '-' : phone.trim(),
    );
    _accounts.add(_SeedAccount(user: newUser, password: initialPassword));
    return newUser;
  }

  /// Updates an existing staff user's active status or assigned role locally.
  AuthUser updateStaffUser({
    required String userId,
    UserRole? role,
    bool? isActive,
  }) {
    final index = _accounts.indexWhere((entry) => entry.user.id == userId);
    if (index == -1) {
      throw StateError('Pengguna tidak ditemukan.');
    }
    final updated = _accounts[index].user.copyWith(
      role: role,
      isActive: isActive,
    );
    _accounts[index].user = updated;
    return updated;
  }

  /// Authenticates an employee against `POST /api/v1/auth/login`.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (enableRemoteSync && _apiClient != null) {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
          'device_name': 'dobrak_mandiri_mobile',
        },
      );

      final rawData = ApiClient.unwrapData(response.data);
      final data = rawData is Map<String, dynamic>
          ? rawData
          : <String, dynamic>{};

      final token =
          (data['token'] as String?) ?? (data['access_token'] as String?) ?? '';
      if (token.isEmpty) {
        throw const ApiException(
          'Server tidak mengembalikan token autentikasi.',
          statusCode: 500,
        );
      }

      final userJson =
          data['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final session = AuthSession(
        user: AuthUser.fromJson(userJson),
        accessToken: token,
        tokenType: data['token_type'] as String? ?? 'Bearer',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      await _persistSession(session);
      return session;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final normalizedEmail = email.trim().toLowerCase();
    final matchIndex = _accounts.indexWhere(
      (entry) => entry.user.email.toLowerCase() == normalizedEmail,
    );

    if (matchIndex == -1 || _accounts[matchIndex].password != password) {
      throw const ApiException(
        'Email atau kata sandi tidak sesuai.',
        statusCode: 401,
        errorCode: 'INVALID_CREDENTIALS',
      );
    }

    final user = _accounts[matchIndex].user;
    if (!user.isActive) {
      throw const ApiException(
        'Akun dinonaktifkan oleh Owner. Hubungi admin toko.',
        statusCode: 403,
        errorCode: 'ACCOUNT_INACTIVE',
      );
    }

    return AuthSession(
      user: user,
      accessToken: 'dm-token-${user.id}-${user.role.code}',
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      isDemoSession: true,
    );
  }

  /// Signs in locally as the seeded demo account matching [role] for UI/RBAC previews.
  Future<AuthSession> loginWithDemoRole(UserRole role) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final account = _accounts.firstWhere(
      (entry) => entry.user.role == role && entry.user.isActive,
      orElse: () => throw ApiException(
        'Tidak ada akun aktif untuk peran ${role.label}.',
        statusCode: 403,
      ),
    );
    return AuthSession(
      user: account.user,
      accessToken: 'dm-token-${account.user.id}-${role.code}',
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      isDemoSession: true,
    );
  }

  /// Fetches fresh authenticated user details from `GET /api/v1/auth/me`.
  Future<AuthUser> fetchCurrentUser() async {
    if (!enableRemoteSync || _apiClient == null) {
      throw StateError('Remote API tidak aktif.');
    }
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.currentUser,
    );
    final payload = ApiClient.unwrapData(response.data);
    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Format profil pengguna tidak valid.');
    }
    return AuthUser.fromJson(payload);
  }

  /// Changes the current user's password via `PATCH /api/v1/auth/password`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (!enableRemoteSync || _apiClient == null) return;
    await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.changePassword,
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );
  }

  /// Revokes active backend Sanctum token (best-effort) and clears stored credentials.
  Future<void> logout({bool revokeRemote = true}) async {
    if (revokeRemote && enableRemoteSync && _apiClient != null) {
      try {
        await _apiClient.post<void>(ApiEndpoints.logout);
      } on ApiException {
        // Local session cleanup must always succeed even if network/token fails.
      }
    }
    await clearPersistedSession();
  }
}
