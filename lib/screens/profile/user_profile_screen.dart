
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  // ── State ──────────────────────────────────────────────────────
  UserModel? _user;
  List<SkillModel> _teachingSkills = [];
  List<SkillModel> _learningSkills = [];
  List<ReviewModel> _reviews       = [];
  bool _isLoading   = false;
  bool _isLiked     = false;
  bool _isSaved     = false;
  bool _isMatched   = false;
  int  _likeCount   = 0;
  String? _matchedSwapId;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load all profile data ──────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) return;

      // 1. Fetch user data
      final userRes = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      // 2. Fetch their skills
      final skillsRes = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', widget.userId);

      // 3. Fetch their reviews
      final reviewsRes = await SupabaseService.client
          .from('reviews')
          .select()
          .eq('reviewed_id', widget.userId)
          .order('created_at', ascending: false);

      // 4. Check liked
      final likedRes = await SupabaseService.client
          .from('user_likes')
          .select('id')
          .eq('liker_id', currentUserId)
          .eq('liked_id', widget.userId)
          .maybeSingle();

      // 5. Check saved
      final savedRes = await SupabaseService.client
          .from('saved_profiles')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('saved_user_id', widget.userId)
          .maybeSingle();

      // 6. Check matched
      final matchRes = await SupabaseService.client
          .from('swaps')
          .select('id')
          .eq('status', 'accepted')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)')
          .maybeSingle();

      // 7. Like count
      final likeCountRes = await SupabaseService.client
          .from('user_likes')
          .select('id')
          .eq('liked_id', widget.userId);

      setState(() {
        _user          = UserModel.fromJson(userRes);
        _teachingSkills = (skillsRes as List)
            .map((j) => SkillModel.fromJson(j))
            .where((s) => s.isTeaching)
            .toList();
        _learningSkills = (skillsRes as List)
            .map((j) => SkillModel.fromJson(j))
            .where((s) => !s.isTeaching)
            .toList();
        _reviews       = (reviewsRes as List)
            .map((j) => ReviewModel.fromJson(j))
            .toList();
        _isLiked       = likedRes != null;
        _isSaved       = savedRes != null;
        _isMatched     = matchRes != null;
        _matchedSwapId = matchRes?['id'] as String?;
        _likeCount     = (likeCountRes as List).length;
      });
    } catch (e) {
      debugPrint('Load profile error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Toggle like ────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    setState(() {
      _isLiked  = !_isLiked;
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
      // Revert on error
      setState(() {
        _isLiked  = !_isLiked;
        _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      });
    }
  }

  // ── Toggle save ────────────────────────────────────────────────
  Future<void> _toggleSave() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    setState(() => _isSaved = !_isSaved);

    try {
      if (_isSaved) {
        await SupabaseService.client.from('saved_profiles').insert({
          'user_id':      currentUserId,
          'saved_user_id': widget.userId,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_user?.displayName} saved!',
            ),
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

  // ── Show swap proposal sheet ───────────────────────────────────
  void _showSwapSheet() {
    if (widget.myTeachingSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add skills you can teach first',
          ),
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

    // TODO: replace with real sheet when built
    // showModalBottomSheet(context: context,
    //   builder: (_) => SwapProposalSheet(...));
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

  // ── Go to chat ────────────────────────────────────────────────
  void _goToChat() {
    if (!_isMatched || _matchedSwapId == null) return;
    // TODO: replace with real chat when built
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => ChatScreen(
    //     swapId: _matchedSwapId!, otherUser: _user!)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat — coming soon'),
        backgroundColor: AppColors.indigo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const LoadingSpinner()
          : _user == null
              ? const Center(
                  child: Text(
                    'Profile not found',
                    style: AppTextStyles.body,
                  ),
                )
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        _buildHeroSliver(),
      ],
      body: Column(
        children: [

          // ── Action row ─────────────────────────────────
          _buildActionRow(),

          // ── Tab bar ────────────────────────────────────
          TabBar(
            controller: _tabController,
            labelColor: AppColors.indigo,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.indigo,
            labelStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            tabs: const [
              Tab(text: 'About'),
              Tab(text: 'Skills'),
              Tab(text: 'Reviews'),
              Tab(text: 'Certs'),
            ],
          ),

          // ── Tab content ────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(),
                _buildSkillsTab(),
                _buildReviewsTab(),
                _buildCertsTab(),
              ],
            ),
          ),

        ],
      ),
    );
  }

  // ── Hero sliver ────────────────────────────────────────────────
  SliverAppBar _buildHeroSliver() {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
        ),
      ),
      actions: [
        // Report / Block button
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report/Block — coming soon'),
                backgroundColor: AppColors.indigo,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.cardSurface,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.more_vert_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [

            // Avatar background
            _user!.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: _user!.avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.cardSurface,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.cardSurface,
                      child: Center(
                        child: GradientAvatar(
                          name: _user!.displayName,
                          size: 100,
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.cardSurface,
                    child: Center(
                      child: GradientAvatar(
                        name: _user!.displayName,
                        size: 100,
                      ),
                    ),
                  ),

            // Dark gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.darkHeroGradient,
              ),
            ),

            // Name and occupation at bottom
            Positioned(
              bottom: AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user!.displayName,
                    style: AppTextStyles.heading1,
                  ),
                  if (_user!.occupation != null)
                    Text(
                      _user!.occupation!,
                      style: AppTextStyles.body,
                    ),
                  if (_user!.institution != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _user!.institution!,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ── Action row ─────────────────────────────────────────────────
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

          // ── Like button ──────────────────────────────
          GestureDetector(
            onTap: _toggleLike,
            child: Column(
              children: [
                Icon(
                  _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isLiked ? AppColors.coral : AppColors.textMuted,
                  size: 24,
                ),
                Text(
                  '$_likeCount',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.lg),

          // ── Save button ──────────────────────────────
          GestureDetector(
            onTap: _toggleSave,
            child: Column(
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
                Text(
                  _isSaved ? 'Saved' : 'Save',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Swap button ──────────────────────────────
          if (!_isMatched)
            ElevatedButton(
              onPressed: _showSwapSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
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

          if (_isMatched) ...[
            const SizedBox(width: AppSpacing.sm),
            // ── Message button ────────────────────────
            ElevatedButton.icon(
              onPressed: _goToChat,
              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
              label: const Text(
                'Message',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],

        ],
      ),
    );
  }

  // ── About tab ──────────────────────────────────────────────────
  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Rating
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.gold,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _user!.avgRating.toStringAsFixed(1),
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '(${_reviews.length} reviews)',
                style: AppTextStyles.caption,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Info rows
          if (_user!.institution != null)
            _buildInfoRow(
              icon: Icons.school_outlined,
              text: _user!.institution!,
            ),
          if (_user!.occupation != null)
            _buildInfoRow(
              icon: Icons.work_outline_rounded,
              text: _user!.occupation!,
            ),
          if (_user!.email.isNotEmpty)
            _buildInfoRow(
              icon: Icons.email_outlined,
              text: _user!.email,
            ),

        ],
      ),
    );
  }

  // ── Skills tab ─────────────────────────────────────────────────
  Widget _buildSkillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text('Can Teach', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          _teachingSkills.isEmpty
              ? const Text('No teaching skills', style: AppTextStyles.body)
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _teachingSkills.map((s) => SkillChip(
                    label: s.name,
                    isVerified: s.isVerified,
                  )).toList(),
                ),

          const SizedBox(height: AppSpacing.xl),

          const Text('Wants to Learn', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          _learningSkills.isEmpty
              ? const Text('No learning skills', style: AppTextStyles.body)
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _learningSkills.map((s) => SkillChip(
                    label: s.name,
                  )).toList(),
                ),

        ],
      ),
    );
  }

  // ── Reviews tab ────────────────────────────────────────────────
  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(
        child: Text('No reviews yet', style: AppTextStyles.body),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return _buildReviewCard(_reviews[index]);
      },
    );
  }

  // ── Review card ────────────────────────────────────────────────
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
                  style: AppTextStyles.bodyBold,
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
          if (review.comment != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(review.comment!, style: AppTextStyles.body),
          ],
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: review.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.indigo,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Certs tab ──────────────────────────────────────────────────
  Widget _buildCertsTab() {
    final verifiedSkills = _teachingSkills
        .where((s) => s.isVerified && s.certificateUrl != null)
        .toList();

    if (verifiedSkills.isEmpty) {
      return const Center(
        child: Text(
          'No certificates uploaded yet',
          style: AppTextStyles.body,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: verifiedSkills.length,
      itemBuilder: (context, index) {
        final skill = verifiedSkills[index];
        return GlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.indigo,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                skill.name,
                style: AppTextStyles.bodyBold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Certificate uploaded',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Info row ───────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}