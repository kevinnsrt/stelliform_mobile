import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Supported RBAC employee roles across Dobrak Mandiri ERP.
///
/// The Laravel backend enforces four core RBAC roles (`OWNER`, `FINANCE`,
/// `GUDANG`, `KASIR`). Within the mobile app, `staffGudang` and `kurir`
/// both map to the backend `GUDANG` role so warehouse logistics and driver POD
/// permissions align seamlessly with server-side `spatie/laravel-permission`.
enum UserRole {
  kasir,
  staffGudang,
  kurir,
  finance,
  owner;

  /// Client-side role identifier.
  String get code => switch (this) {
    UserRole.kasir => 'KASIR',
    UserRole.staffGudang => 'GUDANG',
    UserRole.kurir => 'KURIR',
    UserRole.finance => 'FINANCE',
    UserRole.owner => 'OWNER',
  };

  /// Canonical role string recognized by `/api/v1/sistem/user` endpoints.
  String get backendCode => switch (this) {
    UserRole.kasir => 'KASIR',
    UserRole.staffGudang => 'GUDANG',
    UserRole.kurir => 'GUDANG',
    UserRole.finance => 'FINANCE',
    UserRole.owner => 'OWNER',
  };

  /// Human-readable Indonesian role title.
  String get label => switch (this) {
    UserRole.kasir => 'Kasir',
    UserRole.staffGudang => 'Staff Gudang',
    UserRole.kurir => 'Kurir',
    UserRole.finance => 'Finance',
    UserRole.owner => 'Owner',
  };

  /// Concise description of this role's operational scope.
  String get description => switch (this) {
    UserRole.kasir => 'Transaksi POS kasir, pelanggan, & cetak struk',
    UserRole.staffGudang => 'Stok opname material & penjadwalan muat armada',
    UserRole.kurir => 'Pengiriman pesanan, foto POD & tanda tangan digital',
    UserRole.finance => 'Rekap penjualan, laba kotor (HPP), & pengadaan',
    UserRole.owner => 'Analitik eksekutif, kontrol penuh & manajemen akun',
  };

  /// Material icon representing this role.
  IconData get icon => switch (this) {
    UserRole.kasir => Icons.point_of_sale_rounded,
    UserRole.staffGudang => Icons.inventory_2_rounded,
    UserRole.kurir => Icons.local_shipping_rounded,
    UserRole.finance => Icons.account_balance_wallet_rounded,
    UserRole.owner => Icons.analytics_rounded,
  };

  /// Semantic accent color for role chips and badges.
  Color get color => switch (this) {
    UserRole.kasir => AppColors.accent,
    UserRole.staffGudang => AppColors.secondary,
    UserRole.kurir => AppColors.info,
    UserRole.finance => AppColors.success,
    UserRole.owner => AppColors.primaryDark,
  };

  /// Default landing route path after successful authentication.
  String get homeRoute => switch (this) {
    UserRole.kasir => '/cashier/pos',
    UserRole.staffGudang => '/scm/stock-opname',
    UserRole.kurir => '/scm/driver-pod',
    UserRole.finance => '/finance/pnl-report',
    UserRole.owner => '/owner/dashboard',
  };

  /// Parses a backend or local role [code] into [UserRole].
  static UserRole fromCode(String code) {
    final normalized = code.trim().toUpperCase();
    return switch (normalized) {
      'OWNER' => UserRole.owner,
      'FINANCE' => UserRole.finance,
      'GUDANG' || 'STAFF_GUDANG' || 'STAFFGUDANG' => UserRole.staffGudang,
      'KURIR' => UserRole.kurir,
      'KASIR' => UserRole.kasir,
      _ => UserRole.values.firstWhere(
        (role) => role.name.toUpperCase() == normalized,
        orElse: () => UserRole.kasir,
      ),
    };
  }
}

/// Authenticated employee profile matching Laravel `UserResource`.
class AuthUser {
  /// Creates an [AuthUser].
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.branchName,
    required this.phone,
    this.isActive = true,
    this.roleLabel,
    this.permissions = const [],
    this.lastLoginAt,
  });

  /// Unique staff identifier (numeric ID from database as string, or local seed ID).
  final String id;

  /// Full employee name.
  final String name;

  /// Corporate login email.
  final String email;

  /// Assigned RBAC role.
  final UserRole role;

  /// Backend role label if supplied by `UserResource`.
  final String? roleLabel;

  /// Store or warehouse branch name.
  final String branchName;

  /// Active phone or WhatsApp contact number.
  final String phone;

  /// Whether the account is active and permitted to log in.
  final bool isActive;

  /// Fine-grained Spatie permission names returned by `/auth/login` or `/auth/me`.
  final List<String> permissions;

  /// Last successful login timestamp.
  final DateTime? lastLoginAt;

  /// Integer primary key for REST endpoints accepting `{id}`, or `null` for local seeds.
  int? get numericId => int.tryParse(id);

  /// Returns `true` if [permissions] includes [permission] (or empty when offline).
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Creates an [AuthUser] from an API `UserResource` JSON map.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    final parsedPermissions = rawPermissions is List
        ? rawPermissions.map((item) => item.toString()).toList(growable: false)
        : const <String>[];

    final rawLastLogin = json['last_login_at'] as String?;

    return AuthUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['nama'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: UserRole.fromCode((json['role'] ?? 'KASIR').toString()),
      roleLabel: json['role_label'] as String?,
      branchName: json['branch_name'] as String? ?? 'TB. Dobrak Mandiri Pusat',
      phone: (json['phone'] as String?)?.trim().isNotEmpty == true
          ? (json['phone'] as String).trim()
          : '-',
      isActive: json['is_active'] as bool? ?? true,
      permissions: parsedPermissions,
      lastLoginAt: rawLastLogin != null
          ? DateTime.tryParse(rawLastLogin)
          : null,
    );
  }

  /// Serializes this user to a JSON map for caching or requests.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nama': name,
    'email': email,
    'role': role.backendCode,
    'role_label': roleLabel ?? role.label,
    'branch_name': branchName,
    'phone': phone,
    'is_active': isActive,
    'permissions': permissions,
    if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
  };

  /// Returns a copy with selectively updated attributes.
  AuthUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? roleLabel,
    String? branchName,
    String? phone,
    bool? isActive,
    List<String>? permissions,
    DateTime? lastLoginAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      roleLabel: roleLabel ?? this.roleLabel,
      branchName: branchName ?? this.branchName,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

/// Active authenticated session containing [user] and Sanctum Bearer token metadata.
class AuthSession {
  /// Creates an [AuthSession].
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
    this.isDemoSession = false,
  });

  /// Authenticated employee profile.
  final AuthUser user;

  /// Sanctum Bearer token for API requests.
  final String accessToken;

  /// Token scheme returned by Laravel (`Bearer`).
  final String tokenType;

  /// Local cache expiry timestamp.
  final DateTime expiresAt;

  /// Whether this session originated from the offline RBAC demo switcher.
  final bool isDemoSession;

  /// Serializes this session into a compact JSON string for SharedPreferences.
  String toStorageString() => jsonEncode({
    'access_token': accessToken,
    'token_type': tokenType,
    'expires_at': expiresAt.toIso8601String(),
    'user': user.toJson(),
  });

  /// Restores an [AuthSession] from a stored JSON string, or `null` if malformed.
  static AuthSession? fromStorageString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final token = map['access_token'] as String? ?? '';
      final userMap = map['user'] as Map<String, dynamic>?;
      if (token.isEmpty || userMap == null) return null;
      final expiresAt =
          DateTime.tryParse(map['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7));
      return AuthSession(
        user: AuthUser.fromJson(userMap),
        accessToken: token,
        tokenType: map['token_type'] as String? ?? 'Bearer',
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }
}
