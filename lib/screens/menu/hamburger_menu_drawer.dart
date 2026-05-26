
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/gradient_avatar.dart';

class HamburgerMenuDrawer extends StatefulWidget {
  const HamburgerMenuDrawer({super.key});

  @override
  State<HamburgerMenuDrawer> createState() => _HamburgerMenuDrawerState();
}

class _HamburgerMenuDrawerState extends State<HamburgerMenuDrawer> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // ── Load current user data ─────────────────────────────────────
  Future<void> _loadUser() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      setState(() => _currentUser = UserModel.fromJson(res));
    } catch (e) {
      debugPrint('Drawer load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    // Close drawer first
    Navigator.pop(context);

    try {
      await SupabaseService.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/get-started',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logout failed. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Navigate and close drawer ──────────────────────────────────
  void _navigate(String route) {
    Navigator.pop(context); // close drawer
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cardSurface,
      child: SafeArea(
        child: Column(
          children: [

            // ── Header ────────────────────────────────────────
            _buildHeader(),

            const Divider(
              color: AppColors.elevated,
              thickness: 1,
              height: 1,
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Menu items ────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [

                  _buildMenuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Personal Details',
                    onTap: () => _navigate('/personal-details'),
                  ),

                  _buildMenuItem(
                    icon: Icons.groups_outlined,
                    label: 'Community',
                    onTap: () => _navigate('/community'),
                  ),

                  _buildMenuItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Schedule',
                    onTap: () => _navigate('/schedule'),
                  ),

                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _navigate('/settings'),
                  ),

                  _buildMenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => _navigate('/help'),
                  ),

                ],
              ),
            ),

            const Divider(
              color: AppColors.elevated,
              thickness: 1,
              height: 1,
            ),

            // ── Logout ────────────────────────────────────────
            _buildMenuItem(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              color: AppColors.red,
              onTap: _logout,
            ),

            const SizedBox(height: AppSpacing.md),

          ],
        ),
      ),
    );
  }

  // ── Header with user info ──────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.indigo,
                strokeWidth: 2,
              ),
            )
          : Row(
              children: [

                // Avatar
                GradientAvatar(
                  imageUrl: _currentUser?.avatarUrl,
                  name: _currentUser?.displayName,
                  size: 52,
                ),

                const SizedBox(width: AppSpacing.md),

                // Name + occupation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.displayName ?? 'SkillSwap User',
                        style: AppTextStyles.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_currentUser?.occupation != null)
                        Text(
                          _currentUser!.occupation!,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_currentUser?.institution != null)
                        Text(
                          _currentUser!.institution!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.indigo,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

              ],
            ),
    );
  }

  // ── Menu item builder ──────────────────────────────────────────
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.textSecondary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(
        icon,
        color: itemColor,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: itemColor,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: color != null
            ? itemColor.withValues(alpha: 0.5)
            : AppColors.textMuted,
        size: 14,
      ),
      onTap: onTap,
    );
  }
}