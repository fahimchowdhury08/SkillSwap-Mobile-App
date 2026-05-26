
class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? institution;
  final String? occupation;
  final String? phone;
  final String? linkedinUrl;
  final String? dateOfBirth;
  final int? passingYear;
  final double avgRating;
  final Map<String, dynamic>? availability;
  final bool isAvailableNow;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.institution,
    this.occupation,
    this.phone,
    this.linkedinUrl,
    this.dateOfBirth,
    this.passingYear,
    this.avgRating = 0.0,
    this.availability,
    this.isAvailableNow = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) {
    return UserModel(
      id:             j['id'] ?? '',
      email:          j['email'] ?? '',
      fullName:       j['full_name'],
      avatarUrl:      j['avatar_url'],
      institution:    j['institution'],
      occupation:     j['occupation'],
      phone:          j['phone'],
      linkedinUrl:    j['linkedin_url'],
      dateOfBirth:    j['date_of_birth'],
      passingYear:    j['passing_year'],
      avgRating:      (j['avg_rating'] ?? 0.0).toDouble(),
      availability:   j['availability'] != null
                        ? Map<String, dynamic>.from(j['availability'])
                        : null,
      isAvailableNow: j['is_available_now'] ?? false,
      createdAt:      j['created_at'] != null
                        ? DateTime.parse(j['created_at'])
                        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':               id,
      'email':            email,
      'full_name':        fullName,
      'avatar_url':       avatarUrl,
      'institution':      institution,
      'occupation':       occupation,
      'phone':            phone,
      'linkedin_url':     linkedinUrl,
      'date_of_birth':    dateOfBirth,
      'passing_year':     passingYear,
      'avg_rating':       avgRating,
      'availability':     availability,
      'is_available_now': isAvailableNow,
    };
  }

  // Helper — returns display name or email if name not set yet
  String get displayName => fullName ?? email;

  // Helper — returns true if profile is complete enough to show
  bool get isProfileComplete =>
      fullName != null &&
      institution != null &&
      occupation != null;
}