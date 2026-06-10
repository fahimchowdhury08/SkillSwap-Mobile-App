// lib/screens/profile/my_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme.dart';
import '../../models/skill_model.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../supabase_service.dart';
import '../menu/personal_details_screen.dart';
import 'saved_profiles_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  UserModel? _user;
  List<SkillModel> _teachingSkills = [];
  List<SkillModel> _learningSkills = [];
  List<ReviewModel> _reviews = [];
  int _totalSwaps = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId!;

      final userData = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', uid)
          .single();

      final skillsData = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      final reviewsData = await SupabaseService.client
          .from('reviews')
          .select()
          .eq('reviewed_id', uid)
          .order('created_at', ascending: false);

      final swapsData = await SupabaseService.client
          .from('swaps')
          .select('id')
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .eq('status', 'accepted');

      if (mounted) {
        final allSkills = (skillsData as List)
            .map((s) => SkillModel.fromJson(s))
            .toList();
        setState(() {
          _user = UserModel.fromJson(userData);
          _teachingSkills =
              allSkills.where((s) => s.isTeaching).toList();
          _learningSkills =
              allSkills.where((s) => !s.isTeaching).toList();
          _reviews = (reviewsData as List)
              .map((r) => ReviewModel.fromJson(r))
              .toList();
          _totalSwaps = (swapsData as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e')),
        );
      }
    }
  }

  List<String> _availabilityChips(dynamic availability) {
    if (availability == null) return [];
    final map = availability as Map<String, dynamic>;
    final chips = <String>[];
    const dayMap = {
      'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
      'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
    };
    const slotMap = {
      'morning': '🌅 Morning',
      'afternoon': '☀️ Afternoon',
      'evening': '🌙 Evening',
    };
    map.forEach((day, slots) {
      if (slots is List) {
        for (final slot in slots) {
          final d = dayMap[day.toLowerCase()] ?? day;
          final s = slotMap[slot.toString().toLowerCase()] ?? slot;
          chips.add('$d $s');
        }
      }
    });
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.indigo),
        ),
      );
    }

    final user = _user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Could not load profile.',
              style: AppTextStyles.body),
        ),
      );
    }

    final availChips = _availabilityChips(user.availability);
    final recentReviews = _reviews.take(2).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.indigo,
        backgroundColor: AppColors.cardSurface,
        onRefresh: _fetchProfile,
        child: CustomScrollView(
          slivers: [
            // ── Hero SliverAppBar ─────────────────────────────
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppColors.background,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PersonalDetailsScreen()),
                    );
                    _fetchProfile();
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    user.avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _HeroBg(name: user.fullName),
                          )
                        : _HeroBg(name: user.fullName),
                    // Gradient overlay
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1.0],
                          colors: [
                            Colors.transparent,
                            AppColors.background,
                          ],
                        ),
                      ),
                    ),
                    // Name + meta
                    Positioned(
                      bottom: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName ?? 'My Profile',
                            style: AppTextStyles.heading1,
                          ),
                          if (user.occupation != null ||
                              user.institution != null)
                            Text(
                              [
                                if (user.occupation != null)
                                  user.occupation!,
                                if (user.institution != null)
                                  user.institution!,
                              ].join(' · '),
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // ── Stats row ─────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: _totalSwaps.toString(),
                            label: 'Total Swaps',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            value: user.avgRating > 0
                                ? user.avgRating.toStringAsFixed(1)
                                : '—',
                            label: 'Avg Rating',
                            showStar: user.avgRating > 0,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── My Skills ─────────────────────────────
                    const Text('My Skills', style: AppTextStyles.heading3),
                    const SizedBox(height: AppSpacing.sm),

                    _teachingSkills.isEmpty
                        ? _DashedChip(
                            label: '+ Add Teaching Skill',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PersonalDetailsScreen()),
                              );
                              _fetchProfile();
                            },
                          )
                        : Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              ..._teachingSkills
                                  .map((s) => _SkillPill(skill: s)),
                              _DashedChip(
                                label: '+ Add Skill',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PersonalDetailsScreen()),
                                  );
                                  _fetchProfile();
                                },
                              ),
                            ],
                          ),

                    if (_learningSkills.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Text('Wants to Learn',
                          style: AppTextStyles.label),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _learningSkills
                            .map((s) => _SkillPill(
                                skill: s, isLearning: true))
                            .toList(),
                      ),
                    ],

                    if (availChips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Text('Availability',
                          style: AppTextStyles.label),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: availChips
                            .map((c) => _AvailChip(label: c))
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // ── Reviews ───────────────────────────────
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reviews',
                            style: AppTextStyles.heading3),
                        if (_reviews.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.gold, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${user.avgRating.toStringAsFixed(1)} · ${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    if (recentReviews.isEmpty)
                      const Text(
                        'No reviews yet. Complete a session to get your first review!',
                        style: AppTextStyles.body,
                      )
                    else ...[
                      ...recentReviews
                          .map((r) => _ReviewCard(review: r)),
                      if (_reviews.length > 2)
                        TextButton(
                          onPressed: () =>
                              showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.cardSurface,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (_) => _AllReviewsSheet(
                                reviews: _reviews),
                          ),
                          child: Text(
                            'See All ${_reviews.length} Reviews →',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.indigo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // ── Achievements ──────────────────────────
                    const Text('Achievements',
                        style: AppTextStyles.heading3),
                    const SizedBox(height: AppSpacing.sm),
                    _CertGrid(skills: _teachingSkills),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Saved Profiles ────────────────────────
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const SavedProfilesScreen()),
                      ),
                      icon: const Icon(Icons.bookmark_outline,
                          color: AppColors.indigo, size: 18),
                      label: const Text(
                        'Saved Profiles',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          color: AppColors.indigo,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.indigo, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero gradient background ──────────────────────────────────────────────────

class _HeroBg extends StatelessWidget {
  final String? name;
  const _HeroBg({this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigo, Color(0xFF2D1F8F)],
        ),
      ),
      child: Center(
        child: Text(
          name?.isNotEmpty == true ? name![0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 80,
            color: Colors.white24,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool showStar;

  const _StatCard({
    required this.value,
    required this.label,
    this.showStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showStar) ...[
                const Icon(Icons.star_rounded,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 4),
              ],
              Text(value, style: AppTextStyles.heading1),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ── Skill pill ────────────────────────────────────────────────────────────────

class _SkillPill extends StatelessWidget {
  final SkillModel skill;
  final bool isLearning;
  const _SkillPill({required this.skill, this.isLearning = false});

  Color _color() {
    if (isLearning) return AppColors.textMuted;
    switch (skill.category) {
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
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill.name,
            style: AppTextStyles.label.copyWith(color: color),
          ),
          if (skill.isVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified, color: color, size: 12),
          ],
        ],
      ),
    );
  }
}

// ── Dashed add-skill chip ─────────────────────────────────────────────────────

class _DashedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DashedChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.indigo.withValues(alpha: 0.5),
              width: 1.5),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.indigo,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Availability chip ─────────────────────────────────────────────────────────

class _AvailChip extends StatelessWidget {
  final String label;
  const _AvailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Text(label, style: AppTextStyles.caption),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: i < review.rating
                      ? AppColors.gold
                      : AppColors.elevated,
                  size: 16,
                ),
              ),
              const Spacer(),
              Text(
                timeago.format(review.createdAt),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              children: review.tags
                  .map((t) => _TagPill(label: t))
                  .toList(),
            ),
          ],
          if (review.comment != null &&
              review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!,
              style: AppTextStyles.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.indigo),
      ),
    );
  }
}

// ── All reviews sheet ─────────────────────────────────────────────────────────

class _AllReviewsSheet extends StatelessWidget {
  final List<ReviewModel> reviews;
  const _AllReviewsSheet({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('All Reviews', style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: reviews.length,
                itemBuilder: (_, i) =>
                    _ReviewCard(review: reviews[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Certificates grid ─────────────────────────────────────────────────────────

class _CertGrid extends StatelessWidget {
  final List<SkillModel> skills;
  const _CertGrid({required this.skills});

  @override
  Widget build(BuildContext context) {
    final verified = skills
        .where((s) => s.isVerified && s.certificateUrl != null)
        .toList();

    if (verified.isEmpty) {
      return const Text(
        'No certificates yet. Verify a skill to earn one!',
        style: AppTextStyles.body,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
      ),
      itemCount: verified.length,
      itemBuilder: (_, i) {
        final skill = verified[i];
        return GestureDetector(
          onTap: () async {
            final url = Uri.tryParse(skill.certificateUrl ?? '');
            if (url != null && await canLaunchUrl(url)) {
              await launchUrl(url,
                  mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.indigo.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_outlined,
                    color: AppColors.indigo, size: 28),
                const SizedBox(height: 4),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    skill.name,
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}