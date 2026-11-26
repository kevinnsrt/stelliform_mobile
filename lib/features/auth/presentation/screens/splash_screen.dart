import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';

/// Minimalist initialization screen checking saved JWT credentials before
/// routing the employee to their RBAC dashboard or `/login`.
class SplashScreen extends StatefulWidget {
  /// Creates a [SplashScreen].
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeSession());
  }

  Future<void> _initializeSession() async {
    final auth = context.read<AuthController>();
    await auth.restoreSession();
    if (!mounted) return;

    final role = auth.currentRole;
    if (auth.isAuthenticated && role != null) {
      context.go(role.homeRoute);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.construction_rounded,
                    color: palette.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Dobrak Mandiri ERP',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enterprise ERP Mobile v1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
