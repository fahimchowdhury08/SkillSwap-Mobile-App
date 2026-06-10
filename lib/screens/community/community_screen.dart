
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/community_model.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart'; 
import 'create_community_screen.dart';
import 'community_detail_screen.dart';
import 'admin_actions_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<CommunityModel> _communities = [];
  List<CommunityModel> _filtered = [];

  // membership status cache: communityId → status string
  final Map<String, String?> _membershipStatus = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Load all communities ───────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client
          .from('communities')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List).map((j) => CommunityModel.fromJson(j)).toList();

      // batch-fetch current user's membership status
      final uid = SupabaseService.currentUserId;
      if (uid != null && list.isNotEmpty) {
        final ids = list.map((c) => c.id).toList();
        final memRes = await SupabaseService.client
            .from('community_members')
            .select('community_id, status, role')
            .eq('user_id', uid)
            .inFilter('community_id', ids);

        for (final m in memRes as List) {
          final cid = m['community_id'] as String;
          // if they are admin, status = 'admin', else use role/status
          final role   = m['role'] as String? ?? 'member';
          final status = m['status'] as String? ?? 'pending';
          if (role == 'admin') {
            _membershipStatus[cid] = 'admin';
          } else if (role == 'moderator') {
            _membershipStatus[cid] = 'moderator';
          } else {
            _membershipStatus[cid] = status; // pending / member / rejected
          }
        }
      }

      setState(() {
        _communities = list;
        _filtered    = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load communities: $e'),
            backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q;
      _filtered = q.isEmpty
          ? _communities
          : _communities
              .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  // ── Join request ───────────────────────────────────────────────
  Future<void> _requestJoin(CommunityModel c) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    // Check if community has join questions
    final qRes = await SupabaseService.client
        .from('community_join_questions')
        .select()
        .eq('community_id', c.id)
        .order('order_index');

    final questions = (qRes as List);

    if (!mounted) return;

    if (questions.isEmpty) {
      // No questions — insert directly as pending
      await _submitJoinRequest(c.id, uid, {});
    } else {
      // Show Q&A sheet
      final answers = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _JoinQASheet(questions: questions, community: c),
      );
      if (answers == null) return;
      await _submitJoinRequest(c.id, uid, answers);
    }
  }

  Future<void> _submitJoinRequest(
      String communityId, String uid, Map<String, String> answers) async {
    try {
      // Insert member row
      await SupabaseService.client.from('community_members').insert({
        'community_id': communityId,
        'user_id':      uid,
        'status':       'pending',
        'role':         'member',
        'answers':      answers,
      });

      // Get admin id
      final comm = _communities.firstWhere((c) => c.id == communityId);

      // Get current user name
      final meRes = await SupabaseService.client
          .from('users')
          .select('full_name')
          .eq('id', uid)
          .single();
      final myName = meRes['full_name'] ?? 'Someone';

      // Notify admin
      await SupabaseService.sendNotification(
        userId: comm.adminId,
        type:   'community_join_request',
        title:  '$myName wants to join ${comm.name}',
        body:   'Review their request and answers',
        data:   {'community_id': communityId},
      );

      // Also notify moderators
      final modRes = await SupabaseService.client
          .from('community_members')
          .select('user_id')
          .eq('community_id', communityId)
          .eq('role', 'moderator')
          .eq('status', 'member');

      for (final m in modRes as List) {
        await SupabaseService.sendNotification(
          userId: m['user_id'] as String,
          type:   'community_join_request',
          title:  '$myName wants to join ${comm.name}',
          body:   'Review their request and answers',
          data:   {'community_id': communityId},
        );
      }

      setState(() => _membershipStatus[communityId] = 'pending');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! Waiting for approval.'),
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

  // ── Open community ─────────────────────────────────────────────
  void _openCommunity(CommunityModel c) {
    final status = _membershipStatus[c.id];

    if (status == 'admin') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityId: c.id,
          role: 'admin',
        ),
      )).then((_) => _load());
    } else if (status == 'moderator') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityId: c.id,
          role: 'moderator',
        ),
      )).then((_) => _load());
    } else if (status == 'member') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityId: c.id,
          role: 'member',
        ),
      )).then((_) => _load());
    } else if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⏳ Your request is pending. Wait for admin approval.'),
          backgroundColor: AppColors.orange,
        ),
      );
    } else {
      // Not joined — trigger join flow directly, never open community
      _requestJoin(c);
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
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Community', style: AppTextStyles.heading2),
        actions: [
          // Create community
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.indigo, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Search bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyBold,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search communities...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Nunito',
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
                ),
              ),
            ),
          ),

          // ── List ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const LoadingSpinner()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.groups_outlined,
                        title: _searchQuery.isEmpty
                            ? 'No communities yet'
                            : 'No results for "$_searchQuery"',
                        subtitle: _searchQuery.isEmpty
                            ? 'Be the first! Tap + to create one.'
                            : 'Try a different search term',
                        buttonLabel: _searchQuery.isEmpty ? 'Create Community' : null,
                        onButtonTap: _searchQuery.isEmpty
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const CreateCommunityScreen()),
                                ).then((_) => _load())
                            : null,
                      )
                    : RefreshIndicator(
                        color: AppColors.indigo,
                        backgroundColor: AppColors.cardSurface,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) =>
                              _buildCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Community card ─────────────────────────────────────────────
  Widget _buildCard(CommunityModel c) {
    final status = _membershipStatus[c.id];
    final uid    = SupabaseService.currentUserId;
    final isAdmin = c.adminId == uid;

    return GestureDetector(
      onTap: () => _openCommunity(c),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [

            // ── Icon / Avatar ──────────────────────────────────
            _buildCommunityAvatar(c, 52),

            const SizedBox(width: AppSpacing.md),

            // ── Info ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: AppTextStyles.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.indigo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: AppColors.indigo,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (c.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.description!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${c.memberCount} members',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      if (c.skillTag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            c.skillTag!,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.coral,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // ── Action button ──────────────────────────────────
            _buildActionButton(c, status, isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      CommunityModel c, String? status, bool isAdmin) {
    if (isAdmin || status == 'admin') {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AdminActionsScreen(communityId: c.id)),
        ).then((_) => _load()),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.indigo.withValues(alpha: 0.4)),
          ),
          child: const Text(
            'Manage ⚙️',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.indigo,
            ),
          ),
        ),
      );
    }
    if (status == 'moderator') {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Mod ✓',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.green,
          ),
        ),
      );
    }
    if (status == 'member') {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Joined ✓',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.green,
          ),
        ),
      );
    }
    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Pending...',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.orange,
          ),
        ),
      );
    }
    // Not joined
    return GestureDetector(
      onTap: () => _requestJoin(c),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Join',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityAvatar(CommunityModel c, double size) {
    if (c.avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: c.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackAvatar(c, size),
        ),
      );
    }
    return _fallbackAvatar(c, size);
  }

  Widget _fallbackAvatar(CommunityModel c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.indigoCoralGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Join Q&A Bottom Sheet
// ══════════════════════════════════════════════════════════════════
class _JoinQASheet extends StatefulWidget {
  final List<dynamic> questions;
  final CommunityModel community;

  const _JoinQASheet({required this.questions, required this.community});

  @override
  State<_JoinQASheet> createState() => _JoinQASheetState();
}

class _JoinQASheetState extends State<_JoinQASheet> {
  final Map<String, TextEditingController> _controllers = {};
  final bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final q in widget.questions) {
      _controllers[q['id'].toString()] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // Validate all answered
    for (final q in widget.questions) {
      final ctrl = _controllers[q['id'].toString()];
      if (ctrl == null || ctrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please answer all questions'),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
    }
    final answers = <String, String>{};
    for (final q in widget.questions) {
      answers[q['question'] as String] =
          _controllers[q['id'].toString()]!.text.trim();
    }
    Navigator.pop(context, answers);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'Join ${widget.community.name}',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Answer the questions below to request access.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Questions
            ...widget.questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q   = entry.value;
              final id  = q['id'].toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${idx + 1}. ${q['question']}',
                    style: AppTextStyles.bodyBold,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _controllers[id],
                    maxLines: 2,
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Your answer...',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontFamily: 'Nunito'),
                      filled: true,
                      fillColor: AppColors.elevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              );
            }),

            const SizedBox(height: AppSpacing.md),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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