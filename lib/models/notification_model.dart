
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    return NotificationModel(
      id:        j['id'] ?? '',
      userId:    j['user_id'] ?? '',
      type:      j['type'] ?? '',
      title:     j['title'] ?? '',
      body:      j['body'] ?? '',
      data:      Map<String, dynamic>.from(j['data'] ?? {}),
      isRead:    j['is_read'] ?? false,
      createdAt: DateTime.parse(j['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id':  userId,
      'type':     type,
      'title':    title,
      'body':     body,
      'data':     data,
      'is_read':  isRead,
    };
  }

  // ── Type check helpers ────────────────────────────────────────
  // Use these instead of comparing strings manually
  // Example: if (notif.isSwapReceived) { ... }

  bool get isSwapReceived       => type == 'swap_received';
  bool get isSwapAccepted       => type == 'swap_accepted';
  bool get isMessageReceived    => type == 'message_received';
  bool get isSessionBooked      => type == 'session_booked';
  bool get isSessionCancelled   => type == 'session_cancelled';
  bool get isCommunityRequest   => type == 'community_join_request';
  bool get isCommunityApproved  => type == 'community_approved';

  // ── Data field helpers ────────────────────────────────────────
  // These extract the ids stored in the data JSONB column
  // Used in notification_screen.dart for deep-link navigation

  // Returns swapId — available on swap and message notifications
  String? get swapId => data['swap_id'] as String?;

  // Returns communityId — available on community notifications
  String? get communityId => data['community_id'] as String?;

  // ── Icon helper ───────────────────────────────────────────────
  // Returns the right emoji icon for each notification type
  // Used when rendering each notification row in the list
  String get icon {
    switch (type) {
      case 'swap_received':        return '🔄';
      case 'swap_accepted':        return '🎉';
      case 'message_received':     return '💬';
      case 'session_booked':       return '📅';
      case 'session_cancelled':    return '❌';
      case 'community_join_request': return '🌐';
      case 'community_approved':   return '✅';
      default:                     return '🔔';
    }
  }
}