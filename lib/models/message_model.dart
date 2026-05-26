
class MessageModel {
  final String id;
  final String swapId;
  final String senderId;
  final String content;
  final String messageType;
  final String? fileUrl;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.swapId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.fileUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) {
    return MessageModel(
      id:          j['id'] ?? '',
      swapId:      j['swap_id'] ?? '',
      senderId:    j['sender_id'] ?? '',
      content:     j['content'] ?? '',
      messageType: j['message_type'] ?? 'text',
      fileUrl:     j['file_url'],
      isRead:      j['is_read'] ?? false,
      createdAt:   DateTime.parse(j['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'swap_id':      swapId,
      'sender_id':    senderId,
      'content':      content,
      'message_type': messageType,
      'file_url':     fileUrl,
      'is_read':      isRead,
    };
  }

  // Helpers — check message type easily
  bool get isText    => messageType == 'text';
  bool get isImage   => messageType == 'image';
  bool get isFile    => messageType == 'file';
  bool get isSystem  => messageType == 'system';

  // Helper — check if this message was sent by the current user
  bool isMine(String currentUserId) => senderId == currentUserId;
}