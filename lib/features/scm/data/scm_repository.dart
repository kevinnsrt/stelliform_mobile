import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_repository.dart';
import 'package:stelliform_mobile/features/scm/data/scm_models.dart';

/// Repository managing warehouse stock opname, fleet dispatch, and courier PODs.
class ScmRepository {
  /// Creates an [ScmRepository] synchronized with [cashierRepository].
  ScmRepository({
    required CashierRepository cashierRepository,
    ApiClient? apiClient,
    this.enableRemoteSync = true,
  }) : _cashierRepository = cashierRepository,
       _apiClient = apiClient;

  final CashierRepository _cashierRepository;
  final ApiClient? _apiClient;

  /// Whether SCM mutations should sync with remote Laravel endpoints.
  final bool enableRemoteSync;

  final List<DeliveryOrder> _deliveries = [
    DeliveryOrder(
      id: 'DEL-001',
      suratJalanNumber: 'SJ-20261126-01',
      invoiceNumber: 'INV-20261126-001',
      customerName: 'CV. Karya Mandiri Kontraktor',
      customerPhone: '0812-3344-5566',
      destinationAddress: 'Jl. Raya Kalimalang No. 88, Bekasi Barat',
      driverName: 'Dedi Kurniawan',
      vehiclePlate: 'B 9421 DM',
      status: DeliveryStatus.inTransit,
      scheduledAt: DateTime(2026, 11, 26, 9, 30),
      dispatchedAt: DateTime(2026, 11, 26, 9, 55),
      items: const [
        DeliveryLineItem(
          productName: 'Semen Tiga Roda 50 Kg',
          quantityLabel: '40 Sak',
        ),
        DeliveryLineItem(
          productName: 'Pasir Lumajang Super Cor',
          quantityLabel: '3 Kubik',
        ),
        DeliveryLineItem(
          productName: 'Besi Beton SNI 10mm Full (12m)',
          quantityLabel: '25 Biji',
        ),
      ],
      notes: 'Turunkan di gerbang proyek sisi timur, hubungi Pak Yanto.',
    ),
    DeliveryOrder(
      id: 'DEL-002',
      suratJalanNumber: 'SJ-20261126-02',
      invoiceNumber: 'INV-20261126-003',
      customerName: 'Proyek Ruko Grand Galaxy',
      customerPhone: '0813-9988-1122',
      destinationAddress: 'Boulevard Grand Galaxy Blok RGA No. 14, Bekasi',
      driverName: 'Dedi Kurniawan',
      vehiclePlate: 'B 9421 DM',
      status: DeliveryStatus.pending,
      scheduledAt: DateTime(2026, 11, 26, 13, 0),
      items: const [
        DeliveryLineItem(
          productName: 'Keramik Roman 40x40 Putih Polos',
          quantityLabel: '30 Dus',
        ),
        DeliveryLineItem(
          productName: 'Mortar Utama MU-380 40 Kg',
          quantityLabel: '12 Sak',
        ),
      ],
      notes: 'Muat pakai palet agar dus keramik tidak pecah.',
    ),
    DeliveryOrder(
      id: 'DEL-003',
      suratJalanNumber: 'SJ-20261126-03',
      invoiceNumber: 'INV-20261125-019',
      customerName: 'Bapak Hendro Susilo',
      customerPhone: '0819-7765-4321',
      destinationAddress: 'Perum Harapan Indah Cluster Melati No. 7',
      driverName: 'Rizal Fauzi',
      vehiclePlate: 'B 9104 DM',
      status: DeliveryStatus.delivered,
      scheduledAt: DateTime(2026, 11, 26, 8, 0),
      dispatchedAt: DateTime(2026, 11, 26, 8, 15),
      deliveredAt: DateTime(2026, 11, 26, 9, 5),
      receiverName: 'Hendro Susilo',
      items: const [
        DeliveryLineItem(
          productName: 'Pipa PVC Rucika AW 3/4"',
          quantityLabel: '15 Biji',
        ),
        DeliveryLineItem(
          productName: 'Kabel NYM Eterna 2x1.5mm',
          quantityLabel: '100 Meter',
        ),
      ],
      notes: 'Sudah diterima lengkap oleh pemilik rumah.',
    ),
  ];

  final List<StockOpnameRecord> _opnameHistory = [
    StockOpnameRecord(
      id: 'OPN-001',
      productId: 'PRD-001',
      productName: 'Semen Tiga Roda 50 Kg',
      sku: 'SMN-TR-50',
      unitLabel: 'Sak',
      systemStock: 14,
      physicalStock: 12,
      reason: '2 sak pecah saat bongkar muat gudang',
      checkedBy: 'Budi Santoso',
      checkedAt: DateTime(2026, 11, 26, 8, 30),
    ),
  ];

  /// Returns all tracked products from the shared store catalog.
  List<ProductItem> getInventoryProducts() => _cashierRepository.getProducts();

  /// Returns all delivery orders ordered with active shipments first.
  List<DeliveryOrder> getDeliveries() => List.unmodifiable(_deliveries);

  /// Returns stock opname audit entries ordered newest-first.
  List<StockOpnameRecord> getOpnameHistory() =>
      List.unmodifiable(_opnameHistory.reversed);

  /// Fetches live inventory SKUs from `/api/v1/stok`.
  Future<List<ProductItem>> fetchInventoryProducts() =>
      _cashierRepository.fetchProducts();

  /// Fetches live pending/in-transit delivery orders from `GET /kasir/tugas-antar`.
  Future<List<DeliveryOrder>> fetchDeliveryTasks() async {
    if (!enableRemoteSync || _apiClient == null) {
      return getDeliveries();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.deliveryTasks,
      queryParameters: {'per_page': 50},
    );
    final rawList = ApiClient.unwrapList(response.data);
    final fetched = rawList
        .map(DeliveryOrder.fromBackendJson)
        .toList(growable: false);

    _deliveries
      ..clear()
      ..addAll(fetched);
    return fetched;
  }

  /// Fetches historical stock opname sessions from `GET /gudang/opname`.
  Future<List<StockOpnameRecord>> fetchOpnameHistory() async {
    if (!enableRemoteSync || _apiClient == null) {
      return getOpnameHistory();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.opname,
      queryParameters: {'per_page': 20},
    );
    final sessions = ApiClient.unwrapList(response.data);
    final records = <StockOpnameRecord>[];

    for (final session in sessions) {
      final opnameId = (session['id_opname'] as num?)?.toInt();
      final docNo = (session['nomor_opname'] ?? 'OPN-$opnameId').toString();
      final pembuat = session['pembuat'] as Map<String, dynamic>?;
      final checkedBy = (pembuat?['name'] ?? 'Staff Gudang').toString();
      final checkedAt =
          DateTime.tryParse(session['created_at'] as String? ?? '') ??
          DateTime.tryParse(session['tanggal_opname'] as String? ?? '') ??
          DateTime.now();
      final statusLabel =
          session['status_label'] as String? ?? session['status'] as String?;

      final rawItems = session['item'] as List?;
      if (rawItems != null && rawItems.isNotEmpty) {
        for (final rawItem in rawItems.whereType<Map<String, dynamic>>()) {
          final produk = rawItem['produk'] as Map<String, dynamic>?;
          records.add(
            StockOpnameRecord(
              id: '${opnameId ?? docNo}-${rawItem['id_item']}',
              opnameId: opnameId,
              documentNumber: docNo,
              statusLabel: statusLabel,
              productId: (rawItem['id_produk'] ?? '').toString(),
              productName:
                  (produk?['nama_produk'] ?? 'Produk #${rawItem['id_produk']}')
                      .toString(),
              sku: (produk?['kode_sku'] ?? '-').toString(),
              unitLabel: (produk?['satuan'] ?? 'unit').toString(),
              systemStock:
                  (rawItem['kuantitas_sistem'] as num?)?.toDouble() ?? 0,
              physicalStock:
                  (rawItem['kuantitas_fisik'] as num?)?.toDouble() ??
                  (rawItem['kuantitas_sistem'] as num?)?.toDouble() ??
                  0,
              reason: (session['catatan'] as String?) ?? docNo,
              checkedBy: checkedBy,
              checkedAt: checkedAt,
            ),
          );
        }
      } else {
        records.add(
          StockOpnameRecord(
            id: docNo,
            opnameId: opnameId,
            documentNumber: docNo,
            statusLabel: statusLabel,
            productId: '-',
            productName: '$docNo (${session['item_count'] ?? 0} item)',
            sku: docNo,
            unitLabel: 'item',
            systemStock: 0,
            physicalStock: 0,
            reason:
                (session['catatan'] as String?) ??
                (statusLabel ?? 'Sesi opname'),
            checkedBy: checkedBy,
            checkedAt: checkedAt,
          ),
        );
      }
    }

    _opnameHistory
      ..clear()
      ..addAll(records.reversed);
    return getOpnameHistory();
  }

  /// Creates a new pending [DeliveryOrder] directly from a POS delivery checkout.
  DeliveryOrder createDeliveryFromReceipt(TransactionReceipt receipt) {
    final nextSeq = (_deliveries.length + 1).toString().padLeft(2, '0');
    final now = DateTime.now();
    final dateCode =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suratJalan = receipt.deliveryOrderId ?? 'SJ-$dateCode-$nextSeq';
    final order = DeliveryOrder(
      id:
          receipt.transactionId?.toString() ??
          'DEL-${(_deliveries.length + 1).toString().padLeft(3, '0')}',
      transactionId: receipt.transactionId,
      suratJalanNumber: suratJalan,
      invoiceNumber: receipt.invoiceNumber,
      customerName: receipt.customerName,
      customerPhone: receipt.customerPhone ?? '-',
      destinationAddress: receipt.deliveryAddress ?? 'Alamat menyusul',
      driverName: 'Dedi Kurniawan',
      vehiclePlate: 'B 9421 DM',
      shippingCost: receipt.deliveryFee,
      status: DeliveryStatus.pending,
      scheduledAt: now,
      items: receipt.items
          .map(
            (item) => DeliveryLineItem(
              detailId: item.detailId,
              productId: item.product.numericId,
              statusBarang: item.itemStatus ?? 'MENUNGGU_DIANTAR',
              productName: item.product.name,
              quantityLabel: item.unitOption.formatQuantity(item.quantity),
            ),
          )
          .toList(growable: false),
      notes: 'Dibuat otomatis dari POS Kasir (${receipt.paymentMethod.label}).',
    );
    _deliveries.insert(0, order);
    return order;
  }

  /// Assigns driver/fleet metadata locally and persists shipping cost to
  /// `PATCH /kasir/pesanan/{id}/biaya-angkut` when connected to backend.
  Future<DeliveryOrder> assignFleet({
    required String orderId,
    required String driverName,
    required String vehiclePlate,
    DeliveryStatus? nextStatus,
    double? shippingCost,
  }) async {
    final index = _deliveries.indexWhere((order) => order.id == orderId);
    if (index == -1) {
      throw StateError('Surat jalan tidak ditemukan.');
    }
    final current = _deliveries[index];

    if (enableRemoteSync &&
        _apiClient != null &&
        current.transactionId != null) {
      await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.updateShippingCost(current.transactionId!),
        data: {'biaya_angkut': (shippingCost ?? current.shippingCost).round()},
      );

      if (nextStatus == DeliveryStatus.delivered) {
        await _markAllDeliverableItemsRemote(
          current,
          statusBarang: 'SUDAH_DIANTAR',
          catatan: 'Armada $driverName ($vehiclePlate) selesai mengantar.',
        );
      }
    }

    final updatedStatus = nextStatus ?? current.status;
    final updated = current.copyWith(
      driverName: driverName,
      vehiclePlate: vehiclePlate,
      shippingCost: shippingCost ?? current.shippingCost,
      status: updatedStatus,
      dispatchedAt:
          updatedStatus == DeliveryStatus.inTransit &&
              current.dispatchedAt == null
          ? DateTime.now()
          : null,
    );
    _deliveries[index] = updated;
    return updated;
  }

  /// Transitions [orderId] delivery status (`Pending` -> `In Transit` -> `Delivered`).
  Future<DeliveryOrder> updateStatus({
    required String orderId,
    required DeliveryStatus status,
    String? notes,
  }) async {
    final index = _deliveries.indexWhere((order) => order.id == orderId);
    if (index == -1) {
      throw StateError('Surat jalan tidak ditemukan.');
    }
    final current = _deliveries[index];

    if (enableRemoteSync &&
        _apiClient != null &&
        current.transactionId != null &&
        status == DeliveryStatus.delivered) {
      await _markAllDeliverableItemsRemote(
        current,
        statusBarang: 'SUDAH_DIANTAR',
        catatan: notes,
      );
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      status: status,
      dispatchedAt:
          status == DeliveryStatus.inTransit && current.dispatchedAt == null
          ? now
          : null,
      deliveredAt:
          status == DeliveryStatus.delivered && current.deliveredAt == null
          ? now
          : null,
    );
    _deliveries[index] = updated;
    return updated;
  }

  /// Uploads multipart Proof-of-Delivery photo & signature (`FormData`) and marks
  /// the order [DeliveryStatus.delivered] on both server and local state.
  Future<DeliveryOrder> submitProofOfDelivery({
    required String orderId,
    required String receiverName,
    required Uint8List proofPhotoBytes,
    required String proofPhotoName,
    required Uint8List signatureBytes,
    String? notes,
  }) async {
    final index = _deliveries.indexWhere((order) => order.id == orderId);
    if (index == -1) {
      throw StateError('Surat jalan tidak ditemukan.');
    }
    final current = _deliveries[index];
    final cleanReceiver = receiverName.trim();
    final cleanNotes = notes?.trim();

    if (enableRemoteSync &&
        _apiClient != null &&
        current.transactionId != null) {
      final formData = FormData.fromMap({
        'receiver_name': cleanReceiver,
        'status_barang': 'SUDAH_DIANTAR',
        if (cleanNotes != null && cleanNotes.isNotEmpty) 'catatan': cleanNotes,
        'proof_photo': MultipartFile.fromBytes(
          proofPhotoBytes,
          filename: proofPhotoName,
        ),
        'signature_image': MultipartFile.fromBytes(
          signatureBytes,
          filename: 'signature_${current.transactionId}.png',
        ),
      });

      try {
        await _apiClient.postMultipart<Map<String, dynamic>>(
          ApiEndpoints.submitDeliveryPod(current.transactionId!),
          formData: formData,
        );
      } on ApiException catch (error) {
        // Fallback for backends without custom `/pod`: confirm delivery per item via
        // `PATCH /kasir/pesanan/{id}/barang/{detailId}` while preserving real 4xx/5xx failures.
        if (error.statusCode != 404) {
          rethrow;
        }
        final combinedNote = [
          'Diterima oleh $cleanReceiver',
          if (cleanNotes != null && cleanNotes.isNotEmpty) cleanNotes,
        ].join(' — ');
        await _markAllDeliverableItemsRemote(
          current,
          statusBarang: 'SUDAH_DIANTAR',
          catatan: combinedNote,
        );
      }
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      status: DeliveryStatus.delivered,
      dispatchedAt: current.dispatchedAt ?? now,
      deliveredAt: now,
      receiverName: cleanReceiver,
      proofPhotoBytes: proofPhotoBytes,
      proofPhotoName: proofPhotoName,
      signatureBytes: signatureBytes,
      notes: cleanNotes != null && cleanNotes.isNotEmpty ? cleanNotes : null,
    );
    _deliveries[index] = updated;
    return updated;
  }

  Future<void> _markAllDeliverableItemsRemote(
    DeliveryOrder order, {
    required String statusBarang,
    String? catatan,
  }) async {
    final txId = order.transactionId;
    if (_apiClient == null || txId == null) return;

    final deliverableItems = order.items
        .where((item) => item.detailId != null && item.isDeliverable)
        .toList(growable: false);

    for (final item in deliverableItems) {
      await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.updateOrderItemStatus(txId, item.detailId!),
        data: {
          'status_barang': statusBarang,
          if (catatan != null && catatan.trim().isNotEmpty)
            'catatan': catatan.trim(),
        },
      );
    }
  }

  /// Creates an opname session and submits physical count (`POST /gudang/opname` +
  /// `PATCH /gudang/opname/{id}/item/{itemId}`), updating local catalog snapshot.
  Future<StockOpnameRecord> recordStockOpname({
    required ProductItem product,
    required double physicalStock,
    required String reason,
    required String checkedBy,
  }) async {
    int? opnameId;
    String? documentNumber;
    String? statusLabel;

    if (enableRemoteSync && _apiClient != null && product.numericId != null) {
      final createRes = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.opname,
        data: {
          'id_produk': [product.numericId],
          if (reason.trim().isNotEmpty) 'catatan': reason.trim(),
        },
      );
      final createdMap = ApiClient.unwrapData(createRes.data);
      if (createdMap is Map<String, dynamic>) {
        opnameId = (createdMap['id_opname'] as num?)?.toInt();
        documentNumber = createdMap['nomor_opname'] as String?;
        statusLabel = createdMap['status_label'] as String? ?? 'Dihitung';
        final rawItems = createdMap['item'] as List?;
        final firstItem = rawItems
            ?.whereType<Map<String, dynamic>>()
            .firstOrNull;
        final itemId = (firstItem?['id_item'] as num?)?.toInt();

        if (opnameId != null && itemId != null) {
          await _apiClient.patch<Map<String, dynamic>>(
            ApiEndpoints.opnameCountItem(opnameId, itemId),
            data: {'kuantitas_fisik': physicalStock.round()},
          );
        }
      }
    }

    final record = StockOpnameRecord(
      id:
          documentNumber ??
          'OPN-${(_opnameHistory.length + 1).toString().padLeft(3, '0')}',
      opnameId: opnameId,
      documentNumber: documentNumber,
      statusLabel: statusLabel,
      productId: product.id,
      productName: product.name,
      sku: product.sku,
      unitLabel: product.rawUnitLabel ?? product.baseUnit.label,
      systemStock: product.stockQuantity,
      physicalStock: physicalStock,
      reason: reason.trim().isEmpty ? 'Penyesuaian stok rutin' : reason.trim(),
      checkedBy: checkedBy,
      checkedAt: DateTime.now(),
    );

    _opnameHistory.add(record);
    _cashierRepository.setProductStock(product.id, physicalStock);
    return record;
  }
}
