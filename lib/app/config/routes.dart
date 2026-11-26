import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/theme_controller.dart';
import 'package:stelliform_mobile/core/widgets/app_footer.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';
import 'package:stelliform_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:stelliform_mobile/features/auth/presentation/screens/splash_screen.dart';
import 'package:stelliform_mobile/features/cashier/data/cashier_models.dart';
import 'package:stelliform_mobile/features/cashier/presentation/screens/pos_checkout_screen.dart';
import 'package:stelliform_mobile/features/cashier/presentation/screens/receipt_screen.dart';
import 'package:stelliform_mobile/features/finance/presentation/screens/expense_form_screen.dart';
import 'package:stelliform_mobile/features/finance/presentation/screens/payroll_screen.dart';
import 'package:stelliform_mobile/features/finance/presentation/screens/pnl_report_screen.dart';
import 'package:stelliform_mobile/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:stelliform_mobile/features/owner/presentation/screens/user_management_screen.dart';
import 'package:stelliform_mobile/features/scm/presentation/screens/delivery_dispatch_screen.dart';
import 'package:stelliform_mobile/features/scm/presentation/screens/driver_pod_screen.dart';
import 'package:stelliform_mobile/features/scm/presentation/screens/stock_opname_screen.dart';

/// Canonical route paths across Dobrak Mandiri ERP.
abstract final class AppRoutes {
  static const String root = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String unauthorized = '/unauthorized';

  // Cashier module
  static const String posCheckout = '/cashier/pos';
  static const String receipt = '/cashier/receipt';

  // SCM & Logistics module
  static const String stockOpname = '/scm/stock-opname';
  static const String deliveryDispatch = '/scm/delivery-dispatch';
  static const String driverPod = '/scm/driver-pod';

  // Finance module
  static const String expenseForm = '/finance/expense-form';
  static const String payroll = '/finance/payroll';
  static const String pnlReport = '/finance/pnl-report';

  // Owner executive module
  static const String ownerDashboard = '/owner/dashboard';
  static const String userManagement = '/owner/users';
}

/// Metadata entry describing an authorized navigation destination for drawer menus.
class ErpRouteDestination {
  /// Creates an [ErpRouteDestination].
  const ErpRouteDestination({
    required this.path,
    required this.title,
    required this.groupLabel,
    required this.icon,
  });

  /// GoRouter destination path.
  final String path;

  /// Human-readable menu title.
  final String title;

  /// Feature division section label.
  final String groupLabel;

  /// Icon displayed in navigation menus.
  final IconData icon;
}

/// Role-Based Access Control (RBAC) route middleware and permission policy table.
abstract final class RbacGuard {
  static const List<ErpRouteDestination> _allDestinations = [
    ErpRouteDestination(
      path: AppRoutes.ownerDashboard,
      title: 'Dashboard Eksekutif',
      groupLabel: 'Owner',
      icon: Icons.analytics_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.userManagement,
      title: 'Manajemen User & RBAC',
      groupLabel: 'Owner',
      icon: Icons.manage_accounts_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.posCheckout,
      title: 'Kasir POS Checkout',
      groupLabel: 'Kasir',
      icon: Icons.point_of_sale_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.receipt,
      title: 'Struk Transaksi',
      groupLabel: 'Kasir',
      icon: Icons.receipt_long_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.stockOpname,
      title: 'Stock Opname Gudang',
      groupLabel: 'SCM & Logistik',
      icon: Icons.inventory_2_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.deliveryDispatch,
      title: 'Dispatch Armada',
      groupLabel: 'SCM & Logistik',
      icon: Icons.departure_board_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.driverPod,
      title: 'Kurir & Bukti POD',
      groupLabel: 'SCM & Logistik',
      icon: Icons.local_shipping_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.pnlReport,
      title: 'Laporan Laba Rugi',
      groupLabel: 'Finance',
      icon: Icons.assessment_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.expenseForm,
      title: 'Pengeluaran Operasional',
      groupLabel: 'Finance',
      icon: Icons.add_card_rounded,
    ),
    ErpRouteDestination(
      path: AppRoutes.payroll,
      title: 'Penggajian Karyawan',
      groupLabel: 'Finance',
      icon: Icons.payments_rounded,
    ),
  ];

  /// Explicit route permissions enforced dynamically per [UserRole].
  static const Map<UserRole, Set<String>> rolePermissions = {
    UserRole.kasir: {AppRoutes.posCheckout, AppRoutes.receipt},
    UserRole.staffGudang: {
      AppRoutes.stockOpname,
      AppRoutes.deliveryDispatch,
      AppRoutes.driverPod,
    },
    UserRole.kurir: {AppRoutes.driverPod},
    UserRole.finance: {
      AppRoutes.expenseForm,
      AppRoutes.payroll,
      AppRoutes.pnlReport,
    },
    UserRole.owner: {
      AppRoutes.ownerDashboard,
      AppRoutes.userManagement,
      AppRoutes.posCheckout,
      AppRoutes.receipt,
      AppRoutes.stockOpname,
      AppRoutes.deliveryDispatch,
      AppRoutes.driverPod,
      AppRoutes.expenseForm,
      AppRoutes.payroll,
      AppRoutes.pnlReport,
    },
  };

  /// Returns `true` when [role] is authorized to access [path].
  static bool canAccess(UserRole role, String path) {
    final allowed = rolePermissions[role];
    if (allowed == null) return false;
    return allowed.contains(path);
  }

  /// Returns ordered navigation menu items authorized for [role].
  static List<ErpRouteDestination> accessibleDestinationsFor(UserRole role) {
    return _allDestinations
        .where((dest) => canAccess(role, dest.path))
        .toList(growable: false);
  }

  /// Evaluates authentication and RBAC authorization for incoming [state].
  static String? evaluateRedirect({
    required AuthController authController,
    required GoRouterState state,
  }) {
    final location = state.uri.path;
    if (location == AppRoutes.splash) {
      return null;
    }

    final isAuthenticated = authController.isAuthenticated;

    // 1. Unauthenticated guard: force redirect to /login.
    if (!isAuthenticated) {
      if (location == AppRoutes.login) return null;
      return AppRoutes.login;
    }

    final currentUser = authController.currentUser!;
    if (!currentUser.isActive) {
      return AppRoutes.login;
    }

    // 2. Authenticated users visiting / or /login go to requested or role home route.
    if (location == AppRoutes.login || location == AppRoutes.root) {
      final requestedFrom = state.uri.queryParameters['from'];
      if (requestedFrom != null && requestedFrom.isNotEmpty) {
        final parsed = Uri.tryParse(requestedFrom);
        if (parsed != null && canAccess(currentUser.role, parsed.path)) {
          return requestedFrom;
        }
      }
      return currentUser.role.homeRoute;
    }

    // 3. Always permit rendering the RBAC access-denied view.
    if (location == AppRoutes.unauthorized) {
      return null;
    }

    // 4. Dynamic role-based access check against permission matrix.
    if (!canAccess(currentUser.role, location)) {
      return '${AppRoutes.unauthorized}?attempted=${Uri.encodeComponent(location)}';
    }

    return null;
  }
}

/// Central [GoRouter] factory wired to [AuthController] RBAC middleware.
abstract final class AppRouter {
  /// Builds the application [GoRouter] with dynamic auth and role guards.
  static GoRouter createRouter(
    AuthController authController, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: AppRoutes.splash,
      refreshListenable: authController,
      debugLogDiagnostics: false,
      redirect: (context, state) => RbacGuard.evaluateRedirect(
        authController: authController,
        state: state,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.unauthorized,
          name: 'unauthorized',
          builder: (context, state) => UnauthorizedScreen(
            attemptedPath: state.uri.queryParameters['attempted'],
          ),
        ),
        GoRoute(
          path: AppRoutes.posCheckout,
          name: 'pos_checkout',
          builder: (context, state) => const PosCheckoutScreen(),
        ),
        GoRoute(
          path: AppRoutes.receipt,
          name: 'receipt',
          builder: (context, state) {
            final extraReceipt = state.extra is TransactionReceipt
                ? state.extra as TransactionReceipt
                : null;
            return ReceiptScreen(
              receipt: extraReceipt,
              invoiceNumber: state.uri.queryParameters['invoice'],
            );
          },
        ),
        GoRoute(
          path: AppRoutes.stockOpname,
          name: 'stock_opname',
          builder: (context, state) => const StockOpnameScreen(),
        ),
        GoRoute(
          path: AppRoutes.deliveryDispatch,
          name: 'delivery_dispatch',
          builder: (context, state) => const DeliveryDispatchScreen(),
        ),
        GoRoute(
          path: AppRoutes.driverPod,
          name: 'driver_pod',
          builder: (context, state) => const DriverPodScreen(),
        ),
        GoRoute(
          path: AppRoutes.expenseForm,
          name: 'expense_form',
          builder: (context, state) => const ExpenseFormScreen(),
        ),
        GoRoute(
          path: AppRoutes.payroll,
          name: 'payroll',
          builder: (context, state) => const PayrollScreen(),
        ),
        GoRoute(
          path: AppRoutes.pnlReport,
          name: 'pnl_report',
          builder: (context, state) => const PnlReportScreen(),
        ),
        GoRoute(
          path: AppRoutes.ownerDashboard,
          name: 'owner_dashboard',
          builder: (context, state) => const OwnerDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.userManagement,
          name: 'user_management',
          builder: (context, state) => const UserManagementScreen(),
        ),
      ],
      errorBuilder: (context, state) =>
          _RouterNotFoundScreen(location: state.uri.toString()),
    );
  }
}

/// Role-filtered navigation drawer shared across authenticated ERP screens.
class ErpNavigationDrawer extends StatelessWidget {
  /// Creates an [ErpNavigationDrawer] highlighting [currentPath].
  const ErpNavigationDrawer({required this.currentPath, super.key});

  /// Active route path highlighted in the drawer menu.
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeController = context.watch<ThemeController?>();
    final palette = AppColors.of(context);
    final user = auth.currentUser;
    if (user == null) {
      return const Drawer(child: SizedBox.shrink());
    }

    final destinations = RbacGuard.accessibleDestinationsFor(user.role);

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 46, 18, 18),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: palette.primarySoft,
                      child: Icon(
                        user.role.icon,
                        color: palette.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Role: ${user.role.label} • ${user.branchName}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final item = destinations[index];
                final isSelected = item.path == currentPath;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isSelected
                          ? BorderSide(
                              color: palette.primary.withValues(alpha: 0.35),
                            )
                          : BorderSide.none,
                    ),
                    leading: Icon(
                      item.icon,
                      size: 20,
                      color: isSelected
                          ? palette.primary
                          : palette.textSecondary,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? palette.primary
                            : palette.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      item.groupLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: palette.primarySoft,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (!isSelected) {
                        context.go(item.path);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(),
          if (themeController != null)
            ListTile(
              leading: Icon(
                themeController.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: palette.primary,
                size: 20,
              ),
              title: Text(
                themeController.isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              trailing: Switch(
                value: themeController.isDarkMode,
                onChanged: (_) => themeController.toggleTheme(),
              ),
              onTap: themeController.toggleTheme,
            ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: palette.danger,
                    size: 20,
                  ),
                  title: Text(
                    'Keluar dari ERP',
                    style: TextStyle(
                      color: palette.danger,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await context.read<AuthController>().logout();
                  },
                ),
                const AppFooter(padding: EdgeInsets.fromLTRB(16, 2, 16, 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen displayed when an authenticated employee lacks RBAC permission for a route.
class UnauthorizedScreen extends StatelessWidget {
  /// Creates an [UnauthorizedScreen].
  const UnauthorizedScreen({super.key, this.attemptedPath});

  /// Restricted route path intercepted by [RbacGuard].
  final String? attemptedPath;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final palette = AppColors.of(context);
    final homeRoute = user?.role.homeRoute ?? AppRoutes.login;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akses Ditolak (RBAC)'),
        actions: const [ThemeToggleButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.gpp_bad_rounded,
                      size: 36,
                      color: palette.danger,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Izin Akses Tidak Mencukupi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role Anda (${user?.role.label ?? 'Tamu'}) tidak memiliki hak akses ke halaman ${attemptedPath ?? 'yang diminta'}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: 'Kembali ke Halaman Utama',
                    icon: Icons.home_rounded,
                    onPressed: () => context.go(homeRoute),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouterNotFoundScreen extends StatelessWidget {
  const _RouterNotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthController>().currentRole;
    final palette = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Halaman Tidak Ditemukan'),
        actions: const [ThemeToggleButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_rounded,
                size: 48,
                color: palette.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'Rute "$location" tidak terdaftar di sistem.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Kembali ke Beranda',
                isFullWidth: false,
                onPressed: () => context.go(role?.homeRoute ?? AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
