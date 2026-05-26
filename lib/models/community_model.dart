
class CommunityModel {
  final String id;
  final String name;
  final String? description;
  final String? skillTag;
  final String adminId;
  final String? avatarUrl;
  final int memberCount;
  final DateTime? createdAt;

  // Populated from community_members table
  // Holds current user's membership status for this community
  String? membershipStatus; // null / 'pending' / 'member' / 'rejected' / 'removed'

  CommunityModel({
    required this.id,
    required this.name,
    this.description,
    this.skillTag,
    required this.adminId,
    this.avatarUrl,
    this.memberCount = 1,
    this.createdAt,
    this.membershipStatus,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> j) {
    return CommunityModel(
      id:          j['id'] ?? '',
      name:        j['name'] ?? '',
      description: j['description'],
      skillTag:    j['skill_tag'],
      adminId:     j['admin_id'] ?? '',
      avatarUrl:   j['avatar_url'],
      memberCount: j['member_count'] ?? 1,
      createdAt:   j['created_at'] != null
                     ? DateTime.parse(j['created_at'])
                     : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name':         name,
      'description':  description,
      'skill_tag':    skillTag,
      'admin_id':     adminId,
      'avatar_url':   avatarUrl,
      'member_count': memberCount,
    };
  }

  // Helpers — check membership status easily
  bool get isJoined  => membershipStatus == 'member';
  bool get isPending => membershipStatus == 'pending';
  bool get isNotJoined =>
      membershipStatus == null ||
      membershipStatus == 'rejected' ||
      membershipStatus == 'removed';

  // Helper — check if a user is the admin of this community
  bool isAdmin(String userId) => adminId == userId;

  // Helper — returns the label for the join button
  // based on current membership status
  String joinButtonLabel(String currentUserId) {
    if (isAdmin(currentUserId)) return 'Admin ⚙️';
    if (isJoined)               return 'Joined ✓';
    if (isPending)              return 'Pending...';
    return 'Join';
  }
}