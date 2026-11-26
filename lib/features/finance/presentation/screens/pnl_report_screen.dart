import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/currency_formatter.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/finance/controllers/finance_controller.dart';

/// Minimalist Profit & Loss (Laporan Laba Rugi) statement screen.
class PnlReportScreen extends StatefulWidget {
  /// Creates a [PnlReportScreen].
  const PnlReportScreen({super.key});

  @override
  State<PnlReportScreen> createState() => _PnlReportScreenState();
}

class _PnlReportScreenState extends State<PnlReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        final finance = context.read<FinanceController>();
        await finance.loadFinanceData();
        if (!mounted || finance.lastException == null) return;
        ApiErrorFeedback.showSnackBar(
          context,
          finance.lastException,
          onRetry: finance.loadFinanceData,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final palette = AppColors.of(context);
    final pnl = finance.pnlSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Laba Rugi (P&L)'),
        actions: [
          const ThemeToggleButton(),
          if (context.read<AuthController>().isRemoteSession)
            IconButton(
              tooltip: 'Muat Ulang Laporan',
              icon: finance.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: finance.isLoading ? null : finance.loadFinanceData,
            ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.pnlReport),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (finance.errorMessage != null) ...[
            ApiErrorBanner(
              message: finance.errorMessage!,
              onRetry: finance.loadFinanceData,
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            children: finance.availablePeriods.map((period) {
              final isSelected = finance.selectedPeriod == period;
              return ChoiceChip(
                label: Text(period),
                selected: isSelected,
                onSelected: (_) => finance.setSelectedPeriod(period),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laba Bersih (${pnl.periodLabel})',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatIdr(pnl.netProfit),
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Net Margin: ${pnl.netMarginPercent.toStringAsFixed(1)}% • Piutang Tempo: ${CurrencyFormatter.formatIdr(pnl.tempoReceivables)}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  'Ikhtisar Laba Rugi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _PnlRow(
                  label: 'Pendapatan Kotor (Gross Revenue)',
                  amount: pnl.grossRevenue,
                  color: palette.textPrimary,
                  bold: true,
                ),
                _PnlRow(
                  label: 'Harga Pokok Penjualan (HPP)',
                  amount: -pnl.cogs,
                  color: palette.danger,
                ),
                const Divider(height: 18),
                _PnlRow(
                  label: 'Laba Kotor (Gross Profit)',
                  amount: pnl.grossProfit,
                  color: palette.primary,
                  bold: true,
                ),
                _PnlRow(
                  label: 'Beban Operasional & Armada',
                  amount: -pnl.operatingExpenses,
                  color: palette.danger,
                ),
                _PnlRow(
                  label: 'Beban Gaji Karyawan (Payroll)',
                  amount: -pnl.payrollTotal,
                  color: palette.danger,
                ),
                const Divider(height: 18),
                _PnlRow(
                  label: 'Laba Bersih (Net Profit)',
                  amount: pnl.netProfit,
                  color: palette.success,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Input Biaya',
                  icon: Icons.add_card_rounded,
                  variant: CustomButtonVariant.secondary,
                  onPressed: () => context.go(AppRoutes.expenseForm),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  label: 'Kelola Payroll',
                  icon: Icons.payments_outlined,
                  variant: CustomButtonVariant.outline,
                  onPressed: () => context.go(AppRoutes.payroll),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PnlRow extends StatelessWidget {
  const _PnlRow({
    required this.label,
    required this.amount,
    required this.color,
    this.bold = false,
  });

  final String label;
  final double amount;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 13.5 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ),
          Text(
            CurrencyFormatter.formatIdr(amount),
            style: TextStyle(
              fontSize: bold ? 14.5 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
