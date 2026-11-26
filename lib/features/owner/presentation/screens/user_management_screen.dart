import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';
import 'package:stelliform_mobile/app/config/routes.dart';
import 'package:stelliform_mobile/core/widgets/custom_button.dart';
import 'package:stelliform_mobile/core/widgets/custom_textfield.dart';
import 'package:stelliform_mobile/core/widgets/loading_indicator.dart';
import 'package:stelliform_mobile/features/auth/controllers/auth_controller.dart';
import 'package:stelliform_mobile/features/auth/data/auth_models.dart';
import 'package:stelliform_mobile/features/owner/controllers/owner_controller.dart';

/// Minimalist Owner RBAC employee administration screen.
class UserManagementScreen extends StatefulWidget {
  /// Creates a [UserManagementScreen].
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthController>().isRemoteSession) {
        context.read<OwnerController>().loadUsers();
      }
    });
  }

  Future<void> _showCreateUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final branchController = TextEditingController(
      text: 'TB. Dobrak Mandiri Pusat',
    );
    var selectedRole = UserRole.kasir;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Tambah Akun Karyawan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Nama Lengkap',
                  hintText: 'Contoh: Andi Saputra',
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: emailController,
                  label: 'Email Login',
                  hintText: 'andi@dobrakmandiri.id',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: phoneController,
                  label: 'No. HP / WhatsApp',
                  hintText: '0812-xxxx-xxxx',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: branchController,
                  label: 'Cabang / Armada',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role RBAC'),
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedRole = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Buat Akun'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;

    final owner = context.read<OwnerController>();
    final ok = await owner.addUser(
      name: nameController.text,
      email: emailController.text,
      role: selectedRole,
      branchName: branchController.text,
      phone: phoneController.text,
    );
    if (!mounted) return;

    if (!ok) {
      ApiErrorFeedback.showSnackBar(
        context,
        owner.lastException ?? owner.errorMessage,
        fallbackMessage: 'Gagal menambahkan karyawan.',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Akun ${nameController.text} (${selectedRole.label}) aktif dengan password default password123.',
        ),
      ),
    );
  }

  Future<void> _handleToggleActive(AuthUser user) async {
    final owner = context.read<OwnerController>();
    final auth = context.read<AuthController>();
    final ok = await owner.toggleUserActive(user);
    if (!mounted) return;
    if (!ok) {
      ApiErrorFeedback.showSnackBar(
        context,
        owner.lastException ?? owner.errorMessage,
      );
      return;
    }
    await auth.refreshUserFromDirectory();
  }

  Future<void> _handleRoleChange(AuthUser user, UserRole? nextRole) async {
    if (nextRole == null) return;
    final owner = context.read<OwnerController>();
    final auth = context.read<AuthController>();
    final ok = await owner.updateUserRole(user, nextRole);
    if (!mounted) return;
    if (!ok) {
      ApiErrorFeedback.showSnackBar(
        context,
        owner.lastException ?? owner.errorMessage,
      );
      return;
    }
    await auth.refreshUserFromDirectory();
  }

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<OwnerController>();
    final palette = AppColors.of(context);
    final currentUser = context.watch<AuthController>().currentUser;
    final users = owner.staffUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen User & RBAC'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Muat Ulang Karyawan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: owner.isUsersLoading ? null : owner.loadUsers,
          ),
        ],
      ),
      drawer: const ErpNavigationDrawer(currentPath: AppRoutes.userManagement),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah Karyawan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
        children: [
          if (owner.isUsersLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: palette.primary),
            ),
          if (owner.errorMessage != null) ...[
            ApiErrorBanner(
              message: owner.errorMessage!,
              onRetry: owner.loadUsers,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.infoSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: palette.info,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Total ${users.length} akun terdaftar (${users.where((u) => u.isActive).length} aktif). Perubahan role langsung berlaku pada middleware GoRouter.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...users.map((user) {
            final isSelf = currentUser?.id == user.id;
            return Container(
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
                      CircleAvatar(
                        backgroundColor: user.role.color.withValues(
                          alpha: 0.14,
                        ),
                        child: Icon(
                          user.role.icon,
                          color: user.role.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.primarySoft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Anda',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: palette.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${user.email} • ${user.branchName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: user.isActive,
                        onChanged: isSelf
                            ? null
                            : (_) => _handleToggleActive(user),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Text(
                        'Role Akses:',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<UserRole>(
                          isExpanded: true,
                          value: user.role,
                          underline: const SizedBox.shrink(),
                          onChanged: isSelf
                              ? null
                              : (nextRole) => _handleRoleChange(user, nextRole),
                          items: UserRole.values
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
