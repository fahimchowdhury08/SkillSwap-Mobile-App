
import 'package:flutter/material.dart';
import '../theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final IconData? icon;
  final String? lottieAsset;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
    this.icon,
    this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Icon ──────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.cardSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Title ─────────────────────────────────────────
            Text(
              title,
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),

            // ── Subtitle ──────────────────────────────────────
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],

            // ── Button ────────────────────────────────────────
            if (buttonLabel != null && onButtonTap != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onButtonTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    buttonLabel!,
                    style: AppTextStyles.button,
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }
}