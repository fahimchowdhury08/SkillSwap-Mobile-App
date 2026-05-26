
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/user_model.dart';
import '../../models/skill_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // ── Controllers ───────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _focusNode        = FocusNode();

  // ── State ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _results = [];
  bool _isLoading    = false;
  bool _hasSearched  = false;
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'Same University',
    'Verified',
    'Available Now',
  ];

  @override
  void initState() {
    super.initState();
    // Auto focus the search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Search ─────────────────────────────────────────────────────
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results.clear();
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading   = true;
      _hasSearched = true;
    });

    try {
      final currentUserId = SupabaseService.currentUserId;

      // Find skills matching the search query
      var skillsQuery = SupabaseService.client
          .from('skills')
          .select('user_id, name, is_verified')
          .ilike('name', '%${query.trim()}%')
          .eq('is_teaching', true);

      if (currentUserId != null) {
        skillsQuery = skillsQuery.neq('user_id', currentUserId);
      }

      final skillsRes = await skillsQuery;
      final skillsList = skillsRes as List;

      if (skillsList.isEmpty) {
        setState(() {
          _results.clear();
          _isLoading = false;
        });
        return;
      }

      // Get unique user ids from matched skills
      final userIds = skillsList
          .map((s) => s['user_id'] as String)
          .toSet()
          .toList();

      // Fetch user profiles
      var usersQuery = SupabaseService.client
          .from('users')
          .select()
          .inFilter('id', userIds);

      // Apply filters
      if (_activeFilter == 'Available Now') {
        usersQuery = usersQuery.eq('is_available_now', true);
      }

      final usersRes = await usersQuery;
      final usersList = usersRes as List;

      // Get current user's institution for same university filter
      String? myInstitution;
      if (_activeFilter == 'Same University' && currentUserId != null) {
        final meRes = await SupabaseService.client
            .from('users')
            .select('institution')
            .eq('id', currentUserId)
            .single();
        myInstitution = meRes['institution'] as String?;
      }

      // Build results combining user + matched skill
      final results = <Map<String, dynamic>>[];

      for (final user in usersList) {
        final userModel = UserModel.fromJson(user);

        // Apply same university filter
        if (_activeFilter == 'Same University' &&
            myInstitution != null &&
            userModel.institution != myInstitution) {
          continue;
        }

        // Find the matched skill for this user
        final matchedSkill = skillsList.firstWhere(
          (s) => s['user_id'] == userModel.id,
          orElse: () => {},
        );

        if (matchedSkill.isEmpty) continue;

        final skillModel = SkillModel.fromJson({
          'id':         '',
          'user_id':    userModel.id,
          'name':       matchedSkill['name'],
          'category':   SkillModel.detectCategory(matchedSkill['name']),
          'is_teaching': true,
          'is_verified': matchedSkill['is_verified'] ?? false,
        });

        // Apply verified filter
        if (_activeFilter == 'Verified' && !skillModel.isVerified) continue;

        results.add({
          'user':  userModel,
          'skill': skillModel,
        });
      }

      setState(() => _results = results);

    } catch (e) {
      debugPrint('Search error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search failed. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Debounce timer ─────────────────────────────────────────────
  // Waits 400ms after user stops typing before searching
  Future<void> _onSearchChanged(String value) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_searchController.text == value) {
      await _search(value);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: _buildSearchField(),
        titleSpacing: 0,
      ),
      body: Column(
        children: [

          // ── Filter chips ───────────────────────────────────
          _buildFilterRow(),

          const Divider(color: AppColors.elevated, height: 1),

          // ── Results ────────────────────────────────────────
          Expanded(child: _buildBody()),

        ],
      ),
    );
  }

  // ── Search field ───────────────────────────────────────────────
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      style: AppTextStyles.bodyBold,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      onSubmitted: _search,
      decoration: const InputDecoration(
        hintText: 'Search skills or people...',
        hintStyle: TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Nunito',
          fontSize: 14,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }

  // ── Filter chips row ───────────────────────────────────────────
  Widget _buildFilterRow() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter   = _filters[index];
          final isActive = filter == _activeFilter;
          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = filter);
              if (_searchController.text.isNotEmpty) {
                _search(_searchController.text);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.indigo
                    : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive
                      ? AppColors.indigo
                      : AppColors.elevated,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isActive
                      ? Colors.white
                      : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return const LoadingSpinner();

    if (!_hasSearched) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for a skill',
        subtitle: 'Type a skill name to find people who can teach you',
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No results found',
        subtitle:
            'No one found for "${_searchController.text}" — try a different skill',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Result count ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '${_results.length} ${_results.length == 1 ? 'person' : 'people'} found for "${_searchController.text}"',
            style: AppTextStyles.label,
          ),
        ),

        // ── Result list ──────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            itemCount: _results.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _buildResultCard(
                _results[index]['user'] as UserModel,
                _results[index]['skill'] as SkillModel,
              );
            },
          ),
        ),

      ],
    );
  }

  // ── Result card ────────────────────────────────────────────────
  Widget _buildResultCard(UserModel user, SkillModel skill) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} — coming soon'),
            backgroundColor: AppColors.indigo,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [

            // ── Avatar ────────────────────────────────────
            GradientAvatar(
              imageUrl: user.avatarUrl,
              name: user.displayName,
              size: 52,
            ),

            const SizedBox(width: AppSpacing.md),

            // ── Info ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: AppTextStyles.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.institution != null)
                    Text(
                      user.institution!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  // Matched skill chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      skill.name,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: AppColors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Swap button ───────────────────────────────
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Swap with ${user.displayName} — coming soon',
                    ),
                    backgroundColor: AppColors.coral,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Swap',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}