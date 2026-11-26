import 'package:flutter/foundation.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/scm/data/scm_models.dart';
import 'package:stelliform_mobile/features/scm/data/scm_repository.dart';

/// Controller managing Supply Chain operations: Stock Opname, Dispatch, and Driver POD.
class ScmController extends ChangeNotifier {
  /// Creates an [ScmController] backed by [repository].
  ScmController({required ScmRepository repository}) : _repository = repository;

  final ScmRepository _repository;

  String? _selectedDeliveryId;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ApiException? _lastException;

  /// All warehouse inventory SKUs.
  List<ProductItem> get inventoryProducts => _repository.getInventoryProducts();

  /// All delivery orders tracked across the store fleet.
  List<DeliveryOrder> get deliveries => _repository.getDeliveries();

  /// Historical stock opname adjustments.
  List<StockOpnameRecord> get opnameHistory => _repository.getOpnameHistory();

  /// Number of deliveries currently pending or in transit.
  int get activeDeliveryCount =>
      deliveries.where((d) => d.status != DeliveryStatus.delivered).length;

  /// Number of pending deliveries waiting for loading.
  int get pendingCount =>
      deliveries.where((d) => d.status == DeliveryStatus.pending).length;

  /// Number of deliveries currently on the road.
  int get inTransitCount =>
      deliveries.where((d) => d.status == DeliveryStatus.inTransit).length;

  /// Number of deliveries completed with POD.
  int get deliveredCount =>
      deliveries.where((d) => d.status == DeliveryStatus.delivered).length;

  /// Currently selected delivery order in [DriverPodScreen].
  DeliveryOrder? get selectedDelivery {
    final list = deliveries;
    if (list.isEmpty) return null;
    if (_selectedDeliveryId != null) {
      for (final order in list) {
        if (order.id == _selectedDeliveryId) return order;
      }
    }
    return list.firstWhere(
      (order) => order.status != DeliveryStatus.delivered,
      orElse: () => list.first,
    );
  }

  /// Whether background SCM refresh is in progress.
  bool get isLoading => _isLoading;

  /// Whether an SCM write action is in flight.
  bool get isSubmitting => _isSubmitting;

  /// Latest validation or operation error message.
  String? get errorMessage => _errorMessage;

  /// Latest structured [ApiException] from SCM endpoints.
  ApiException? get lastException => _lastException;

  /// Refreshes warehouse SKUs, opname history, and delivery dispatch tasks.
  Future<void> loadWarehouseData({
    bool includeInventory = true,
    bool includeOpname = true,
    bool includeDeliveries = true,
  }) async {
    if (!_repository.enableRemoteSync) return;
    _isLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      if (includeInventory) {
        await _repository.fetchInventoryProducts();
      }
      if (includeOpname) {
        await _repository.fetchOpnameHistory();
      }
      if (includeDeliveries) {
        await _repository.fetchDeliveryTasks();
      }
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
    } catch (_) {
      _errorMessage = 'Gagal memuat data gudang & pengantaran.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a specific delivery order by [orderId] for POD inspection.
  void selectDelivery(String orderId) {
    _selectedDeliveryId = orderId;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();
  }

  /// Registers a delivery order produced during POS checkout and returns its ID.
  String createDeliveryFromCheckout(TransactionReceipt receipt) {
    final created = _repository.createDeliveryFromReceipt(receipt);
    _selectedDeliveryId = created.id;
    notifyListeners();
    return created.suratJalanNumber;
  }

  /// Assigns driver and fleet plate (plus optional shipping cost) to a delivery order.
  Future<bool> assignFleet({
    required String orderId,
    required String driverName,
    required String vehiclePlate,
    DeliveryStatus? nextStatus,
    double? shippingCost,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.assignFleet(
        orderId: orderId,
        driverName: driverName,
        vehiclePlate: vehiclePlate,
        nextStatus: nextStatus,
        shippingCost: shippingCost,
      );
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal menugaskan armada pengiriman.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Updates the lifecycle status of [orderId] (`Pending` -> `In Transit` -> `Delivered`).
  Future<bool> updateDeliveryStatus({
    required String orderId,
    required DeliveryStatus status,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.updateStatus(orderId: orderId, status: status);
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal memperbarui status pengiriman.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Submits complete Proof of Delivery (photo + customer digital signature) for [orderId].
  Future<bool> submitProofOfDelivery({
    required String orderId,
    required String receiverName,
    required Uint8List? proofPhotoBytes,
    required String? proofPhotoName,
    required Uint8List? signatureBytes,
    String? notes,
  }) async {
    if (receiverName.trim().isEmpty) {
      _errorMessage = 'Nama penerima barang wajib diisi.';
      notifyListeners();
      return false;
    }
    if (proofPhotoBytes == null || proofPhotoBytes.isEmpty) {
      _errorMessage = 'Lampirkan foto bukti serah terima barang.';
      notifyListeners();
      return false;
    }
    if (signatureBytes == null || signatureBytes.isEmpty) {
      _errorMessage = 'Tanda tangan digital penerima wajib diisi.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.submitProofOfDelivery(
        orderId: orderId,
        receiverName: receiverName,
        proofPhotoBytes: proofPhotoBytes,
        proofPhotoName: proofPhotoName ?? 'pod_photo.jpg',
        signatureBytes: signatureBytes,
        notes: notes,
      );
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal menyimpan Bukti Pengiriman (POD).';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Saves a Stock Opname adjustment for [product].
  Future<bool> submitStockOpname({
    required ProductItem product,
    required double physicalStock,
    required String reason,
    required String checkedBy,
  }) async {
    if (physicalStock < 0) {
      _errorMessage = 'Stok fisik tidak boleh bernilai negatif.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.recordStockOpname(
        product: product,
        physicalStock: physicalStock,
        reason: reason,
        checkedBy: checkedBy,
      );
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal menyimpan hasil Stock Opname.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
