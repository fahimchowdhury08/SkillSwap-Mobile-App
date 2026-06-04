import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/user_model.dart';
import '../../models/skill_model.dart';
import '../../models/review_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/skill_chip.dart';
import '../../widgets/glass_card.dart';
import '../swap/swap_proposal_sheet.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final List<SkillModel> myTeachingSkills;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.myTeachingSkills,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {

  UserModel? _user;
  List<SkillModel> _teachingSkills = [];
  List<SkillModel> _learningSkills = [];
  List<ReviewModel> _reviews       = [];
  bool _isLoading   = true;
  bool _hasError    = false;
  bool _isLiked     = false;
  bool _isSaved     = false;
  bool _isMatched   = false;
  int  _likeCount   = 0;
  String _errorMessage  = '';
  // ignore: unused_field
  String? _matchedSwapId;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _hasError  = false;
    });

    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) {
        setState(() {
          _hasError     = true;
          _errorMessage = 'Not logged in';
          _isLoading    = false;
        });
        return;
      }

      final userRes = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      final skillsRes = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', widget.userId);

      final reviewsRes = await SupabaseService.client
          .from('reviews')
          .select()
          .eq('reviewed_id', widget.userId)
          .order('created_at', ascending: false);

      final likedRes = await SupabaseService.client
          .from('user_likes')
          .select('id')
          .eq('liker_id', currentUserId)
          .eq('liked_id', widget.userId)
          .maybeSingle();

      final savedRes = await SupabaseService.client
          .from('saved_profiles')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('saved_user_id', widget.userId)
          .maybeSingle();

      final matchRes = await SupabaseService.client
          .from('swaps')
          .select('id')
          .eq('status', 'accepted')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)')
          .maybeSingle();

      final likeCountRes = await SupabaseService.client
          .from('user_likes')
          .select('id')
          .eq('liked_id', widget.userId);

      final allSkills = (skillsRes as List)
          .map((j) => SkillModel.fromJson(j))
          .toList();

      setState(() {
        _user           = UserModel.fromJson(userRes);
        _teachingSkills = allSkills.where((s) => s.isTeaching).toList();
        _learningSkills = allSkills.where((s) => !s.isTeaching).toList();
        _reviews        = (reviewsRes as List)
            .map((j) => ReviewModel.fromJson(j))
            .toList();
        _isLiked        = likedRes != null;
        _isSaved        = savedRes != null;
        _isMatched      = matchRes != null;
        _matchedSwapId  = matchRes?['id'] as String?;
        _likeCount      = (likeCountRes as List).length;
        _isLoading      = false;
      });

    } catch (e) {
      debugPrint('Load profile error: $e');
      setState(() {
        _hasError     = true;
        _errorMessage = e.toString();
        _isLoading    = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;
    setState(() {
      _isLiked   = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });
    try {
      if (_isLiked) {
        await SupabaseService.client.from('user_likes').insert({
          'liker_id': currentUserId,
          'liked_id': widget.userId,
        });
      } else {
        await SupabaseService.client
            .from('user_likes')
            .delete()
            .eq('liker_id', currentUserId)
            .eq('liked_id', widget.userId);
      }
    } catch (e) {
      setState(() {
        _isLiked   = !_isLiked;
        _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      });
    }
  }

  Future<void> _toggleSave() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;
    setState(() => _isSaved = !_isSaved);
    try {
      if (_isSaved) {
        await SupabaseService.client.from('saved_profiles').insert({
          'user_id':       currentUserId,
          'saved_user_id': widget.userId,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_user?.displayName} saved!'),
            backgroundColor: AppColors.indigo,
          ),
        );
      } else {
        await SupabaseService.client
            .from('saved_profiles')
            .delete()
            .eq('user_id', currentUserId)
            .eq('saved_user_id', widget.userId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved'),
            backgroundColor: AppColors.indigo,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaved = !_isSaved);
    }
  }

  void _showSwapSheet() {
    if (widget.myTeachingSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add skills you can teach first'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    if (_teachingSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has no skills to offer yet'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SwapProposalSheet(
        receiverId:             widget.userId,
        receiverName:           _user!.displayName,
        receiverTeachingSkills: _teachingSkills,
        myTeachingSkills:       widget.myTeachingSkills,
      ),
    );
  }

  void _goToChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Go to Messages tab to chat'),
        backgroundColor: AppColors.indigo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
        ),
        body: const LoadingSpinner(),
      );
    }

    if (_hasError || _user == null) {
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
          title: const Text('Profile', style: AppTextStyles.heading2),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.coral,
                  size: 56,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Could not load profile',
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _errorMessage,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _loadProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _user!.displayName,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isSaved
                  ? AppColors.indigo
                  : AppColors.textPrimary,
            ),
            onPressed: _toggleSave,
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report/Block — coming soon'),
                  backgroundColor: AppColors.indigo,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatarSection(),
            _buildActionRow(),
            _buildTabSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      width: double.infinity,
      color: AppColors.cardSurface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientAvatar(
            imageUrl: _user!.avatarUrl,
            name: _user!.displayName,
            size: 80,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user!.displayName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_user!.occupation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _user!.occupation!,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (_user!.institution != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 13,
                        color: AppColors.indigo,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _user!.institution!,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_user!.avgRating.toStringAsFixed(1)}  •  ${_reviews.length} reviews',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary,
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

  Widget _buildActionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.elevated),
        ),
      ),
      child: Row(
        children: [

          // Like
          GestureDetector(
            onTap: _toggleLike,
            child: Row(
              children: [
                Icon(
                  _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isLiked
                      ? AppColors.coral
                      : AppColors.textMuted,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_likeCount',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.lg),

          // Save
          GestureDetector(
            onTap: _toggleSave,
            child: Row(
              children: [
                Icon(
                  _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _isSaved
                      ? AppColors.indigo
                      : AppColors.textMuted,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  _isSaved ? 'Saved' : 'Save',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Message (if matched) — fixed width to avoid infinite constraint
          if (_isMatched)
            SizedBox(
              width: 120,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: _goToChat,
                icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                label: const Text(
                  'Message',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),

          // Swap (if not matched) — fixed width to avoid infinite constraint
          if (!_isMatched)
            SizedBox(
              width: 110,
              height: 38,
              child: ElevatedButton(
                onPressed: _showSwapSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Swap →',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Column(
      children: [
        Container(
          color: AppColors.background,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.indigo,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.indigo,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'About'),
              Tab(text: 'Skills'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),
        SizedBox(
          height: 500,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAboutTab(),
              _buildSkillsTab(),
              _buildReviewsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_user!.email.isNotEmpty)
            _buildInfoCard(
              icon: Icons.email_outlined,
              text: _user!.email,
            ),
          if (_user!.linkedinUrl != null &&
              _user!.linkedinUrl!.isNotEmpty)
            _buildInfoCard(
              icon: Icons.link_rounded,
              text: _user!.linkedinUrl!,
            ),
          if (_user!.institution != null)
            _buildInfoCard(
              icon: Icons.school_outlined,
              text: _user!.institution!,
            ),
          if (_user!.occupation != null)
            _buildInfoCard(
              icon: Icons.work_outline_rounded,
              text: _user!.occupation!,
            ),
          if (_user!.email.isEmpty &&
              _user!.linkedinUrl == null &&
              _user!.institution == null &&
              _user!.occupation == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No details added yet',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.indigo),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Skills',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _teachingSkills.isEmpty
              ? const Text(
                  'No teaching skills added yet',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _teachingSkills
                      .map((s) => SkillChip(
                            label: s.name,
                            isVerified: s.isVerified,
                          ))
                      .toList(),
                ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Wants to Learn',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _learningSkills.isEmpty
              ? const Text(
                  'No learning skills added yet',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _learningSkills
                      .map((s) => SkillChip(label: s.name))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) =>
          _buildReviewCard(_reviews[index]),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientAvatar(
                name: review.reviewerDisplayName,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  review.reviewerDisplayName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.gold,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null &&
              review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: review.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.indigo
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: AppColors.indigo,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}