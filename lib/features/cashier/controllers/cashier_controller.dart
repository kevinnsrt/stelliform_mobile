import 'package:flutter/foundation.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_repository.dart';

/// POS state controller managing catalog loading/filtering, multi-unit cart items,
/// fulfillment mode, payment selection, and checkout execution.
class CashierController extends ChangeNotifier {
  /// Creates a [CashierController] backed by [repository].
  CashierController({required CashierRepository repository})
    : _repository = repository;

  final CashierRepository _repository;

  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  ProductUnit? _unitFilter;
  List<String> _remoteCategories = [];

  final List<CartItem> _cart = [];
  FulfillmentType _fulfillmentType = FulfillmentType.directPickup;
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  double _cashTendered = 0;
  double _deliveryFee = 75000;
  String _selectedBank = 'BCA';
  int _tempoDays = 30;

  String _customerName = 'Pelanggan Umum';
  String _customerPhone = '';
  String _deliveryAddress = '';

  bool _isCatalogLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ApiException? _lastException;
  TransactionReceipt? _latestReceipt;

  /// Active search text query.
  String get searchQuery => _searchQuery;

  /// Currently selected category chip.
  String get selectedCategory => _selectedCategory;

  /// Optional unit filter chip (`Sak`, `Meter`, `Kubik`, `Biji`, `Dus`).
  ProductUnit? get unitFilter => _unitFilter;

  /// Current shopping cart line items.
  List<CartItem> get cartItems => List.unmodifiable(_cart);

  /// Selected fulfillment mode (`Direct Pickup` vs `Delivery Service`).
  FulfillmentType get fulfillmentType => _fulfillmentType;

  /// Whether delivery logistics is required for the current order.
  bool get requiresDelivery =>
      _fulfillmentType == FulfillmentType.deliveryService;

  /// Selected payment method (`Cash`, `Transfer`, `QRIS`, `Tempo / Credit`).
  PaymentMethod get paymentMethod => _paymentMethod;

  /// Cash amount handed over by the customer.
  double get cashTendered => _cashTendered;

  /// Delivery fee estimate shown locally (backend manages `biaya_angkut` on dispatch).
  double get deliveryFee => requiresDelivery ? _deliveryFee : 0;

  /// Selected destination bank for transfer payments.
  String get selectedBank => _selectedBank;

  /// Credit term duration in days for Tempo payments.
  int get tempoDays => _tempoDays;

  /// Customer name for receipt or delivery tracking.
  String get customerName => _customerName;

  /// Customer phone number for delivery contact.
  String get customerPhone => _customerPhone;

  /// Delivery destination address.
  String get deliveryAddress => _deliveryAddress;

  /// Whether catalog synchronization is in progress.
  bool get isCatalogLoading => _isCatalogLoading;

  /// Whether checkout submission is running.
  bool get isSubmitting => _isSubmitting;

  /// Most recent validation or submission error message.
  String? get errorMessage => _errorMessage;

  /// Most recent [ApiException] for dialog/SnackBar presentation.
  ApiException? get lastException => _lastException;

  /// Most recently completed transaction receipt.
  TransactionReceipt? get latestReceipt => _latestReceipt;

  /// All available catalog categories prefixed with `'Semua'`.
  List<String> get categories {
    final distinct = {
      ..._remoteCategories,
      ..._repository.getProducts().map((p) => p.category),
    }.toList()..sort();
    return ['Semua', ...distinct];
  }

  /// Catalog products filtered by search query, category, and optional unit filter.
  List<ProductItem> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _repository
        .getProducts()
        .where((product) {
          final matchesCategory =
              _selectedCategory == 'Semua' ||
              product.category == _selectedCategory;
          final matchesUnit =
              _unitFilter == null || product.optionFor(_unitFilter!) != null;
          final matchesQuery =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query);
          return matchesCategory && matchesUnit && matchesQuery;
        })
        .toList(growable: false);
  }

  /// Sum of line item subtotals before delivery fee.
  double get cartSubtotal => _cart.fold(0, (sum, item) => sum + item.subtotal);

  /// Total payable amount including delivery fee when offline, or backend total.
  double get grandTotal => cartSubtotal + deliveryFee;

  /// Total distinct line entries in the cart.
  int get totalLineCount => _cart.length;

  /// Change due for cash payments (`0` if underpaid or non-cash).
  double get cashChange {
    if (_paymentMethod != PaymentMethod.cash) return 0;
    final diff = _cashTendered - grandTotal;
    return diff > 0 ? diff : 0;
  }

  /// All stored transaction receipts.
  List<TransactionReceipt> get receiptHistory => _repository.getReceipts();

  /// Loads live catalog products & categories from the backend REST API.
  Future<void> loadCatalog() async {
    if (!_repository.enableRemoteSync) return;
    _isCatalogLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.fetchProducts();
      _remoteCategories = await _repository.fetchCategories();
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
    } catch (_) {
      _errorMessage = 'Gagal memuat katalog produk dari server.';
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }
  }

  /// Fetches live receipt details from `/kasir/pesanan/{id}/struk` when needed.
  Future<TransactionReceipt?> fetchReceiptByTransactionId(
    int transactionId,
  ) async {
    try {
      final fetched = await _repository.fetchReceiptById(transactionId);
      _latestReceipt = fetched;
      notifyListeners();
      return fetched;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      notifyListeners();
      return null;
    }
  }

  /// Looks up a receipt by [invoiceNumber], falling back to [latestReceipt].
  TransactionReceipt? resolveReceipt(String? invoiceNumber) {
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      return _repository.findReceipt(invoiceNumber) ?? _latestReceipt;
    }
    return _latestReceipt ?? _repository.getReceipts().firstOrNull;
  }

  /// Updates catalog search filter.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Selects category filter chip.
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Toggles unit filter chip; tapping the active unit clears the filter.
  void toggleUnitFilter(ProductUnit? unit) {
    _unitFilter = _unitFilter == unit ? null : unit;
    notifyListeners();
  }

  /// Adds [product] with [unit] to the cart or increments existing quantity.
  void addToCart(ProductItem product, ProductUnit unit, {double? quantity}) {
    final option = product.optionFor(unit) ?? product.defaultOption;
    final stepQty = quantity ?? 1.0;
    final key = '${product.id}_${option.unit.name}';
    final existingIndex = _cart.indexWhere((item) => item.key == key);

    if (existingIndex != -1) {
      final current = _cart[existingIndex];
      _cart[existingIndex] = current.copyWith(
        quantity: current.quantity + stepQty,
      );
    } else {
      _cart.add(
        CartItem(product: product, unitOption: option, quantity: stepQty),
      );
    }
    _errorMessage = null;
    _lastException = null;
    notifyListeners();
  }

  /// Changes the unit of an existing cart line identified by [itemKey].
  void changeCartItemUnit(String itemKey, ProductUnit newUnit) {
    final index = _cart.indexWhere((item) => item.key == itemKey);
    if (index == -1) return;
    final current = _cart[index];
    final nextOption = current.product.optionFor(newUnit);
    if (nextOption == null) return;

    final targetKey = '${current.product.id}_${newUnit.name}';
    final duplicateIndex = _cart.indexWhere((item) => item.key == targetKey);
    if (duplicateIndex != -1 && duplicateIndex != index) {
      final target = _cart[duplicateIndex];
      _cart[duplicateIndex] = target.copyWith(
        quantity: target.quantity + current.quantity,
      );
      _cart.removeAt(index);
    } else {
      _cart[index] = current.copyWith(unitOption: nextOption);
    }
    notifyListeners();
  }

  /// Increments cart line quantity by its unit step.
  void incrementQuantity(String itemKey) {
    final index = _cart.indexWhere((item) => item.key == itemKey);
    if (index == -1) return;
    final current = _cart[index];
    final step = current.unitOption.unit.quantityStep;
    _cart[index] = current.copyWith(quantity: current.quantity + step);
    notifyListeners();
  }

  /// Decrements cart line quantity, removing the item if quantity reaches zero.
  void decrementQuantity(String itemKey) {
    final index = _cart.indexWhere((item) => item.key == itemKey);
    if (index == -1) return;
    final current = _cart[index];
    final step = current.unitOption.unit.quantityStep;
    final nextQty = current.quantity - step;
    if (nextQty <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = current.copyWith(quantity: nextQty);
    }
    notifyListeners();
  }

  /// Removes a line item from the cart.
  void removeFromCart(String itemKey) {
    _cart.removeWhere((item) => item.key == itemKey);
    notifyListeners();
  }

  /// Clears all items from the cart.
  void clearCart() {
    _cart.clear();
    _errorMessage = null;
    _lastException = null;
    notifyListeners();
  }

  /// Switches between Direct Pickup and Delivery Service.
  void setFulfillmentType(FulfillmentType type) {
    _fulfillmentType = type;
    if (type == FulfillmentType.deliveryService &&
        _customerName == 'Pelanggan Umum') {
      _customerName = '';
    } else if (type == FulfillmentType.directPickup &&
        _customerName.trim().isEmpty) {
      _customerName = 'Pelanggan Umum';
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// Updates the active payment method.
  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    if (method == PaymentMethod.cash && _cashTendered < grandTotal) {
      _cashTendered = grandTotal;
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets tendered cash amount.
  void setCashTendered(double amount) {
    _cashTendered = amount;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets shipping fee for delivery orders.
  void setDeliveryFee(double fee) {
    _deliveryFee = fee < 0 ? 0 : fee;
    notifyListeners();
  }

  /// Sets destination bank for Transfer payments.
  void setSelectedBank(String bank) {
    _selectedBank = bank;
    notifyListeners();
  }

  /// Sets credit term length in days for Tempo payments.
  void setTempoDays(int days) {
    _tempoDays = days;
    notifyListeners();
  }

  /// Updates customer contact and shipping details.
  void updateCustomerDetails({String? name, String? phone, String? address}) {
    if (name != null) _customerName = name;
    if (phone != null) _customerPhone = phone;
    if (address != null) _deliveryAddress = address;
    _errorMessage = null;
  }

  /// Validates and commits the current cart, returning the generated [TransactionReceipt].
  Future<TransactionReceipt?> submitCheckout({
    required String cashierName,
    String? Function(TransactionReceipt receipt)? onCreateDeliveryOrder,
  }) async {
    if (_cart.isEmpty) {
      _errorMessage = 'Keranjang masih kosong. Pilih material terlebih dahulu.';
      notifyListeners();
      return null;
    }

    final cleanCustomer = _customerName.trim();
    if (requiresDelivery) {
      if (cleanCustomer.isEmpty) {
        _errorMessage = 'Nama penerima wajib diisi untuk layanan pengiriman.';
        notifyListeners();
        return null;
      }
      if (_deliveryAddress.trim().isEmpty) {
        _errorMessage = 'Alamat pengiriman wajib diisi.';
        notifyListeners();
        return null;
      }
    }

    if (_paymentMethod == PaymentMethod.tempo && cleanCustomer.isEmpty) {
      _errorMessage = 'Nama pelanggan/kontraktor wajib diisi untuk Tempo.';
      notifyListeners();
      return null;
    }

    final expectedBackendTotal = cartSubtotal;
    if (_paymentMethod == PaymentMethod.cash &&
        _cashTendered <
            (_repository.enableRemoteSync
                ? expectedBackendTotal
                : grandTotal)) {
      _errorMessage = 'Nominal uang tunai kurang dari total tagihan.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final invoiceNo = _repository.generateNextInvoiceNumber();
      final effectivePaid = switch (_paymentMethod) {
        PaymentMethod.cash => _cashTendered,
        PaymentMethod.tempo => 0.0,
        PaymentMethod.transfer || PaymentMethod.qris => grandTotal,
      };

      var draftReceipt = TransactionReceipt(
        invoiceNumber: invoiceNo,
        createdAt: now,
        cashierName: cashierName,
        items: List<CartItem>.unmodifiable(_cart),
        subtotal: cartSubtotal,
        deliveryFee: deliveryFee,
        grandTotal: _repository.enableRemoteSync
            ? expectedBackendTotal
            : grandTotal,
        paymentMethod: _paymentMethod,
        amountPaid: effectivePaid,
        changeAmount: cashChange,
        fulfillmentType: _fulfillmentType,
        customerName: cleanCustomer.isEmpty ? 'Pelanggan Umum' : cleanCustomer,
        customerPhone: _customerPhone.trim().isEmpty
            ? null
            : _customerPhone.trim(),
        deliveryAddress: requiresDelivery ? _deliveryAddress.trim() : null,
        bankName: _paymentMethod == PaymentMethod.transfer
            ? _selectedBank
            : null,
        tempoDueDate: _paymentMethod == PaymentMethod.tempo
            ? now.add(Duration(days: _tempoDays))
            : null,
      );

      final saved = await _repository.recordTransaction(draftReceipt);
      final linkedOrderId = requiresDelivery
          ? onCreateDeliveryOrder?.call(saved)
          : null;

      final finalReceipt = linkedOrderId != null
          ? TransactionReceipt(
              transactionId: saved.transactionId,
              invoiceNumber: saved.invoiceNumber,
              createdAt: saved.createdAt,
              cashierName: saved.cashierName,
              items: saved.items,
              subtotal: saved.subtotal,
              deliveryFee: saved.deliveryFee,
              grandTotal: saved.grandTotal,
              paymentMethod: saved.paymentMethod,
              paymentStatus: saved.paymentStatus,
              orderStatus: saved.orderStatus,
              amountPaid: saved.amountPaid,
              changeAmount: saved.changeAmount,
              fulfillmentType: saved.fulfillmentType,
              customerId: saved.customerId,
              customerName: saved.customerName,
              customerPhone: saved.customerPhone,
              deliveryAddress: saved.deliveryAddress,
              bankName: saved.bankName,
              tempoDueDate: saved.tempoDueDate,
              deliveryOrderId: saved.deliveryOrderId ?? linkedOrderId,
              notes: saved.notes,
            )
          : saved;

      _latestReceipt = finalReceipt;

      _cart.clear();
      _cashTendered = 0;
      _customerName = 'Pelanggan Umum';
      _customerPhone = '';
      _deliveryAddress = '';
      _fulfillmentType = FulfillmentType.directPickup;
      _paymentMethod = PaymentMethod.cash;

      return finalReceipt;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'Gagal menyimpan transaksi. Periksa data lalu coba lagi.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
