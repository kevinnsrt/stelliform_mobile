import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';

/// Repository managing building material catalog (`GET /stok`), customers
/// (`GET/POST /kasir/pelanggan`), POS orders (`POST /kasir/pesanan`), and receipts.
class CashierRepository {
  /// Creates a [CashierRepository].
  ///
  /// When [enableRemoteSync] is `true`, product loading, customer lookup,
  /// order submission, and receipt retrieval hit the Laravel REST API while
  /// keeping an in-memory synchronized snapshot for reactive UI filters.
  CashierRepository({ApiClient? apiClient, this.enableRemoteSync = true})
    : _apiClient = apiClient;

  final ApiClient? _apiClient;

  /// Whether catalog reads and POS mutations should hit the remote API.
  final bool enableRemoteSync;

  final List<ProductItem> _catalog = [
    const ProductItem(
      id: 'PRD-001',
      sku: 'SMN-TR-50',
      name: 'Semen Tiga Roda 50 Kg',
      category: 'Semen & Mortar',
      baseUnit: ProductUnit.sak,
      stockQuantity: 12,
      minStockThreshold: 25,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.sak, price: 68000),
        ProductUnitOption(
          unit: ProductUnit.biji,
          price: 2000,
          stockConversion: 0.02,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-002',
      sku: 'SMN-MU-380',
      name: 'Mortar Utama MU-380 40 Kg',
      category: 'Semen & Mortar',
      baseUnit: ProductUnit.sak,
      stockQuantity: 64,
      minStockThreshold: 20,
      unitOptions: [ProductUnitOption(unit: ProductUnit.sak, price: 118000)],
    ),
    const ProductItem(
      id: 'PRD-003',
      sku: 'KRM-RMN-40',
      name: 'Keramik Roman 40x40 Putih Polos',
      category: 'Keramik & Granit',
      baseUnit: ProductUnit.dus,
      stockQuantity: 85,
      minStockThreshold: 20,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.dus, price: 74000),
        ProductUnitOption(unit: ProductUnit.meter, price: 74000),
        ProductUnitOption(
          unit: ProductUnit.biji,
          price: 13000,
          stockConversion: 1 / 6,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-004',
      sku: 'PSR-LMJ-01',
      name: 'Pasir Lumajang Super Cor',
      category: 'Pasir & Batu',
      baseUnit: ProductUnit.kubik,
      stockQuantity: 3,
      minStockThreshold: 5,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.kubik, price: 365000),
        ProductUnitOption(
          unit: ProductUnit.sak,
          price: 28000,
          stockConversion: 0.06,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-005',
      sku: 'BTU-SPL-12',
      name: 'Batu Split 1/2 Pengecoran',
      category: 'Pasir & Batu',
      baseUnit: ProductUnit.kubik,
      stockQuantity: 18,
      minStockThreshold: 6,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.kubik, price: 340000),
        ProductUnitOption(
          unit: ProductUnit.sak,
          price: 26000,
          stockConversion: 0.06,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-006',
      sku: 'KBL-NYM-215',
      name: 'Kabel NYM Eterna 2x1.5mm',
      category: 'Pipa & Listrik',
      baseUnit: ProductUnit.meter,
      stockQuantity: 420,
      minStockThreshold: 100,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.meter, price: 11500),
        ProductUnitOption(
          unit: ProductUnit.dus,
          price: 540000,
          stockConversion: 50,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-007',
      sku: 'PVC-RCK-34',
      name: 'Pipa PVC Rucika AW 3/4"',
      category: 'Pipa & Listrik',
      baseUnit: ProductUnit.biji,
      stockQuantity: 92,
      minStockThreshold: 30,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.biji, price: 52000),
        ProductUnitOption(
          unit: ProductUnit.meter,
          price: 14000,
          stockConversion: 0.25,
        ),
        ProductUnitOption(
          unit: ProductUnit.dus,
          price: 500000,
          stockConversion: 10,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-008',
      sku: 'BSI-SNI-10',
      name: 'Besi Beton SNI 10mm Full (12m)',
      category: 'Besi & Kayu',
      baseUnit: ProductUnit.biji,
      stockQuantity: 8,
      minStockThreshold: 20,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.biji, price: 82000),
        ProductUnitOption(
          unit: ProductUnit.meter,
          price: 7200,
          stockConversion: 1 / 12,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-009',
      sku: 'BTA-PRS-01',
      name: 'Bata Merah Press Super',
      category: 'Pasir & Batu',
      baseUnit: ProductUnit.biji,
      stockQuantity: 4500,
      minStockThreshold: 1000,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.biji, price: 1150),
        ProductUnitOption(
          unit: ProductUnit.kubik,
          price: 540000,
          stockConversion: 500,
        ),
      ],
    ),
    const ProductItem(
      id: 'PRD-010',
      sku: 'GRN-ESZ-60',
      name: 'Granit Essenza 60x60 Cream Polish',
      category: 'Keramik & Granit',
      baseUnit: ProductUnit.dus,
      stockQuantity: 42,
      minStockThreshold: 15,
      unitOptions: [
        ProductUnitOption(unit: ProductUnit.dus, price: 185000),
        ProductUnitOption(
          unit: ProductUnit.meter,
          price: 132000,
          stockConversion: 1 / 1.44,
        ),
        ProductUnitOption(
          unit: ProductUnit.biji,
          price: 48000,
          stockConversion: 0.25,
        ),
      ],
    ),
  ];

  final List<TransactionReceipt> _receipts = [
    TransactionReceipt(
      invoiceNumber: 'INV-20261126-001',
      createdAt: DateTime(2026, 11, 26, 9, 15),
      cashierName: 'Siti Rahayu',
      items: const [],
      subtotal: 4850000,
      deliveryFee: 100000,
      grandTotal: 4950000,
      paymentMethod: PaymentMethod.transfer,
      amountPaid: 4950000,
      changeAmount: 0,
      fulfillmentType: FulfillmentType.deliveryService,
      customerName: 'CV. Karya Mandiri Kontraktor',
      customerPhone: '0812-3344-5566',
      deliveryAddress: 'Jl. Raya Kalimalang No. 88, Bekasi',
      bankName: 'BCA',
      deliveryOrderId: 'SJ-20261126-01',
    ),
    TransactionReceipt(
      invoiceNumber: 'INV-20261126-002',
      createdAt: DateTime(2026, 11, 26, 10, 40),
      cashierName: 'Siti Rahayu',
      items: const [],
      subtotal: 1840000,
      deliveryFee: 0,
      grandTotal: 1840000,
      paymentMethod: PaymentMethod.qris,
      amountPaid: 1840000,
      changeAmount: 0,
      fulfillmentType: FulfillmentType.directPickup,
      customerName: 'Bapak Agus Pratama',
    ),
  ];

  /// Returns an unmodifiable view of cached products in catalog.
  List<ProductItem> getProducts() => List.unmodifiable(_catalog);

  /// Returns all items currently at or below their minimum stock threshold.
  List<ProductItem> getLowStockProducts() =>
      _catalog.where((item) => item.isLowStock).toList(growable: false);

  /// Returns finalized POS receipts ordered newest-first.
  List<TransactionReceipt> getReceipts() =>
      List.unmodifiable(_receipts.reversed);

  /// Finds a receipt by [invoiceNumber], or returns `null`.
  TransactionReceipt? findReceipt(String invoiceNumber) {
    for (final receipt in _receipts) {
      if (receipt.invoiceNumber == invoiceNumber) return receipt;
    }
    return null;
  }

  /// Updates cached physical stock for [productId] following SCM Stock Opname.
  void setProductStock(String productId, double newStockQuantity) {
    final index = _catalog.indexWhere((item) => item.id == productId);
    if (index == -1) return;
    _catalog[index] = _catalog[index].copyWith(
      stockQuantity: newStockQuantity < 0 ? 0 : newStockQuantity,
    );
  }

  /// Fetches live product catalog from `GET /api/v1/stok` and caches it.
  Future<List<ProductItem>> fetchProducts({
    String? search,
    int? categoryId,
    bool availableOnly = false,
  }) async {
    if (!enableRemoteSync || _apiClient == null) {
      return getProducts();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.products,
      queryParameters: {
        'per_page': 100,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (categoryId != null) 'id_kategori': categoryId,
        if (availableOnly) 'tersedia': 1,
      },
    );

    final rawList = ApiClient.unwrapList(response.data);
    final fetched = rawList.map(ProductItem.fromJson).toList(growable: false);

    if (search == null && categoryId == null && !availableOnly) {
      _catalog
        ..clear()
        ..addAll(fetched);
    }
    return fetched;
  }

  /// Looks up a single product by exact SKU via `GET /api/v1/stok/scan`.
  Future<ProductItem> scanProductBySku(String kodeSku) async {
    final cleanSku = kodeSku.trim();
    if (!enableRemoteSync || _apiClient == null) {
      return _catalog.firstWhere(
        (p) => p.sku.toLowerCase() == cleanSku.toLowerCase(),
        orElse: () => throw const ApiException(
          'Produk dengan kode SKU tersebut tidak ditemukan.',
          statusCode: 404,
          errorCode: 'NOT_FOUND',
        ),
      );
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.productScan,
      queryParameters: {'kode_sku': cleanSku},
    );
    final data = ApiClient.unwrapData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Produk tidak ditemukan.', statusCode: 404);
    }
    return ProductItem.fromJson(data);
  }

  /// Fetches category names from `GET /api/v1/kategori`.
  Future<List<String>> fetchCategories() async {
    if (!enableRemoteSync || _apiClient == null) {
      return _catalog.map((p) => p.category).toSet().toList()..sort();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.categories,
      queryParameters: {'per_page': 100},
    );
    final rawList = ApiClient.unwrapList(response.data);
    final names = rawList
        .map((e) => (e['nama_kategori'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();
    names.sort();
    return names;
  }

  /// Fetches recent orders from `GET /api/v1/kasir/pesanan`.
  Future<List<TransactionReceipt>> fetchOrders({int perPage = 20}) async {
    if (!enableRemoteSync || _apiClient == null) {
      return getReceipts();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      queryParameters: {'per_page': perPage},
    );
    final rawList = ApiClient.unwrapList(response.data);
    final parsed = rawList
        .map(TransactionReceipt.fromBackendJson)
        .toList(growable: false);
    if (parsed.isNotEmpty) {
      _receipts
        ..clear()
        ..addAll(parsed.reversed);
    }
    return parsed;
  }

  /// Fetches itemized receipt details from `GET /api/v1/kasir/pesanan/{id}/struk`.
  Future<TransactionReceipt> fetchReceiptById(int transactionId) async {
    if (!enableRemoteSync || _apiClient == null) {
      throw StateError('Remote API tidak aktif.');
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.orderReceipt(transactionId),
    );
    final data = ApiClient.unwrapData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Data struk tidak valid.');
    }
    return TransactionReceipt.fromBackendJson(data);
  }

  /// Finds or creates a customer with a valid address for delivery orders.
  Future<CustomerOption> _resolveDeliveryCustomer({
    required String name,
    String? phone,
    required String address,
  }) async {
    final cleanName = name.trim();
    final cleanAddress = address.trim();
    final cleanPhone = phone?.trim();

    final searchRes = await _apiClient!.get<Map<String, dynamic>>(
      ApiEndpoints.customers,
      queryParameters: {'search': cleanName, 'per_page': 20},
    );
    final candidates = ApiClient.unwrapList(
      searchRes.data,
    ).map(CustomerOption.fromJson).toList(growable: false);

    final exact = candidates
        .where((c) => c.name.trim().toLowerCase() == cleanName.toLowerCase())
        .firstOrNull;

    if (exact != null) {
      final updateRes = await _apiClient.put<Map<String, dynamic>>(
        ApiEndpoints.customerById(exact.id),
        data: {
          'nama_pelanggan': cleanName,
          if (cleanPhone != null && cleanPhone.isNotEmpty)
            'telepon': cleanPhone,
          'alamat': cleanAddress,
          'is_active': true,
        },
      );
      final updatedMap = ApiClient.unwrapData(updateRes.data);
      if (updatedMap is Map<String, dynamic>) {
        return CustomerOption.fromJson(updatedMap);
      }
      return exact;
    }

    final createRes = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.customers,
      data: {
        'nama_pelanggan': cleanName,
        if (cleanPhone != null && cleanPhone.isNotEmpty) 'telepon': cleanPhone,
        'alamat': cleanAddress,
        'is_active': true,
      },
    );
    final createdMap = ApiClient.unwrapData(createRes.data);
    if (createdMap is! Map<String, dynamic>) {
      throw const ApiException(
        'Gagal mendaftarkan alamat pelanggan pengiriman.',
      );
    }
    return CustomerOption.fromJson(createdMap);
  }

  /// Submits a POS transaction to `POST /api/v1/kasir/pesanan`, updates local
  /// stock cache, and returns the finalized [TransactionReceipt].
  Future<TransactionReceipt> recordTransaction(
    TransactionReceipt receipt,
  ) async {
    if (enableRemoteSync && _apiClient != null) {
      int? customerId = receipt.customerId;
      final needsDelivery =
          receipt.fulfillmentType == FulfillmentType.deliveryService;

      if (needsDelivery && customerId == null) {
        final resolved = await _resolveDeliveryCustomer(
          name: receipt.customerName,
          phone: receipt.customerPhone,
          address: receipt.deliveryAddress ?? '',
        );
        customerId = resolved.id;
      }

      // Backend enforces distinct `id_produk` lines with integer `jumlah >= 1`.
      final aggregatedQuantities = <int, int>{};
      for (final cartItem in receipt.items) {
        final numericId = cartItem.product.numericId;
        if (numericId == null) {
          throw const ApiException(
            'Produk belum tersinkronisasi dengan database server. Muat ulang katalog terlebih dahulu.',
            statusCode: 400,
          );
        }
        final intQty = cartItem.baseStockConsumed.ceil().clamp(1, 999999);
        aggregatedQuantities[numericId] =
            (aggregatedQuantities[numericId] ?? 0) + intQty;
      }

      final detailPayload = aggregatedQuantities.entries
          .map(
            (entry) => {
              'id_produk': entry.key,
              'jumlah': entry.value,
              'status_barang': receipt.fulfillmentType.backendItemStatus,
            },
          )
          .toList(growable: false);

      final payload = <String, dynamic>{
        'detail': detailPayload,
        'jenis_pembayaran': receipt.paymentMethod.backendCode,
        if (receipt.paymentMethod == PaymentMethod.cash)
          'jumlah_bayar': receipt.amountPaid,
        if (receipt.paymentMethod == PaymentMethod.transfer &&
            receipt.bankName != null)
          'referensi_pembayaran': 'Bank ${receipt.bankName}',
        if (customerId != null) 'id_pelanggan': customerId,
        if (receipt.notes != null && receipt.notes!.trim().isNotEmpty)
          'catatan': receipt.notes!.trim(),
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.orders,
        data: payload,
      );

      final responseData = ApiClient.unwrapData(response.data);
      final savedReceipt = responseData is Map<String, dynamic>
          ? TransactionReceipt.fromBackendJson(responseData)
          : receipt;

      if (!needsDelivery) {
        _deductLocalCatalog(receipt.items);
      }
      _receipts.add(savedReceipt);
      return savedReceipt;
    }

    _deductLocalCatalog(receipt.items);
    _receipts.add(receipt);
    return receipt;
  }

  void _deductLocalCatalog(List<CartItem> items) {
    for (final cartItem in items) {
      final index = _catalog.indexWhere((p) => p.id == cartItem.product.id);
      if (index != -1) {
        final nextStock =
            (_catalog[index].stockQuantity - cartItem.baseStockConsumed).clamp(
              0.0,
              double.infinity,
            );
        _catalog[index] = _catalog[index].copyWith(stockQuantity: nextStock);
      }
    }
  }

  /// Generates the next sequential offline invoice identifier.
  String generateNextInvoiceNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seq = (_receipts.length + 1).toString().padLeft(3, '0');
    return 'INV-$datePart-$seq';
  }
}
