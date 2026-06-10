
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skill_chip.dart';

class AdminActionsScreen extends StatefulWidget {
  final String communityId;

  const AdminActionsScreen({super.key, required this.communityId});

  @override
  State<AdminActionsScreen> createState() => _AdminActionsScreenState();
}

class _AdminActionsScreenState extends State<AdminActionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _pending  = [];
  List<Map<String, dynamic>> _members  = [];
  bool _isLoadingPending = true;
  bool _isLoadingMembers = true;
  bool _membersLoaded    = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_membersLoaded) {
        _loadMembers();
      }
    });
    _loadPending();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load pending requests ──────────────────────────────────────
  Future<void> _loadPending() async {
    setState(() => _isLoadingPending = true);
    try {
      final res = await SupabaseService.client
          .from('community_members')
          .select()
          .eq('community_id', widget.communityId)
          .eq('status', 'pending')
          .order('joined_at', ascending: true);

      final List<Map<String, dynamic>> items = [];
      for (final row in res as List) {
        final userId = row['user_id'] as String;
        final userRes = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', userId)
            .single();

        // Fetch their teaching skills (up to 4)
        final skillsRes = await SupabaseService.client
            .from('skills')
            .select('name')
            .eq('user_id', userId)
            .eq('is_teaching', true)
            .limit(4);

        final skills = (skillsRes as List)
            .map((s) => s['name'] as String)
            .toList();

        // Parse answers from JSONB
        final answers = Map<String, dynamic>.from(row['answers'] ?? {});

        items.add({
          'member': row,
          'user':   userRes,
          'skills': skills,
          'answers': answers,
        });
      }

      setState(() {
        _pending = items;
        _isLoadingPending = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  // ── Load members ───────────────────────────────────────────────
  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final uid = SupabaseService.currentUserId;
      final res = await SupabaseService.client
          .from('community_members')
          .select()
          .eq('community_id', widget.communityId)
          .eq('status', 'member')
          .order('joined_at', ascending: true);

      final List<Map<String, dynamic>> items = [];
      for (final row in res as List) {
        final userId = row['user_id'] as String;
        if (userId == uid) continue; // skip self

        final userRes = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', userId)
            .single();

        items.add({'member': row, 'user': userRes});
      }

      setState(() {
        _members = items;
        _isLoadingMembers = false;
        _membersLoaded    = true;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  // ── Accept ─────────────────────────────────────────────────────
  Future<void> _accept(Map<String, dynamic> item) async {
    try {
      final member = item['member'] as Map<String, dynamic>;
      final user   = item['user']   as Map<String, dynamic>;
      final userId = member['user_id'] as String;

      await SupabaseService.client
          .from('community_members')
          .update({'status': 'member'})
          .eq('community_id', widget.communityId)
          .eq('user_id', userId);

      // Increment member count (try RPC first, fallback manual)
      try {
        await SupabaseService.client.rpc('increment_member_count',
            params: {'community_id': widget.communityId});
      } catch (_) {
        final commRes = await SupabaseService.client
            .from('communities')
            .select('member_count')
            .eq('id', widget.communityId)
            .single();
        final current = commRes['member_count'] as int? ?? 0;
        await SupabaseService.client
            .from('communities')
            .update({'member_count': current + 1})
            .eq('id', widget.communityId);
      }

      // Notify user
      final commRes = await SupabaseService.client
          .from('communities')
          .select('name')
          .eq('id', widget.communityId)
          .single();

      await SupabaseService.sendNotification(
        userId: userId,
        type:   'community_approved',
        title:  'You\'re in! ${commRes['name']} approved you 🎉',
        body:   'Welcome to the community! Start exploring posts.',
        data:   {'community_id': widget.communityId},
      );

      setState(() => _pending.remove(item));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['full_name'] ?? 'User'} approved!'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Reject ─────────────────────────────────────────────────────
  Future<void> _reject(Map<String, dynamic> item) async {
    try {
      final member = item['member'] as Map<String, dynamic>;
      final userId = member['user_id'] as String;

      await SupabaseService.client
          .from('community_members')
          .update({'status': 'rejected'})
          .eq('community_id', widget.communityId)
          .eq('user_id', userId);

      setState(() => _pending.remove(item));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: AppColors.indigo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Remove member ──────────────────────────────────────────────
  Future<void> _removeMember(Map<String, dynamic> item) async {
    final member = item['member'] as Map<String, dynamic>;
    final user   = item['user']   as Map<String, dynamic>;
    final userId = member['user_id'] as String;
    final role   = member['role']   as String? ?? 'member';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          role == 'moderator' ? 'Remove Moderator' : 'Remove Member',
          style: AppTextStyles.heading3,
        ),
        content: Text(
          '${user['full_name']} will be removed from this community.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.red, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client
          .from('community_members')
          .update({'status': 'removed'})
          .eq('community_id', widget.communityId)
          .eq('user_id', userId);

      // Decrement count
      try {
        await SupabaseService.client.rpc('decrement_member_count',
            params: {'community_id': widget.communityId});
      } catch (_) {
        final commRes = await SupabaseService.client
            .from('communities')
            .select('member_count')
            .eq('id', widget.communityId)
            .single();
        final current = commRes['member_count'] as int? ?? 1;
        await SupabaseService.client
            .from('communities')
            .update({'member_count': (current - 1).clamp(0, 99999)})
            .eq('id', widget.communityId);
      }

      setState(() => _members.remove(item));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['full_name']} removed'),
          backgroundColor: AppColors.indigo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Make moderator ─────────────────────────────────────────────
  Future<void> _makeModerator(Map<String, dynamic> item) async {
    final member = item['member'] as Map<String, dynamic>;
    final user   = item['user']   as Map<String, dynamic>;
    final userId = member['user_id'] as String;
    final currentRole = member['role'] as String? ?? 'member';

    final newRole = currentRole == 'moderator' ? 'member' : 'moderator';
    final label   = newRole == 'moderator' ? 'Make Moderator' : 'Remove Moderator';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(label, style: AppTextStyles.heading3),
        content: Text(
          newRole == 'moderator'
              ? '${user['full_name']} will be able to approve requests and delete posts.'
              : '${user['full_name']} will go back to regular member.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label,
                style: TextStyle(
                  color: newRole == 'moderator' ? AppColors.indigo : AppColors.orange,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client
          .from('community_members')
          .update({'role': newRole})
          .eq('community_id', widget.communityId)
          .eq('user_id', userId);

      // Notify user
      await SupabaseService.sendNotification(
        userId: userId,
        type:   'community_approved',
        title:  newRole == 'moderator'
            ? 'You\'re now a moderator! 🛡️'
            : 'Your moderator role was removed',
        body:   '',
        data:   {'community_id': widget.communityId},
      );

      // Reload members
      await _loadMembers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newRole == 'moderator'
              ? '${user['full_name']} is now a moderator!'
              : '${user['full_name']} is now a regular member'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
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
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manage Community', style: AppTextStyles.heading2),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.indigo,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.indigo,
          labelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              text: _pending.isEmpty
                  ? 'Pending'
                  : 'Pending (${_pending.length})',
            ),
            const Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildMembersTab(),
        ],
      ),
    );
  }

  // ── Pending tab ────────────────────────────────────────────────
  Widget _buildPendingTab() {
    if (_isLoadingPending) return const LoadingSpinner();
    if (_pending.isEmpty) {
      return const EmptyState(
        icon: Icons.how_to_reg_outlined,
        title: 'No pending requests',
        subtitle: 'All join requests have been reviewed',
      );
    }
    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.cardSurface,
      onRefresh: _loadPending,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => _buildPendingCard(_pending[i]),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> item) {
    final user    = item['user']    as Map<String, dynamic>;
    final skills  = item['skills']  as List<String>;
    final answers = item['answers'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              GradientAvatar(
                imageUrl: user['avatar_url'] as String?,
                name: user['full_name'] as String? ?? '?',
                size: 46,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['full_name'] ?? 'Unknown',
                      style: AppTextStyles.bodyBold,
                    ),
                    if (user['institution'] != null)
                      Text(user['institution'] as String,
                          style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),

          // Teaching skills
          if (skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: skills
                  .map((s) => SkillChip(label: s))
                  .toList(),
            ),
          ],

          // Answers
          if (answers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.elevated),
            const SizedBox(height: AppSpacing.sm),
            const Text('Their answers:', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            ...answers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: AppSpacing.md),

          // Accept / Reject buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  ),
                  child: const Text('✕ Reject',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _accept(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  ),
                  child: const Text('✓ Accept',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Members tab ────────────────────────────────────────────────
  Widget _buildMembersTab() {
    if (_isLoadingMembers) return const LoadingSpinner();
    if (_members.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No members yet',
        subtitle: 'Approve pending requests to add members',
      );
    }
    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.cardSurface,
      onRefresh: _loadMembers,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _buildMemberCard(_members[i]),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> item) {
    final user   = item['user']   as Map<String, dynamic>;
    final member = item['member'] as Map<String, dynamic>;
    final role   = member['role'] as String? ?? 'member';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Row(
        children: [
          GradientAvatar(
            imageUrl: user['avatar_url'] as String?,
            name: user['full_name'] as String? ?? '?',
            size: 44,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user['full_name'] ?? 'Unknown',
                        style: AppTextStyles.bodyBold),
                    const SizedBox(width: AppSpacing.xs),
                    if (role == 'moderator')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          '🛡️ Mod',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.indigo,
                          ),
                        ),
                      ),
                  ],
                ),
                if (user['institution'] != null)
                  Text(user['institution'] as String,
                      style: AppTextStyles.caption),
              ],
            ),
          ),
          // Actions popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textMuted, size: 20),
            color: AppColors.cardSurface,
            onSelected: (val) {
              if (val == 'moderator') _makeModerator(item);
              if (val == 'remove')    _removeMember(item);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'moderator',
                child: Row(
                  children: [
                    Icon(
                      role == 'moderator'
                          ? Icons.shield_outlined
                          : Icons.shield_rounded,
                      color: AppColors.indigo,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      role == 'moderator'
                          ? 'Remove Moderator'
                          : 'Make Moderator',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: AppColors.indigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_outlined,
                        color: AppColors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Remove from Community',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            color: AppColors.red,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}