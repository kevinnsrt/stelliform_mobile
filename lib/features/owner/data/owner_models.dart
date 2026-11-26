import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';

/// Executive dashboard reporting period filter.
enum AnalyticsPeriod {
  today,
  thisWeek,
  thisMonth;

  /// Display label used in period segmented tabs.
  String get label => switch (this) {
    AnalyticsPeriod.today => 'Hari Ini',
    AnalyticsPeriod.thisWeek => 'Minggu Ini',
    AnalyticsPeriod.thisMonth => 'Bulan Ini',
  };
}

/// Daily or periodic cashflow data point for the executive revenue trend chart.
class RevenueTrendPoint {
  /// Creates a [RevenueTrendPoint].
  const RevenueTrendPoint({
    required this.label,
    required this.revenue,
    required this.expense,
  });

  /// Short axis label (e.g. `Sen`, `Sel`, `26/11`).
  final String label;

  /// Gross revenue in IDR.
  final double revenue;

  /// Total operating & COGS outflow in IDR.
  final double expense;
}

/// Payment channel share summary displayed on the Owner dashboard.
class PaymentShare {
  /// Creates a [PaymentShare].
  const PaymentShare({
    required this.method,
    required this.amount,
    required this.percentage,
  });

  /// Payment channel.
  final PaymentMethod method;

  /// Total settled or booked amount in IDR.
  final double amount;

  /// Percentage share from `0` to `100`.
  final double percentage;
}

/// Consolidated real-time executive KPI snapshot for [OwnerDashboardScreen].
class OwnerDashboardSnapshot {
  /// Creates an [OwnerDashboardSnapshot].
  const OwnerDashboardSnapshot({
    required this.period,
    required this.grossRevenue,
    required this.netProfit,
    required this.netMarginPercent,
    required this.revenueGrowthPercent,
    required this.totalTransactions,
    required this.pendingDeliveries,
    required this.inTransitDeliveries,
    required this.deliveredCount,
    required this.lowStockProducts,
    required this.revenueTrend,
    required this.paymentBreakdown,
    required this.lastUpdated,
  });

  /// Selected reporting period.
  final AnalyticsPeriod period;

  /// Gross sales revenue in IDR.
  final double grossRevenue;

  /// Net profit after COGS, expenses, and payroll in IDR.
  final double netProfit;

  /// Net profit margin percentage.
  final double netMarginPercent;

  /// Period-over-period revenue growth percentage.
  final double revenueGrowthPercent;

  /// Total POS transactions counted in the period.
  final int totalTransactions;

  /// Count of delivery orders awaiting dispatch.
  final int pendingDeliveries;

  /// Count of delivery orders currently in transit.
  final int inTransitDeliveries;

  /// Count of completed POD deliveries.
  final int deliveredCount;

  /// Products whose inventory is at or below minimum threshold.
  final List<ProductItem> lowStockProducts;

  /// Chart series comparing revenue and outflow.
  final List<RevenueTrendPoint> revenueTrend;

  /// Revenue split across payment channels.
  final List<PaymentShare> paymentBreakdown;

  /// Timestamp when snapshot was compiled.
  final DateTime lastUpdated;

  /// Combined count of active shipments (`pending + inTransit`).
  int get activeDeliveries => pendingDeliveries + inTransitDeliveries;
}
