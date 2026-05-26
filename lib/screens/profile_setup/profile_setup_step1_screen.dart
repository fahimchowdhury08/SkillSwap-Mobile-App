
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/skill_model.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class ProfileSetupStep1Screen extends StatefulWidget {
  const ProfileSetupStep1Screen({super.key});

  @override
  State<ProfileSetupStep1Screen> createState() =>
      _ProfileSetupStep1ScreenState();
}

class _ProfileSetupStep1ScreenState extends State<ProfileSetupStep1Screen> {
  // ── Controllers ───────────────────────────────────────────────
  final _teachController = TextEditingController();
  final _learnController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────
  final List<String> _teachingSkills = [];
  final List<String> _learningSkills = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _teachController.dispose();
    _learnController.dispose();
    super.dispose();
  }

  // ── Add a teaching skill ───────────────────────────────────────
  void _addTeachingSkill() {
    final skill = _teachController.text.trim();
    if (skill.isEmpty) return;
    if (_teachingSkills.contains(skill)) {
      _teachController.clear();
      return;
    }
    setState(() {
      _teachingSkills.add(skill);
      _teachController.clear();
    });
  }

  // ── Add a learning skill ───────────────────────────────────────
  void _addLearningSkill() {
    final skill = _learnController.text.trim();
    if (skill.isEmpty) return;
    if (_learningSkills.contains(skill)) {
      _learnController.clear();
      return;
    }
    setState(() {
      _learningSkills.add(skill);
      _learnController.clear();
    });
  }

  // ── Remove a skill ─────────────────────────────────────────────
  void _removeTeaching(String skill) {
    setState(() => _teachingSkills.remove(skill));
  }

  void _removeLearning(String skill) {
    setState(() => _learningSkills.remove(skill));
  }

  // ── Save skills to Supabase ────────────────────────────────────
  Future<void> _saveAndContinue() async {
    if (_teachingSkills.isEmpty || _learningSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one skill you have and one you want to learn',
          ),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseService.client;
      final userId = SupabaseService.currentUserId!;

      // Insert teaching skills
      for (final skill in _teachingSkills) {
        await supabase.from('skills').insert({
          'user_id':    userId,
          'name':       skill,
          'category':   SkillModel.detectCategory(skill),
          'is_teaching': true,
        });
      }

      // Insert learning skills
      for (final skill in _learningSkills) {
        await supabase.from('skills').insert({
          'user_id':    userId,
          'name':       skill,
          'category':   SkillModel.detectCategory(skill),
          'is_teaching': false,
        });
      }

      if (!mounted) return;

      // Navigate to home
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: AppSpacing.lg),

                // ── Progress indicator ───────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.indigo,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                const Text(
                  'Step 1 of 2',
                  style: AppTextStyles.label,
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Heading ──────────────────────────────────
                const Text(
                  'What can you teach?',
                  style: AppTextStyles.heading1,
                ),

                const SizedBox(height: AppSpacing.sm),

                const Text(
                  'Add at least 1 skill to get matched with others',
                  style: AppTextStyles.body,
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Skills I Have section ────────────────────
                _buildSectionLabel(
                  '⭐ Skills I Have',
                  AppColors.indigo,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Teaching skill input
                _buildSkillInput(
                  controller: _teachController,
                  hint: 'e.g. Python, UI/UX Design, Marketing',
                  color: AppColors.indigo,
                  onAdd: _addTeachingSkill,
                ),

                const SizedBox(height: AppSpacing.md),

                // Teaching skill chips
                if (_teachingSkills.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _teachingSkills.map((skill) {
                      return _buildChip(
                        skill,
                        AppColors.indigo,
                        () => _removeTeaching(skill),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: AppSpacing.xl),

                // ── Skills I Want to Learn section ───────────
                _buildSectionLabel(
                  '🎯 I Want to Learn',
                  AppColors.coral,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Learning skill input
                _buildSkillInput(
                  controller: _learnController,
                  hint: 'e.g. Flutter, Data Science, Photography',
                  color: AppColors.coral,
                  onAdd: _addLearningSkill,
                ),

                const SizedBox(height: AppSpacing.md),

                // Learning skill chips
                if (_learningSkills.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _learningSkills.map((skill) {
                      return _buildChip(
                        skill,
                        AppColors.coral,
                        () => _removeLearning(skill),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Find Matches button ──────────────────────
                CoralButton(
                  label: 'Find My Matches →',
                  onTap: _isLoading ? null : _saveAndContinue,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Skip link ────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section label builder ──────────────────────────────────────
  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: color,
      ),
    );
  }

  // ── Skill input row builder ────────────────────────────────────
  Widget _buildSkillInput({
    required TextEditingController controller,
    required String hint,
    required Color color,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [

        // Text field
        Expanded(
          child: TextField(
            controller: controller,
            style: AppTextStyles.bodyBold,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Nunito',
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.cardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.sm),

        // Add button
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),

      ],
    );
  }

  // ── Skill chip builder ─────────────────────────────────────────
  Widget _buildChip(String skill, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}