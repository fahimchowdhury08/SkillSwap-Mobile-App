
import 'package:flutter/material.dart';
import '../theme.dart';

class IndigoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isFullWidth;
  final bool isOutlined;
  final IconData? icon;

  const IndigoButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 52,
      child: isOutlined
          ? _buildOutlined()
          : _buildFilled(),
    );
  }

  // ── Filled indigo button ───────────────────────────────────────
  // Used for primary actions like "Join", "Book Session", "Accept"
  Widget _buildFilled() {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.indigo,
        disabledBackgroundColor: AppColors.indigo.withValues(alpha: 0.5),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: _buildChild(),
    );
  }

  // ── Outlined indigo button ─────────────────────────────────────
  // Used for secondary actions like "Joined ✓", "Cancel", "Skip"
  Widget _buildOutlined() {
    return OutlinedButton(
      onPressed: isLoading ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.indigo,
        side: const BorderSide(
          color: AppColors.indigo,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: _buildChild(),
    );
  }

  // ── Shared child widget ────────────────────────────────────────
  Widget _buildChild() {
    return isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: isOutlined ? AppColors.indigo : Colors.white,
              strokeWidth: 2.5,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: isOutlined
                    ? AppTextStyles.button.copyWith(
                        color: AppColors.indigo,
                      )
                    : AppTextStyles.button,
              ),
            ],
          );
  }
}