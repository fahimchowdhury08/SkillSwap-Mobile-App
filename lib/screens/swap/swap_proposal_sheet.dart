
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/skill_model.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class SwapProposalSheet extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final List<SkillModel> receiverTeachingSkills;
  final List<SkillModel> myTeachingSkills;

  const SwapProposalSheet({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverTeachingSkills,
    required this.myTeachingSkills,
  });

  @override
  State<SwapProposalSheet> createState() => _SwapProposalSheetState();
}

class _SwapProposalSheetState extends State<SwapProposalSheet> {
  // ── State ──────────────────────────────────────────────────────
  SkillModel? _selectedMySkill;       // what I will teach
  SkillModel? _selectedTheirSkill;    // what I will learn
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first skills if available
    if (widget.myTeachingSkills.isNotEmpty) {
      _selectedMySkill = widget.myTeachingSkills.first;
    }
    if (widget.receiverTeachingSkills.isNotEmpty) {
      _selectedTheirSkill = widget.receiverTeachingSkills.first;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ── Check if swap is mutual ────────────────────────────────────
  // Mutual = they teach what I want to learn AND I teach what they want
  bool get _isMutual {
    if (_selectedMySkill == null || _selectedTheirSkill == null) {
      return false;
    }
    return true; // both selected = both benefit
  }

  // ── Match score ────────────────────────────────────────────────
  int get _matchScore => _isMutual ? 90 : 60;

  // ── Send swap proposal ─────────────────────────────────────────
  Future<void> _sendProposal() async {
    if (_selectedMySkill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a skill you will teach'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    if (_selectedTheirSkill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a skill you want to learn'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUserId = SupabaseService.currentUserId!;
      final currentUserRes = await SupabaseService.client
          .from('users')
          .select('full_name')
          .eq('id', currentUserId)
          .single();
      final myName = currentUserRes['full_name'] ?? 'Someone';

      // Insert swap
      await SupabaseService.client.from('swaps').insert({
        'sender_id':      currentUserId,
        'receiver_id':    widget.receiverId,
        'sender_skill':   _selectedMySkill!.name,
        'receiver_skill': _selectedTheirSkill!.name,
        'message':        _messageController.text.trim().isEmpty
                            ? null
                            : _messageController.text.trim(),
        'status':         'pending',
        'match_score':    _matchScore,
      });

      // Send notification to receiver
      await SupabaseService.sendNotification(
        userId: widget.receiverId,
        type:   'swap_received',
        title:  '$myName wants to swap skills with you!',
        body:   'Offers: ${_selectedMySkill!.name} → Wants: ${_selectedTheirSkill!.name}',
        data:   {},
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Swap request sent! ✓'),
          backgroundColor: AppColors.green,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send swap. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left:   AppSpacing.xl,
            right:  AppSpacing.xl,
            top:    AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Handle bar ───────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Title ────────────────────────────────────
              Text(
                'Swap with ${widget.receiverName}',
                style: AppTextStyles.heading2,
              ),

              const SizedBox(height: AppSpacing.xs),

              const Text(
                'Choose what you will teach and what you will learn',
                style: AppTextStyles.body,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── You will teach ───────────────────────────
              const Text(
                'You will teach 👨‍🏫',
                style: AppTextStyles.label,
              ),

              const SizedBox(height: AppSpacing.sm),

              widget.myTeachingSkills.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'You have no teaching skills yet. Add skills in Personal Details.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : _buildSkillDropdown(
                      value: _selectedMySkill,
                      items: widget.myTeachingSkills,
                      onChanged: (skill) =>
                          setState(() => _selectedMySkill = skill),
                    ),

              const SizedBox(height: AppSpacing.lg),

              // ── You will learn ───────────────────────────
              const Text(
                'You will learn 🎓',
                style: AppTextStyles.label,
              ),

              const SizedBox(height: AppSpacing.sm),

              widget.receiverTeachingSkills.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'This user has no teaching skills yet.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : _buildSkillDropdown(
                      value: _selectedTheirSkill,
                      items: widget.receiverTeachingSkills,
                      onChanged: (skill) =>
                          setState(() => _selectedTheirSkill = skill),
                    ),

              const SizedBox(height: AppSpacing.lg),

              // ── Match indicator ──────────────────────────
              _buildMatchIndicator(),

              const SizedBox(height: AppSpacing.lg),

              // ── Optional message ─────────────────────────
              const Text(
                'Add a message (optional)',
                style: AppTextStyles.label,
              ),

              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _messageController,
                maxLines: 3,
                maxLength: 200,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText:
                      'Hi! I would love to swap skills with you...',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Nunito',
                    fontSize: 13,
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
                  counterStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Send button ──────────────────────────────
              CoralButton(
                label: 'Send Swap Proposal',
                icon: Icons.swap_horiz_rounded,
                onTap: _isLoading ? null : _sendProposal,
                isLoading: _isLoading,
              ),

            ],
          ),
        ),
      ),
    );
  }

  // ── Skill dropdown ─────────────────────────────────────────────
  Widget _buildSkillDropdown({
    required SkillModel? value,
    required List<SkillModel> items,
    required ValueChanged<SkillModel?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SkillModel>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.cardSurface,
          style: AppTextStyles.bodyBold,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.indigo,
          ),
          items: items.map((skill) {
            return DropdownMenuItem<SkillModel>(
              value: skill,
              child: Row(
                children: [
                  Text(skill.name),
                  if (skill.isVerified) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.verified,
                      size: 14,
                      color: AppColors.indigo,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Match indicator ────────────────────────────────────────────
  Widget _buildMatchIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _isMutual
            ? AppColors.green.withValues(alpha: 0.1)
            : AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMutual
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.elevated,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isMutual
                ? Icons.sync_rounded
                : Icons.star_outline_rounded,
            color: _isMutual ? AppColors.green : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMutual ? '🔄 Mutual Match' : '⭐ One-way Interest',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _isMutual
                        ? AppColors.green
                        : AppColors.textMuted,
                  ),
                ),
                Text(
                  _isMutual
                      ? 'Both of you benefit from this swap'
                      : 'Select skills on both sides for a mutual match',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _isMutual
                  ? AppColors.green.withValues(alpha: 0.2)
                  : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$_matchScore%',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _isMutual
                    ? AppColors.green
                    : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}