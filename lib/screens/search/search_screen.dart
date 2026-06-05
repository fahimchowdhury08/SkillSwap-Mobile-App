import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/user_model.dart';
import '../../models/skill_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart';
import '../profile/user_profile_screen.dart';
import '../swap/swap_proposal_sheet.dart';
import '../messages/chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode        = FocusNode();

  List<Map<String, dynamic>> _results  = [];
  List<SkillModel> _myTeachingSkills   = [];
  final Set<String> _matchedUserIds    = {};
  final Map<String, String> _swapIds   = {}; // userId -> swapId
  bool _isLoading      = false;
  bool _hasSearched    = false;
  String _activeFilter = 'All';
  String? _myInstitution;
  String? _currentUserId;

  final List<String> _filters = [
    'All',
    'Same University',
    'Verified',
    'Available Now',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
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

  // ── Normalize institution name ─────────────────────────────────
  String? _normalizeInstitution(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toLowerCase().trim();

    const uniMap = <String, String>{
      'lu':    'leading university',
      'l.u':   'leading university',
      'buet':  'buet',
      'nsu':   'north south university',
      'du':    'dhaka university',
      'd.u':   'dhaka university',
      'brac':  'brac university',
      'bracu': 'brac university',
      'sust':  'shahjalal university of science and technology',
      'mu':    'metropolitan university',
      'm.u':   'metropolitan university',
      'sec':   'sylhet engineering college',
      'sau':   'sylhet agriculture university',
      'iut':   'islamic university of technology',
      'ruet':  'rajshahi university of engineering and technology',
      'cuet':  'chittagong university of engineering and technology',
      'ku':    'khulna university',
      'ju':    'jahangirnagar university',
      'ru':    'rajshahi university',
      'cu':    'chittagong university',
      'aust':  'ahsanullah university of science and technology',
      'uiu':   'united international university',
      'iub':   'independent university bangladesh',
      'ewu':   'east west university',
      'aiub':  'american international university bangladesh',
      'diu':   'daffodil international university',
      'pust':  'pabna university of science and technology',
      'hstu':  'hajee mohammad danesh science and technology university',
    };

    if (uniMap.containsKey(cleaned)) return uniMap[cleaned];

    for (final fullName in uniMap.values.toSet()) {
      if (cleaned.length >= 4 &&
          fullName.length >= 4 &&
          cleaned.startsWith(fullName.substring(0, 4))) {
        return fullName;
      }
    }

    return cleaned;
  }

  // ── Load current user data + matched users ─────────────────────
  Future<void> _loadCurrentUser() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      _currentUserId = userId;

      // Load institution
      final res = await SupabaseService.client
          .from('users')
          .select('institution')
          .eq('id', userId)
          .single();
      _myInstitution = _normalizeInstitution(res['institution'] as String?);

      // Load my teaching skills
      final skillsRes = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', userId)
          .eq('is_teaching', true);

      // Load accepted swaps
      final swapsRes = await SupabaseService.client
          .from('swaps')
          .select('id, sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');

      setState(() {
        _myTeachingSkills = (skillsRes as List)
            .map((j) => SkillModel.fromJson(j))
            .toList();

        _matchedUserIds.clear();
        _swapIds.clear();
        for (final row in swapsRes as List) {
          final otherId = row['sender_id'] == userId
              ? row['receiver_id'] as String
              : row['sender_id'] as String;
          _matchedUserIds.add(otherId);
          _swapIds[otherId] = row['id'] as String;
        }
      });
    } catch (e) {
      debugPrint('Load current user error: $e');
    }
  }

  // ── Show all users from same university ────────────────────────
  Future<void> _searchSameUniversity() async {
    if (_myInstitution == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your institution in profile first'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() { _isLoading = true; _hasSearched = true; });

    try {
      final res = await SupabaseService.client
          .from('users')
          .select()
          .neq('id', _currentUserId!);

      final allUsers = (res as List)
          .map((j) => UserModel.fromJson(j))
          .toList();

      final results = <Map<String, dynamic>>[];

      for (final user in allUsers) {
        if (user.institution == null) continue;
        if (_normalizeInstitution(user.institution) != _myInstitution) continue;

        SkillModel? skill;
        try {
          final sr = await SupabaseService.client
              .from('skills')
              .select()
              .eq('user_id', user.id)
              .eq('is_teaching', true)
              .limit(1);
          if ((sr as List).isNotEmpty) {
            skill = SkillModel.fromJson(sr.first);
          }
        } catch (_) {}

        results.add({'user': user, 'skill': skill});
      }

      setState(() => _results = results);

    } catch (e) {
      debugPrint('Same university search error: $e');
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

  // ── Search by skill name OR user name ─────────────────────────
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results.clear(); _hasSearched = false; });
      return;
    }

    setState(() { _isLoading = true; _hasSearched = true; });

    try {
      final q = query.trim();

      // Step 1 — Find users by full name
      var nameQuery = SupabaseService.client
          .from('users')
          .select()
          .ilike('full_name', '%$q%');
      if (_currentUserId != null) {
        nameQuery = nameQuery.neq('id', _currentUserId!);
      }
      final nameRes     = await nameQuery;
      final usersByName = (nameRes as List)
          .map((j) => UserModel.fromJson(j))
          .toList();

      // Step 2 — Find users by skill name
      var skillQuery = SupabaseService.client
          .from('skills')
          .select('user_id, name, is_verified, category')
          .ilike('name', '%$q%')
          .eq('is_teaching', true);
      if (_currentUserId != null) {
        skillQuery = skillQuery.neq('user_id', _currentUserId!);
      }
      final skillsRes  = await skillQuery;
      final skillsList = skillsRes as List;

      final skillUserIds = skillsList
          .map((s) => s['user_id'] as String)
          .toSet()
          .toList();

      List<UserModel> usersBySkill = [];
      if (skillUserIds.isNotEmpty) {
        final usersRes = await SupabaseService.client
            .from('users')
            .select()
            .inFilter('id', skillUserIds);
        usersBySkill = (usersRes as List)
            .map((j) => UserModel.fromJson(j))
            .toList();
      }

      // Step 3 — Merge and deduplicate
      final allUsers = <String, UserModel>{};
      for (final u in usersByName)  { allUsers[u.id] = u; }
      for (final u in usersBySkill) { allUsers[u.id] = u; }

      // Step 4 — Build results
      final results = <Map<String, dynamic>>[];

      for (final user in allUsers.values) {

        // Same University filter
        if (_activeFilter == 'Same University') {
          if (_myInstitution == null) continue;
          if (user.institution == null) continue;
          if (_normalizeInstitution(user.institution) != _myInstitution) continue;
        }

        // Find matched skill
        SkillModel? matchedSkill;
        final userSkillMatch = skillsList.firstWhere(
          (s) => s['user_id'] == user.id,
          orElse: () => <String, dynamic>{},
        );

        if (userSkillMatch.isNotEmpty) {
          matchedSkill = SkillModel.fromJson({
            'id':          '',
            'user_id':     user.id,
            'name':        userSkillMatch['name'],
            'category':    userSkillMatch['category'] ??
                SkillModel.detectCategory(userSkillMatch['name'] as String),
            'is_teaching': true,
            'is_verified': userSkillMatch['is_verified'] ?? false,
            'created_at':  DateTime.now().toIso8601String(),
          });
        } else {
          try {
            final sr = await SupabaseService.client
                .from('skills')
                .select()
                .eq('user_id', user.id)
                .eq('is_teaching', true)
                .limit(1);
            if ((sr as List).isNotEmpty) {
              matchedSkill = SkillModel.fromJson(sr.first);
            }
          } catch (_) {}
        }

        // Verified filter
        if (_activeFilter == 'Verified') {
          if (matchedSkill == null || !matchedSkill.isVerified) continue;
        }

        results.add({'user': user, 'skill': matchedSkill});
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

  Future<void> _onSearchChanged(String value) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_searchController.text == value) await _search(value);
  }

  // ── Show swap sheet ────────────────────────────────────────────
  Future<void> _showSwapSheet(UserModel otherUser) async {
    try {
      final skillsRes = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', otherUser.id)
          .eq('is_teaching', true);

      final theirSkills = (skillsRes as List)
          .map((j) => SkillModel.fromJson(j))
          .toList();

      if (!mounted) return;

      if (_myTeachingSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add skills you can teach first'),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      if (theirSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This user has no teaching skills yet'),
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
          receiverId:             otherUser.id,
          receiverName:           otherUser.displayName,
          receiverTeachingSkills: theirSkills,
          myTeachingSkills:       _myTeachingSkills,
        ),
      );
    } catch (e) {
      debugPrint('Show swap sheet error: $e');
    }
  }

  // ── Open chat directly ─────────────────────────────────────────
  void _openChat(UserModel user) {
    final swapId = _swapIds[user.id];
    if (swapId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(swapId: swapId, otherUser: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildSearchField(),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          const Divider(color: AppColors.elevated, height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

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
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter   = _filters[index];
          final isActive = filter == _activeFilter;
          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = filter);
              if (_searchController.text.isNotEmpty) {
                _search(_searchController.text);
              } else if (filter == 'Same University') {
                _searchSameUniversity();
              } else if (filter == 'All') {
                setState(() { _results.clear(); _hasSearched = false; });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isActive ? AppColors.indigo : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? AppColors.indigo : AppColors.elevated,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isActive ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingSpinner();

    if (!_hasSearched) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for anyone',
        subtitle: 'Search by skill name or person name',
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No results found',
        subtitle: _activeFilter == 'Same University'
            ? 'No one from your university found'
            : 'No one found for "${_searchController.text}"',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '${_results.length} ${_results.length == 1 ? 'person' : 'people'} found'
            '${_activeFilter == 'Same University' ? ' from your university' : ''}',
            style: AppTextStyles.label,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _results.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _buildResultCard(
                _results[index]['user']  as UserModel,
                _results[index]['skill'] as SkillModel?,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(UserModel user, SkillModel? skill) {
    final isMatched = _matchedUserIds.contains(user.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            userId: user.id,
            myTeachingSkills: _myTeachingSkills,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [

            GradientAvatar(
              imageUrl: user.avatarUrl,
              name: user.displayName,
              size: 52,
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: AppTextStyles.bodyBold,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (user.institution != null)
                    Row(
                      children: [
                        const Icon(Icons.school_outlined,
                            size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(user.institution!,
                              style: AppTextStyles.caption,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  if (user.occupation != null)
                    Text(user.occupation!, style: AppTextStyles.caption,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text(user.avgRating.toStringAsFixed(1),
                          style: AppTextStyles.caption),
                    ],
                  ),
                  if (skill != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (skill.isVerified) ...[
                            const Icon(Icons.verified,
                                size: 10, color: AppColors.indigo),
                            const SizedBox(width: 3),
                          ],
                          Text(skill.name,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: AppColors.indigo,
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // ── Message or Swap button ─────────────────────
            SizedBox(
              width: 80,
              child: isMatched

                  // Already matched — Message button
                  ? ElevatedButton.icon(
                      onPressed: () => _openChat(user),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 11),
                      label: const Text(
                        'Chat',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    )

                  // Not matched — Swap button
                  : ElevatedButton(
                      onPressed: () => _showSwapSheet(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
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
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),

          ],
        ),
      ),
    );
  }
}