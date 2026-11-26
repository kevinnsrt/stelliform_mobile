import 'package:flutter/material.dart';

/// Supported sales and inventory units in Dobrak Mandiri building store.
enum ProductUnit {
  sak,
  meter,
  kubik,
  biji,
  dus;

  /// Human-readable Indonesian unit label.
  String get label => switch (this) {
    ProductUnit.sak => 'Sak',
    ProductUnit.meter => 'Meter',
    ProductUnit.kubik => 'Kubik',
    ProductUnit.biji => 'Biji',
    ProductUnit.dus => 'Dus',
  };

  /// Abbreviated unit symbol used on compact badges and receipts.
  String get symbol => switch (this) {
    ProductUnit.sak => 'sak',
    ProductUnit.meter => 'm',
    ProductUnit.kubik => 'm³',
    ProductUnit.biji => 'pcs',
    ProductUnit.dus => 'dus',
  };

  /// Whether fractional quantities (e.g. `1.5 m³` or `2.5 m`) are allowed.
  bool get allowsDecimal =>
      this == ProductUnit.meter || this == ProductUnit.kubik;

  /// Step increment used by POS quantity steppers.
  double get quantityStep => allowsDecimal ? 0.5 : 1.0;

  /// Formats [qty] cleanly without trailing `.0` for whole numbers.
  String formatQuantity(double qty, {String? customUnitLabel}) {
    final unitText =
        (customUnitLabel != null && customUnitLabel.trim().isNotEmpty)
        ? customUnitLabel.trim()
        : label;
    if (qty % 1 == 0) {
      return '${qty.toInt()} $unitText';
    }
    return '${qty.toStringAsFixed(1)} $unitText';
  }

  /// Parses free-text backend `satuan` values into a matching [ProductUnit].
  static ProductUnit fromString(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return switch (normalized) {
      'sak' || 'zak' => ProductUnit.sak,
      'meter' || 'm' || 'roll' => ProductUnit.meter,
      'kubik' || 'm3' || 'm³' => ProductUnit.kubik,
      'dus' || 'box' || 'kardus' || 'pack' => ProductUnit.dus,
      _ => ProductUnit.biji,
    };
  }
}

/// Supported POS payment methods mapped to Laravel `JenisPembayaran`.
enum PaymentMethod {
  cash,
  transfer,
  qris,
  tempo;

  /// Display label shown on payment selector tiles.
  String get label => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.transfer => 'Transfer',
    PaymentMethod.qris => 'QRIS',
    PaymentMethod.tempo => 'Tempo / Credit',
  };

  /// Indonesian clarification subtitle.
  String get subtitle => switch (this) {
    PaymentMethod.cash => 'Tunai di kasir',
    PaymentMethod.transfer => 'Transfer bank toko',
    PaymentMethod.qris => 'Scan QRIS dinamis',
    PaymentMethod.tempo => 'Piutang (BELUM_LUNAS)',
  };

  /// Backend `jenis_pembayaran` enum value.
  ///
  /// Laravel supports `TUNAI`, `QRIS`, and `TRANSFER`. When `TUNAI` is posted
  /// without `jumlah_bayar`, `PenjualanService` records the order as `BELUM_LUNAS`.
  String get backendCode => switch (this) {
    PaymentMethod.cash => 'TUNAI',
    PaymentMethod.transfer => 'TRANSFER',
    PaymentMethod.qris => 'QRIS',
    PaymentMethod.tempo => 'TUNAI',
  };

  /// Icon representing this payment method.
  IconData get icon => switch (this) {
    PaymentMethod.cash => Icons.payments_rounded,
    PaymentMethod.transfer => Icons.account_balance_rounded,
    PaymentMethod.qris => Icons.qr_code_2_rounded,
    PaymentMethod.tempo => Icons.event_repeat_rounded,
  };

  /// Parses backend `jenis_pembayaran` and `status_pembayaran` into [PaymentMethod].
  static PaymentMethod fromBackend(String? jenis, {String? statusPembayaran}) {
    final normalized = (jenis ?? '').trim().toUpperCase();
    if (normalized == 'TUNAI' &&
        (statusPembayaran ?? '').toUpperCase() == 'BELUM_LUNAS') {
      return PaymentMethod.tempo;
    }
    return switch (normalized) {
      'TRANSFER' => PaymentMethod.transfer,
      'QRIS' => PaymentMethod.qris,
      _ => PaymentMethod.cash,
    };
  }
}

/// Customer fulfillment mode selected during POS checkout.
enum FulfillmentType {
  directPickup,
  deliveryService;

  /// English/ERP display label.
  String get label => switch (this) {
    FulfillmentType.directPickup => 'Direct Pickup',
    FulfillmentType.deliveryService => 'Delivery Service',
  };

  /// Indonesian operational description.
  String get subtitle => switch (this) {
    FulfillmentType.directPickup => 'Pelanggan bawa barang langsung',
    FulfillmentType.deliveryService => 'Kirim via armada kurir toko',
  };

  /// Backend `status_barang` value sent on order creation (`POST /kasir/pesanan`).
  String get backendItemStatus => switch (this) {
    FulfillmentType.directPickup => 'DIAMBIL',
    FulfillmentType.deliveryService => 'MENUNGGU_DIANTAR',
  };
}

/// Unit-specific price and base-stock conversion rate for a building material.
class ProductUnitOption {
  /// Creates a [ProductUnitOption].
  const ProductUnitOption({
    required this.unit,
    required this.price,
    this.stockConversion = 1.0,
    this.customLabel,
  });

  /// Unit of measurement offered for sale.
  final ProductUnit unit;

  /// Selling price in IDR for 1 [unit].
  final double price;

  /// Amount deducted from [ProductItem.stockQuantity] per 1 [unit] sold.
  final double stockConversion;

  /// Optional raw backend unit name (e.g. `batang`, `kaleng`).
  final String? customLabel;

  /// Formats [qty] preferring [customLabel] when supplied by backend.
  String formatQuantity(double qty) =>
      unit.formatQuantity(qty, customUnitLabel: customLabel);
}

/// Customer directory entry matching Laravel `PelangganResource`.
class CustomerOption {
  /// Creates a [CustomerOption].
  const CustomerOption({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.isActive = true,
  });

  /// Primary key `id_pelanggan`.
  final int id;

  /// Customer or contractor name (`nama_pelanggan`).
  final String name;

  /// Optional telephone number (`telepon`).
  final String? phone;

  /// Delivery address (`alamat`).
  final String? address;

  /// Optional internal notes (`catatan`).
  final String? notes;

  /// Active flag (`is_active`).
  final bool isActive;

  /// Parses a [CustomerOption] from `PelangganResource` JSON.
  factory CustomerOption.fromJson(Map<String, dynamic> json) {
    return CustomerOption(
      id: (json['id_pelanggan'] as num?)?.toInt() ?? 0,
      name: (json['nama_pelanggan'] ?? '').toString(),
      phone: json['telepon'] as String?,
      address: json['alamat'] as String?,
      notes: json['catatan'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Building material SKU catalog entry matching Laravel `StokResource`.
class ProductItem {
  /// Creates a [ProductItem].
  const ProductItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.baseUnit,
    required this.stockQuantity,
    required this.minStockThreshold,
    required this.unitOptions,
    this.categoryId,
    this.costPrice,
    this.rawUnitLabel,
  });

  /// Unique product identifier (`id_produk` as string, or local seed ID).
  final String id;

  /// Store SKU code (`kode_sku`).
  final String sku;

  /// Commercial product title (`nama_produk`).
  final String name;

  /// Optional relational category ID (`id_kategori`).
  final int? categoryId;

  /// Material category name (`kategori.nama_kategori`).
  final String category;

  /// Base unit in which warehouse stock is tracked.
  final ProductUnit baseUnit;

  /// Original unit text returned by backend `satuan`.
  final String? rawUnitLabel;

  /// Current physical/book stock measured in [baseUnit] (`kuantitas`).
  final double stockQuantity;

  /// Reorder threshold measured in [baseUnit] (`stok_minimum`).
  final double minStockThreshold;

  /// Optional cost price / HPP (`harga_modal`).
  final double? costPrice;

  /// Available sale units and their respective prices.
  final List<ProductUnitOption> unitOptions;

  /// Integer primary key `id_produk`, or `null` for offline seed entries.
  int? get numericId => int.tryParse(id);

  /// Whether current inventory has reached or fallen below [minStockThreshold].
  bool get isLowStock => stockQuantity <= minStockThreshold;

  /// Returns the default (first) unit option.
  ProductUnitOption get defaultOption => unitOptions.first;

  /// Finds the option matching [unit], or `null` if unavailable for this item.
  ProductUnitOption? optionFor(ProductUnit unit) {
    for (final option in unitOptions) {
      if (option.unit == unit) return option;
    }
    return null;
  }

  /// Parses a [ProductItem] from a Laravel `StokResource` JSON payload.
  factory ProductItem.fromJson(Map<String, dynamic> json) {
    final kategoriMap = json['kategori'];
    final categoryName = kategoriMap is Map<String, dynamic>
        ? (kategoriMap['nama_kategori'] as String? ?? 'Material Umum')
        : (json['category'] as String? ?? 'Material Umum');

    final rawSatuan = (json['satuan'] as String? ?? 'pcs').trim();
    final mappedUnit = ProductUnit.fromString(rawSatuan);
    final sellingPrice = (json['harga'] as num?)?.toDouble() ?? 0;

    return ProductItem(
      id: (json['id_produk'] ?? json['id'] ?? '').toString(),
      sku: (json['kode_sku'] ?? '').toString(),
      name: (json['nama_produk'] ?? '').toString(),
      categoryId: (json['id_kategori'] as num?)?.toInt(),
      category: categoryName,
      baseUnit: mappedUnit,
      rawUnitLabel: rawSatuan,
      stockQuantity: (json['kuantitas'] as num?)?.toDouble() ?? 0,
      minStockThreshold: (json['stok_minimum'] as num?)?.toDouble() ?? 5,
      costPrice: (json['harga_modal'] as num?)?.toDouble(),
      unitOptions: [
        ProductUnitOption(
          unit: mappedUnit,
          price: sellingPrice,
          customLabel: rawSatuan,
        ),
      ],
    );
  }

  /// Returns a copy with updated stock or metadata.
  ProductItem copyWith({double? stockQuantity, double? minStockThreshold}) {
    return ProductItem(
      id: id,
      sku: sku,
      name: name,
      categoryId: categoryId,
      category: category,
      baseUnit: baseUnit,
      rawUnitLabel: rawUnitLabel,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockThreshold: minStockThreshold ?? this.minStockThreshold,
      costPrice: costPrice,
      unitOptions: unitOptions,
    );
  }
}

/// Line item inside the active POS cart or finalized receipt.
class CartItem {
  /// Creates a [CartItem].
  const CartItem({
    required this.product,
    required this.unitOption,
    required this.quantity,
    this.detailId,
    this.itemStatus,
  });

  /// Catalog product referenced by this line item.
  final ProductItem product;

  /// Chosen selling unit and unit price.
  final ProductUnitOption unitOption;

  /// Quantity ordered in [unitOption.unit].
  final double quantity;

  /// Optional backend `id_detail` when hydrated from `DetailTransaksiResource`.
  final int? detailId;

  /// Optional backend item delivery status (`DIAMBIL`, `MENUNGGU_DIANTAR`, etc.).
  final String? itemStatus;

  /// Unique cart key distinguishing same product across different units.
  String get key => '${product.id}_${unitOption.unit.name}';

  /// Line total in IDR.
  double get subtotal => unitOption.price * quantity;

  /// Base stock units consumed by this cart line.
  double get baseStockConsumed => quantity * unitOption.stockConversion;

  /// Parses a line item snapshot from Laravel `DetailTransaksiResource` JSON.
  factory CartItem.fromBackendDetailJson(Map<String, dynamic> json) {
    final produkMap = json['produk'] as Map<String, dynamic>?;
    final rawSatuan = (produkMap?['satuan'] as String? ?? 'pcs').trim();
    final mappedUnit = ProductUnit.fromString(rawSatuan);
    final unitPrice = (json['harga_satuan'] as num?)?.toDouble() ?? 0;

    final product = ProductItem(
      id: (json['id_produk'] ?? '').toString(),
      sku: (produkMap?['kode_sku'] ?? '').toString(),
      name:
          (json['nama_produk'] ??
                  produkMap?['nama_produk'] ??
                  'Produk #${json['id_produk']}')
              .toString(),
      category: 'Material',
      baseUnit: mappedUnit,
      rawUnitLabel: rawSatuan,
      stockQuantity: 0,
      minStockThreshold: 0,
      unitOptions: [
        ProductUnitOption(
          unit: mappedUnit,
          price: unitPrice,
          customLabel: rawSatuan,
        ),
      ],
    );

    return CartItem(
      product: product,
      unitOption: product.defaultOption,
      quantity: (json['jumlah'] as num?)?.toDouble() ?? 1,
      detailId: (json['id_detail'] as num?)?.toInt(),
      itemStatus: json['status_barang'] as String?,
    );
  }

  /// Returns a copy with modified [unitOption] or [quantity].
  CartItem copyWith({ProductUnitOption? unitOption, double? quantity}) {
    return CartItem(
      product: product,
      unitOption: unitOption ?? this.unitOption,
      quantity: quantity ?? this.quantity,
      detailId: detailId,
      itemStatus: itemStatus,
    );
  }
}

/// Finalized POS checkout receipt matching Laravel `TransaksiResource`.
class TransactionReceipt {
  /// Creates a [TransactionReceipt].
  const TransactionReceipt({
    required this.invoiceNumber,
    required this.createdAt,
    required this.cashierName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.grandTotal,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    required this.fulfillmentType,
    required this.customerName,
    this.transactionId,
    this.paymentStatus,
    this.orderStatus,
    this.customerId,
    this.customerPhone,
    this.deliveryAddress,
    this.bankName,
    this.tempoDueDate,
    this.deliveryOrderId,
    this.notes,
  });

  /// Backend database primary key `id_transaksi`, if synced with server.
  final int? transactionId;

  /// Sequential store invoice number (`nomor_struk`), e.g. `INV-20261126-001`.
  final String invoiceNumber;

  /// Transaction completion timestamp (`tanggal_transaksi`).
  final DateTime createdAt;

  /// Name of the cashier processing the sale (`pengguna.nama`).
  final String cashierName;

  /// Purchased line items snapshot.
  final List<CartItem> items;

  /// Merchandise subtotal before delivery fee.
  final double subtotal;

  /// Delivery service fee paid by store (`biaya_angkut`).
  final double deliveryFee;

  /// Total payable amount (`total_pembayaran`).
  final double grandTotal;

  /// Payment method selected at checkout.
  final PaymentMethod paymentMethod;

  /// Backend payment status (`LUNAS` / `BELUM_LUNAS`).
  final String? paymentStatus;

  /// Backend calculated order status (`BERJALAN` / `SELESAI`).
  final String? orderStatus;

  /// Amount tendered by the customer (`jumlah_bayar`, `0` for unpaid Tempo).
  final double amountPaid;

  /// Cash change returned to customer (`kembalian`).
  final double changeAmount;

  /// Direct pickup vs delivery service mode.
  final FulfillmentType fulfillmentType;

  /// Optional linked backend `id_pelanggan`.
  final int? customerId;

  /// Buyer or contractor name.
  final String customerName;

  /// Optional customer phone number.
  final String? customerPhone;

  /// Optional shipping destination address.
  final String? deliveryAddress;

  /// Destination bank or transfer reference (`referensi_pembayaran`).
  final String? bankName;

  /// Due date for Tempo / Credit transactions.
  final DateTime? tempoDueDate;

  /// Linked SCM delivery order identifier if [fulfillmentType] is delivery.
  final String? deliveryOrderId;

  /// Optional transaction notes (`catatan`).
  final String? notes;

  /// Hydrates a [TransactionReceipt] from a Laravel `TransaksiResource` JSON map.
  factory TransactionReceipt.fromBackendJson(Map<String, dynamic> json) {
    final penggunaMap = json['pengguna'] as Map<String, dynamic>?;
    final pelangganMap = json['pelanggan'] as Map<String, dynamic>?;
    final rawDetails = json['detail'] as List?;
    final items = rawDetails == null
        ? const <CartItem>[]
        : rawDetails
              .whereType<Map<String, dynamic>>()
              .map(CartItem.fromBackendDetailJson)
              .toList(growable: false);

    final statusPembayaran = json['status_pembayaran'] as String?;
    final method = PaymentMethod.fromBackend(
      json['jenis_pembayaran'] as String?,
      statusPembayaran: statusPembayaran,
    );
    final total = (json['total_pembayaran'] as num?)?.toDouble() ?? 0;
    final needsDelivery = json['perlu_diantar'] as bool? ?? false;
    final txId = (json['id_transaksi'] as num?)?.toInt();

    return TransactionReceipt(
      transactionId: txId,
      invoiceNumber: (json['nomor_struk'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['tanggal_transaksi'] as String? ?? '') ??
          DateTime.now(),
      cashierName: (penggunaMap?['nama'] ?? 'Kasir').toString(),
      items: items,
      subtotal: total,
      deliveryFee: (json['biaya_angkut'] as num?)?.toDouble() ?? 0,
      grandTotal: total,
      paymentMethod: method,
      paymentStatus: statusPembayaran,
      orderStatus: json['status_pesanan'] as String?,
      amountPaid:
          (json['jumlah_bayar'] as num?)?.toDouble() ??
          (method == PaymentMethod.tempo ? 0.0 : total),
      changeAmount: (json['kembalian'] as num?)?.toDouble() ?? 0,
      fulfillmentType: needsDelivery
          ? FulfillmentType.deliveryService
          : FulfillmentType.directPickup,
      customerId: (json['id_pelanggan'] as num?)?.toInt(),
      customerName:
          (pelangganMap?['nama_pelanggan'] as String?) ?? 'Pelanggan Umum',
      customerPhone: pelangganMap?['telepon'] as String?,
      deliveryAddress: pelangganMap?['alamat'] as String?,
      bankName: json['referensi_pembayaran'] as String?,
      deliveryOrderId: needsDelivery && txId != null ? 'SJ-$txId' : null,
      notes: json['catatan'] as String?,
    );
  }
}
