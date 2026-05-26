
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

  // Populated from JOIN with users table in one query
  // Never fetch these separately — always use the join query
  final String? posterName;
  final String? posterAvatarUrl;

  // Tracked locally — whether current user has liked this post
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

      // These come from the JOIN with users table
      // Query: .select('*, users(full_name, avatar_url)')
      posterName:      j['users']?['full_name'],
      posterAvatarUrl: j['users']?['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'user_id':      userId,
      'content_type': contentType,
      'caption':      caption,
      'file_url':     fileUrl,
      'article_url':  articleUrl,
    };
  }

  // Helpers — check content type easily
  bool get isImage   => contentType == 'image';
  bool get isVideo   => contentType == 'video';
  bool get isFile    => contentType == 'file';
  bool get isArticle => contentType == 'article';

  // Helper — returns true if this post has any media to display
  bool get hasMedia => fileUrl != null || articleUrl != null;

  // Helper — returns display name of poster
  // Falls back to "Unknown" if join query didn't include user data
  String get posterDisplayName => posterName ?? 'Unknown';
}