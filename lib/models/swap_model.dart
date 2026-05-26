
class SwapModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? senderSkill;
  final String? receiverSkill;
  final String? message;
  final String status;
  final int matchScore;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // These are populated when fetching swaps with a JOIN query
  // They hold the other user's info so you don't need a second query
  final String? otherUserName;
  final String? otherUserAvatar;

  SwapModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.senderSkill,
    this.receiverSkill,
    this.message,
    required this.status,
    this.matchScore = 60,
    required this.createdAt,
    this.updatedAt,
    this.otherUserName,
    this.otherUserAvatar,
  });

  factory SwapModel.fromJson(Map<String, dynamic> j) {
    return SwapModel(
      id:             j['id'] ?? '',
      senderId:       j['sender_id'] ?? '',
      receiverId:     j['receiver_id'] ?? '',
      senderSkill:    j['sender_skill'],
      receiverSkill:  j['receiver_skill'],
      message:        j['message'],
      status:         j['status'] ?? 'pending',
      matchScore:     j['match_score'] ?? 60,
      createdAt:      DateTime.parse(j['created_at']),
      updatedAt:      j['updated_at'] != null
                        ? DateTime.parse(j['updated_at'])
                        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id':      senderId,
      'receiver_id':    receiverId,
      'sender_skill':   senderSkill,
      'receiver_skill': receiverSkill,
      'message':        message,
      'status':         status,
      'match_score':    matchScore,
    };
  }

  // Helpers — check swap status easily
  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  // Helper — returns true if both users benefit from the swap
  bool get isMutual => matchScore >= 90;

  // Helper — given the current user's id, returns the other person's id
  String otherUserId(String currentUserId) {
    return senderId == currentUserId ? receiverId : senderId;
  }
}