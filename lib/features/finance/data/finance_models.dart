import 'package:flutter/material.dart';

/// Categories for store operational expenses.
enum ExpenseCategory {
  operational,
  fuelAndFleet,
  supplierPurchase,
  utilities,
  maintenance;

  /// Human-readable Indonesian label.
  String get label => switch (this) {
    ExpenseCategory.operational => 'Operasional Toko',
    ExpenseCategory.fuelAndFleet => 'BBM & Perawatan Armada',
    ExpenseCategory.supplierPurchase => 'Kulakan / Supplier',
    ExpenseCategory.utilities => 'Listrik, Air & Internet',
    ExpenseCategory.maintenance => 'Perbaikan Gudang',
  };

  /// Icon paired with this expense category.
  IconData get icon => switch (this) {
    ExpenseCategory.operational => Icons.storefront_rounded,
    ExpenseCategory.fuelAndFleet => Icons.local_gas_station_rounded,
    ExpenseCategory.supplierPurchase => Icons.warehouse_rounded,
    ExpenseCategory.utilities => Icons.bolt_rounded,
    ExpenseCategory.maintenance => Icons.handyman_rounded,
  };
}

/// Recorded store expense ledger entry (or mapped backend procurement/stock-out record).
class ExpenseEntry {
  /// Creates an [ExpenseEntry].
  const ExpenseEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.recordedBy,
    this.notes = '',
  });

  /// Unique expense identifier.
  final String id;

  /// Short expense description.
  final String title;

  /// Accounting category.
  final ExpenseCategory category;

  /// Total cost in IDR.
  final double amount;

  /// Expense booking date.
  final DateTime date;

  /// Employee who submitted the expense.
  final String recordedBy;

  /// Optional supporting notes or receipt number.
  final String notes;

  /// Hydrates a supplier purchase entry from `/api/v1/finance/pengadaan` JSON.
  factory ExpenseEntry.fromProcurementJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>?;
    final pengaju = json['pengaju'] as Map<String, dynamic>?;
    final items = json['item'] as List? ?? const [];
    final estimatedTotal = items.whereType<Map<String, dynamic>>().fold<double>(
      0,
      (sum, item) {
        final qty = (item['jumlah_diminta'] as num?)?.toDouble() ?? 0;
        final est = (item['perkiraan_harga'] as num?)?.toDouble() ?? 0;
        return sum + (qty * est);
      },
    );

    return ExpenseEntry(
      id: (json['nomor_pengadaan'] ?? json['id_pengadaan'] ?? '').toString(),
      title:
          'Pengadaan ${supplier?['nama_supplier'] ?? 'Supplier'} (${json['status_label'] ?? json['status'] ?? 'Draft'})',
      category: ExpenseCategory.supplierPurchase,
      amount: estimatedTotal,
      date:
          DateTime.tryParse(json['tanggal_pengajuan'] as String? ?? '') ??
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      recordedBy: (pengaju?['name'] ?? 'Gudang').toString(),
      notes: (json['alasan'] as String?) ?? '',
    );
  }
}

/// Monthly staff payroll payout item.
class PayrollEntry {
  /// Creates a [PayrollEntry].
  const PayrollEntry({
    required this.id,
    required this.employeeName,
    required this.roleLabel,
    required this.baseSalary,
    required this.overtimeAllowance,
    required this.deductions,
    required this.isPaid,
    required this.periodLabel,
    this.paidAt,
  });

  /// Unique payroll record ID.
  final String id;

  /// Employee full name.
  final String employeeName;

  /// Role or department label.
  final String roleLabel;

  /// Monthly base salary in IDR.
  final double baseSalary;

  /// Overtime / delivery bonus allowance in IDR.
  final double overtimeAllowance;

  /// Deductions (kasbon / late penalty) in IDR.
  final double deductions;

  /// Whether salary transfer has been disbursed.
  final bool isPaid;

  /// Billing month label, e.g. `November 2026`.
  final String periodLabel;

  /// Payout timestamp when [isPaid] is `true`.
  final DateTime? paidAt;

  /// Net take-home salary in IDR.
  double get netSalary => baseSalary + overtimeAllowance - deductions;

  /// Returns a copy with updated payout status.
  PayrollEntry copyWith({bool? isPaid, DateTime? paidAt}) {
    return PayrollEntry(
      id: id,
      employeeName: employeeName,
      roleLabel: roleLabel,
      baseSalary: baseSalary,
      overtimeAllowance: overtimeAllowance,
      deductions: deductions,
      isPaid: isPaid ?? this.isPaid,
      periodLabel: periodLabel,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

/// Profit & Loss (Laba Rugi) financial statement snapshot.
class PnlSummary {
  /// Creates a [PnlSummary].
  const PnlSummary({
    required this.periodLabel,
    required this.grossRevenue,
    required this.cogs,
    required this.operatingExpenses,
    required this.payrollTotal,
    required this.tempoReceivables,
    this.transactionCount = 0,
    this.hppCoveragePercent = 100.0,
    this.isHppComplete = true,
    this.coverageNote,
  });

  /// Reporting period title.
  final String periodLabel;

  /// Total gross sales revenue in IDR.
  final double grossRevenue;

  /// Cost of Goods Sold (Harga Pokok Penjualan / HPP) in IDR.
  final double cogs;

  /// Non-payroll operating expenses in IDR.
  final double operatingExpenses;

  /// Total disbursed/accrued payroll in IDR.
  final double payrollTotal;

  /// Outstanding Tempo / Credit invoices receivable in IDR (`piutang_berjalan.nilai`).
  final double tempoReceivables;

  /// Total non-void transactions in period.
  final int transactionCount;

  /// Percentage of invoice lines with populated `harga_modal_snapshot`.
  final double hppCoveragePercent;

  /// Whether all lines in the period have a known cost price (`hpp_lengkap`).
  final bool isHppComplete;

  /// Optional backend disclaimer note (`catatan`) when some lines lack modal.
  final String? coverageNote;

  /// Gross profit (`grossRevenue - cogs`).
  double get grossProfit => grossRevenue - cogs;

  /// Net operating profit (`grossProfit - operatingExpenses - payrollTotal`).
  double get netProfit => grossProfit - operatingExpenses - payrollTotal;

  /// Net profit margin percentage (`0` when revenue is zero).
  double get netMarginPercent =>
      grossRevenue <= 0 ? 0 : (netProfit / grossRevenue) * 100;
}
