
class ReviewModel {
  final String id;
  final String? sessionId;
  final String swapId;
  final String reviewerId;
  final String reviewedId;
  final int rating;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  // Populated from JOIN with users table
  // Holds reviewer's info so no second query needed
  final String? reviewerName;
  final String? reviewerAvatarUrl;

  ReviewModel({
    required this.id,
    this.sessionId,
    required this.swapId,
    required this.reviewerId,
    required this.reviewedId,
    required this.rating,
    this.tags = const [],
    this.comment,
    required this.createdAt,
    this.reviewerName,
    this.reviewerAvatarUrl,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> j) {
    return ReviewModel(
      id:         j['id'] ?? '',
      sessionId:  j['session_id'],
      swapId:     j['swap_id'] ?? '',
      reviewerId: j['reviewer_id'] ?? '',
      reviewedId: j['reviewed_id'] ?? '',
      rating:     j['rating'] ?? 0,
      tags:       j['tags'] != null
                    ? List<String>.from(j['tags'])
                    : [],
      comment:    j['comment'],
      createdAt:  DateTime.parse(j['created_at']),

      // From JOIN with users table
      // Query: .select('*, users!reviewer_id(full_name, avatar_url)')
      reviewerName:      j['users']?['full_name'],
      reviewerAvatarUrl: j['users']?['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id':   sessionId,
      'swap_id':      swapId,
      'reviewer_id':  reviewerId,
      'reviewed_id':  reviewedId,
      'rating':       rating,
      'tags':         tags,
      'comment':      comment,
    };
  }

  // Helpers — check rating level easily
  bool get isExcellent => rating == 5;
  bool get isGood      => rating == 4;
  bool get isAverage   => rating == 3;
  bool get isPoor      => rating <= 2;

  // Helper — returns star rating as a display string
  // Example: 4 → "4.0 ⭐"
  String get ratingDisplay => '$rating.0 ⭐';

  // Helper — returns the label shown below stars on rate_session_screen
  String get ratingLabel {
    switch (rating) {
      case 1:  return 'Not helpful';
      case 2:  return 'Could be better';
      case 3:  return 'It was okay';
      case 4:  return 'Pretty good!';
      case 5:  return 'Amazing session!';
      default: return '';
    }
  }

  // Helper — returns reviewer display name
  String get reviewerDisplayName => reviewerName ?? 'Anonymous';
}