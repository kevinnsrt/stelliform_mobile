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
import 'package:stelliform_mobile/features/cashier/controllers/cashier_controller.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/scm/controllers/scm_controller.dart';

/// Minimalist POS checkout screen supporting multi-unit building materials,
/// fulfillment toggle (`Direct Pickup` vs `Delivery Service`), and payment selection.
class PosCheckoutScreen extends StatefulWidget {
  /// Creates a [PosCheckoutScreen].
  const PosCheckoutScreen({super.key});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _mobileTabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController(
    text: 'Pelanggan Umum',
  );
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController(
    text: '75000',
  );
  final TextEditingController _cashTenderedController = TextEditingController();

  final Map<String, ProductUnit> _selectedUnitByProduct = {};

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        context.read<CashierController>().loadCatalog();
      }
    });
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deliveryAddressController.dispose();
    _deliveryFeeController.dispose();
    _cashTenderedController.dispose();
    super.dispose();
  }

  ProductUnit _activeUnitFor(ProductItem product) {
    return _selectedUnitByProduct[product.id] ?? product.defaultOption.unit;
  }

  void _syncCashFieldWithGrandTotal(CashierController cashier) {
    if (cashier.paymentMethod == PaymentMethod.cash &&
        cashier.cashTendered > 0) {
      final rounded = cashier.cashTendered.round().toString();
      if (_cashTenderedController.text != rounded) {
        _cashTenderedController.text = rounded;
      }
    }
  }

  Future<void> _handleCheckout() async {
    final cashier = context.read<CashierController>();
    final auth = context.read<AuthController>();
    final scm = context.read<ScmController>();

    cashier.updateCustomerDetails(
      name: _customerNameController.text,
      phone: _customerPhoneController.text,
      address: _deliveryAddressController.text,
    );

    if (cashier.requiresDelivery) {
      final parsedFee =
          double.tryParse(
            _deliveryFeeController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      cashier.setDeliveryFee(parsedFee);
    }

    if (cashier.paymentMethod == PaymentMethod.cash) {
      final parsedCash =
          double.tryParse(
            _cashTenderedController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          cashier.cashTendered;
      cashier.setCashTendered(parsedCash);
    }

    final receipt = await cashier.submitCheckout(
      cashierName: auth.currentUser?.name ?? 'Kasir',
      onCreateDeliveryOrder: scm.createDeliveryFromCheckout,
    );

    if (!mounted) return;
    if (receipt == null) {
      final ex = cashier.lastException;
      if (ex != null &&
          (ex.isTimeout || ex.isServerError || ex.isUnauthorized)) {
        await ApiErrorFeedback.showErrorDialog(
          context,
          error: ex,
          onRetry: ex.isUnauthorized ? null : _handleCheckout,
        );
      } else {
        ApiErrorFeedback.showSnackBar(
          context,
          ex ?? cashier.errorMessage,
          fallbackMessage: 'Periksa kembali data checkout Anda.',
        );
      }
      return;
    }

    _customerNameController.text = 'Pelanggan Umum';
    _customerPhoneController.clear();
    _deliveryAddressController.clear();
    _cashTenderedController.clear();
    context.go(AppRoutes.receipt, extra: receipt);
  }

  @override
  Widget build(BuildContext context) {
    final cashier = context.watch<CashierController>();
    final palette = AppColors.of(context);
    final isWideLayout = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir POS — TB. Dobrak Mandiri'),
        actions: [
          const ThemeToggleButton(),
          if (context.read<AuthController>().isRemoteSession)
            IconButton(
              tooltip: 'Muat Ulang Katalog',
              icon: cashier.isCatalogLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: cashier.isCatalogLoading ? null : cashier.loadCatalog,
            ),
          IconButton(
            tooltip: 'Lihat Struk Terakhir',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => context.go(AppRoutes.receipt),
          ),
        ],
        bottom: isWideLayout
            ? null
            : TabBar(
                controller: _mobileTabController,
                indicatorColor: palette.primary,
                labelColor: palette.primary,
                unselectedLabelColor: palette.textSecondary,
                dividerColor: palette.border,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                    text: 'Katalog Material',
                  ),
                  Tab(
                    icon: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 18,
                    ),
                    text: 'Checkout (${cashier.totalLineCount})',
                  ),
                ],
              ),
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.posCheckout),
      body: isWideLayout
          ? Row(
              children: [
                Expanded(flex: 6, child: _buildCatalogPane(cashier, palette)),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: _buildCheckoutPane(cashier, palette)),
              ],
            )
          : TabBarView(
              controller: _mobileTabController,
              children: [
                _buildCatalogPane(cashier, palette),
                _buildCheckoutPane(cashier, palette),
              ],
            ),
      bottomNavigationBar: isWideLayout
          ? null
          : AnimatedBuilder(
              animation: _mobileTabController,
              builder: (context, _) {
                if (_mobileTabController.index == 1) {
                  return const SizedBox.shrink();
                }
                return _MobileCheckoutSummaryBar(
                  lineCount: cashier.totalLineCount,
                  grandTotal: cashier.grandTotal,
                  onProceed: () => _mobileTabController.animateTo(1),
                );
              },
            ),
    );
  }

  Widget _buildCatalogPane(CashierController cashier, AppPalette palette) {
    final products = cashier.filteredProducts;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _searchController,
                hintText: 'Cari semen, pasir, keramik, pipa, SKU...',
                prefixIcon: Icons.search_rounded,
                suffixIcon: cashier.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          cashier.setSearchQuery('');
                        },
                      )
                    : null,
                onChanged: cashier.setSearchQuery,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: cashier.categories.map((category) {
                    final selected = cashier.selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _MinimalPillChip(
                        label: category,
                        selected: selected,
                        onTap: () => cashier.setSelectedCategory(category),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Satuan:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...ProductUnit.values.map((unit) {
                      final isSelected = cashier.unitFilter == unit;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _MinimalPillChip(
                          label: unit.label,
                          selected: isSelected,
                          compact: true,
                          onTap: () => cashier.toggleUnitFilter(unit),
                        ),
                      );
                    }),
                    if (!BackendFeatureFlags.optionalStockSyncSupported)
                      InkWell(
                        key: const ValueKey('locked_stock_sync_chip'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () =>
                            BackendFeatureFlags.showUnsupportedFeedback(
                              context,
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceMuted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: palette.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Sync Stok • Coming Soon',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (cashier.isCatalogLoading)
          LinearProgressIndicator(color: palette.primary),
        if (cashier.errorMessage != null && !cashier.isSubmitting)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: ApiErrorBanner(
              message: cashier.errorMessage!,
              onRetry: cashier.loadCatalog,
            ),
          ),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada material yang sesuai filter pencarian.',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final selectedUnit = _activeUnitFor(product);
                    final activeOption =
                        product.optionFor(selectedUnit) ??
                        product.defaultOption;

                    return _ProductCatalogRow(
                      product: product,
                      activeOption: activeOption,
                      onSelectUnit: (unit) {
                        setState(() {
                          _selectedUnitByProduct[product.id] = unit;
                        });
                      },
                      onAddToCart: () {
                        cashier.addToCart(product, activeOption.unit);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            content: Text(
                              'Ditambahkan: ${product.name} (1 ${activeOption.unit.label})',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCheckoutPane(CashierController cashier, AppPalette palette) {
    final isDelivery = cashier.requiresDelivery;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cashier.errorMessage != null && !cashier.isSubmitting) ...[
          ApiErrorBanner(
            message: cashier.errorMessage!,
            onRetry: cashier.cartItems.isNotEmpty ? _handleCheckout : null,
          ),
          const SizedBox(height: 12),
        ],
        // 1. Cart Line Items Section (flat, unnested)
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Keranjang Belanja (${cashier.totalLineCount})',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (cashier.cartItems.isNotEmpty)
                    TextButton(
                      onPressed: cashier.clearCart,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.danger,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Kosongkan'),
                    ),
                ],
              ),
              if (cashier.cartItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'Keranjang masih kosong. Pilih material & satuan dari katalog.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 8),
                for (var i = 0; i < cashier.cartItems.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _CartLineRow(
                    item: cashier.cartItems[i],
                    onUnitChanged: (newUnit) => cashier.changeCartItemUnit(
                      cashier.cartItems[i].key,
                      newUnit,
                    ),
                    onIncrement: () =>
                        cashier.incrementQuantity(cashier.cartItems[i].key),
                    onDecrement: () =>
                        cashier.decrementQuantity(cashier.cartItems[i].key),
                    onRemove: () =>
                        cashier.removeFromCart(cashier.cartItems[i].key),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Fulfillment Section
        Container(
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
                  Icon(
                    isDelivery
                        ? Icons.local_shipping_outlined
                        : Icons.store_mall_directory_outlined,
                    size: 19,
                    color: isDelivery ? palette.info : palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDelivery
                              ? 'Requires Delivery Service'
                              : 'Direct Pickup',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          cashier.fulfillmentType.subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    key: const ValueKey('fulfillment_delivery_switch'),
                    value: isDelivery,
                    onChanged: (needsDelivery) {
                      cashier.setFulfillmentType(
                        needsDelivery
                            ? FulfillmentType.deliveryService
                            : FulfillmentType.directPickup,
                      );
                      if (needsDelivery &&
                          _customerNameController.text == 'Pelanggan Umum') {
                        _customerNameController.clear();
                      } else if (!needsDelivery &&
                          _customerNameController.text.trim().isEmpty) {
                        _customerNameController.text = 'Pelanggan Umum';
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FulfillmentOptionButton(
                      label: 'Direct Pickup',
                      selected: !isDelivery,
                      onTap: () {
                        cashier.setFulfillmentType(
                          FulfillmentType.directPickup,
                        );
                        if (_customerNameController.text.trim().isEmpty) {
                          _customerNameController.text = 'Pelanggan Umum';
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FulfillmentOptionButton(
                      label: 'Requires Delivery Service',
                      selected: isDelivery,
                      onTap: () {
                        cashier.setFulfillmentType(
                          FulfillmentType.deliveryService,
                        );
                        if (_customerNameController.text == 'Pelanggan Umum') {
                          _customerNameController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              CustomTextField(
                controller: _customerNameController,
                label:
                    isDelivery || cashier.paymentMethod == PaymentMethod.tempo
                    ? 'Nama Pelanggan / Kontraktor *'
                    : 'Nama Pelanggan',
                hintText: 'Contoh: CV. Karya Mandiri / Pak Budi',
                prefixIcon: Icons.person_outline_rounded,
              ),
              if (isDelivery) ...[
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _customerPhoneController,
                  label: 'No. Telepon Penerima',
                  hintText: '0812-xxxx-xxxx',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _deliveryAddressController,
                  label: 'Alamat Pengiriman *',
                  hintText: 'Jalan, nomor proyek, kecamatan...',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _deliveryFeeController,
                  label: 'Ongkos Kirim Armada (Rp)',
                  prefixIcon: Icons.local_shipping_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed =
                        double.tryParse(
                          value.replaceAll(RegExp(r'[^0-9]'), ''),
                        ) ??
                        0;
                    cashier.setDeliveryFee(parsed);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Payment Method Section
        Container(
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
                'Metode Pembayaran',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.35,
                children: PaymentMethod.values.map((method) {
                  final isSelected = cashier.paymentMethod == method;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      cashier.setPaymentMethod(method);
                      _syncCashFieldWithGrandTotal(cashier);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.primarySoft
                            : palette.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            method.icon,
                            size: 18,
                            color: isSelected
                                ? palette.primary
                                : palette.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  method.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? palette.primary
                                        : palette.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  method.subtitle,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: palette.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 22),
              _buildPaymentDetailPanel(cashier, palette),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Grand Total & Submit CTA Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              _CheckoutTotalRow(
                label: 'Subtotal Material',
                value: CurrencyFormatter.formatIdr(cashier.cartSubtotal),
              ),
              if (cashier.requiresDelivery)
                _CheckoutTotalRow(
                  label: 'Biaya Pengiriman',
                  value: CurrencyFormatter.formatIdr(cashier.deliveryFee),
                ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Tagihan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIdr(cashier.grandTotal),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!BackendFeatureFlags.bluetoothThermalPrintSupported) ...[
                const LockedFeatureButton(
                  key: ValueKey('locked_pos_auto_print'),
                  label: 'Cetak Struk Bluetooth Otomatis',
                ),
                const SizedBox(height: 10),
              ],
              CustomButton(
                label: 'Proses Pembayaran & Cetak Struk',
                icon: Icons.check_circle_outline_rounded,
                isLoading: cashier.isSubmitting,
                onPressed: cashier.cartItems.isEmpty ? null : _handleCheckout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailPanel(
    CashierController cashier,
    AppPalette palette,
  ) {
    switch (cashier.paymentMethod) {
      case PaymentMethod.cash:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _cashTenderedController,
              label: 'Uang Tunai Diterima (Rp)',
              hintText: 'Masukkan nominal uang tunai',
              prefixIcon: Icons.money_rounded,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final parsed =
                    double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                cashier.setCashTendered(parsed);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Uang Pas'),
                  onPressed: () {
                    final exact = cashier.grandTotal.round();
                    _cashTenderedController.text = exact.toString();
                    cashier.setCashTendered(exact.toDouble());
                  },
                ),
                ActionChip(
                  label: const Text('+50 Rb'),
                  onPressed: () {
                    final next = cashier.grandTotal.round() + 50000;
                    _cashTenderedController.text = next.toString();
                    cashier.setCashTendered(next.toDouble());
                  },
                ),
                ActionChip(
                  label: const Text('+100 Rb'),
                  onPressed: () {
                    final next = cashier.grandTotal.round() + 100000;
                    _cashTenderedController.text = next.toString();
                    cashier.setCashTendered(next.toDouble());
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kembalian:',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                Text(
                  CurrencyFormatter.formatIdr(cashier.cashChange),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.success,
                  ),
                ),
              ],
            ),
          ],
        );

      case PaymentMethod.transfer:
        const banks = ['BCA', 'Mandiri', 'BRI'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih Rekening Bank Tujuan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: banks.map((bank) {
                final selected = cashier.selectedBank == bank;
                return _MinimalPillChip(
                  label: bank,
                  selected: selected,
                  onTap: () => cashier.setSelectedBank(bank),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Rekening TB. Dobrak Mandiri (${cashier.selectedBank}) siap diverifikasi mutasi.',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        );

      case PaymentMethod.qris:
        return Row(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 28,
              color: palette.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QRIS Dinamis Siap Dipindai',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    'Nominal otomatis: ${CurrencyFormatter.formatIdr(cashier.grandTotal)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case PaymentMethod.tempo:
        const terms = [14, 30, 45];
        final dueDate = DateTime.now().add(Duration(days: cashier.tempoDays));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tenor Jatuh Tempo (Kredit Proyek)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: terms.map((days) {
                final selected = cashier.tempoDays == days;
                return _MinimalPillChip(
                  label: '$days Hari',
                  selected: selected,
                  onTap: () => cashier.setTempoDays(days),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Jatuh tempo tagihan: ${DateFormatter.formatShortDate(dueDate)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.warning,
              ),
            ),
          ],
        );
    }
  }
}

class _MinimalPillChip extends StatelessWidget {
  const _MinimalPillChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.primarySoft : palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.primary : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ProductCatalogRow extends StatelessWidget {
  const _ProductCatalogRow({
    required this.product,
    required this.activeOption,
    required this.onSelectUnit,
    required this.onAddToCart,
  });

  final ProductItem product;
  final ProductUnitOption activeOption;
  final ValueChanged<ProductUnit> onSelectUnit;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.sku} • ${product.category}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: product.isLowStock
                      ? palette.dangerSoft
                      : palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: product.isLowStock
                        ? palette.danger.withValues(alpha: 0.35)
                        : palette.border,
                  ),
                ),
                child: Text(
                  'Stok: ${product.baseUnit.formatQuantity(product.stockQuantity)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: product.isLowStock
                        ? palette.danger
                        : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: product.unitOptions.map((option) {
              final isSelected = option.unit == activeOption.unit;
              return _MinimalPillChip(
                label:
                    '${option.unit.label} • ${CurrencyFormatter.formatIdr(option.price)}',
                selected: isSelected,
                compact: true,
                onTap: () => onSelectUnit(option.unit),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${CurrencyFormatter.formatIdr(activeOption.price)} / ${activeOption.unit.label}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAddToCart,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text('Tambah'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({
    required this.item,
    required this.onUnitChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final ValueChanged<ProductUnit> onUnitChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final qtyDisplay = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.product.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: palette.textPrimary,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: palette.danger,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (item.product.unitOptions.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                child: DropdownButton<ProductUnit>(
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  value: item.unitOption.unit,
                  items: item.product.unitOptions
                      .map(
                        (opt) => DropdownMenuItem(
                          value: opt.unit,
                          child: Text(
                            opt.unit.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (next) {
                    if (next != null) onUnitChanged(next);
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  item.unitOption.unit.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton.outlined(
              visualDensity: VisualDensity.compact,
              onPressed: onDecrement,
              style: IconButton.styleFrom(
                side: BorderSide(color: palette.border),
              ),
              icon: const Icon(Icons.remove_rounded, size: 15),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                qtyDisplay,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: palette.textPrimary,
                ),
              ),
            ),
            IconButton.outlined(
              visualDensity: VisualDensity.compact,
              onPressed: onIncrement,
              style: IconButton.styleFrom(
                side: BorderSide(color: palette.border),
              ),
              icon: const Icon(Icons.add_rounded, size: 15),
            ),
            const Spacer(),
            Text(
              CurrencyFormatter.formatIdr(item.subtotal),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: palette.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FulfillmentOptionButton extends StatelessWidget {
  const _FulfillmentOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primarySoft : palette.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.primary : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CheckoutTotalRow extends StatelessWidget {
  const _CheckoutTotalRow({required this.label, required this.value});

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
          Text(
            label,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCheckoutSummaryBar extends StatelessWidget {
  const _MobileCheckoutSummaryBar({
    required this.lineCount,
    required this.grandTotal,
    required this.onProceed,
  });

  final int lineCount;
  final double grandTotal;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$lineCount item di keranjang',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIdr(grandTotal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
            ),
            CustomButton(
              label: 'Checkout',
              icon: Icons.arrow_forward_rounded,
              isFullWidth: false,
              onPressed: onProceed,
            ),
          ],
        ),
      ),
    );
  }
}
