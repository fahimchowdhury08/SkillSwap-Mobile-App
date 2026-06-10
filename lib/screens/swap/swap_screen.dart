import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/swap_model.dart';
import '../../models/user_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart';
import 'match_moment_screen.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _received = [];
  final List<Map<String, dynamic>> _sent     = [];
  bool _isLoadingReceived = true;
  bool _isLoadingSent     = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReceived();
    _loadSent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load received — ALL statuses (pending + accepted + rejected)
  Future<void> _loadReceived() async {
    setState(() => _isLoadingReceived = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.client
          .from('swaps')
          .select('*, sender:users!sender_id(id, full_name, avatar_url, institution)')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _received.clear();
        _received.addAll(
          (res as List).map((row) {
            final swap   = SwapModel.fromJson(row);
            final sender = UserModel.fromJson(
              row['sender'] as Map<String, dynamic>,
            );
            return {'swap': swap, 'sender': sender};
          }),
        );
      });
    } catch (e) {
      debugPrint('Load received error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReceived = false);
    }
  }

  // ── Load sent — ALL statuses ───────────────────────────────────
  Future<void> _loadSent() async {
    setState(() => _isLoadingSent = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.client
          .from('swaps')
          .select('*, receiver:users!receiver_id(id, full_name, avatar_url, institution)')
          .eq('sender_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _sent.clear();
        _sent.addAll(
          (res as List).map((row) {
            final swap     = SwapModel.fromJson(row);
            final receiver = UserModel.fromJson(
              row['receiver'] as Map<String, dynamic>,
            );
            return {'swap': swap, 'receiver': receiver};
          }),
        );
      });
    } catch (e) {
      debugPrint('Load sent error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSent = false);
    }
  }

  // ── Accept swap ────────────────────────────────────────────────
  Future<void> _acceptSwap(SwapModel swap, UserModel sender) async {
    try {
      final currentUserId = SupabaseService.currentUserId!;

      final meRes = await SupabaseService.client
          .from('users')
          .select('full_name')
          .eq('id', currentUserId)
          .single();
      final myName = meRes['full_name'] ?? 'Someone';

      await SupabaseService.client
          .from('swaps')
          .update({
            'status':     'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', swap.id);

      await SupabaseService.sendNotification(
        userId: swap.senderId,
        type:   'swap_accepted',
        title:  '$myName accepted your swap! 🎉',
        body:   'You are now matched. Start chatting!',
        data:   {'swap_id': swap.id},
      );

      // Update status locally instead of removing
      setState(() {
        final index = _received.indexWhere(
          (item) => (item['swap'] as SwapModel).id == swap.id,
        );
        if (index != -1) {
          final updatedSwap = SwapModel(
            id:            swap.id,
            senderId:      swap.senderId,
            receiverId:    swap.receiverId,
            senderSkill:   swap.senderSkill,
            receiverSkill: swap.receiverSkill,
            status:        'accepted',
            message:       swap.message,
            createdAt:     swap.createdAt,
          );
          _received[index] = {
            'swap':   updatedSwap,
            'sender': sender,
          };
        }
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchMomentScreen(
            swapId:    swap.id,
            otherUser: sender,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept swap. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Reject swap ────────────────────────────────────────────────
  Future<void> _rejectSwap(SwapModel swap) async {
    try {
      await SupabaseService.client
          .from('swaps')
          .update({'status': 'rejected'})
          .eq('id', swap.id);

      // Update status locally
      setState(() {
        final index = _received.indexWhere(
          (item) => (item['swap'] as SwapModel).id == swap.id,
        );
        if (index != -1) {
          final sender = _received[index]['sender'] as UserModel;
          final updatedSwap = SwapModel(
            id:            swap.id,
            senderId:      swap.senderId,
            receiverId:    swap.receiverId,
            senderSkill:   swap.senderSkill,
            receiverSkill: swap.receiverSkill,
            status:        'rejected',
            message:       swap.message,
            createdAt:     swap.createdAt,
          );
          _received[index] = {
            'swap':   updatedSwap,
            'sender': sender,
          };
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Swap request rejected'),
          backgroundColor: AppColors.indigo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Count pending received ─────────────────────────────────────
  int get _pendingCount => _received
      .where((item) => (item['swap'] as SwapModel).status == 'pending')
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Swaps', style: AppTextStyles.heading2),
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
              text: _pendingCount > 0
                  ? 'Received ($_pendingCount)'
                  : 'Received',
            ),
            const Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedTab(),
          _buildSentTab(),
        ],
      ),
    );
  }

  Widget _buildReceivedTab() {
    if (_isLoadingReceived) return const LoadingSpinner();
    if (_received.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_horiz_outlined,
        title: 'No swap requests yet',
        subtitle:
            'When someone wants to swap skills with you it will appear here',
      );
    }
    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.cardSurface,
      onRefresh: _loadReceived,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _received.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final swap   = _received[index]['swap']   as SwapModel;
          final sender = _received[index]['sender'] as UserModel;
          return _buildReceivedCard(swap, sender);
        },
      ),
    );
  }

  Widget _buildSentTab() {
    if (_isLoadingSent) return const LoadingSpinner();
    if (_sent.isEmpty) {
      return const EmptyState(
        icon: Icons.send_outlined,
        title: 'No sent requests yet',
        subtitle: 'Go to a profile and tap Swap to send your first request',
      );
    }
    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.cardSurface,
      onRefresh: _loadSent,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _sent.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final swap     = _sent[index]['swap']     as SwapModel;
          final receiver = _sent[index]['receiver'] as UserModel;
          return _buildSentCard(swap, receiver);
        },
      ),
    );
  }

  Widget _buildReceivedCard(SwapModel swap, UserModel sender) {
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

          // ── Sender info ──────────────────────────────
          Row(
            children: [
              GradientAvatar(
                imageUrl: sender.avatarUrl,
                name: sender.displayName,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sender.displayName, style: AppTextStyles.bodyBold),
                    if (sender.institution != null)
                      Text(sender.institution!, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Text(timeago.format(swap.createdAt), style: AppTextStyles.caption),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Skill exchange ───────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('They offer', style: AppTextStyles.label),
                      const SizedBox(height: 4),
                      Text(
                        swap.senderSkill ?? 'Unknown',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.indigo, size: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('They want', style: AppTextStyles.label),
                      const SizedBox(height: 4),
                      Text(
                        swap.receiverSkill ?? 'Unknown',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Message ──────────────────────────────────
          if (swap.message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '"${swap.message}"',
              style: AppTextStyles.body.copyWith(fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── Pending: Accept/Reject buttons ───────────
          // ── Accepted/Rejected: status badge ──────────
          if (swap.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectSwap(swap),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: const Text(
                      '✕ Reject',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptSwap(swap, sender),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: const Text(
                      '✓ Accept',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: (swap.status == 'accepted'
                          ? AppColors.green
                          : AppColors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: (swap.status == 'accepted'
                            ? AppColors.green
                            : AppColors.red)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  swap.status == 'accepted' ? '✓ Accepted' : '✕ Rejected',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: swap.status == 'accepted'
                        ? AppColors.green
                        : AppColors.red,
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildSentCard(SwapModel swap, UserModel receiver) {
    Color statusColor;
    String statusLabel;

    switch (swap.status) {
      case 'accepted':
        statusColor = AppColors.green;
        statusLabel = '✓ Accepted';
        break;
      case 'rejected':
        statusColor = AppColors.red;
        statusLabel = '✕ Rejected';
        break;
      default:
        statusColor = AppColors.orange;
        statusLabel = '⏳ Pending';
    }

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

          // ── Receiver info ────────────────────────────
          Row(
            children: [
              GradientAvatar(
                imageUrl: receiver.avatarUrl,
                name: receiver.displayName,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receiver.displayName, style: AppTextStyles.bodyBold),
                    if (receiver.institution != null)
                      Text(receiver.institution!, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Skill exchange ───────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You offer', style: AppTextStyles.label),
                      const SizedBox(height: 4),
                      Text(
                        swap.senderSkill ?? 'Unknown',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.indigo, size: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('You learn', style: AppTextStyles.label),
                      const SizedBox(height: 4),
                      Text(
                        swap.receiverSkill ?? 'Unknown',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            timeago.format(swap.createdAt),
            style: AppTextStyles.caption,
          ),

        ],
      ),
    );
  }
}