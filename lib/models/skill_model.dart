
class SkillModel {
  final String id;
  final String userId;
  final String name;
  final String category;
  final bool isTeaching;
  final bool isVerified;
  final String? verifiedVia;
  final String? certificateUrl;
  final DateTime? createdAt;

  SkillModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.isTeaching,
    this.isVerified = false,
    this.verifiedVia,
    this.certificateUrl,
    this.createdAt,
  });

  factory SkillModel.fromJson(Map<String, dynamic> j) {
    return SkillModel(
      id:             j['id'] ?? '',
      userId:         j['user_id'] ?? '',
      name:           j['name'] ?? '',
      category:       j['category'] ?? 'other',
      isTeaching:     j['is_teaching'] ?? true,
      isVerified:     j['is_verified'] ?? false,
      verifiedVia:    j['verified_via'],
      certificateUrl: j['certificate_url'],
      createdAt:      j['created_at'] != null
                        ? DateTime.parse(j['created_at'])
                        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id':         userId,
      'name':            name,
      'category':        category,
      'is_teaching':     isTeaching,
      'is_verified':     isVerified,
      'verified_via':    verifiedVia,
      'certificate_url': certificateUrl,
    };
  }

  // Helper — returns the skill category from the skill name
  // Use this when inserting a new skill to auto-detect category
  static String detectCategory(String skillName) {
    const coding = [
      'Python', 'Flutter', 'React', 'Full Stack', 'Machine Learning',
      'Data Science', 'Django', 'Flask', 'FastAPI', 'NumPy', 'SQL',
      'Dart', 'Web Dev', 'App Dev', 'JavaScript', 'TypeScript',
      'Node.js', 'MongoDB', 'Firebase', 'Java', 'Kotlin', 'Swift',
      'C++', 'C#', 'PHP', 'Ruby', 'Go', 'Rust', 'ML', 'AI',
    ];
    const design = [
      'UI/UX Design', 'Figma', 'Graphic Design', 'Adobe XD',
      'Photography', 'Lightroom', 'Branding', 'Illustration',
      'Canva', 'Adobe Photoshop', 'Adobe Illustrator', 'Motion Design',
    ];
    const marketing = [
      'Digital Marketing', 'SEO', 'Content Writing', 'Marketing',
      'Meta Ads', 'Google Ads', 'Social Media', 'PPC', 'Copywriting',
      'Email Marketing', 'Affiliate Marketing',
    ];

    final lower = skillName.toLowerCase();

    for (final s in coding) {
      if (lower.contains(s.toLowerCase())) return 'coding';
    }
    for (final s in design) {
      if (lower.contains(s.toLowerCase())) return 'design';
    }
    for (final s in marketing) {
      if (lower.contains(s.toLowerCase())) return 'marketing';
    }

    return 'other';
  }
}