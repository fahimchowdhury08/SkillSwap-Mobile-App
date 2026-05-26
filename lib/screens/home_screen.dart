import 'package:flutter/material.dart';
import '../theme.dart';
import '../supabase_service.dart';
import '../models/user_model.dart';
import '../models/skill_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_spinner.dart';
import 'menu/hamburger_menu_drawer.dart';
import 'profile_setup/profile_setup_step2_screen.dart';
import 'search/search_screen.dart';
import 'profile/user_profile_screen.dart';
import 'swap/swap_screen.dart';
import 'notification_screen.dart';
import 'messages/messages_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex              = 0;
  bool _isLoading                = true;
  List<UserModel> _matches       = [];
  final List<SkillModel> _myTeachingSkills = [];
  bool _isProfileComplete        = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadCurrentUser(),
        _loadMatches(),
      ]);
    } catch (e) {
      debugPrint('Home load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final res = await SupabaseService.client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    final user = UserModel.fromJson(res);

    final skillsRes = await SupabaseService.client
        .from('skills')
        .select()
        .eq('user_id', userId);

    final skills = (skillsRes as List)
        .map((j) => SkillModel.fromJson(j))
        .toList();

    _myTeachingSkills.clear();
    _myTeachingSkills.addAll(skills.where((s) => s.isTeaching));

    setState(() {
      _isProfileComplete = user.fullName != null &&
          user.institution != null &&
          skills.length >= 2;
    });
  }

  Future<void> _loadMatches() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final learningRes = await SupabaseService.client
        .from('skills')
        .select('name')
        .eq('user_id', userId)
        .eq('is_teaching', false);

    final learningSkills = (learningRes as List)
        .map((j) => j['name'] as String)
        .toList();

    if (learningSkills.isEmpty) return;

    final matchedSkillsRes = await SupabaseService.client
        .from('skills')
        .select('user_id')
        .eq('is_teaching', true)
        .inFilter('name', learningSkills)
        .neq('user_id', userId);

    final matchedUserIds = (matchedSkillsRes as List)
        .map((j) => j['user_id'] as String)
        .toSet()
        .toList();

    if (matchedUserIds.isEmpty) return;

    final usersRes = await SupabaseService.client
        .from('users')
        .select()
        .inFilter('id', matchedUserIds);

    setState(() {
      _matches = (usersRes as List)
          .map((j) => UserModel.fromJson(j))
          .toList();
    });
  }

  // ── Bottom nav screens ─────────────────────────────────────────
  // TODO: Replace placeholders with real screens as they are built
  List<Widget> get _screens => [
    _buildHomeFeed(),
    const SwapScreen(),
    const MessagesScreen(),
    const _PlaceholderScreen(label: 'My Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const HamburgerMenuDrawer(),
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
      body: _isLoading
          ? const LoadingSpinner()
          : _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App bar ────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.indigoCoralGradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'SkillSwap',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Home feed ──────────────────────────────────────────────────
  Widget _buildHomeFeed() {
    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.cardSurface,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Profile completion banner ──────────────────
            if (!_isProfileComplete) _buildCompletionBanner(),

            // ── Search bar ─────────────────────────────────
            _buildSearchBar(),

            const SizedBox(height: AppSpacing.lg),

            // ── Heading ────────────────────────────────────
            const Text(
              'Matched for You 🔥',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _matches.isEmpty
                  ? 'Add learning skills to see matches'
                  : 'People who can teach what you want to learn',
              style: AppTextStyles.body,
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Grid ───────────────────────────────────────
            _matches.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No matches yet',
                    subtitle: 'Add skills you want to learn to get matched',
                    buttonLabel: 'Update Skills',
                    onButtonTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile setup — coming soon'),
                          backgroundColor: AppColors.indigo,
                        ),
                      );
                    },
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      return _buildProfileCard(_matches[index]);
                    },
                  ),

            const SizedBox(height: AppSpacing.xl),

          ],
        ),
      ),
    );
  }

  // ── Profile completion banner ──────────────────────────────────
  Widget _buildCompletionBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileSetupStep2Screen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.indigo.withValues(alpha: 0.2),
              AppColors.coral.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.indigo.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.coral, size: 24),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Complete your profile for 3x more swaps ⚡',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SearchScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.elevated),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Search skills or people...',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile card ───────────────────────────────────────────────
  Widget _buildProfileCard(UserModel user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: user.id,
              myTeachingSkills: _myTeachingSkills,
            ),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Center(
              child: GradientAvatar(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                size: 64,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Center(
              child: Text(
                user.displayName,
                style: AppTextStyles.bodyBold,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (user.occupation != null)
              Center(
                child: Text(
                  user.occupation!,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const Spacer(),

            if (user.institution != null)
              Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      user.institution!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  user.avgRating.toStringAsFixed(1),
                  style: AppTextStyles.caption,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: user.id,
                        myTeachingSkills: _myTeachingSkills,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
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
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      backgroundColor: AppColors.cardSurface,
      selectedItemColor: AppColors.indigo,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 11,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.swap_horiz_outlined),
          activeIcon: Icon(Icons.swap_horiz_rounded),
          label: 'Swap',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          activeIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}

// ── Temporary placeholder screens ─────────────────────────────────
// These will be replaced one by one as real screens are built
// Do NOT remove these until the real screen is ready

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          '$label — Coming Soon',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontFamily: 'Nunito',
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

