import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/date_formatter.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/custom_textfield.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/scm/controllers/scm_controller.dart';
import 'package:stelliform_mobile/features/scm/data/scm_models.dart';

/// Minimalist Driver Proof-of-Delivery (POD) screen supporting status toggle
/// (`Pending` -> `In Transit` -> `Delivered`), photo capture, and signature pad.
class DriverPodScreen extends StatefulWidget {
  /// Creates a [DriverPodScreen].
  const DriverPodScreen({super.key});

  @override
  State<DriverPodScreen> createState() => _DriverPodScreenState();
}

class _DriverPodScreenState extends State<DriverPodScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<List<Offset>> _signatureStrokes = [];
  List<Offset> _activeStroke = [];
  Size _canvasSize = const Size(320, 170);

  Uint8List? _proofPhotoBytes;
  String? _proofPhotoName;
  String? _loadedOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        context.read<ScmController>().loadWarehouseData(
          includeInventory: false,
          includeOpname: false,
        );
      }
    });
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncOrderDraft(DeliveryOrder? order) {
    if (order == null || _loadedOrderId == order.id) return;
    _loadedOrderId = order.id;
    _receiverNameController.text = order.receiverName ?? '';
    _notesController.text = order.notes ?? '';
    _proofPhotoBytes = order.proofPhotoBytes;
    _proofPhotoName = order.proofPhotoName;
    _signatureStrokes.clear();
    _activeStroke = [];
  }

  Future<void> _pickProofPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _proofPhotoBytes = bytes;
        _proofPhotoName = picked.name;
      });
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera/Galeri tidak tersedia pada platform ini.'),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Gagal mengakses kamera/galeri.'),
        ),
      );
    }
  }

  Future<Uint8List?> _exportSignaturePng() async {
    if (_signatureStrokes.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = _canvasSize.width > 0 ? _canvasSize.width : 320.0;
    final height = _canvasSize.height > 0 ? _canvasSize.height : 170.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final strokePaint = Paint()
      ..color = AppColors.lightTextPrimary
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _signatureStrokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.6, strokePaint);
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _handleStatusToggle(
    DeliveryOrder order,
    DeliveryStatus nextStatus,
  ) async {
    final scm = context.read<ScmController>();
    if (nextStatus == DeliveryStatus.delivered && !order.hasCompletePod) {
      final hasLocalPod =
          _proofPhotoBytes != null &&
          _signatureStrokes.isNotEmpty &&
          _receiverNameController.text.trim().isNotEmpty;
      if (hasLocalPod) {
        await _submitPod(order);
        return;
      }
    }

    final updated = await scm.updateDeliveryStatus(
      orderId: order.id,
      status: nextStatus,
    );
    if (!mounted) return;
    if (!updated) {
      ApiErrorFeedback.showSnackBar(
        context,
        scm.lastException ?? scm.errorMessage,
        fallbackMessage: 'Gagal memperbarui status pengiriman.',
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status ${order.suratJalanNumber} diperbarui ke ${nextStatus.label}.',
        ),
      ),
    );
  }

  Future<void> _submitPod(DeliveryOrder order) async {
    final scm = context.read<ScmController>();
    final signaturePng = order.signatureBytes ?? await _exportSignaturePng();

    final success = await scm.submitProofOfDelivery(
      orderId: order.id,
      receiverName: _receiverNameController.text,
      proofPhotoBytes: _proofPhotoBytes,
      proofPhotoName: _proofPhotoName,
      signatureBytes: signaturePng,
      notes: _notesController.text,
    );

    if (!mounted) return;
    if (!success) {
      final ex = scm.lastException;
      if (ex != null &&
          (ex.isTimeout || ex.isServerError || ex.isUnauthorized)) {
        await ApiErrorFeedback.showErrorDialog(
          context,
          error: ex,
          onRetry: ex.isUnauthorized ? null : () => _submitPod(order),
        );
      } else {
        ApiErrorFeedback.showSnackBar(
          context,
          ex ?? scm.errorMessage,
          fallbackMessage: 'Lengkapi foto bukti & tanda tangan pelanggan.',
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.of(context).success,
        content: Text(
          'POD ${order.suratJalanNumber} berhasil disimpan! Status: Delivered.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scm = context.watch<ScmController>();
    final palette = AppColors.of(context);
    final deliveries = scm.deliveries;
    final activeOrder = scm.selectedDelivery;
    _syncOrderDraft(activeOrder);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurir & Bukti Pengiriman (POD)'),
        actions: const [ThemeToggleButton()],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.driverPod),
      body: activeOrder == null
          ? Center(
              child: Text(
                'Belum ada jadwal pengiriman untuk armada.',
                style: TextStyle(color: palette.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (scm.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(color: palette.primary),
                  ),
                if (scm.errorMessage != null && !scm.isSubmitting) ...[
                  ApiErrorBanner(
                    message: scm.errorMessage!,
                    onRetry: () => scm.loadWarehouseData(
                      includeInventory: false,
                      includeOpname: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // 1. Assigned Delivery Order Switcher
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: deliveries.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final order = deliveries[index];
                      final isSelected = order.id == activeOrder.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => scm.selectDelivery(order.id),
                        child: Container(
                          width: 264,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primarySoft
                                : palette.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? palette.primary
                                  : palette.border,
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.suratJalanNumber,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? palette.primary
                                            : palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: order.status.softColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      order.status.label,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: order.status.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                order.customerName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Delivery Order Detail & Manifest Section (flat, unnested)
                Container(
                  padding: const EdgeInsets.all(16),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeOrder.customerName,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${activeOrder.suratJalanNumber} • ${activeOrder.invoiceNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.primary,
                                    fontWeight: FontWeight.w600,
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
                              color: activeOrder.status.softColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  activeOrder.status.icon,
                                  size: 14,
                                  color: activeOrder.status.color,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  activeOrder.status.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: activeOrder.status.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${activeOrder.destinationAddress} (${activeOrder.customerPhone})',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        'Muatan Material',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: activeOrder.items
                            .map(
                              (item) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Text(
                                  '${item.productName} • ${item.quantityLabel}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Delivery Status Toggle (flat pills)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Pengiriman',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeOrder.status.indonesianLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: DeliveryStatus.values.map((status) {
                          final isCurrent = activeOrder.status == status;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: status == DeliveryStatus.delivered
                                    ? 0
                                    : 6,
                              ),
                              child: InkWell(
                                key: ValueKey('pod_status_${status.name}'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    _handleStatusToggle(activeOrder, status),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? status.softColor
                                        : palette.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? status.color
                                          : palette.border,
                                      width: isCurrent ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        status.icon,
                                        size: 18,
                                        color: isCurrent
                                            ? status.color
                                            : palette.textSecondary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        status.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? status.color
                                              : palette.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (activeOrder.dispatchedAt != null ||
                          activeOrder.deliveredAt != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          children: [
                            if (activeOrder.dispatchedAt != null)
                              Text(
                                'Berangkat: ${DateFormatter.formatTime(activeOrder.dispatchedAt!)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: palette.textSecondary,
                                ),
                              ),
                            if (activeOrder.deliveredAt != null)
                              Text(
                                'Tiba: ${DateFormatter.formatTime(activeOrder.deliveredAt!)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: palette.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Image Picker & Signature Section (unified flat section)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Foto Bukti Serah Terima Barang',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ambil foto material yang telah diturunkan di lokasi pelanggan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_proofPhotoBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Image.memory(
                                _proofPhotoBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: palette.danger,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _proofPhotoBytes = null;
                                      _proofPhotoName = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'File: ${_proofPhotoName ?? 'pod_photo.jpg'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              label: 'Ambil Foto (Kamera)',
                              icon: Icons.camera_alt_rounded,
                              variant: CustomButtonVariant.secondary,
                              onPressed: () =>
                                  _pickProofPhoto(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomButton(
                              label: 'Pilih Galeri',
                              icon: Icons.photo_library_outlined,
                              variant: CustomButtonVariant.outline,
                              onPressed: () =>
                                  _pickProofPhoto(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Tanda Tangan Digital Penerima',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _signatureStrokes.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _signatureStrokes.removeLast();
                                        });
                                      },
                                child: const Text('Undo'),
                              ),
                              TextButton(
                                onPressed: _signatureStrokes.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _signatureStrokes.clear();
                                          _activeStroke = [];
                                        });
                                      },
                                child: Text(
                                  'Bersihkan',
                                  style: TextStyle(color: palette.danger),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (activeOrder.signatureBytes != null &&
                          _signatureStrokes.isEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: palette.success),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.memory(
                              activeOrder.signatureBytes!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            _canvasSize = Size(constraints.maxWidth, 170);
                            return Container(
                              height: 170,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: palette.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _signatureStrokes.isNotEmpty
                                      ? palette.primary
                                      : palette.border,
                                  width: 1.2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: GestureDetector(
                                  key: const ValueKey('pod_signature_pad'),
                                  onPanStart: (details) {
                                    setState(() {
                                      _activeStroke = [details.localPosition];
                                      _signatureStrokes.add(_activeStroke);
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _activeStroke.add(details.localPosition);
                                    });
                                  },
                                  onPanEnd: (_) {
                                    _activeStroke = [];
                                  },
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(constraints.maxWidth, 170),
                                        painter: _SignaturePadPainter(
                                          strokes: _signatureStrokes,
                                          strokeColor: palette.textPrimary,
                                          guideColor: palette.border,
                                        ),
                                      ),
                                      if (_signatureStrokes.isEmpty)
                                        Center(
                                          child: IgnorePointer(
                                            child: Text(
                                              'Tanda tangan pelanggan di area ini',
                                              style: TextStyle(
                                                color: palette.textMuted,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _receiverNameController,
                        label: 'Nama Penerima Barang *',
                        hintText: 'Contoh: Pak Yanto (Mandor Proyek)',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        controller: _notesController,
                        label: 'Catatan Serah Terima',
                        hintText: 'Kondisi barang saat diterima...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        label: 'Simpan & Selesaikan Pengiriman (POD)',
                        icon: Icons.verified_rounded,
                        isLoading: scm.isSubmitting,
                        onPressed: () => _submitPod(activeOrder),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SignaturePadPainter extends CustomPainter {
  const _SignaturePadPainter({
    required this.strokes,
    required this.strokeColor,
    required this.guideColor,
  });

  final List<List<Offset>> strokes;
  final Color strokeColor;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(16, size.height - 28),
      Offset(size.width - 16, size.height - 28),
      guidePaint,
    );

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.5, strokePaint);
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePadPainter oldDelegate) => true;
}
