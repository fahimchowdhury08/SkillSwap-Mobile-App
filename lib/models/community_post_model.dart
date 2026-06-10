// ── Updated CommunityPostModel ─────────────────────────────────────
// Supports: article | image | video | file | youtube
// Replace lib/models/community_post_model.dart with this file

class CommunityPostModel {
  final String id;
  final String communityId;
  final String userId;
  final String contentType;
  final String? caption;
  final String? fileUrl;
  final String? articleUrl;
  final int likeCount;
  final DateTime createdAt;

  // From JOIN with users table
  final String? posterName;
  final String? posterAvatarUrl;

  bool isLikedByMe;

  CommunityPostModel({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.contentType,
    this.caption,
    this.fileUrl,
    this.articleUrl,
    this.likeCount = 0,
    required this.createdAt,
    this.posterName,
    this.posterAvatarUrl,
    this.isLikedByMe = false,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> j) {
    return CommunityPostModel(
      id:            j['id'] ?? '',
      communityId:   j['community_id'] ?? '',
      userId:        j['user_id'] ?? '',
      contentType:   j['content_type'] ?? 'article',
      caption:       j['caption'],
      fileUrl:       j['file_url'],
      articleUrl:    j['article_url'],
      likeCount:     j['like_count'] ?? 0,
      createdAt:     DateTime.parse(j['created_at']),
      posterName:      j['users']?['full_name'],
      posterAvatarUrl: j['users']?['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':           id,
      'community_id': communityId,
      'user_id':      userId,
      'content_type': contentType,
      'caption':      caption,
      'file_url':     fileUrl,
      'article_url':  articleUrl,
      'like_count':   likeCount,
      'created_at':   createdAt.toIso8601String(),
    };
  }

  // Content type helpers
  bool get isImage   => contentType == 'image';
  bool get isVideo   => contentType == 'video';
  bool get isFile    => contentType == 'file';
  bool get isArticle => contentType == 'article';
  bool get isYoutube => contentType == 'youtube';
  bool get hasMedia  => fileUrl != null || articleUrl != null;

  String get posterDisplayName => posterName ?? 'Unknown';
}