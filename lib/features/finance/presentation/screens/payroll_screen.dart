import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/currency_formatter.dart';
import 'package:stelliform_mobile/core/network/feature_flags.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/features/finance/controllers/finance_controller.dart';

/// Minimalist employee payroll disbursement tracking screen.
class PayrollScreen extends StatelessWidget {
  /// Creates a [PayrollScreen].
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final palette = AppColors.of(context);
    final entries = finance.payrollEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penggajian Karyawan (Payroll)'),
        actions: [
          const ThemeToggleButton(),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.pnlReport),
            icon: const Icon(Icons.assessment_outlined, size: 18),
            label: const Text('Laba Rugi'),
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.payroll),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!BackendFeatureFlags.payrollModuleSupported) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modul Payroll • Coming Soon (${BackendFeatureFlags.unsupportedMessage})',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Payroll Periode November 2026',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatIdr(finance.totalPayroll),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${finance.paidPayrollCount}/${entries.length} Lunas',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.employeeName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              '${entry.roleLabel} • ${entry.periodLabel}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
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
                          color: entry.isPaid
                              ? palette.successSoft
                              : palette.warningSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.isPaid ? 'Dibayar' : 'Menunggu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: entry.isPaid
                                ? palette.success
                                : palette.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PayrollRow(
                    label: 'Gaji Pokok',
                    value: CurrencyFormatter.formatIdr(entry.baseSalary),
                  ),
                  _PayrollRow(
                    label: 'Lembur & Tunjangan Muat',
                    value: CurrencyFormatter.formatIdr(entry.overtimeAllowance),
                  ),
                  if (entry.deductions > 0)
                    _PayrollRow(
                      label: 'Potongan Kasbon',
                      value:
                          '-${CurrencyFormatter.formatIdr(entry.deductions)}',
                    ),
                  const Divider(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Diterima',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              CurrencyFormatter.formatIdr(entry.netSalary),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (BackendFeatureFlags.payrollModuleSupported)
                        CustomButton(
                          label: entry.isPaid
                              ? 'Batalkan Status'
                              : 'Bayar Sekarang',
                          variant: entry.isPaid
                              ? CustomButtonVariant.outline
                              : CustomButtonVariant.primary,
                          onPressed: () => finance.togglePayrollPaid(entry.id),
                        )
                      else
                        LockedFeatureButton(
                          label: entry.isPaid
                              ? 'Batalkan Status'
                              : 'Bayar Sekarang',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollRow extends StatelessWidget {
  const _PayrollRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
