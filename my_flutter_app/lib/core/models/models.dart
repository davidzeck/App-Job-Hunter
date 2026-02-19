// All data models matching the backend Pydantic schemas exactly.
// Each model has fromJson/toJson for future API integration.

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        expiresIn: json['expires_in'] as int,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
      };
}

class UserProfileResponse {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final bool emailVerified;
  final bool isActive;
  final Map<String, dynamic> preferences;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int skillsCount;
  final bool hasCv;

  const UserProfileResponse({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.emailVerified = false,
    this.isActive = true,
    this.preferences = const {},
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    this.skillsCount = 0,
    this.hasCv = false,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) =>
      UserProfileResponse(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        phone: json['phone'] as String?,
        emailVerified: json['email_verified'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        preferences: json['preferences'] as Map<String, dynamic>? ?? {},
        lastSeenAt: json['last_seen_at'] != null
            ? DateTime.parse(json['last_seen_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        skillsCount: json['skills_count'] as int? ?? 0,
        hasCv: json['has_cv'] as bool? ?? false,
      );
}

class CompanyBrief {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;

  const CompanyBrief({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
  });

  factory CompanyBrief.fromJson(Map<String, dynamic> json) => CompanyBrief(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        logoUrl: json['logo_url'] as String?,
      );
}

class CompanyResponse {
  final String id;
  final String name;
  final String slug;
  final String? careersUrl;
  final String? logoUrl;
  final String? description;
  final bool isActive;
  final int jobsCount;
  final int sourcesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyResponse({
    required this.id,
    required this.name,
    required this.slug,
    this.careersUrl,
    this.logoUrl,
    this.description,
    this.isActive = true,
    this.jobsCount = 0,
    this.sourcesCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyResponse.fromJson(Map<String, dynamic> json) =>
      CompanyResponse(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        careersUrl: json['careers_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        jobsCount: json['jobs_count'] as int? ?? 0,
        sourcesCount: json['sources_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class JobListItem {
  final String id;
  final String title;
  final String? location;
  final String? locationType;
  final String? jobType;
  final String applyUrl;
  final CompanyBrief company;
  final DateTime? postedAt;
  final DateTime discoveredAt;
  final bool isActive;

  const JobListItem({
    required this.id,
    required this.title,
    this.location,
    this.locationType,
    this.jobType,
    required this.applyUrl,
    required this.company,
    this.postedAt,
    required this.discoveredAt,
    this.isActive = true,
  });

  factory JobListItem.fromJson(Map<String, dynamic> json) => JobListItem(
        id: json['id'] as String,
        title: json['title'] as String,
        location: json['location'] as String?,
        locationType: json['location_type'] as String?,
        jobType: json['job_type'] as String?,
        applyUrl: json['apply_url'] as String,
        company: CompanyBrief.fromJson(json['company'] as Map<String, dynamic>),
        postedAt: json['posted_at'] != null
            ? DateTime.parse(json['posted_at'] as String)
            : null,
        discoveredAt: DateTime.parse(json['discovered_at'] as String),
        isActive: json['is_active'] as bool? ?? true,
      );
}

class JobSkillResponse {
  final String skillName;
  final String? skillCategory;
  final bool isRequired;
  final int? minYearsExperience;

  const JobSkillResponse({
    required this.skillName,
    this.skillCategory,
    this.isRequired = true,
    this.minYearsExperience,
  });

  factory JobSkillResponse.fromJson(Map<String, dynamic> json) =>
      JobSkillResponse(
        skillName: json['skill_name'] as String,
        skillCategory: json['skill_category'] as String?,
        isRequired: json['is_required'] as bool? ?? true,
        minYearsExperience: json['min_years_experience'] as int?,
      );
}

class JobDetail extends JobListItem {
  final String? description;
  final String? seniorityLevel;
  final int? salaryMin;
  final int? salaryMax;
  final String? salaryCurrency;
  final DateTime? expiresAt;
  final List<JobSkillResponse> skills;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobDetail({
    required super.id,
    required super.title,
    super.location,
    super.locationType,
    super.jobType,
    required super.applyUrl,
    required super.company,
    super.postedAt,
    required super.discoveredAt,
    super.isActive,
    this.description,
    this.seniorityLevel,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency,
    this.expiresAt,
    this.skills = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobDetail.fromJson(Map<String, dynamic> json) => JobDetail(
        id: json['id'] as String,
        title: json['title'] as String,
        location: json['location'] as String?,
        locationType: json['location_type'] as String?,
        jobType: json['job_type'] as String?,
        applyUrl: json['apply_url'] as String,
        company: CompanyBrief.fromJson(json['company'] as Map<String, dynamic>),
        postedAt: json['posted_at'] != null
            ? DateTime.parse(json['posted_at'] as String)
            : null,
        discoveredAt: DateTime.parse(json['discovered_at'] as String),
        isActive: json['is_active'] as bool? ?? true,
        description: json['description'] as String?,
        seniorityLevel: json['seniority_level'] as String?,
        salaryMin: json['salary_min'] as int?,
        salaryMax: json['salary_max'] as int?,
        salaryCurrency: json['salary_currency'] as String?,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        skills: (json['skills'] as List<dynamic>?)
                ?.map((s) =>
                    JobSkillResponse.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class SkillMatch {
  final String skillName;
  final String? userLevel;
  final String? requiredLevel;

  const SkillMatch({
    required this.skillName,
    this.userLevel,
    this.requiredLevel,
  });
}

class MissingSkill {
  final String skillName;
  final bool isRequired;
  final String? category;

  const MissingSkill({
    required this.skillName,
    this.isRequired = true,
    this.category,
  });
}

class PartialSkill {
  final String skillName;
  final double? userYears;
  final int? requiredYears;
  final String gap;

  const PartialSkill({
    required this.skillName,
    this.userYears,
    this.requiredYears,
    this.gap = 'Need more experience',
  });
}

class SkillGapResponse {
  final String jobId;
  final String jobTitle;
  final List<SkillMatch> matchingSkills;
  final List<MissingSkill> missingSkills;
  final List<PartialSkill> partialSkills;
  final double matchPercentage;
  final String recommendation;

  const SkillGapResponse({
    required this.jobId,
    required this.jobTitle,
    this.matchingSkills = const [],
    this.missingSkills = const [],
    this.partialSkills = const [],
    required this.matchPercentage,
    required this.recommendation,
  });
}

class AlertResponse {
  final String id;
  bool isRead;
  bool isSaved;
  bool isApplied;
  final JobListItem job;
  final DateTime notifiedAt;
  final String? notificationChannel;
  final bool isDelivered;
  final DateTime? appliedAt;

  AlertResponse({
    required this.id,
    this.isRead = false,
    this.isSaved = false,
    this.isApplied = false,
    required this.job,
    required this.notifiedAt,
    this.notificationChannel,
    this.isDelivered = true,
    this.appliedAt,
  });
}

class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });
}
