
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme.dart';
import '../../../supabase_service.dart';
import '../../../widgets/coral_button.dart';
import '../../../widgets/loading_spinner.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // ── Controllers ───────────────────────────────────────────────
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────
  bool _isLoading       = false;
  bool _showNew         = false;
  bool _showConfirm     = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Update password ────────────────────────────────────────────
  Future<void> _updatePassword() async {
    final newPass     = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    // Validate
    if (newPass.isEmpty) {
      _showError('Please enter a new password');
      return;
    }
    if (newPass.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully! ✓'),
          backgroundColor: AppColors.green,
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      _showError('Could not update password. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Change Password',
          style: AppTextStyles.heading2,
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Info card ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.indigo.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.indigo,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Choose a strong password with at least 8 characters',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── New password ──────────────────────────
              const Text(
                'New Password',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPasswordField(
                controller: _newPasswordController,
                hint: 'Enter new password',
                showPassword: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Confirm password ──────────────────────
              const Text(
                'Confirm New Password',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPasswordField(
                controller: _confirmPasswordController,
                hint: 'Re-enter new password',
                showPassword: _showConfirm,
                onToggle: () =>
                    setState(() => _showConfirm = !_showConfirm),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Password requirements ─────────────────
              const Text(
                'Password requirements',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildRequirement('At least 8 characters'),
              _buildRequirement('Mix of letters and numbers recommended'),
              _buildRequirement('Avoid using your name or email'),

              const SizedBox(height: AppSpacing.xxl),

              // ── Update button ─────────────────────────
              CoralButton(
                label: 'Update Password',
                onTap: _isLoading ? null : _updatePassword,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

            ],
          ),
        ),
      ),
    );
  }

  // ── Password field ─────────────────────────────────────────────
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      style: AppTextStyles.bodyBold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Nunito',
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.textMuted,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.indigo,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ── Requirement row ────────────────────────────────────────────
  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}