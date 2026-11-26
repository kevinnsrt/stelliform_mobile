/// Centralized REST API v1 endpoints matching the `andcrst/backend-ERP` Laravel specification.
abstract final class ApiEndpoints {
  /// Base URL pointing to the local Laravel ERP backend (`http://192.168.1.43:8080/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.43:8080/api/v1',
  );

  // 1. Authentication & Utilities
  static const String health = '/health';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String changePassword = '/auth/password';

  // 2. Master Produk & Kategori
  static const String products = '/stok';
  static const String productScan = '/stok/scan';
  static String productById(int productId) => '/stok/$productId';
  static const String categories = '/kategori';
  static String categoryById(int categoryId) => '/kategori/$categoryId';

  // 3. Kasir — Pelanggan & Pesanan
  static const String customers = '/kasir/pelanggan';
  static String customerById(int customerId) => '/kasir/pelanggan/$customerId';
  static String customerHistory(int customerId) =>
      '/kasir/pelanggan/$customerId/riwayat';

  static const String orders = '/kasir/pesanan';
  static String orderById(int orderId) => '/kasir/pesanan/$orderId';
  static String orderReceipt(int orderId) => '/kasir/pesanan/$orderId/struk';
  static const String deliveryTasks = '/kasir/tugas-antar';
  static String updateOrderItemStatus(int orderId, int detailId) =>
      '/kasir/pesanan/$orderId/barang/$detailId';
  static String updateShippingCost(int orderId) =>
      '/kasir/pesanan/$orderId/biaya-angkut';
  static String submitDeliveryPod(int orderId) => '/kasir/pesanan/$orderId/pod';

  // 5-8. Gudang — Supplier, Pengeluaran, Opname, Kartu Stok
  static const String suppliers = '/gudang/supplier';
  static String supplierById(int supplierId) => '/gudang/supplier/$supplierId';

  static const String stockOutReasons = '/gudang/pengeluaran/opsi-alasan';
  static const String stockOut = '/gudang/pengeluaran';
  static String stockOutById(int stockOutId) =>
      '/gudang/pengeluaran/$stockOutId';
  static String postStockOut(int stockOutId) =>
      '/gudang/pengeluaran/$stockOutId/posting';

  static const String opnameStatuses = '/gudang/opname/opsi-status';
  static const String opname = '/gudang/opname';
  static String opnameById(int opnameId) => '/gudang/opname/$opnameId';
  static String opnameCountItem(int opnameId, int itemId) =>
      '/gudang/opname/$opnameId/item/$itemId';
  static String opnameApprove(int opnameId) =>
      '/gudang/opname/$opnameId/setujui';
  static String opnameCancel(int opnameId) =>
      '/gudang/opname/$opnameId/batalkan';

  static const String lowStock = '/gudang/stok-menipis';
  static const String inventorySummary = '/gudang/ringkasan-persediaan';
  static const String mutationTypes = '/gudang/jenis-mutasi';
  static String stockCard(int productId) => '/gudang/kartu-stok/$productId';

  // 9. Pengadaan
  static const String procurement = '/gudang/pengadaan';
  static String procurementById(int id) => '/gudang/pengadaan/$id';
  static String procurementRemaining(int id) => '/gudang/pengadaan/$id/sisa';
  static String procurementReceive(int id) =>
      '/gudang/pengadaan/$id/penerimaan';
  static const String financeProcurement = '/finance/pengadaan';
  static String financeProcurementDecide(int id) =>
      '/finance/pengadaan/$id/putuskan';
  static String financeProcurementClose(int id) =>
      '/finance/pengadaan/$id/tutup';

  // 10. Finance (Read-Only Analytics & Recaps)
  static const String financeDashboard = '/finance/dashboard';
  static const String financePaymentOptions =
      '/finance/dashboard/opsi-pembayaran';
  static const String financeRecapTypes = '/finance/jenis-rekap';
  static const String financeDailySales = '/finance/rekap/penjualan/harian';
  static const String financeMonthlySales = '/finance/rekap/penjualan/bulanan';
  static const String financeRevenue = '/finance/rekap/pendapatan';
  static const String financePayments = '/finance/rekap/pembayaran';
  static const String financeCashiers = '/finance/rekap/kasir';
  static const String financeTopProducts = '/finance/rekap/produk';
  static const String financeGrossProfit = '/finance/rekap/laba-kotor';
  static const String financeTransactions = '/finance/rekap/transaksi';
  static const String financeInventoryValue = '/finance/rekap/stok';
  static String financeExportCsv(String type) => '/finance/rekap/$type/ekspor';

  // 11. Sistem (Owner Administration)
  static const String userRoles = '/sistem/user/opsi-role';
  static const String users = '/sistem/user';
  static String userById(int userId) => '/sistem/user/$userId';
  static String updateUserRole(int userId) => '/sistem/user/$userId/role';
  static String updateUserStatus(int userId) => '/sistem/user/$userId/status';
  static String resetUserPassword(int userId) =>
      '/sistem/user/$userId/reset-password';
  static const String roles = '/sistem/role';
  static const String permissions = '/sistem/permission';
  static String updateRolePermissions(String role) =>
      '/sistem/role/$role/permission';
  static const String auditLogs = '/sistem/audit-log';
  static const String storeSettings = '/sistem/pengaturan';
}
