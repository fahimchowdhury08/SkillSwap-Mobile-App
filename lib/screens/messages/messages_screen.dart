import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/user_model.dart';
import '../../models/swap_model.dart';
import '../../models/message_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final swapsRes = await SupabaseService.client
          .from('swaps')
          .select()
          .eq('status', 'accepted')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> conversations = [];

      for (final row in swapsRes as List) {
        final swap = SwapModel.fromJson(row);

        final otherId = swap.senderId == userId
            ? swap.receiverId
            : swap.senderId;

        final userRes = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', otherId)
            .single();

        final otherUser = UserModel.fromJson(userRes);

        final msgRes = await SupabaseService.client
            .from('messages')
            .select()
            .eq('swap_id', swap.id)
            .order('created_at', ascending: false)
            .limit(1);

        MessageModel? lastMessage;
        if ((msgRes as List).isNotEmpty) {
          lastMessage = MessageModel.fromJson(msgRes.first);
        }

        final unreadRes = await SupabaseService.client
            .from('messages')
            .select('id')
            .eq('swap_id', swap.id)
            .eq('is_read', false)
            .neq('sender_id', userId);

        final unreadCount = (unreadRes as List).length;

        conversations.add({
          'swap':        swap,
          'otherUser':   otherUser,
          'lastMessage': lastMessage,
          'unreadCount': unreadCount,
        });
      }

      conversations.sort((a, b) {
        final aMsg = a['lastMessage'] as MessageModel?;
        final bMsg = b['lastMessage'] as MessageModel?;
        if (aMsg == null && bMsg == null) return 0;
        if (aMsg == null) return 1;
        if (bMsg == null) return -1;
        return bMsg.createdAt.compareTo(aMsg.createdAt);
      });

      setState(() => _conversations = conversations);

    } catch (e) {
      debugPrint('Load conversations error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Messages',
          style: AppTextStyles.heading2,
        ),
      ),
      body: _isLoading
          ? const LoadingSpinner()
          : _conversations.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  subtitle:
                      'Accept a swap request to unlock messaging with that person',
                )
              : RefreshIndicator(
                  color: AppColors.indigo,
                  backgroundColor: AppColors.cardSurface,
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppColors.elevated,
                      height: 1,
                      indent: 80,
                    ),
                    itemBuilder: (context, index) {
                      return _buildConversationRow(
                        _conversations[index],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildConversationRow(Map<String, dynamic> conv) {
    final swap        = conv['swap'] as SwapModel;
    final otherUser   = conv['otherUser'] as UserModel;
    final lastMessage = conv['lastMessage'] as MessageModel?;
    final unreadCount = conv['unreadCount'] as int;
    final hasUnread   = unreadCount > 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              swapId:    swap.id,
              otherUser: otherUser,
            ),
          ),
        ).then((_) => _loadConversations());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [

            GradientAvatar(
              imageUrl: otherUser.avatarUrl,
              name: otherUser.displayName,
              size: 54,
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        otherUser.displayName,
                        style: hasUnread
                            ? AppTextStyles.bodyBold
                            : AppTextStyles.body.copyWith(
                                color: AppColors.textPrimary,
                              ),
                      ),
                      if (lastMessage != null)
                        Text(
                          timeago.format(lastMessage.createdAt),
                          style: AppTextStyles.caption.copyWith(
                            color: hasUnread
                                ? AppColors.coral
                                : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPreview(lastMessage),
                    style: AppTextStyles.body.copyWith(
                      color: hasUnread
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            if (hasUnread)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }

  String _getPreview(MessageModel? message) {
  if (message == null) return 'Say hello! 👋';
  switch (message.messageType) {
    case 'image':
      return '📷 Image';
    case 'file':
      return '📄 File';
    case 'system':
      return message.content;
    case 'session_proposal':           // ← ADD THIS
      return '📅 Session Proposal';   // ← ADD THIS
    default:
      return message.content;
  }
}
}