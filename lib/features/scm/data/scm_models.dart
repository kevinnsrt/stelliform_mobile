import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Lifecycle states for a Dobrak Mandiri material delivery order.
enum DeliveryStatus {
  pending,
  inTransit,
  delivered;

  /// Canonical status badge label.
  String get label => switch (this) {
    DeliveryStatus.pending => 'Pending',
    DeliveryStatus.inTransit => 'In Transit',
    DeliveryStatus.delivered => 'Delivered',
  };

  /// Indonesian operational description for warehouse and driver teams.
  String get indonesianLabel => switch (this) {
    DeliveryStatus.pending => 'Menunggu Muat',
    DeliveryStatus.inTransit => 'Dalam Pengiriman',
    DeliveryStatus.delivered => 'Terkirim (POD Selesai)',
  };

  /// Backend `status_barang` value matching this lifecycle stage.
  String get backendStatus => switch (this) {
    DeliveryStatus.pending => 'MENUNGGU_DIANTAR',
    DeliveryStatus.inTransit => 'MENUNGGU_DIANTAR',
    DeliveryStatus.delivered => 'SUDAH_DIANTAR',
  };

  /// Semantic status color.
  Color get color => switch (this) {
    DeliveryStatus.pending => AppColors.info,
    DeliveryStatus.inTransit => AppColors.warning,
    DeliveryStatus.delivered => AppColors.success,
  };

  /// Soft translucent background color compatible with both Light & Dark themes.
  Color get softColor => color.withValues(alpha: 0.12);

  /// Icon paired with this delivery status.
  IconData get icon => switch (this) {
    DeliveryStatus.pending => Icons.inventory_rounded,
    DeliveryStatus.inTransit => Icons.local_shipping_rounded,
    DeliveryStatus.delivered => Icons.verified_rounded,
  };
}

/// Compact material line item printed on a Surat Jalan delivery order.
class DeliveryLineItem {
  /// Creates a [DeliveryLineItem].
  const DeliveryLineItem({
    required this.productName,
    required this.quantityLabel,
    this.detailId,
    this.productId,
    this.statusBarang,
  });

  /// Backend `id_detail` primary key when loaded from API.
  final int? detailId;

  /// Backend `id_produk` identifier when loaded from API.
  final int? productId;

  /// Raw backend item status (`MENUNGGU_DIANTAR`, `GAGAL_DIANTAR`, `SUDAH_DIANTAR`).
  final String? statusBarang;

  /// Material display name.
  final String productName;

  /// Formatted quantity with unit, e.g. `20 Sak` or `2.5 Kubik`.
  final String quantityLabel;

  /// Whether this line item can transition to `SUDAH_DIANTAR`.
  bool get isDeliverable =>
      statusBarang == null ||
      statusBarang == 'MENUNGGU_DIANTAR' ||
      statusBarang == 'GAGAL_DIANTAR';

  /// Parses a [DeliveryLineItem] from Laravel `DetailTransaksiResource` JSON.
  factory DeliveryLineItem.fromBackendJson(Map<String, dynamic> json) {
    final produk = json['produk'] as Map<String, dynamic>?;
    final qty = (json['jumlah'] as num?)?.toInt() ?? 1;
    final unit = (produk?['satuan'] as String? ?? 'unit').trim();
    return DeliveryLineItem(
      detailId: (json['id_detail'] as num?)?.toInt(),
      productId: (json['id_produk'] as num?)?.toInt(),
      statusBarang: json['status_barang'] as String?,
      productName: (json['nama_produk'] ?? produk?['nama_produk'] ?? 'Material')
          .toString(),
      quantityLabel: '$qty $unit',
    );
  }
}

/// Warehouse dispatch and driver proof-of-delivery record mapped from `TransaksiResource`.
class DeliveryOrder {
  /// Creates a [DeliveryOrder].
  const DeliveryOrder({
    required this.id,
    required this.suratJalanNumber,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.destinationAddress,
    required this.driverName,
    required this.vehiclePlate,
    required this.status,
    required this.scheduledAt,
    required this.items,
    this.transactionId,
    this.shippingCost = 0,
    this.dispatchedAt,
    this.deliveredAt,
    this.notes,
    this.receiverName,
    this.proofPhotoBytes,
    this.proofPhotoName,
    this.signatureBytes,
  });

  /// Internal delivery order ID.
  final String id;

  /// Backend database `id_transaksi`, if synced from REST API.
  final int? transactionId;

  /// Official Surat Jalan number.
  final String suratJalanNumber;

  /// Associated POS invoice number.
  final String invoiceNumber;

  /// Recipient / contractor name.
  final String customerName;

  /// Recipient phone number.
  final String customerPhone;

  /// Full delivery address.
  final String destinationAddress;

  /// Assigned courier/driver name.
  final String driverName;

  /// Assigned fleet license plate.
  final String vehiclePlate;

  /// Store-borne shipping cost (`biaya_angkut`) in IDR.
  final double shippingCost;

  /// Current delivery lifecycle state.
  final DeliveryStatus status;

  /// Scheduled dispatch timestamp.
  final DateTime scheduledAt;

  /// Manifest of building materials to deliver.
  final List<DeliveryLineItem> items;

  /// Timestamp when driver departed from warehouse.
  final DateTime? dispatchedAt;

  /// Timestamp when customer signed POD.
  final DateTime? deliveredAt;

  /// Special unloading or access instructions.
  final String? notes;

  /// Name of the person who signed off at destination.
  final String? receiverName;

  /// Captured photo proof bytes (camera or gallery).
  final Uint8List? proofPhotoBytes;

  /// Captured photo filename.
  final String? proofPhotoName;

  /// Exported PNG bytes of customer signature pad.
  final Uint8List? signatureBytes;

  /// Whether both photo proof and digital signature are captured.
  bool get hasCompletePod =>
      proofPhotoBytes != null &&
      signatureBytes != null &&
      (receiverName?.trim().isNotEmpty ?? false);

  /// Hydrates a [DeliveryOrder] from Laravel `GET /kasir/tugas-antar` item JSON.
  factory DeliveryOrder.fromBackendJson(Map<String, dynamic> json) {
    final txId = (json['id_transaksi'] as num?)?.toInt();
    final pelanggan = json['pelanggan'] as Map<String, dynamic>?;
    final rawDetails = json['detail'] as List? ?? const [];
    final items = rawDetails
        .whereType<Map<String, dynamic>>()
        .map(DeliveryLineItem.fromBackendJson)
        .toList(growable: false);

    final statusPesanan = (json['status_pesanan'] as String? ?? '')
        .toUpperCase();
    final biayaAngkut = (json['biaya_angkut'] as num?)?.toDouble() ?? 0;

    final hasPendingOrFailed = items.any(
      (item) =>
          item.statusBarang == 'MENUNGGU_DIANTAR' ||
          item.statusBarang == 'GAGAL_DIANTAR',
    );
    final status = (statusPesanan == 'SELESAI' || !hasPendingOrFailed)
        ? DeliveryStatus.delivered
        : (biayaAngkut > 0 ? DeliveryStatus.inTransit : DeliveryStatus.pending);

    return DeliveryOrder(
      id: txId != null
          ? txId.toString()
          : (json['nomor_struk'] ?? '').toString(),
      transactionId: txId,
      suratJalanNumber: 'SJ-${txId ?? json['nomor_struk']}',
      invoiceNumber: (json['nomor_struk'] ?? '').toString(),
      customerName:
          (pelanggan?['nama_pelanggan'] as String?) ?? 'Pelanggan Pengantaran',
      customerPhone: (pelanggan?['telepon'] as String?) ?? '-',
      destinationAddress:
          (pelanggan?['alamat'] as String?) ?? 'Alamat belum dilengkapi',
      driverName: 'Armada Gudang',
      vehiclePlate: 'TB Dobrak Mandiri',
      shippingCost: biayaAngkut,
      status: status,
      scheduledAt:
          DateTime.tryParse(json['tanggal_transaksi'] as String? ?? '') ??
          DateTime.now(),
      items: items,
      notes: json['catatan'] as String?,
    );
  }

  /// Returns a copy with selectively updated delivery fields.
  DeliveryOrder copyWith({
    String? driverName,
    String? vehiclePlate,
    double? shippingCost,
    DeliveryStatus? status,
    DateTime? dispatchedAt,
    DateTime? deliveredAt,
    String? notes,
    String? receiverName,
    Uint8List? proofPhotoBytes,
    String? proofPhotoName,
    Uint8List? signatureBytes,
    bool clearProofPhoto = false,
    bool clearSignature = false,
  }) {
    return DeliveryOrder(
      id: id,
      transactionId: transactionId,
      suratJalanNumber: suratJalanNumber,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      destinationAddress: destinationAddress,
      driverName: driverName ?? this.driverName,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      shippingCost: shippingCost ?? this.shippingCost,
      status: status ?? this.status,
      scheduledAt: scheduledAt,
      items: items,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
      receiverName: receiverName ?? this.receiverName,
      proofPhotoBytes: clearProofPhoto
          ? null
          : (proofPhotoBytes ?? this.proofPhotoBytes),
      proofPhotoName: clearProofPhoto
          ? null
          : (proofPhotoName ?? this.proofPhotoName),
      signatureBytes: clearSignature
          ? null
          : (signatureBytes ?? this.signatureBytes),
    );
  }
}

/// Audit log entry generated during warehouse Stock Opname verification.
class StockOpnameRecord {
  /// Creates a [StockOpnameRecord].
  const StockOpnameRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitLabel,
    required this.systemStock,
    required this.physicalStock,
    required this.reason,
    required this.checkedBy,
    required this.checkedAt,
    this.opnameId,
    this.documentNumber,
    this.statusLabel,
  });

  /// Unique audit record ID.
  final String id;

  /// Backend `id_opname` primary key when synced from server.
  final int? opnameId;

  /// Backend `nomor_opname` document code.
  final String? documentNumber;

  /// Opname workflow status (`DRAFT`, `DIHITUNG`, `DISETUJUI`, `DIBATALKAN`).
  final String? statusLabel;

  /// Referenced product ID.
  final String productId;

  /// Product display name.
  final String productName;

  /// Product SKU code.
  final String sku;

  /// Base unit label.
  final String unitLabel;

  /// Stock quantity recorded in system prior to opname.
  final double systemStock;

  /// Counted physical warehouse stock.
  final double physicalStock;

  /// Variance explanation (damage, shrinkage, unrecorded return, etc.).
  final String reason;

  /// Staff Gudang or Owner who submitted the adjustment.
  final String checkedBy;

  /// Timestamp of stock opname submission.
  final DateTime checkedAt;

  /// Stock difference (`physicalStock - systemStock`).
  double get discrepancy => physicalStock - systemStock;
}
