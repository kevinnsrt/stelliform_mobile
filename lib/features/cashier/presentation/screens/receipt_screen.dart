import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/currency_formatter.dart';
import 'package:stelliform_mobile/app/utils/date_formatter.dart';
import 'package:stelliform_mobile/core/network/feature_flags.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/features/cashier/controllers/cashier_controller.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';

/// Minimalist digital POS transaction receipt screen.
class ReceiptScreen extends StatelessWidget {
  /// Creates a [ReceiptScreen] for [receipt] or [invoiceNumber].
  const ReceiptScreen({super.key, this.receipt, this.invoiceNumber});

  /// Directly passed receipt object from checkout.
  final TransactionReceipt? receipt;

  /// Optional invoice number query parameter used for lookup.
  final String? invoiceNumber;

  @override
  Widget build(BuildContext context) {
    final cashier = context.watch<CashierController>();
    final palette = AppColors.of(context);
    final activeReceipt = receipt ?? cashier.resolveReceipt(invoiceNumber);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Transaksi POS'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Kembali ke Kasir',
            icon: const Icon(Icons.point_of_sale_rounded),
            onPressed: () => context.go(AppRoutes.posCheckout),
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.receipt),
      body: activeReceipt == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 52,
                      color: palette.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada struk transaksi yang dipilih.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Buat Transaksi POS',
                      isFullWidth: false,
                      onPressed: () => context.go(AppRoutes.posCheckout),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReceiptCard(receipt: activeReceipt),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child:
                                BackendFeatureFlags
                                    .bluetoothThermalPrintSupported
                                ? CustomButton(
                                    label: 'Cetak / Bagikan',
                                    variant: CustomButtonVariant.outline,
                                    icon: Icons.print_rounded,
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Struk ${activeReceipt.invoiceNumber} dikirim ke antrean printer thermal.',
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : const LockedFeatureButton(
                                    key: ValueKey('locked_thermal_print'),
                                    label: 'Cetak Thermal',
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              label: 'Transaksi Baru',
                              icon: Icons.add_shopping_cart_rounded,
                              onPressed: () =>
                                  context.go(AppRoutes.posCheckout),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});

  final TransactionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDelivery =
        receipt.fulfillmentType == FulfillmentType.deliveryService;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: palette.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TB. DOBRAK MANDIRI',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      receipt.invoiceNumber,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDelivery ? palette.infoSoft : palette.successSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  receipt.fulfillmentType.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDelivery ? palette.info : palette.success,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _InfoRow(
            label: 'Tanggal',
            value: DateFormatter.formatDateTime(receipt.createdAt),
          ),
          _InfoRow(label: 'Kasir', value: receipt.cashierName),
          _InfoRow(label: 'Pelanggan', value: receipt.customerName),
          _InfoRow(
            label: 'Pembayaran',
            value: receipt.bankName != null
                ? '${receipt.paymentMethod.label} (${receipt.bankName})'
                : receipt.paymentMethod.label,
          ),
          if (receipt.tempoDueDate != null)
            _InfoRow(
              label: 'Jatuh Tempo',
              value: DateFormatter.formatShortDate(receipt.tempoDueDate!),
            ),
          if (isDelivery) ...[
            if (receipt.deliveryOrderId != null)
              _InfoRow(
                label: 'No. Surat Jalan',
                value: receipt.deliveryOrderId!,
              ),
            if (receipt.deliveryAddress != null)
              _InfoRow(label: 'Alamat Kirim', value: receipt.deliveryAddress!),
          ],
          const Divider(height: 24),
          Text(
            'Rincian Material',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (receipt.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Ringkasan transaksi tersimpan pada arsip kasir.',
                style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
              ),
            )
          else
            ...receipt.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            '${item.unitOption.unit.formatQuantity(item.quantity)} x ${CurrencyFormatter.formatIdr(item.unitOption.price)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIdr(item.subtotal),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Subtotal Barang',
            value: CurrencyFormatter.formatIdr(receipt.subtotal),
          ),
          if (receipt.deliveryFee > 0)
            _SummaryRow(
              label: 'Biaya Pengiriman',
              value: CurrencyFormatter.formatIdr(receipt.deliveryFee),
            ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: 'Grand Total',
            value: CurrencyFormatter.formatIdr(receipt.grandTotal),
            isTotal: true,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: receipt.paymentMethod == PaymentMethod.tempo
                ? 'Status Piutang'
                : 'Dibayar',
            value: receipt.paymentMethod == PaymentMethod.tempo
                ? 'Belum Lunas (Tempo)'
                : CurrencyFormatter.formatIdr(receipt.amountPaid),
          ),
          if (receipt.changeAmount > 0)
            _SummaryRow(
              label: 'Kembalian',
              value: CurrencyFormatter.formatIdr(receipt.changeAmount),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? palette.textPrimary : palette.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13.5,
              fontWeight: FontWeight.w700,
              color: isTotal ? palette.primary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
