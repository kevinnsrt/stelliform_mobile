import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/utils/date_formatter.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/scm/controllers/scm_controller.dart';
import 'package:stelliform_mobile/features/scm/data/scm_models.dart';

/// Minimalist warehouse fleet scheduling and Surat Jalan dispatch screen.
class DeliveryDispatchScreen extends StatefulWidget {
  /// Creates a [DeliveryDispatchScreen].
  const DeliveryDispatchScreen({super.key});

  @override
  State<DeliveryDispatchScreen> createState() => _DeliveryDispatchScreenState();
}

class _DeliveryDispatchScreenState extends State<DeliveryDispatchScreen> {
  DeliveryStatus? _statusFilter;

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

  Future<void> _showAssignSheet(DeliveryOrder order) async {
    var driver = order.driverName;
    var plate = order.vehiclePlate;
    var nextStatus = order.status == DeliveryStatus.pending
        ? DeliveryStatus.inTransit
        : order.status;

    const drivers = [
      ('Dedi Kurniawan', 'B 9421 DM'),
      ('Rizal Fauzi', 'B 9104 DM'),
      ('Agus Saputra', 'B 9772 DM'),
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Dispatch ${order.suratJalanNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Kurir & Armada',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: driver,
                onChanged: (value) {
                  if (value == null) return;
                  final match = drivers.firstWhere((e) => e.$1 == value);
                  setModalState(() {
                    driver = match.$1;
                    plate = match.$2;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: drivers
                      .map(
                        (entry) => RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: entry.$1,
                          title: Text(entry.$1),
                          subtitle: Text('Armada ${entry.$2}'),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: nextStatus == DeliveryStatus.inTransit,
                title: const Text('Langsung ubah status ke In Transit'),
                onChanged: (checked) {
                  setModalState(() {
                    nextStatus = (checked ?? false)
                        ? DeliveryStatus.inTransit
                        : order.status;
                  });
                },
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
              child: const Text('Simpan Penugasan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final scm = context.read<ScmController>();
    final ok = await scm.assignFleet(
      orderId: order.id,
      driverName: driver,
      vehiclePlate: plate,
      nextStatus: nextStatus,
    );
    if (!mounted) return;
    if (!ok) {
      ApiErrorFeedback.showSnackBar(
        context,
        scm.lastException ?? scm.errorMessage,
        fallbackMessage: 'Gagal memperbarui penugasan armada.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scm = context.watch<ScmController>();
    final palette = AppColors.of(context);
    final orders = scm.deliveries
        .where((order) {
          return _statusFilter == null || order.status == _statusFilter;
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal & Dispatch Armada'),
        actions: [
          const ThemeToggleButton(),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.stockOpname),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Opname'),
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(
        currentPath: AppRoutes.deliveryDispatch,
      ),
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
              onRetry: () => scm.loadWarehouseData(
                includeInventory: false,
                includeOpname: false,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('Semua (${scm.deliveries.length})'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                ...DeliveryStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status.label),
                      selected: _statusFilter == status,
                      onSelected: (_) => setState(() {
                        _statusFilter = _statusFilter == status ? null : status;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...orders.map(
            (order) => Container(
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.suratJalanNumber,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              '${order.invoiceNumber} • ${DateFormatter.formatDateTime(order.scheduledAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order.status.softColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: order.status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.customerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    order.destinationAddress,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: order.items
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceMuted,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              '${item.productName} (${item.quantityLabel})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.person_pin_circle_outlined,
                        size: 16,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Kurir: ${order.driverName} (${order.vehiclePlate})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (order.status != DeliveryStatus.delivered)
                        CustomButton(
                          label: 'Atur Armada',
                          isFullWidth: false,
                          variant: CustomButtonVariant.outline,
                          onPressed: () => _showAssignSheet(order),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
