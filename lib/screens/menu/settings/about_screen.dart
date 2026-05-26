
import 'package:flutter/material.dart';
import '../../../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          'About SkillSwap',
          style: AppTextStyles.heading2,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [

            const SizedBox(height: AppSpacing.xl),

            // ── Logo ────────────────────────────────────
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.indigoCoralGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── App name ─────────────────────────────────
            const Text(
              'SkillSwap',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Tagline ───────────────────────────────────
            const Text(
              'Swap Skills. Grow Together.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: AppColors.coral,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Version ───────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.elevated),
              ),
              child: const Text(
                'v1.0.0 (Build 1)',
                style: AppTextStyles.caption,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Description ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.elevated),
              ),
              child: const Text(
                'SkillSwap is a peer-to-peer skill exchange platform built for university students. '
                'Instead of paying for tutors or courses, students swap what they know. '
                'You teach Python, they teach UI Design. Both of you grow — completely free.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Feature highlights ─────────────────────────
            _buildFeatureRow(
              icon: Icons.swap_horiz_rounded,
              color: AppColors.coral,
              title: 'Skill Swapping',
              subtitle: 'Exchange skills with matched students',
            ),

            const SizedBox(height: AppSpacing.md),

            _buildFeatureRow(
              icon: Icons.videocam_rounded,
              color: AppColors.indigo,
              title: 'Live Video Calls',
              subtitle: '1-on-1 sessions with screen sharing',
            ),

            const SizedBox(height: AppSpacing.md),

            _buildFeatureRow(
              icon: Icons.groups_rounded,
              color: AppColors.green,
              title: 'Communities',
              subtitle: 'Join skill-based groups and share content',
            ),

            const SizedBox(height: AppSpacing.md),

            _buildFeatureRow(
              icon: Icons.calendar_today_rounded,
              color: AppColors.gold,
              title: 'Smart Scheduling',
              subtitle: 'Book sessions that fit your calendar',
            ),

            const SizedBox(height: AppSpacing.xl),

            const Divider(color: AppColors.elevated),

            const SizedBox(height: AppSpacing.lg),

            // ── Made by ───────────────────────────────────
            const Text(
              'Made with ❤️ for university students',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xs),

            // ── Tech stack ────────────────────────────────
            const Text(
              'Built with Flutter + Supabase',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.indigo,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

          ],
        ),
      ),
    );
  }

  // ── Feature row ────────────────────────────────────────────────
  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyBold),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}