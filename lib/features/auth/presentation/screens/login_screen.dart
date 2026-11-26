import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/core/widgets/app_footer.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/custom_textfield.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';

/// Clean minimalist enterprise login screen without demo quick-access shortcuts.
class LoginScreen extends StatefulWidget {
  /// Creates a [LoginScreen].
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (!success) {
      final ex = auth.lastException;
      if (ex != null && (ex.isTimeout || ex.isServerError)) {
        await ApiErrorFeedback.showErrorDialog(
          context,
          error: ex,
          onRetry: _handleLogin,
        );
      } else {
        ApiErrorFeedback.showSnackBar(
          context,
          ex ?? auth.errorMessage,
          fallbackMessage: 'Gagal masuk ke aplikasi. Periksa kredensial Anda.',
        );
      }
      return;
    }

    final role = auth.currentRole;
    if (role != null) {
      context.go(role.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: Colors.transparent,
        shape: const Border(),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: ThemeToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.construction_rounded,
                          color: palette.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dobrak Mandiri ERP',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'TB. Dobrak Mandiri • Toko Bangunan & Logistik',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Masuk Akun Karyawan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gunakan kredensial perusahaan yang terdaftar.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email / Username',
                            hintText: 'nama@dobrakmandiri.id',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email / Username wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Kata Sandi',
                            hintText: 'Masukkan kata sandi',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: palette.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Kata sandi wajib diisi';
                              }
                              return null;
                            },
                          ),
                          if (auth.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            ApiErrorBanner(
                              message: auth.errorMessage!,
                              onDismiss: auth.clearError,
                            ),
                          ],
                          const SizedBox(height: 20),
                          CustomButton(
                            label: 'Masuk ke ERP',
                            icon: Icons.login_rounded,
                            isLoading: auth.isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
