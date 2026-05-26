
class SessionModel {
  final String id;
  final String swapId;
  final String hostId;
  final String guestId;
  final String? topic;
  final DateTime scheduledAt;
  final int durationMins;
  final String status;
  final DateTime? createdAt;

  // Populated when fetching with JOIN query
  // Holds the partner's info so no second query needed
  final String? partnerName;
  final String? partnerAvatar;

  SessionModel({
    required this.id,
    required this.swapId,
    required this.hostId,
    required this.guestId,
    this.topic,
    required this.scheduledAt,
    this.durationMins = 60,
    required this.status,
    this.createdAt,
    this.partnerName,
    this.partnerAvatar,
  });

  factory SessionModel.fromJson(Map<String, dynamic> j) {
    return SessionModel(
      id:           j['id'] ?? '',
      swapId:       j['swap_id'] ?? '',
      hostId:       j['host_id'] ?? '',
      guestId:      j['guest_id'] ?? '',
      topic:        j['topic'],
      scheduledAt:  DateTime.parse(j['scheduled_at']),
      durationMins: j['duration_mins'] ?? 60,
      status:       j['status'] ?? 'upcoming',
      createdAt:    j['created_at'] != null
                      ? DateTime.parse(j['created_at'])
                      : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'swap_id':       swapId,
      'host_id':       hostId,
      'guest_id':      guestId,
      'topic':         topic,
      'scheduled_at':  scheduledAt.toIso8601String(),
      'duration_mins': durationMins,
      'status':        status,
    };
  }

  // Helpers — check session status easily
  bool get isUpcoming   => status == 'upcoming';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';

  // Helper — returns duration as readable string
  // Example: 60 → "1 hour", 30 → "30 minutes", 90 → "1.5 hours"
  String get durationLabel {
    if (durationMins == 30)  return '30 minutes';
    if (durationMins == 60)  return '1 hour';
    if (durationMins == 90)  return '1.5 hours';
    return '$durationMins minutes';
  }

  // Helper — returns true if session is within the next 30 minutes
  // Used to show the reminder banner on the schedule screen
  bool get isStartingSoon {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now).inMinutes;
    return diff >= 0 && diff <= 30;
  }

  // Helper — given current user id, returns the partner's id
  String partnerUserId(String currentUserId) {
    return hostId == currentUserId ? guestId : hostId;
  }
}