import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/date_formatter.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/custom_textfield.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/scm/controllers/scm_controller.dart';

/// Minimalist warehouse Stock Opname screen for Staff Gudang.
class StockOpnameScreen extends StatefulWidget {
  /// Creates a [StockOpnameScreen].
  const StockOpnameScreen({super.key});

  @override
  State<StockOpnameScreen> createState() => _StockOpnameScreenState();
}

class _StockOpnameScreenState extends State<StockOpnameScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        context.read<ScmController>().loadWarehouseData(
          includeDeliveries: false,
        );
      }
    });
  }

  Future<void> _openOpnameDialog(ProductItem product) async {
    final stockController = TextEditingController(
      text: product.stockQuantity % 1 == 0
          ? product.stockQuantity.toInt().toString()
          : product.stockQuantity.toStringAsFixed(1),
    );
    final reasonController = TextEditingController();
    final palette = AppColors.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Opname: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stok Sistem: ${product.baseUnit.formatQuantity(product.stockQuantity)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: stockController,
              label: 'Jumlah Stok Fisik (${product.baseUnit.label})',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: reasonController,
              label: 'Catatan Selisih / Kondisi',
              hintText: 'Mis. 2 sak rusak terkena hujan',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan Opname'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final parsedStock = double.tryParse(
      stockController.text.replaceAll(',', '.'),
    );
    if (parsedStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan angka stok fisik yang valid.')),
      );
      return;
    }

    final checkedBy =
        context.read<AuthController>().currentUser?.name ?? 'Staff Gudang';
    final scm = context.read<ScmController>();
    final ok = await scm.submitStockOpname(
      product: product,
      physicalStock: parsedStock,
      reason: reasonController.text,
      checkedBy: checkedBy,
    );
    if (!mounted) return;
    if (!ok) {
      ApiErrorFeedback.showSnackBar(
        context,
        scm.lastException ?? scm.errorMessage,
        fallbackMessage: 'Gagal menyimpan hasil Stock Opname.',
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stok ${product.name} diperbarui menjadi ${product.baseUnit.formatQuantity(parsedStock)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scm = context.watch<ScmController>();
    final palette = AppColors.of(context);
    final products = scm.inventoryProducts
        .where((item) {
          if (_search.trim().isEmpty) return true;
          final q = _search.toLowerCase();
          return item.name.toLowerCase().contains(q) ||
              item.sku.toLowerCase().contains(q);
        })
        .toList(growable: false);
    final lowStockCount = scm.inventoryProducts
        .where((item) => item.isLowStock)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Opname Gudang'),
        actions: [
          const ThemeToggleButton(),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.deliveryDispatch),
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Dispatch'),
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.stockOpname),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (scm.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: palette.primary),
            ),
          if (scm.errorMessage != null) ...[
            ApiErrorBanner(
              message: scm.errorMessage!,
              onRetry: () => scm.loadWarehouseData(includeDeliveries: false),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _MetricBanner(
                  label: 'Total SKU Material',
                  value: '${scm.inventoryProducts.length}',
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBanner(
                  label: 'Stok Menipis',
                  value: '$lowStockCount SKU',
                  color: lowStockCount > 0 ? palette.danger : palette.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextField(
            hintText: 'Cari material atau kode SKU...',
            prefixIcon: Icons.search_rounded,
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 12),
          ...products.map(
            (product) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: product.isLowStock
                      ? palette.dangerSoft
                      : palette.primarySoft,
                  child: Icon(
                    product.isLowStock
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_rounded,
                    color: product.isLowStock
                        ? palette.danger
                        : palette.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: palette.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'SKU: ${product.sku} • Sistem: ${product.baseUnit.formatQuantity(product.stockQuantity)} (Min ${product.baseUnit.formatQuantity(product.minStockThreshold)})',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                trailing: CustomButton(
                  label: 'Opname',
                  isFullWidth: false,
                  variant: CustomButtonVariant.secondary,
                  onPressed: () => _openOpnameDialog(product),
                ),
              ),
            ),
          ),
          if (scm.opnameHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Riwayat Audit Opname Terbaru',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  for (
                    var i = 0;
                    i < scm.opnameHistory.take(5).length;
                    i++
                  ) ...[
                    if (i > 0) const Divider(),
                    ListTile(
                      dense: true,
                      title: Text(
                        '${scm.opnameHistory[i].productName} (${scm.opnameHistory[i].discrepancy >= 0 ? '+' : ''}${scm.opnameHistory[i].discrepancy.toStringAsFixed(1)} ${scm.opnameHistory[i].unitLabel})',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${scm.opnameHistory[i].reason} • Oleh ${scm.opnameHistory[i].checkedBy} (${DateFormatter.formatDateTime(scm.opnameHistory[i].checkedAt)})',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBanner extends StatelessWidget {
  const _MetricBanner({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
