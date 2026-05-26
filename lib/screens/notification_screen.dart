import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme.dart';
import '../supabase_service.dart';
import '../models/notification_model.dart';
import '../widgets/loading_spinner.dart';
import '../widgets/empty_state.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _notifications.clear();
        _notifications.addAll(
          (res as List).map((j) => NotificationModel.fromJson(j)),
        );
      });
    } catch (e) {
      debugPrint('Notifications load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);

      setState(() {
        for (int i = 0; i < _notifications.length; i++) {
          final n = _notifications[i];
          _notifications[i] = NotificationModel.fromJson({
            'id':         n.id,
            'user_id':    n.userId,
            'type':       n.type,
            'title':      n.title,
            'body':       n.body,
            'data':       n.data,
            'is_read':    true,
            'created_at': n.createdAt.toIso8601String(),
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
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

  Future<void> _markOneAsRead(NotificationModel notif) async {
    if (notif.isRead) return;
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notif.id);

      final index = _notifications.indexWhere((n) => n.id == notif.id);
      if (index != -1) {
        setState(() {
          _notifications[index] = NotificationModel.fromJson({
            'id':         notif.id,
            'user_id':    notif.userId,
            'type':       notif.type,
            'title':      notif.title,
            'body':       notif.body,
            'data':       notif.data,
            'is_read':    true,
            'created_at': notif.createdAt.toIso8601String(),
          });
        });
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  void _onNotificationTap(NotificationModel notif) {
    _markOneAsRead(notif);
    switch (notif.type) {
      case 'swap_received':
      case 'swap_accepted':
        Navigator.pushNamed(context, '/swap');
        break;
      case 'session_booked':
      case 'session_cancelled':
        Navigator.pushNamed(context, '/schedule');
        break;
      case 'message_received':
        Navigator.pushNamed(context, '/messages');
        break;
      case 'community_join_request':
      case 'community_approved':
        Navigator.pushNamed(context, '/community');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

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
        title: const Text(
          'Notifications',
          style: AppTextStyles.heading2,
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.indigo,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingSpinner()
          : _notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  subtitle:
                      'You will see swap requests, messages and updates here',
                )
              : RefreshIndicator(
                  color: AppColors.indigo,
                  backgroundColor: AppColors.cardSurface,
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppColors.elevated,
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                    itemBuilder: (context, index) {
                      return _buildRow(_notifications[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildRow(NotificationModel notif) {
    return InkWell(
      onTap: () => _onNotificationTap(notif),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: notif.isRead
              ? Colors.transparent
              : AppColors.indigo.withValues(alpha: 0.05),
          border: notif.isRead
              ? null
              : const Border(
                  left: BorderSide(
                    color: AppColors.coral,
                    width: 3,
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Icon circle ──────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.elevated,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  notif.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // ── Text content ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: notif.isRead
                        ? AppTextStyles.body
                        : AppTextStyles.bodyBold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    timeago.format(notif.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // ── Unread dot ───────────────────────────────
            if (!notif.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
              ),

          ],
        ),
      ),
    );
  }
}