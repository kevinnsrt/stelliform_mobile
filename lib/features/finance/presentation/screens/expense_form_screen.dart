import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/currency_formatter.dart';
import 'package:stelliform_mobile/app/utils/date_formatter.dart';
import 'package:stelliform_mobile/core/network/feature_flags.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/custom_textfield.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/finance/controllers/finance_controller.dart';
import 'package:stelliform_mobile/features/finance/data/finance_models.dart';

/// Minimalist operational expense input form and recent ledger list.
class ExpenseFormScreen extends StatefulWidget {
  /// Creates an [ExpenseFormScreen].
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.operational;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        context.read<FinanceController>().loadFinanceData();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitExpense() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cleanAmount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    final userName =
        context.read<AuthController>().currentUser?.name ?? 'Finance';
    final finance = context.read<FinanceController>();
    final ok = await finance.submitExpense(
      title: _titleController.text,
      category: _selectedCategory,
      amount: cleanAmount,
      recordedBy: userName,
      notes: _notesController.text,
    );
    if (!mounted) return;
    if (!ok) {
      ApiErrorFeedback.showSnackBar(
        context,
        finance.lastException ?? finance.errorMessage,
        fallbackMessage: 'Gagal menyimpan pengeluaran operasional.',
      );
      return;
    }
    _titleController.clear();
    _amountController.clear();
    _notesController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengeluaran berhasil dicatat ke buku kas.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Pengeluaran Operasional'),
        actions: [
          const ThemeToggleButton(),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.pnlReport),
            icon: const Icon(Icons.assessment_outlined, size: 18),
            label: const Text('Laba Rugi'),
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.expenseForm),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Input Biaya Baru',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _titleController,
                    label: 'Keterangan Pengeluaran',
                    hintText: 'Mis. Solar truk engkel / Servis forklift',
                    prefixIcon: Icons.receipt_outlined,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kategori Akun',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(),
                    items: ExpenseCategory.values
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _amountController,
                    label: 'Nominal (Rp)',
                    hintText: 'Contoh: 500000',
                    prefixIcon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final parsed = double.tryParse(
                        (v ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                      );
                      if (parsed == null || parsed <= 0) {
                        return 'Nominal harus lebih dari 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _notesController,
                    label: 'Catatan Tambahan (Opsional)',
                    hintText: 'No. nota atau keterangan lampiran',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  if (BackendFeatureFlags.operationalExpensePostSupported)
                    CustomButton(
                      label: 'Simpan Pengeluaran',
                      icon: Icons.save_rounded,
                      isLoading: finance.isSubmitting,
                      onPressed: _submitExpense,
                    )
                  else
                    const LockedFeatureButton(
                      label: 'Simpan Pengeluaran',
                      badgeText: 'Coming Soon',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Pengeluaran Tercatat',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                CurrencyFormatter.formatIdr(finance.totalRecordedExpenses),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...finance.expenses.map(
            (expense) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: palette.dangerSoft,
                  child: Icon(
                    expense.category.icon,
                    color: palette.danger,
                    size: 19,
                  ),
                ),
                title: Text(
                  expense.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: palette.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${expense.category.label} • ${DateFormatter.formatDateTime(expense.date)}',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                trailing: Text(
                  CurrencyFormatter.formatIdr(expense.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.danger,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
