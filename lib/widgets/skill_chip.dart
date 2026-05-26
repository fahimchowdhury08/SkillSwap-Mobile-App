
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/skill_model.dart';

class SkillChip extends StatelessWidget {
  final String label;
  final bool isVerified;
  final bool isRemovable;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final Color? color;

  const SkillChip({
    super.key,
    required this.label,
    this.isVerified = false,
    this.isRemovable = false,
    this.onRemove,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _getColorForSkill(label);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: chipColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Skill label ─────────────────────────────────
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: chipColor,
              ),
            ),

            // ── Verified badge ──────────────────────────────
            if (isVerified) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.verified,
                size: 12,
                color: chipColor,
              ),
            ],

            // ── Remove button ───────────────────────────────
            if (isRemovable && onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: chipColor,
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  // ── Color picker ───────────────────────────────────────────────
  // Returns the right color based on the skill category
  // Matches the category detection in SkillModel.detectCategory()
  Color _getColorForSkill(String skillName) {
    final category = SkillModel.detectCategory(skillName);
    switch (category) {
      case 'coding':    return AppColors.chipFullStack;
      case 'design':    return AppColors.chipDesign;
      case 'marketing': return AppColors.chipMarketing;
      default:          return AppColors.chipOther;
    }
  }
}

// ── Skill Chip Row ─────────────────────────────────────────────
// Use this to display a row of skill chips
// Automatically wraps to next line if there are many chips
class SkillChipRow extends StatelessWidget {
  final List<String> skills;
  final bool showVerified;
  final bool isRemovable;
  final Function(String)? onRemove;
  final Function(String)? onTap;

  const SkillChipRow({
    super.key,
    required this.skills,
    this.showVerified = false,
    this.isRemovable = false,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return const Text(
        'No skills added yet',
        style: AppTextStyles.body,
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: skills.map((skill) {
        return SkillChip(
          label: skill,
          isVerified: showVerified,
          isRemovable: isRemovable,
          onRemove: onRemove != null
              ? () => onRemove!(skill)
              : null,
          onTap: onTap != null
              ? () => onTap!(skill)
              : null,
        );
      }).toList(),
    );
  }
}