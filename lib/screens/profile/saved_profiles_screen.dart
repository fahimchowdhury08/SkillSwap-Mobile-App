// lib/screens/profile/saved_profiles_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/skill_model.dart';
import '../../models/user_model.dart';
import '../../supabase_service.dart';
import '../../widgets/gradient_avatar.dart';
import 'user_profile_screen.dart';

class SavedProfilesScreen extends StatefulWidget {
  const SavedProfilesScreen({super.key});

  @override
  State<SavedProfilesScreen> createState() => _SavedProfilesScreenState();
}

class _SavedProfilesScreenState extends State<SavedProfilesScreen> {
  List<_SavedEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSaved();
  }

  Future<void> _fetchSaved() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId!;

      final data = await SupabaseService.client
      .from('saved_profiles')
      .select('*, saved_user:users!saved_profiles_saved_user_id_fkey(*)')
      .eq('user_id', uid)
      .order('created_at', ascending: false);

      final List<_SavedEntry> entries = [];
      for (final row in data as List) {
        final userJson = row['saved_user'] as Map<String, dynamic>?;
        if (userJson == null) continue;
        final user = UserModel.fromJson(userJson);

        final skillsData = await SupabaseService.client
            .from('skills')
            .select()
            .eq('user_id', user.id)
            .eq('is_teaching', true)
            .order('created_at', ascending: true)
            .limit(2);

        final skills = (skillsData as List)
            .map((s) => SkillModel.fromJson(s))
            .toList();

        entries.add(_SavedEntry(user: user, skills: skills));
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load saved profiles: $e')),
        );
      }
    }
  }

  Future<void> _unsave(_SavedEntry entry) async {
    try {
      final uid = SupabaseService.currentUserId!;
      await SupabaseService.client
          .from('saved_profiles')
          .delete()
          .eq('user_id', uid)
          .eq('saved_user_id', entry.user.id);

      if (mounted) {
        setState(() => _entries.remove(entry));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not unsave profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Saved Profiles', style: AppTextStyles.heading3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.indigo),
              )
            : _entries.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: AppColors.indigo,
                    backgroundColor: AppColors.cardSurface,
                    onRefresh: _fetchSaved,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _SavedCard(
                        entry: _entries[i],
                        onUnsave: () => _unsave(_entries[i]),
                        onViewProfile: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: _entries[i].user.id,
                                myTeachingSkills: const [],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_outline,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No saved profiles yet',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Bookmark people you want to revisit and they\'ll appear here.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Find people to save →',
                  style: AppTextStyles.button,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data holder ───────────────────────────────────────────────────────────────

class _SavedEntry {
  final UserModel user;
  final List<SkillModel> skills;
  const _SavedEntry({required this.user, required this.skills});
}

// ── Saved profile card ────────────────────────────────────────────────────────

class _SavedCard extends StatelessWidget {
  final _SavedEntry entry;
  final VoidCallback onUnsave;
  final VoidCallback onViewProfile;

  const _SavedCard({
    required this.entry,
    required this.onUnsave,
    required this.onViewProfile,
  });

  Color _chipColor(String category) {
    switch (category) {
      case 'coding':
        return AppColors.chipPython;
      case 'design':
        return AppColors.chipDesign;
      case 'marketing':
        return AppColors.chipMarketing;
      default:
        return AppColors.chipOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = entry.user;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientAvatar(imageUrl: user.avatarUrl),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  user.fullName ?? 'Unknown',
                  style: AppTextStyles.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Occupation · Institution
                if (user.occupation != null || user.institution != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (user.occupation != null) user.occupation!,
                        if (user.institution != null) user.institution!,
                      ].join(' · '),
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Avg rating
                if (user.avgRating > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.gold, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          user.avgRating.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                // Skill chips
                if (entry.skills.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.skills.map((s) {
                      final color = _chipColor(s.category);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          s.name,
                          style: AppTextStyles.caption
                              .copyWith(color: color),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: AppSpacing.sm),

                // Action row
                Row(
                  children: [
                    // View Profile
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewProfile,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.indigo, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'View Profile →',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.indigo,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    // Unsave (filled bookmark)
                    GestureDetector(
                      onTap: onUnsave,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bookmark,
                          color: AppColors.indigo,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}