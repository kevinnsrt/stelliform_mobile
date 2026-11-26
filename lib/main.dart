import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/app_theme.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/app/config/theme_controller.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/core/widgets/offline_banner.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/auth/data/auth_repository.dart';
import 'package:stelliform_mobile/features/cashier/controllers/cashier_controller.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_repository.dart';
import 'package:stelliform_mobile/features/finance/controllers/finance_controller.dart';
import 'package:stelliform_mobile/features/finance/data/finance_repository.dart';
import 'package:stelliform_mobile/features/owner/controllers/owner_controller.dart';
import 'package:stelliform_mobile/features/owner/data/owner_repository.dart';
import 'package:stelliform_mobile/features/scm/controllers/scm_controller.dart';
import 'package:stelliform_mobile/features/scm/data/scm_repository.dart';

/// Application entry point for Dobrak Mandiri Mobile ERP.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(DobrakMandiriApp(sharedPreferences: prefs));
}

/// Root application widget initializing HTTP client, connectivity monitor,
/// theme engine, repositories, global Provider state, and RBAC GoRouter.
class DobrakMandiriApp extends StatefulWidget {
  /// Creates the [DobrakMandiriApp] root widget.
  const DobrakMandiriApp({
    super.key,
    this.sharedPreferences,
    this.enableRemoteSync = true,
    this.httpClientAdapter,
  });

  /// Pre-initialized [SharedPreferences] used for Sanctum token and theme persistence.
  final SharedPreferences? sharedPreferences;

  /// Enables live HTTP communication with the Laravel ERP REST API.
  final bool enableRemoteSync;

  /// Optional [HttpClientAdapter] override used in automated tests.
  final HttpClientAdapter? httpClientAdapter;

  @override
  State<DobrakMandiriApp> createState() => _DobrakMandiriAppState();
}

class _DobrakMandiriAppState extends State<DobrakMandiriApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final ThemeController _themeController;
  late final ConnectivityController _connectivityController;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final CashierRepository _cashierRepository;
  late final ScmRepository _scmRepository;
  late final FinanceRepository _financeRepository;
  late final OwnerRepository _ownerRepository;

  late final AuthController _authController;
  late final CashierController _cashierController;
  late final ScmController _scmController;
  late final FinanceController _financeController;
  late final OwnerController _ownerController;
  late final GoRouter _router;

  bool _handlingUnauthorized = false;

  @override
  void initState() {
    super.initState();

    _themeController = ThemeController(prefs: widget.sharedPreferences);
    _connectivityController = ConnectivityController();

    _apiClient = ApiClient(
      readToken: () => _authController.accessToken,
      readRoleCode: () => _authController.currentRole?.backendCode,
      onUnauthorized: _handleUnauthorized,
      onConnectivityChanged: (isOnline) {
        if (isOnline) {
          _connectivityController.markOnline();
        } else {
          _connectivityController.markOffline();
        }
      },
      httpClientAdapter: widget.httpClientAdapter,
    );

    _authRepository = AuthRepository(
      apiClient: _apiClient,
      prefs: widget.sharedPreferences,
      enableRemoteSync: widget.enableRemoteSync,
    );
    _cashierRepository = CashierRepository(
      apiClient: _apiClient,
      enableRemoteSync: widget.enableRemoteSync,
    );
    _scmRepository = ScmRepository(
      cashierRepository: _cashierRepository,
      apiClient: _apiClient,
      enableRemoteSync: widget.enableRemoteSync,
    );
    _financeRepository = FinanceRepository(
      cashierRepository: _cashierRepository,
      apiClient: _apiClient,
      enableRemoteSync: widget.enableRemoteSync,
    );
    _ownerRepository = OwnerRepository(
      authRepository: _authRepository,
      cashierRepository: _cashierRepository,
      scmRepository: _scmRepository,
      financeRepository: _financeRepository,
      apiClient: _apiClient,
      enableRemoteSync: widget.enableRemoteSync,
    );

    _authController = AuthController(repository: _authRepository);
    _cashierController = CashierController(repository: _cashierRepository);
    _scmController = ScmController(repository: _scmRepository);
    _financeController = FinanceController(repository: _financeRepository);
    _ownerController = OwnerController(repository: _ownerRepository);

    _router = AppRouter.createRouter(
      _authController,
      navigatorKey: _navigatorKey,
    );
  }

  void _handleUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    final wasAuthenticated = _authController.isAuthenticated;
    _authController.logout(fromUnauthorized: true).whenComplete(() {
      _handlingUnauthorized = false;
    });

    if (wasAuthenticated) {
      const sessionMessage = 'Sesi Anda telah berakhir, silakan login kembali.';
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: const Text(
              sessionMessage,
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
    }
    _router.go(AppRoutes.login);
  }

  Future<void> _retryHealthCheck() async {
    await _connectivityController.retryConnection(() async {
      try {
        await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.health);
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  @override
  void dispose() {
    _router.dispose();
    _ownerController.dispose();
    _financeController.dispose();
    _scmController.dispose();
    _cashierController.dispose();
    _authController.dispose();
    _connectivityController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<ThemeController>.value(value: _themeController),
        ChangeNotifierProvider<ConnectivityController>.value(
          value: _connectivityController,
        ),
        ChangeNotifierProvider<AuthController>.value(value: _authController),
        ChangeNotifierProvider<CashierController>.value(
          value: _cashierController,
        ),
        ChangeNotifierProvider<ScmController>.value(value: _scmController),
        ChangeNotifierProvider<FinanceController>.value(
          value: _financeController,
        ),
        ChangeNotifierProvider<OwnerController>.value(value: _ownerController),
      ],
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) => MaterialApp.router(
          title: 'Dobrak Mandiri ERP',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeController.themeMode,
          routerConfig: _router,
          builder: (context, child) => Column(
            children: [
              OfflineBanner(onRetry: _retryHealthCheck),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
