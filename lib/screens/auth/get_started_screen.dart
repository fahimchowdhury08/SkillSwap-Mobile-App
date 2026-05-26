
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/indigo_button.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [

              const Spacer(),

              // ── Logo ─────────────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppColors.indigoCoralGradient,
                  borderRadius: BorderRadius.circular(22),
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
                  size: 50,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── App name ──────────────────────────────────────
              const Text(
                'SkillSwap',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Tagline ───────────────────────────────────────
              const Text(
                'Swap Skills. Grow Together.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Feature highlights ────────────────────────────
              _buildFeatureRow(
                icon: Icons.search_rounded,
                color: AppColors.indigo,
                text: 'Get matched with students who teach what you need',
              ),

              const SizedBox(height: AppSpacing.md),

              _buildFeatureRow(
                icon: Icons.swap_horiz_rounded,
                color: AppColors.coral,
                text: 'Swap skills freely — no money involved',
              ),

              const SizedBox(height: AppSpacing.md),

              _buildFeatureRow(
                icon: Icons.videocam_rounded,
                color: AppColors.green,
                text: 'Learn live through built-in video calls',
              ),

              const Spacer(),

              // ── Join Now button ───────────────────────────────
              CoralButton(
                label: 'Join Now',
                icon: Icons.arrow_forward_rounded,
                onTap: () {
                  Navigator.pushNamed(context, '/signup');
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Login button ──────────────────────────────────
              IndigoButton(
                label: 'Login',
                isOutlined: true,
                onTap: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),

              const SizedBox(height: AppSpacing.lg),

            ],
          ),
        ),
      ),
    );
  }

  // ── Feature row builder ────────────────────────────────────────
  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [

        // ── Icon circle ──────────────────────────────────────────
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // ── Feature text ─────────────────────────────────────────
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
        ),

      ],
    );
  }
}