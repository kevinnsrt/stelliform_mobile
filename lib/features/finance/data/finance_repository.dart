import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_repository.dart';
import 'package:stelliform_mobile/features/finance/data/finance_models.dart';

/// Repository fetching read-only Finance analytics (`/api/v1/finance/*`) and
/// maintaining local store expenses and staff payroll tracking.
class FinanceRepository {
  /// Creates a [FinanceRepository] linked to [cashierRepository] sales records.
  FinanceRepository({
    required CashierRepository cashierRepository,
    ApiClient? apiClient,
    this.enableRemoteSync = true,
  }) : _cashierRepository = cashierRepository,
       _apiClient = apiClient;

  final CashierRepository _cashierRepository;
  final ApiClient? _apiClient;

  /// Whether finance analytics should sync with the remote Laravel backend.
  final bool enableRemoteSync;

  final Map<String, PnlSummary> _syncedPnlByPeriod = {};

  final List<ExpenseEntry> _expenses = [
    ExpenseEntry(
      id: 'EXP-001',
      title: 'Solar Armada Engkel & Truk Pasir',
      category: ExpenseCategory.fuelAndFleet,
      amount: 1450000,
      date: DateTime(2026, 11, 26, 8, 20),
      recordedBy: 'Nadia Permata',
      notes: 'Pengisian penuh 2 unit armada pagi',
    ),
    ExpenseEntry(
      id: 'EXP-002',
      title: 'Restock Semen Tiga Roda (100 Sak)',
      category: ExpenseCategory.supplierPurchase,
      amount: 5400000,
      date: DateTime(2026, 11, 25, 15, 0),
      recordedBy: 'Nadia Permata',
      notes: 'DO PT Indocement Tunggal Prakarsa',
    ),
    ExpenseEntry(
      id: 'EXP-003',
      title: 'Tagihan Listrik Gudang & Kasir',
      category: ExpenseCategory.utilities,
      amount: 1850000,
      date: DateTime(2026, 11, 24, 11, 10),
      recordedBy: 'Nadia Permata',
      notes: 'Token & pascabayar November',
    ),
    ExpenseEntry(
      id: 'EXP-004',
      title: 'Konsumsi Kuli Muat & Bongkar Pasir',
      category: ExpenseCategory.operational,
      amount: 420000,
      date: DateTime(2026, 11, 26, 11, 30),
      recordedBy: 'Nadia Permata',
    ),
  ];

  final List<PayrollEntry> _payroll = [
    PayrollEntry(
      id: 'PAY-001',
      employeeName: 'Siti Rahayu',
      roleLabel: 'Kasir',
      baseSalary: 3800000,
      overtimeAllowance: 350000,
      deductions: 0,
      isPaid: true,
      periodLabel: 'November 2026',
      paidAt: DateTime(2026, 11, 25, 10, 0),
    ),
    const PayrollEntry(
      id: 'PAY-002',
      employeeName: 'Budi Santoso',
      roleLabel: 'Staff Gudang',
      baseSalary: 3600000,
      overtimeAllowance: 450000,
      deductions: 150000,
      isPaid: false,
      periodLabel: 'November 2026',
    ),
    const PayrollEntry(
      id: 'PAY-003',
      employeeName: 'Dedi Kurniawan',
      roleLabel: 'Kurir Armada',
      baseSalary: 3500000,
      overtimeAllowance: 650000,
      deductions: 0,
      isPaid: false,
      periodLabel: 'November 2026',
    ),
    PayrollEntry(
      id: 'PAY-004',
      employeeName: 'Nadia Permata',
      roleLabel: 'Finance',
      baseSalary: 4500000,
      overtimeAllowance: 200000,
      deductions: 0,
      isPaid: true,
      periodLabel: 'November 2026',
      paidAt: DateTime(2026, 11, 25, 10, 5),
    ),
  ];

  /// Returns recorded expenses ordered newest-first.
  List<ExpenseEntry> getExpenses() => List.unmodifiable(_expenses.reversed);

  /// Returns staff payroll entries for the active period.
  List<PayrollEntry> getPayrollEntries() => List.unmodifiable(_payroll);

  /// Formats date range `(dari, sampai)` in `YYYY-MM-DD` for [periodLabel].
  static (String dari, String sampai) dateRangeForPeriod(String periodLabel) {
    final now = DateTime.now();
    String fmt(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final end = fmt(now);
    return switch (periodLabel) {
      'Hari Ini' => (end, end),
      'Minggu Ini' => (fmt(now.subtract(const Duration(days: 6))), end),
      _ => (fmt(DateTime(now.year, now.month, 1)), end),
    };
  }

  /// Fetches live Finance dashboard payload from `GET /api/v1/finance/dashboard`.
  Future<Map<String, dynamic>> fetchDashboardPayload() async {
    if (!enableRemoteSync || _apiClient == null) {
      return const {};
    }
    final res = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.financeDashboard,
    );
    final data = ApiClient.unwrapData(res.data);
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Fetches payment breakdown rows from `GET /api/v1/finance/rekap/pembayaran`.
  Future<List<Map<String, dynamic>>> fetchPaymentBreakdown({
    required String periodLabel,
  }) async {
    if (!enableRemoteSync || _apiClient == null) {
      return const [];
    }
    final (dari, sampai) = dateRangeForPeriod(periodLabel);
    final res = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.financePayments,
      queryParameters: {'dari': dari, 'sampai': sampai},
    );
    final data = ApiClient.unwrapData(res.data);
    if (data is Map<String, dynamic> && data['rows'] is List) {
      return (data['rows'] as List).whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
    }
    return const [];
  }

  /// Fetches real P&L metrics from `/finance/rekap/pendapatan`, `/finance/rekap/laba-kotor`,
  /// and `/finance/dashboard` and caches them for synchronous UI getters.
  Future<PnlSummary> fetchRemotePnlSummary({
    required String periodLabel,
  }) async {
    if (!enableRemoteSync || _apiClient == null) {
      return computePnlSummary(periodLabel: periodLabel);
    }

    final (dari, sampai) = dateRangeForPeriod(periodLabel);
    final query = {'dari': dari, 'sampai': sampai};

    final pendapatanRes = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.financeRevenue,
      queryParameters: query,
    );
    final labaKotorRes = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.financeGrossProfit,
      queryParameters: query,
    );
    final dashboardData = await fetchDashboardPayload();

    final pendapatan =
        ApiClient.unwrapData(pendapatanRes.data) as Map<String, dynamic>? ??
        const {};
    final labaKotor =
        ApiClient.unwrapData(labaKotorRes.data) as Map<String, dynamic>? ??
        const {};
    final piutang = dashboardData['piutang_berjalan'] as Map<String, dynamic>?;

    final summary = PnlSummary(
      periodLabel: periodLabel,
      grossRevenue: (pendapatan['omzet'] as num?)?.toDouble() ?? 0,
      cogs: (labaKotor['hpp'] as num?)?.toDouble() ?? 0,
      operatingExpenses: _operatingExpensesForPeriod(periodLabel),
      payrollTotal: _payrollForPeriod(periodLabel),
      tempoReceivables: (piutang?['nilai'] as num?)?.toDouble() ?? 0,
      transactionCount: (pendapatan['jumlah_transaksi'] as num?)?.toInt() ?? 0,
      hppCoveragePercent:
          (labaKotor['hpp_cakupan'] as num?)?.toDouble() ?? 100.0,
      isHppComplete: labaKotor['hpp_lengkap'] as bool? ?? true,
      coverageNote: labaKotor['catatan'] as String?,
    );

    _syncedPnlByPeriod[periodLabel] = summary;
    return summary;
  }

  /// Fetches submitted procurements (`GET /finance/pengadaan`) as expense entries.
  Future<List<ExpenseEntry>> fetchExpenses() async {
    if (!enableRemoteSync || _apiClient == null) {
      return getExpenses();
    }

    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.financeProcurement,
        queryParameters: {'per_page': 20},
      );
      final rawList = ApiClient.unwrapList(res.data);
      final remoteProcurements = rawList
          .map(ExpenseEntry.fromProcurementJson)
          .toList(growable: false);

      // Preserve manually entered local expenses alongside server procurements.
      for (final item in remoteProcurements.reversed) {
        final exists = _expenses.any((e) => e.id == item.id);
        if (!exists) {
          _expenses.add(item);
        }
      }
    } on ApiException catch (error) {
      if (error.statusCode != 403 && error.statusCode != 404) {
        rethrow;
      }
    }
    return getExpenses();
  }

  /// Adds a new expense item to the store ledger.
  Future<ExpenseEntry> addExpense({
    required String title,
    required ExpenseCategory category,
    required double amount,
    required String recordedBy,
    String notes = '',
  }) async {
    final entry = ExpenseEntry(
      id: 'EXP-${(_expenses.length + 1).toString().padLeft(3, '0')}',
      title: title.trim(),
      category: category,
      amount: amount,
      date: DateTime.now(),
      recordedBy: recordedBy,
      notes: notes.trim(),
    );
    _expenses.add(entry);
    _syncedPnlByPeriod.clear();
    return entry;
  }

  /// Toggles payroll disbursement state for [payrollId].
  Future<PayrollEntry> togglePayrollPaid(String payrollId) async {
    final index = _payroll.indexWhere((entry) => entry.id == payrollId);
    if (index == -1) {
      throw StateError('Data penggajian tidak ditemukan.');
    }
    final current = _payroll[index];
    final nextPaid = !current.isPaid;
    final updated = current.copyWith(
      isPaid: nextPaid,
      paidAt: nextPaid ? DateTime.now() : null,
    );
    _payroll[index] = updated;
    return updated;
  }

  double _operatingExpensesForPeriod(String periodLabel) {
    final nonSupplierExpenses = _expenses
        .where((e) => e.category != ExpenseCategory.supplierPurchase)
        .fold<double>(0, (sum, e) => sum + e.amount);

    final periodExpenseFactor = switch (periodLabel) {
      'Hari Ini' => 1.0,
      'Minggu Ini' => 2.5,
      _ => 4.2,
    };
    return nonSupplierExpenses * periodExpenseFactor;
  }

  double _payrollForPeriod(String periodLabel) {
    return switch (periodLabel) {
      'Hari Ini' => 0.0,
      'Minggu Ini' => _payroll.fold<double>(0, (s, p) => s + p.netSalary) / 4,
      _ => _payroll.fold<double>(0, (s, p) => s + p.netSalary),
    };
  }

  /// Returns cached backend P&L summary when synced, or computes offline fallback.
  PnlSummary computePnlSummary({required String periodLabel}) {
    final synced = _syncedPnlByPeriod[periodLabel];
    if (synced != null) {
      return synced;
    }

    final receipts = _cashierRepository.getReceipts();
    final livePosSales = receipts.fold<double>(
      0,
      (sum, r) => sum + r.grandTotal,
    );
    final liveTempo = receipts
        .where((r) => r.paymentMethod == PaymentMethod.tempo)
        .fold<double>(0, (sum, r) => sum + r.grandTotal);

    final baselineMultiplier = switch (periodLabel) {
      'Hari Ini' => 14500000.0,
      'Minggu Ini' => 68500000.0,
      _ => 248000000.0,
    };

    final grossRevenue = baselineMultiplier + livePosSales;
    final cogs = grossRevenue * 0.72;

    return PnlSummary(
      periodLabel: periodLabel,
      grossRevenue: grossRevenue,
      cogs: cogs,
      operatingExpenses: _operatingExpensesForPeriod(periodLabel),
      payrollTotal: _payrollForPeriod(periodLabel),
      tempoReceivables: 8750000 + liveTempo,
    );
  }
}
