import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/currency_formatter.dart';
import 'package:stelliform_mobile/app/utils/date_formatter.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/owner/controllers/owner_controller.dart';
import 'package:stelliform_mobile/features/owner/data/owner_models.dart';

/// Minimalist executive real-time analytics dashboard for Store Owner.
class OwnerDashboardScreen extends StatefulWidget {
  /// Creates an [OwnerDashboardScreen].
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        final owner = context.read<OwnerController>();
        await owner.refreshAnalytics();
        if (!mounted || owner.lastException == null) return;
        ApiErrorFeedback.showSnackBar(
          context,
          owner.lastException,
          onRetry: owner.refreshAnalytics,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<OwnerController>();
    final palette = AppColors.of(context);
    final snapshot = owner.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Executive Dashboard'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Muat Ulang Analitik',
            icon: owner.isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: owner.isRefreshing ? null : owner.refreshAnalytics,
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.ownerDashboard),
      body: RefreshIndicator(
        onRefresh: owner.refreshAnalytics,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (owner.errorMessage != null) ...[
              ApiErrorBanner(
                message: owner.errorMessage!,
                onRetry: owner.refreshAnalytics,
              ),
              const SizedBox(height: 12),
            ],
            // Executive Header + Period Filter (flat bordered container)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TB. DOBRAK MANDIRI',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ringkasan Real-Time • ${DateFormatter.formatFullDate(snapshot.lastUpdated)}',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'LIVE SYNC',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AnalyticsPeriod.values.map((period) {
                      final isSelected = owner.selectedPeriod == period;
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => owner.setPeriod(period),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primarySoft
                                : palette.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? palette.primary
                                  : palette.border,
                            ),
                          ),
                          child: Text(
                            period.label,
                            style: TextStyle(
                              color: isSelected
                                  ? palette.primary
                                  : palette.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'User Management',
                    icon: Icons.manage_accounts_rounded,
                    variant: CustomButtonVariant.secondary,
                    onPressed: () => context.go(AppRoutes.userManagement),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    label: 'Financial Reports',
                    icon: Icons.assessment_rounded,
                    variant: CustomButtonVariant.primary,
                    onPressed: () => context.go(AppRoutes.pnlReport),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4 Core Executive KPI Cards (flat 10px containers)
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: MediaQuery.sizeOf(context).width >= 760
                  ? 1.35
                  : 1.18,
              children: [
                _ExecutiveKpiCard(
                  title: 'Gross Revenue',
                  subtitle: '${snapshot.totalTransactions} transaksi',
                  value: CurrencyFormatter.formatCompactIdr(
                    snapshot.grossRevenue,
                  ),
                  badgeText: '+${snapshot.revenueGrowthPercent}%',
                  accentColor: palette.primary,
                  icon: Icons.trending_up_rounded,
                ),
                _ExecutiveKpiCard(
                  title: 'Net Profit',
                  subtitle:
                      'Margin ${snapshot.netMarginPercent.toStringAsFixed(1)}%',
                  value: CurrencyFormatter.formatCompactIdr(snapshot.netProfit),
                  badgeText: 'Laba Bersih',
                  accentColor: palette.success,
                  icon: Icons.account_balance_wallet_rounded,
                  onTap: () => context.go(AppRoutes.pnlReport),
                ),
                _ExecutiveKpiCard(
                  title: 'Active Deliveries',
                  subtitle:
                      '${snapshot.pendingDeliveries} Pending • ${snapshot.inTransitDeliveries} Transit',
                  value: '${snapshot.activeDeliveries} Armada',
                  badgeText: '${snapshot.deliveredCount} Selesai',
                  accentColor: palette.info,
                  icon: Icons.local_shipping_rounded,
                  onTap: () => context.go(AppRoutes.deliveryDispatch),
                ),
                _ExecutiveKpiCard(
                  title: 'Low-Stock Alerts',
                  subtitle: 'Perlu restock segera',
                  value: '${snapshot.lowStockProducts.length} SKU',
                  badgeText: snapshot.lowStockProducts.isEmpty
                      ? 'Stok Aman'
                      : 'Kritis',
                  accentColor: snapshot.lowStockProducts.isEmpty
                      ? palette.success
                      : palette.danger,
                  icon: Icons.warning_amber_rounded,
                  onTap: () => context.go(AppRoutes.stockOpname),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Low-Stock Alerts Section (flat rows separated by dividers)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_rounded,
                              color: palette.danger,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Peringatan Stok Menipis',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.stockOpname),
                        child: const Text('Stock Opname'),
                      ),
                    ],
                  ),
                  if (snapshot.lowStockProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Semua material bangunan berada di atas batas minimum.',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    )
                  else ...[
                    for (
                      var i = 0;
                      i < snapshot.lowStockProducts.length;
                      i++
                    ) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.lowStockProducts[i].name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  'SKU: ${snapshot.lowStockProducts[i].sku} • Batas Min: ${snapshot.lowStockProducts[i].baseUnit.formatQuantity(snapshot.lowStockProducts[i].minStockThreshold)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.dangerSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Sisa ${snapshot.lowStockProducts[i].baseUnit.formatQuantity(snapshot.lowStockProducts[i].stockQuantity)}',
                              style: TextStyle(
                                color: palette.danger,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Revenue Trend Bar Chart + Payment Mix Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Omzet vs Pengeluaran',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perbandingan pendapatan harian dengan beban HPP & operasional.',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RevenueComparisonBars(points: snapshot.revenueTrend),
                  const Divider(height: 24),
                  Text(
                    'Komposisi Pembayaran',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...snapshot.paymentBreakdown.map(
                    (share) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                share.method.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                '${share.percentage.toInt()}% (${CurrencyFormatter.formatCompactIdr(share.amount)})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: share.percentage / 100,
                              minHeight: 6,
                              backgroundColor: palette.surfaceMuted,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Operational Shortcuts
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Akses Cepat Divisi Toko',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(
                          Icons.point_of_sale_rounded,
                          size: 16,
                          color: palette.primary,
                        ),
                        label: const Text('POS Kasir'),
                        onPressed: () => context.go(AppRoutes.posCheckout),
                      ),
                      ActionChip(
                        avatar: Icon(
                          Icons.local_shipping_rounded,
                          size: 16,
                          color: palette.primary,
                        ),
                        label: const Text('Driver POD'),
                        onPressed: () => context.go(AppRoutes.driverPod),
                      ),
                      ActionChip(
                        avatar: Icon(
                          Icons.add_card_rounded,
                          size: 16,
                          color: palette.primary,
                        ),
                        label: const Text('Catat Biaya'),
                        onPressed: () => context.go(AppRoutes.expenseForm),
                      ),
                      ActionChip(
                        avatar: Icon(
                          Icons.payments_rounded,
                          size: 16,
                          color: palette.primary,
                        ),
                        label: const Text('Payroll Staff'),
                        onPressed: () => context.go(AppRoutes.payroll),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutiveKpiCard extends StatelessWidget {
  const _ExecutiveKpiCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.badgeText,
    required this.accentColor,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final String badgeText;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accentColor, size: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueComparisonBars extends StatelessWidget {
  const _RevenueComparisonBars({required this.points});

  final List<RevenueTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final maxRevenue = points.fold<double>(
      1,
      (max, p) => p.revenue > max ? p.revenue : max,
    );

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final revHeight = (point.revenue / maxRevenue) * 90;
          final expHeight = (point.expense / maxRevenue) * 90;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 10,
                      height: revHeight.clamp(8, 90),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 10,
                      height: expHeight.clamp(6, 90),
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  point.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
