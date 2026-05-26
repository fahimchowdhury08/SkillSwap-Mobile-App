import 'package:flutter/material.dart';
import 'package:skillswap/screens/menu/settings/about_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import 'settings/change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _emailController = TextEditingController();
  bool _isChangingEmail  = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showChangeEmailDialog() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Change Email',
          style: AppTextStyles.heading3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your new email. A verification link will be sent.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.bodyBold,
              decoration: InputDecoration(
                hintText: 'New email address',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Nunito',
                ),
                filled: true,
                fillColor: AppColors.elevated,
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
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _isChangingEmail
                ? null
                : () async {
                    final newEmail = _emailController.text.trim();
                    if (newEmail.isEmpty || !newEmail.contains('@')) {
                      return;
                    }
                    setState(() => _isChangingEmail = true);
                    try {
                      await SupabaseService.client.auth.updateUser(
                        UserAttributes(email: newEmail),
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Verification sent to new email ✓',
                          ),
                          backgroundColor: AppColors.green,
                        ),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not update email. Try again.',
                          ),
                          backgroundColor: AppColors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isChangingEmail = false);
                      }
                    }
                  },
            child: _isChangingEmail
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.indigo,
                    ),
                  )
                : const Text(
                    'Send Verification',
                    style: TextStyle(
                      color: AppColors.indigo,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
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
          'Settings',
          style: AppTextStyles.heading2,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Account ───────────────────────────────────
            const Text('Account', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            _buildSection(
              children: [
                _buildTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  onTap: () {
                    // TODO: replace when built
                    // Navigator.push(context, MaterialPageRoute(
                    //   builder: (_) => const ChangePasswordScreen()));
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.email_outlined,
                  label: 'Change Email',
                  onTap: _showChangeEmailDialog,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Preferences ───────────────────────────────
            const Text('Preferences', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            _buildSection(
              children: [
                _buildTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark Mode',
                  trailing: const Switch(
                    value: true,
                    onChanged: null,
                    activeThumbColor: AppColors.indigo,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dark mode only in v1'),
                        backgroundColor: AppColors.indigo,
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  subtitle: 'English',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('More languages coming soon'),
                        backgroundColor: AppColors.indigo,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── About ─────────────────────────────────────
            const Text('About', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            _buildSection(
              children: [
                _buildTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About SkillSwap',
                  onTap: () {
                    // TODO: replace when built
                    // Navigator.push(context, MaterialPageRoute(
                    //   builder: (_) => const AboutScreen()));
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AboutScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.star_outline_rounded,
                  label: 'Rate the App',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rate us — coming soon'),
                        backgroundColor: AppColors.indigo,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

          ],
        ),
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.indigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.indigo, size: 18),
      ),
      title: Text(label, style: AppTextStyles.bodyBold),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTextStyles.caption)
          : null,
      trailing: trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textMuted,
            size: 14,
          ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: AppColors.elevated,
      height: 1,
      indent: AppSpacing.lg + 36 + AppSpacing.md,
    );
  }
}