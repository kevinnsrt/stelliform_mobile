import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/core/network/feature_flags.dart';
import 'package:stelliform_mobile/core/widgets/app_footer.dart';
import 'package:stelliform_mobile/core/widgets/offline_banner.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';
import 'package:stelliform_mobile/features/auth/data/auth_repository.dart';
import 'package:stelliform_mobile/features/cashier/controllers/cashier_controller.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_repository.dart';
import 'package:stelliform_mobile/features/scm/data/scm_models.dart';
import 'package:stelliform_mobile/features/scm/data/scm_repository.dart';
import 'package:stelliform_mobile/main.dart';

typedef _MockResponder =
    ResponseBody Function(RequestOptions options, dynamic decodedBody);

class _MockDioAdapter implements HttpClientAdapter {
  _MockDioAdapter(this._responder);

  final _MockResponder _responder;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    dynamic body;
    if (options.data is String) {
      body = jsonDecode(options.data as String);
    } else {
      body = options.data;
    }
    return _responder(options, body);
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Future<void> _signInViaForm(WidgetTester tester, String email) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), 'password123');
  await tester.ensureVisible(find.text('Masuk ke ERP'));
  await tester.tap(find.text('Masuk ke ERP'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RBAC Guard Policy', () {
    test('enforces role-specific route permissions across roles', () {
      expect(
        RbacGuard.canAccess(UserRole.kasir, AppRoutes.posCheckout),
        isTrue,
      );
      expect(
        RbacGuard.canAccess(UserRole.kasir, AppRoutes.ownerDashboard),
        isFalse,
      );
      expect(
        RbacGuard.canAccess(UserRole.staffGudang, AppRoutes.stockOpname),
        isTrue,
      );
      expect(
        RbacGuard.canAccess(UserRole.staffGudang, AppRoutes.driverPod),
        isTrue,
      );
      expect(
        RbacGuard.canAccess(UserRole.staffGudang, AppRoutes.payroll),
        isFalse,
      );
      expect(RbacGuard.canAccess(UserRole.kurir, AppRoutes.driverPod), isTrue);
      expect(
        RbacGuard.canAccess(UserRole.kurir, AppRoutes.posCheckout),
        isFalse,
      );
      expect(
        RbacGuard.canAccess(UserRole.finance, AppRoutes.pnlReport),
        isTrue,
      );
      expect(
        RbacGuard.canAccess(UserRole.finance, AppRoutes.userManagement),
        isFalse,
      );
      expect(
        RbacGuard.canAccess(UserRole.owner, AppRoutes.ownerDashboard),
        isTrue,
      );
      expect(
        RbacGuard.canAccess(UserRole.owner, AppRoutes.userManagement),
        isTrue,
      );
      expect(
        RbacGuard.canAccess(UserRole.owner, AppRoutes.posCheckout),
        isTrue,
      );
    });
  });

  group('REST API v1 Client & Repositories', () {
    test('ApiEndpoints targets http://192.168.1.43:8080/api/v1', () {
      expect(ApiEndpoints.baseUrl, 'http://192.168.1.43:8080/api/v1');
      expect(ApiEndpoints.login, '/auth/login');
      expect(ApiEndpoints.products, '/stok');
      expect(ApiEndpoints.orders, '/kasir/pesanan');
      expect(ApiEndpoints.deliveryTasks, '/kasir/tugas-antar');
      expect(ApiEndpoints.financeDashboard, '/finance/dashboard');
    });

    test(
      'CashierController submits POST /kasir/pesanan and surfaces server stock error verbatim',
      () async {
        final adapter = _MockDioAdapter((options, body) {
          expect(options.headers['Authorization'], 'Bearer test-jwt');
          if (options.path == ApiEndpoints.products) {
            return _jsonResponse({
              'success': true,
              'data': [
                {
                  'id_produk': 1,
                  'kode_sku': 'SMN-001',
                  'nama_produk': 'Semen Tiga Roda',
                  'satuan': 'sak',
                  'harga': 68000,
                  'kuantitas': 1,
                  'stok_minimum': 5,
                },
              ],
            });
          }
          if (options.path == ApiEndpoints.orders) {
            return _jsonResponse({
              'success': false,
              'message': 'Stok Semen Tiga Roda habis (tersedia 0, diminta 2).',
              'error_code': 'STOK_TIDAK_CUKUP',
            }, statusCode: 422);
          }
          return _jsonResponse({'success': false}, statusCode: 404);
        });

        final client = ApiClient(
          readToken: () => 'test-jwt',
          httpClientAdapter: adapter,
        );
        final repo = CashierRepository(
          apiClient: client,
          enableRemoteSync: true,
        );
        final controller = CashierController(repository: repo);

        await controller.loadCatalog();
        expect(controller.filteredProducts, hasLength(1));

        final product = controller.filteredProducts.first;
        controller.addToCart(product, product.baseUnit, quantity: 2);
        controller.setPaymentMethod(PaymentMethod.qris);

        final receipt = await controller.submitCheckout(cashierName: 'Kasir');
        expect(receipt, isNull);
        expect(
          controller.errorMessage,
          'Stok Semen Tiga Roda habis (tersedia 0, diminta 2).',
        );
      },
    );

    test(
      'AuthRepository logs in, persists token to SharedPreferences, attaches Bearer, and restores session',
      () async {
        String? activeToken;
        final adapter = _MockDioAdapter((options, _) {
          if (options.path == ApiEndpoints.login) {
            return _jsonResponse({
              'success': true,
              'message': 'Login berhasil.',
              'data': {
                'token': '1|sanctum-test-token',
                'token_type': 'Bearer',
                'user': {
                  'id': 4,
                  'name': 'Siti Kasir',
                  'email': 'kasir@toko.id',
                  'role': 'KASIR',
                  'is_active': true,
                  'permissions': ['transaksi.create'],
                },
              },
            });
          }
          if (options.path == ApiEndpoints.currentUser) {
            expect(
              options.headers['Authorization'],
              'Bearer 1|sanctum-test-token',
            );
            return _jsonResponse({
              'success': true,
              'data': {
                'id': 4,
                'name': 'Siti Kasir',
                'email': 'kasir@toko.id',
                'role': 'KASIR',
                'is_active': true,
              },
            });
          }
          return _jsonResponse({'success': false}, statusCode: 404);
        });

        final client = ApiClient(
          readToken: () => activeToken,
          httpClientAdapter: adapter,
        );
        final prefs = await SharedPreferences.getInstance();
        final repo = AuthRepository(
          apiClient: client,
          prefs: prefs,
          enableRemoteSync: true,
        );

        final session = await repo.login(
          email: 'kasir@toko.id',
          password: 'password123',
        );
        activeToken = session.accessToken;

        expect(session.accessToken, '1|sanctum-test-token');
        expect(session.user.role, UserRole.kasir);
        expect(prefs.getString('dm_sanctum_token'), '1|sanctum-test-token');

        final restored = await repo.restoreSession();
        expect(restored, isNotNull);
        expect(restored!.user.email, 'kasir@toko.id');
      },
    );

    test(
      'ApiClient triggers unauthorized handler on 401 and surfaces Laravel 422 errors',
      () async {
        var unauthorizedTriggered = false;
        final adapter = _MockDioAdapter((options, _) {
          if (options.path == ApiEndpoints.orders) {
            return _jsonResponse({
              'success': false,
              'message': 'Stok Semen tidak mencukupi (tersedia 2, diminta 5).',
              'error_code': 'STOK_TIDAK_CUKUP',
              'errors': {
                'jumlah': ['Stok tidak mencukupi.'],
              },
            }, statusCode: 422);
          }
          return _jsonResponse({
            'success': false,
            'message': 'Unauthenticated.',
            'error_code': 'UNAUTHENTICATED',
          }, statusCode: 401);
        });

        final client = ApiClient(
          readToken: () => 'expired-token',
          onUnauthorized: () => unauthorizedTriggered = true,
          httpClientAdapter: adapter,
        );

        await expectLater(
          client.get<Map<String, dynamic>>(ApiEndpoints.products),
          throwsA(
            isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue),
          ),
        );
        expect(unauthorizedTriggered, isTrue);

        await expectLater(
          client.post<Map<String, dynamic>>(ApiEndpoints.orders, data: {}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 422)
                .having((e) => e.errorCode, 'errorCode', 'STOK_TIDAK_CUKUP'),
          ),
        );
      },
    );

    test(
      'CashierRepository fetches /stok and ScmRepository uploads multipart FormData POD',
      () async {
        final adapter = _MockDioAdapter((options, body) {
          if (options.path == ApiEndpoints.products) {
            return _jsonResponse({
              'success': true,
              'data': [
                {
                  'id_produk': 10,
                  'kode_sku': 'SMN-010',
                  'nama_produk': 'Semen Gresik 50 Kg',
                  'satuan': 'sak',
                  'kategori': {'id_kategori': 1, 'nama_kategori': 'Semen'},
                  'harga': 65000,
                  'harga_modal': 58000,
                  'kuantitas': 40,
                  'stok_minimum': 10,
                },
              ],
            });
          }
          if (options.path == ApiEndpoints.deliveryTasks) {
            return _jsonResponse({
              'success': true,
              'data': [
                {
                  'id_transaksi': 77,
                  'nomor_struk': 'INV-20261126-077',
                  'tanggal_transaksi': '2026-11-26T10:00:00Z',
                  'biaya_angkut': 0,
                  'status_pesanan': 'BERJALAN',
                  'pelanggan': {
                    'id_pelanggan': 5,
                    'nama_pelanggan': 'Pak Joko',
                    'telepon': '0812345',
                    'alamat': 'Jl. Merdeka No. 9',
                  },
                  'detail': [
                    {
                      'id_detail': 901,
                      'id_produk': 10,
                      'nama_produk': 'Semen Gresik 50 Kg',
                      'jumlah': 5,
                      'status_barang': 'MENUNGGU_DIANTAR',
                      'produk': {'satuan': 'sak'},
                    },
                  ],
                },
              ],
            });
          }
          if (options.path == ApiEndpoints.submitDeliveryPod(77)) {
            expect(options.data, isA<FormData>());
            return _jsonResponse({'success': true, 'data': {}});
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        final client = ApiClient(
          readToken: () => 'valid-token',
          httpClientAdapter: adapter,
        );
        final cashierRepo = CashierRepository(
          apiClient: client,
          enableRemoteSync: true,
        );
        final products = await cashierRepo.fetchProducts();
        expect(products, hasLength(1));
        expect(products.first.numericId, 10);
        expect(products.first.baseUnit, ProductUnit.sak);

        final scmRepo = ScmRepository(
          cashierRepository: cashierRepo,
          apiClient: client,
          enableRemoteSync: true,
        );
        final tasks = await scmRepo.fetchDeliveryTasks();
        expect(tasks, hasLength(1));
        expect(tasks.first.transactionId, 77);

        final updated = await scmRepo.submitProofOfDelivery(
          orderId: tasks.first.id,
          receiverName: 'Pak Joko',
          proofPhotoBytes: Uint8List.fromList([1, 2, 3]),
          proofPhotoName: 'pod.jpg',
          signatureBytes: Uint8List.fromList([4, 5, 6]),
          notes: 'Lengkap dan aman',
        );
        expect(updated.status, DeliveryStatus.delivered);
        expect(adapter.requests.last.path, ApiEndpoints.submitDeliveryPod(77));
      },
    );
  });

  testWidgets(
    'App boots on SplashScreen, removes Demo RBAC chips, and routes Kasir after login',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
      expect(find.text('Enterprise ERP Mobile v1.0.0'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Dobrak Mandiri ERP'), findsOneWidget);
      expect(find.text('Akses Cepat Demo RBAC (5 Role)'), findsNothing);
      expect(find.text(AppFooter.versionLabel), findsOneWidget);

      await _signInViaForm(tester, 'kasir@dobrakmandiri.id');

      expect(find.text('Kasir POS — TB. Dobrak Mandiri'), findsOneWidget);
      for (final unit in ProductUnit.values) {
        expect(find.text(unit.label), findsWidgets);
      }
    },
  );

  testWidgets(
    'SplashScreen auto-routes authenticated token in SharedPreferences to role home',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({'dm_sanctum_token': 'saved-jwt'});
      final prefs = await SharedPreferences.getInstance();

      final adapter = _MockDioAdapter((options, _) {
        if (options.path == ApiEndpoints.currentUser) {
          return _jsonResponse({
            'success': true,
            'data': {
              'id': 1,
              'name': 'Hendra Owner',
              'email': 'owner@dobrakmandiri.id',
              'role': 'OWNER',
              'is_active': true,
            },
          });
        }
        return _jsonResponse({'success': true, 'data': {}});
      });

      await tester.pumpWidget(
        DobrakMandiriApp(
          sharedPreferences: prefs,
          enableRemoteSync: true,
          httpClientAdapter: adapter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner Executive Dashboard'), findsOneWidget);
    },
  );

  testWidgets(
    'OfflineBanner appears on connection failure and 401 clears token back to /login',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var returnUnauthorized = false;

      final adapter = _MockDioAdapter((options, _) {
        if (options.path == ApiEndpoints.login) {
          return _jsonResponse({
            'success': true,
            'data': {
              'token': 'live-jwt',
              'token_type': 'Bearer',
              'user': {
                'id': 2,
                'name': 'Siti Kasir',
                'email': 'kasir@dobrakmandiri.id',
                'role': 'KASIR',
                'is_active': true,
              },
            },
          });
        }
        if (returnUnauthorized) {
          return _jsonResponse({
            'success': false,
            'message': 'Unauthenticated.',
            'error_code': 'UNAUTHENTICATED',
          }, statusCode: 401);
        }
        if (options.path == ApiEndpoints.products) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'Offline',
          );
        }
        return _jsonResponse({'success': true, 'data': []});
      });

      await tester.pumpWidget(
        DobrakMandiriApp(
          sharedPreferences: prefs,
          enableRemoteSync: true,
          httpClientAdapter: adapter,
        ),
      );
      await tester.pumpAndSettle();

      await _signInViaForm(tester, 'kasir@dobrakmandiri.id');

      // Catalog load throws DioException.connectionError -> OfflineBanner must be visible.
      expect(find.text(OfflineBanner.offlineLabel), findsOneWidget);

      // Next request returns 401 Unauthorized -> clears token & redirects to /login.
      returnUnauthorized = true;
      await tester.tap(find.byTooltip('Muat Ulang Katalog'));
      await tester.pumpAndSettle();

      expect(prefs.getString('dm_sanctum_token'), isNull);
      expect(find.text('Dobrak Mandiri ERP'), findsOneWidget);
      expect(
        find.text('Sesi Anda telah berakhir, silakan login kembali.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'POS Checkout supports multi-unit add, delivery toggle, and payment selector',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
      await tester.pumpAndSettle();

      await _signInViaForm(tester, 'kasir@dobrakmandiri.id');

      await tester.tap(find.text('Tambah').first);
      await tester.pumpAndSettle();

      expect(find.text('Keranjang Belanja (1)'), findsOneWidget);
      expect(find.text('Direct Pickup'), findsWidgets);
      expect(find.text('Tempo / Credit'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('fulfillment_delivery_switch')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Requires Delivery Service'), findsWidgets);
      expect(find.text('Alamat Pengiriman *'), findsOneWidget);
    },
  );

  testWidgets('Owner login loads executive KPI cards and navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
    await tester.pumpAndSettle();

    await _signInViaForm(tester, 'owner@dobrakmandiri.id');

    expect(find.text('Owner Executive Dashboard'), findsOneWidget);
    expect(find.text('Gross Revenue'), findsOneWidget);
    expect(find.text('Net Profit'), findsOneWidget);
    expect(find.text('Active Deliveries'), findsOneWidget);
    expect(find.text('Low-Stock Alerts'), findsOneWidget);
    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Financial Reports'), findsOneWidget);
  });

  testWidgets(
    'Kurir login opens Driver POD screen with status toggle and signature pad',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
      await tester.pumpAndSettle();

      await _signInViaForm(tester, 'kurir@dobrakmandiri.id');

      expect(find.text('Kurir & Bukti Pengiriman (POD)'), findsOneWidget);
      expect(find.byKey(const ValueKey('pod_status_pending')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pod_status_inTransit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pod_status_delivered')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pod_signature_pad')), findsOneWidget);
      expect(find.text('Ambil Foto (Kamera)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pod_status_pending')));
      await tester.pumpAndSettle();
      expect(find.text('Menunggu Muat'), findsOneWidget);
    },
  );

  testWidgets('POS Checkout renders cleanly on narrow mobile phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
    await tester.pumpAndSettle();

    await _signInViaForm(tester, 'kasir@dobrakmandiri.id');

    expect(find.text('Katalog Material'), findsOneWidget);
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('Theme toggle switches dynamically between Light and Dark Mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
    await tester.pumpAndSettle();

    final scaffold = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(scaffold).brightness, Brightness.light);
    expect(
      Theme.of(scaffold).scaffoldBackgroundColor,
      AppColors.lightBackground,
    );

    await tester.tap(find.byKey(const ValueKey('theme_toggle_button')));
    await tester.pumpAndSettle();

    final darkScaffold = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(darkScaffold).brightness, Brightness.dark);
    expect(
      Theme.of(darkScaffold).scaffoldBackgroundColor,
      AppColors.darkBackground,
    );
  });

  testWidgets(
    'Locked backend features display Coming Soon notice when tapped',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
      await tester.pumpAndSettle();

      await _signInViaForm(tester, 'kasir@dobrakmandiri.id');

      final lockedChip = find.byKey(const ValueKey('locked_stock_sync_chip'));
      expect(lockedChip, findsOneWidget);

      await tester.tap(lockedChip);
      await tester.pumpAndSettle();

      expect(find.text(BackendFeatureFlags.unsupportedMessage), findsOneWidget);
    },
  );

  testWidgets(
    'PayrollScreen renders without overflow on narrow mobile viewport',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const DobrakMandiriApp(enableRemoteSync: false));
      await tester.pumpAndSettle();

      await _signInViaForm(tester, 'finance@dobrakmandiri.id');

      expect(find.text('Laporan Laba Rugi (P&L)'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Kelola Payroll'), 200);
      await tester.tap(find.text('Kelola Payroll'));
      await tester.pumpAndSettle();

      expect(find.text('Penggajian Karyawan (Payroll)'), findsOneWidget);
      expect(find.text('Siti Rahayu'), findsOneWidget);
      expect(find.text('Rp 4.150.000'), findsOneWidget);
    },
  );
}
