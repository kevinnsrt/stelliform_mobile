import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';
import 'package:stelliform_mobile/features/auth/data/auth_repository.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_repository.dart';
import 'package:stelliform_mobile/features/finance/data/finance_repository.dart';
import 'package:stelliform_mobile/features/owner/data/owner_models.dart';
import 'package:stelliform_mobile/features/scm/data/scm_models.dart';
import 'package:stelliform_mobile/features/scm/data/scm_repository.dart';

/// Repository aggregating cross-module ERP analytics and Owner RBAC user CRUD.
class OwnerRepository {
  /// Creates an [OwnerRepository] backed by store feature repositories.
  OwnerRepository({
    required AuthRepository authRepository,
    required CashierRepository cashierRepository,
    required ScmRepository scmRepository,
    required FinanceRepository financeRepository,
    ApiClient? apiClient,
    this.enableRemoteSync = true,
  }) : _authRepository = authRepository,
       _cashierRepository = cashierRepository,
       _scmRepository = scmRepository,
       _financeRepository = financeRepository,
       _apiClient = apiClient;

  final AuthRepository _authRepository;
  final CashierRepository _cashierRepository;
  final ScmRepository _scmRepository;
  final FinanceRepository _financeRepository;
  final ApiClient? _apiClient;

  /// Whether Owner KPI and User Management actions sync with the remote API.
  final bool enableRemoteSync;

  final Map<AnalyticsPeriod, OwnerDashboardSnapshot> _remoteSnapshots = {};
  List<AuthUser>? _remoteUsers;

  /// Fetches live KPI metrics from `/finance/dashboard`, `/finance/rekap/pembayaran`,
  /// and `/gudang/stok-menipis` and updates the cached [OwnerDashboardSnapshot].
  Future<OwnerDashboardSnapshot> fetchRemoteSnapshot(
    AnalyticsPeriod period,
  ) async {
    if (!enableRemoteSync || _apiClient == null) {
      return fetchSnapshot(period);
    }

    final dashboard = await _financeRepository.fetchDashboardPayload();
    final pnl = await _financeRepository.fetchRemotePnlSummary(
      periodLabel: period.label,
    );
    final paymentRows = await _financeRepository.fetchPaymentBreakdown(
      periodLabel: period.label,
    );

    final lowStockRes = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.lowStock,
      queryParameters: {'per_page': 50},
    );
    final lowStock = ApiClient.unwrapList(
      lowStockRes.data,
    ).map(ProductItem.fromJson).toList(growable: false);

    final periodBlock = switch (period) {
      AnalyticsPeriod.today => dashboard['hari_ini'] as Map<String, dynamic>?,
      AnalyticsPeriod.thisWeek || AnalyticsPeriod.thisMonth =>
        dashboard['bulan_berjalan'] as Map<String, dynamic>?,
    };
    final penjualan = periodBlock?['penjualan'] as Map<String, dynamic>?;
    final perluPerhatian =
        dashboard['perlu_perhatian'] as Map<String, dynamic>?;

    final rawTrend = dashboard['tren_7_hari'] as List? ?? const [];
    final trendPoints = rawTrend
        .whereType<Map<String, dynamic>>()
        .map((day) {
          final rawDate = (day['tanggal'] ?? '').toString();
          final parts = rawDate.split('-');
          final shortDate = parts.length == 3
              ? '${parts[2]}/${parts[1]}'
              : rawDate;
          final omzet = (day['omzet'] as num?)?.toDouble() ?? 0;
          final transportCost = (day['biaya_angkut'] as num?)?.toDouble() ?? 0;
          return RevenueTrendPoint(
            label: shortDate,
            revenue: omzet,
            expense: (omzet * 0.72) + transportCost,
          );
        })
        .toList(growable: false);

    final breakdown = paymentRows
        .map(
          (row) => PaymentShare(
            method: PaymentMethod.fromBackend(
              row['jenis_pembayaran'] as String?,
            ),
            amount: (row['total'] as num?)?.toDouble() ?? 0,
            percentage: (row['persentase'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);

    final pendingAntar =
        (perluPerhatian?['barang_menunggu_diantar'] as num?)?.toInt() ?? 0;
    final gagalAntar =
        (perluPerhatian?['barang_gagal_diantar'] as num?)?.toInt() ?? 0;

    final snapshot = OwnerDashboardSnapshot(
      period: period,
      grossRevenue: pnl.grossRevenue,
      netProfit: pnl.netProfit,
      netMarginPercent: pnl.netMarginPercent,
      revenueGrowthPercent: 0,
      totalTransactions:
          (penjualan?['jumlah_transaksi'] as num?)?.toInt() ??
          pnl.transactionCount,
      pendingDeliveries: pendingAntar,
      inTransitDeliveries: gagalAntar,
      deliveredCount: _scmRepository
          .getDeliveries()
          .where((d) => d.status == DeliveryStatus.delivered)
          .length,
      lowStockProducts: lowStock,
      revenueTrend: trendPoints.isNotEmpty
          ? trendPoints
          : const [
              RevenueTrendPoint(label: 'Hari Ini', revenue: 0, expense: 0),
            ],
      paymentBreakdown: breakdown,
      lastUpdated: DateTime.now(),
    );

    _remoteSnapshots[period] = snapshot;
    return snapshot;
  }

  /// Returns cached remote snapshot if available, otherwise computes offline snapshot.
  OwnerDashboardSnapshot fetchSnapshot(AnalyticsPeriod period) {
    final cached = _remoteSnapshots[period];
    if (cached != null) return cached;

    final pnl = _financeRepository.computePnlSummary(periodLabel: period.label);
    final receipts = _cashierRepository.getReceipts();
    final deliveries = _scmRepository.getDeliveries();
    final lowStock = _cashierRepository.getLowStockProducts();

    final pendingCount = deliveries
        .where((d) => d.status == DeliveryStatus.pending)
        .length;
    final inTransitCount = deliveries
        .where((d) => d.status == DeliveryStatus.inTransit)
        .length;
    final deliveredCount = deliveries
        .where((d) => d.status == DeliveryStatus.delivered)
        .length;

    final baseTxCount = switch (period) {
      AnalyticsPeriod.today => 18,
      AnalyticsPeriod.thisWeek => 96,
      AnalyticsPeriod.thisMonth => 384,
    };

    final growth = switch (period) {
      AnalyticsPeriod.today => 12.4,
      AnalyticsPeriod.thisWeek => 8.7,
      AnalyticsPeriod.thisMonth => 15.2,
    };

    final scale = switch (period) {
      AnalyticsPeriod.today => 1.0,
      AnalyticsPeriod.thisWeek => 4.2,
      AnalyticsPeriod.thisMonth => 14.5,
    };

    final trend = [
      RevenueTrendPoint(
        label: 'Sen',
        revenue: 14200000 * scale / 4,
        expense: 10900000 * scale / 4,
      ),
      RevenueTrendPoint(
        label: 'Sel',
        revenue: 16800000 * scale / 4,
        expense: 12100000 * scale / 4,
      ),
      RevenueTrendPoint(
        label: 'Rab',
        revenue: 13500000 * scale / 4,
        expense: 10400000 * scale / 4,
      ),
      RevenueTrendPoint(
        label: 'Kam',
        revenue: 19400000 * scale / 4,
        expense: 14100000 * scale / 4,
      ),
      RevenueTrendPoint(
        label: 'Jum',
        revenue: 21200000 * scale / 4,
        expense: 15200000 * scale / 4,
      ),
      RevenueTrendPoint(
        label: 'Sab',
        revenue:
            (18500000 * scale / 4) +
            receipts.fold<double>(0, (s, r) => s + r.grandTotal) * 0.25,
        expense: 13200000 * scale / 4,
      ),
    ];

    final totalRev = pnl.grossRevenue;
    final breakdown = [
      PaymentShare(
        method: PaymentMethod.cash,
        amount: totalRev * 0.34,
        percentage: 34,
      ),
      PaymentShare(
        method: PaymentMethod.transfer,
        amount: totalRev * 0.31,
        percentage: 31,
      ),
      PaymentShare(
        method: PaymentMethod.qris,
        amount: totalRev * 0.20,
        percentage: 20,
      ),
      PaymentShare(
        method: PaymentMethod.tempo,
        amount: totalRev * 0.15,
        percentage: 15,
      ),
    ];

    return OwnerDashboardSnapshot(
      period: period,
      grossRevenue: pnl.grossRevenue,
      netProfit: pnl.netProfit,
      netMarginPercent: pnl.netMarginPercent,
      revenueGrowthPercent: growth,
      totalTransactions: baseTxCount + receipts.length,
      pendingDeliveries: pendingCount,
      inTransitDeliveries: inTransitCount,
      deliveredCount: deliveredCount,
      lowStockProducts: lowStock,
      revenueTrend: trend,
      paymentBreakdown: breakdown,
      lastUpdated: DateTime.now(),
    );
  }

  /// Returns staff accounts (prefers remote `/sistem/user` list when loaded).
  List<AuthUser> getStaffUsers() =>
      _remoteUsers ?? _authRepository.getRegisteredUsers();

  /// Fetches employees from `GET /api/v1/sistem/user`.
  Future<List<AuthUser>> fetchStaffUsers() async {
    if (!enableRemoteSync || _apiClient == null) {
      return getStaffUsers();
    }

    final res = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.users,
      queryParameters: {'per_page': 50},
    );
    final rawList = ApiClient.unwrapList(res.data);
    final users = rawList.map(AuthUser.fromJson).toList(growable: false);
    _remoteUsers = users;
    return List.unmodifiable(users);
  }

  /// Creates a new employee user account (`POST /api/v1/sistem/user`).
  Future<AuthUser> createStaffUser({
    required String name,
    required String email,
    required UserRole role,
    required String branchName,
    required String phone,
    String initialPassword = 'password123',
  }) async {
    if (enableRemoteSync && _apiClient != null) {
      final res = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.users,
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim().isEmpty ? null : phone.trim(),
          'password': initialPassword,
          'role': role.backendCode,
          'is_active': true,
        },
      );
      final data = ApiClient.unwrapData(res.data);
      if (data is Map<String, dynamic>) {
        final created = AuthUser.fromJson(data);
        _remoteUsers = [...?_remoteUsers, created];
        return created;
      }
    }

    return _authRepository.addStaffUser(
      name: name,
      email: email,
      role: role,
      branchName: branchName,
      phone: phone,
      initialPassword: initialPassword,
    );
  }

  /// Toggles an employee account's active status (`PATCH /api/v1/sistem/user/{id}/status`).
  Future<AuthUser> toggleUserActive(AuthUser user, bool nextActive) async {
    if (enableRemoteSync && _apiClient != null && user.numericId != null) {
      final res = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.updateUserStatus(user.numericId!),
        data: {'is_active': nextActive},
      );
      final data = ApiClient.unwrapData(res.data);
      if (data is Map<String, dynamic>) {
        final updated = AuthUser.fromJson(data);
        _replaceCachedUser(updated);
        return updated;
      }
    }

    return _authRepository.updateStaffUser(
      userId: user.id,
      isActive: nextActive,
    );
  }

  /// Updates an employee's RBAC role (`PATCH /api/v1/sistem/user/{id}/role`).
  Future<AuthUser> updateUserRole(AuthUser user, UserRole nextRole) async {
    if (enableRemoteSync && _apiClient != null && user.numericId != null) {
      final res = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.updateUserRole(user.numericId!),
        data: {'role': nextRole.backendCode},
      );
      final data = ApiClient.unwrapData(res.data);
      if (data is Map<String, dynamic>) {
        final updated = AuthUser.fromJson(data);
        _replaceCachedUser(updated);
        return updated;
      }
    }

    return _authRepository.updateStaffUser(userId: user.id, role: nextRole);
  }

  void _replaceCachedUser(AuthUser updated) {
    final list = _remoteUsers;
    if (list == null) return;
    _remoteUsers = list
        .map((u) => u.id == updated.id ? updated : u)
        .toList(growable: false);
  }
}
