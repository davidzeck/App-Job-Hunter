import 'package:job_scout/core/models/models.dart';

/// Static mock data matching the backend's seed data.
/// Used by MockApiService to simulate API responses.

// Mutable skills list — modified by skills screen
var mockUserSkills = <String>[
  'Python',
  'FastAPI',
  'PostgreSQL',
  'Docker',
  'React',
  'TypeScript',
  'Redis',
  'AWS',
];

final mockUser = UserProfileResponse(
  id: 'u-001',
  email: 'dev@jobscout.com',
  fullName: 'Alex Kimani',
  phone: '+254712345678',
  emailVerified: true,
  isActive: true,
  preferences: {
    'roles': ['backend_engineer', 'fullstack_engineer'],
    'locations': ['kenya', 'remote'],
    'companies': [],
    'notifications': {'push': true, 'email': true, 'frequency': 'immediate'},
  },
  skillsCount: 8,
  hasCv: true,
  createdAt: DateTime(2024, 6, 1),
  updatedAt: DateTime.now(),
);

// ─── Companies ─────────────────────────────────────────────────

const _safaricom = CompanyBrief(
  id: 'c-001',
  name: 'Safaricom',
  slug: 'safaricom',
  logoUrl: 'https://logo.clearbit.com/safaricom.co.ke',
);

const _twilio = CompanyBrief(
  id: 'c-002',
  name: 'Twilio',
  slug: 'twilio',
  logoUrl: 'https://logo.clearbit.com/twilio.com',
);

const _cloudflare = CompanyBrief(
  id: 'c-003',
  name: 'Cloudflare',
  slug: 'cloudflare',
  logoUrl: 'https://logo.clearbit.com/cloudflare.com',
);

const _gitlab = CompanyBrief(
  id: 'c-004',
  name: 'GitLab',
  slug: 'gitlab',
  logoUrl: 'https://logo.clearbit.com/gitlab.com',
);

const _spotify = CompanyBrief(
  id: 'c-005',
  name: 'Spotify',
  slug: 'spotify',
  logoUrl: 'https://logo.clearbit.com/spotify.com',
);

const _plaid = CompanyBrief(
  id: 'c-006',
  name: 'Plaid',
  slug: 'plaid',
  logoUrl: 'https://logo.clearbit.com/plaid.com',
);

final mockCompanies = [
  CompanyResponse(
    id: 'c-001',
    name: 'Safaricom',
    slug: 'safaricom',
    careersUrl: 'https://safaricom.co.ke/careers',
    logoUrl: 'https://logo.clearbit.com/safaricom.co.ke',
    description: "Kenya's leading telecommunications company",
    jobsCount: 2,
    sourcesCount: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime.now(),
  ),
  CompanyResponse(
    id: 'c-002',
    name: 'Twilio',
    slug: 'twilio',
    careersUrl: 'https://boards.greenhouse.io/twilio',
    logoUrl: 'https://logo.clearbit.com/twilio.com',
    description: 'Cloud communications platform',
    jobsCount: 118,
    sourcesCount: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime.now(),
  ),
  CompanyResponse(
    id: 'c-003',
    name: 'Cloudflare',
    slug: 'cloudflare',
    careersUrl: 'https://boards.greenhouse.io/cloudflare',
    logoUrl: 'https://logo.clearbit.com/cloudflare.com',
    description: 'Web infrastructure and security company',
    jobsCount: 628,
    sourcesCount: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime.now(),
  ),
  CompanyResponse(
    id: 'c-004',
    name: 'GitLab',
    slug: 'gitlab',
    careersUrl: 'https://boards.greenhouse.io/gitlab',
    logoUrl: 'https://logo.clearbit.com/gitlab.com',
    description: 'DevOps platform, all-remote company',
    jobsCount: 157,
    sourcesCount: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime.now(),
  ),
  CompanyResponse(
    id: 'c-005',
    name: 'Spotify',
    slug: 'spotify',
    careersUrl: 'https://jobs.lever.co/spotify',
    logoUrl: 'https://logo.clearbit.com/spotify.com',
    description: 'Music streaming platform',
    jobsCount: 143,
    sourcesCount: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime.now(),
  ),
  CompanyResponse(
    id: 'c-006',
    name: 'Plaid',
    slug: 'plaid',
    careersUrl: 'https://jobs.lever.co/plaid',
    logoUrl: 'https://logo.clearbit.com/plaid.com',
    description: 'Fintech infrastructure for financial services',
    jobsCount: 95,
    sourcesCount: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime.now(),
  ),
];

// ─── Jobs ──────────────────────────────────────────────────────

final _now = DateTime.now();

final mockJobs = <JobListItem>[
  JobListItem(
    id: 'j-001',
    title: 'Senior Backend Engineer',
    location: 'Nairobi, Kenya',
    locationType: 'hybrid',
    jobType: 'full_time',
    applyUrl: 'https://safaricom.co.ke/careers/senior-backend-engineer',
    company: _safaricom,
    postedAt: _now.subtract(const Duration(hours: 3)),
    discoveredAt: _now.subtract(const Duration(hours: 2)),
  ),
  JobListItem(
    id: 'j-002',
    title: 'Frontend Developer',
    location: 'Nairobi, Kenya',
    locationType: 'onsite',
    jobType: 'full_time',
    applyUrl: 'https://safaricom.co.ke/careers/frontend-developer',
    company: _safaricom,
    postedAt: _now.subtract(const Duration(hours: 8)),
    discoveredAt: _now.subtract(const Duration(hours: 7)),
  ),
  JobListItem(
    id: 'j-003',
    title: 'Software Engineer, Cloud Platform',
    location: 'Remote',
    locationType: 'remote',
    jobType: 'full_time',
    applyUrl: 'https://boards.greenhouse.io/twilio',
    company: _twilio,
    postedAt: _now.subtract(const Duration(days: 1)),
    discoveredAt: _now.subtract(const Duration(hours: 18)),
  ),
  JobListItem(
    id: 'j-004',
    title: 'Systems Engineer',
    location: 'Remote',
    locationType: 'remote',
    jobType: 'full_time',
    applyUrl: 'https://boards.greenhouse.io/cloudflare',
    company: _cloudflare,
    postedAt: _now.subtract(const Duration(days: 1)),
    discoveredAt: _now.subtract(const Duration(days: 1)),
  ),
  JobListItem(
    id: 'j-005',
    title: 'Senior Site Reliability Engineer',
    location: 'Remote, Worldwide',
    locationType: 'remote',
    jobType: 'full_time',
    applyUrl: 'https://boards.greenhouse.io/gitlab',
    company: _gitlab,
    postedAt: _now.subtract(const Duration(days: 2)),
    discoveredAt: _now.subtract(const Duration(days: 2)),
  ),
  JobListItem(
    id: 'j-006',
    title: 'Full Stack Engineer',
    location: 'Stockholm, Sweden',
    locationType: 'hybrid',
    jobType: 'full_time',
    applyUrl: 'https://jobs.lever.co/spotify',
    company: _spotify,
    postedAt: _now.subtract(const Duration(days: 2)),
    discoveredAt: _now.subtract(const Duration(days: 2)),
  ),
  JobListItem(
    id: 'j-007',
    title: 'Backend Engineer',
    location: 'San Francisco, CA',
    locationType: 'hybrid',
    jobType: 'full_time',
    applyUrl: 'https://jobs.lever.co/plaid',
    company: _plaid,
    postedAt: _now.subtract(const Duration(days: 3)),
    discoveredAt: _now.subtract(const Duration(days: 3)),
  ),
  JobListItem(
    id: 'j-008',
    title: 'DevOps Engineer',
    location: 'Remote',
    locationType: 'remote',
    jobType: 'full_time',
    applyUrl: 'https://boards.greenhouse.io/gitlab',
    company: _gitlab,
    postedAt: _now.subtract(const Duration(days: 4)),
    discoveredAt: _now.subtract(const Duration(days: 3)),
  ),
];

// ─── Job Details ───────────────────────────────────────────────

final mockJobDetails = <String, JobDetail>{
  'j-001': JobDetail(
    id: 'j-001',
    title: 'Senior Backend Engineer',
    location: 'Nairobi, Kenya',
    locationType: 'hybrid',
    jobType: 'full_time',
    seniorityLevel: 'senior',
    applyUrl: 'https://safaricom.co.ke/careers/senior-backend-engineer',
    company: _safaricom,
    postedAt: _now.subtract(const Duration(hours: 3)),
    discoveredAt: _now.subtract(const Duration(hours: 2)),
    salaryMin: 350000,
    salaryMax: 550000,
    salaryCurrency: 'KES',
    description:
        'We are looking for a Senior Backend Engineer to join our M-PESA team. '
        'You will design and build scalable microservices handling millions of '
        'transactions daily. The ideal candidate has deep experience with Python, '
        'distributed systems, and high-throughput APIs.\n\n'
        'Responsibilities:\n'
        '- Design and implement microservices for the M-PESA platform\n'
        '- Optimize database queries and caching strategies\n'
        '- Mentor junior engineers and conduct code reviews\n'
        '- Collaborate with product and infrastructure teams\n\n'
        'Requirements:\n'
        '- 5+ years of backend development experience\n'
        '- Strong Python and Django/FastAPI skills\n'
        '- Experience with PostgreSQL and Redis\n'
        '- Familiarity with Docker and Kubernetes',
    skills: const [
      JobSkillResponse(skillName: 'Python', skillCategory: 'language', isRequired: true, minYearsExperience: 3),
      JobSkillResponse(skillName: 'Django', skillCategory: 'framework', isRequired: true, minYearsExperience: 2),
      JobSkillResponse(skillName: 'PostgreSQL', skillCategory: 'database', isRequired: true, minYearsExperience: 2),
      JobSkillResponse(skillName: 'Docker', skillCategory: 'tool', minYearsExperience: 1),
      JobSkillResponse(skillName: 'Kubernetes', skillCategory: 'cloud', minYearsExperience: 1),
    ],
    createdAt: _now.subtract(const Duration(hours: 3)),
    updatedAt: _now.subtract(const Duration(hours: 2)),
  ),
  'j-003': JobDetail(
    id: 'j-003',
    title: 'Software Engineer, Cloud Platform',
    location: 'Remote',
    locationType: 'remote',
    jobType: 'full_time',
    seniorityLevel: 'mid',
    applyUrl: 'https://boards.greenhouse.io/twilio',
    company: _twilio,
    postedAt: _now.subtract(const Duration(days: 1)),
    discoveredAt: _now.subtract(const Duration(hours: 18)),
    salaryMin: 4000,
    salaryMax: 7000,
    salaryCurrency: 'USD',
    description:
        'Design, develop, and test cloud communication APIs used by millions of '
        'developers worldwide. You will work on Twilio\'s core messaging '
        'infrastructure, building systems that process billions of messages.\n\n'
        'What you\'ll do:\n'
        '- Build and maintain high-throughput distributed systems\n'
        '- Design APIs that developers love to use\n'
        '- Participate in on-call rotation\n'
        '- Write clean, tested, production-ready code',
    skills: const [
      JobSkillResponse(skillName: 'Go', skillCategory: 'language', isRequired: true, minYearsExperience: 2),
      JobSkillResponse(skillName: 'Python', skillCategory: 'language', isRequired: true, minYearsExperience: 2),
      JobSkillResponse(skillName: 'Kubernetes', skillCategory: 'cloud', isRequired: true, minYearsExperience: 1),
      JobSkillResponse(skillName: 'gRPC', skillCategory: 'framework'),
      JobSkillResponse(skillName: 'Distributed Systems', skillCategory: 'concept', isRequired: true, minYearsExperience: 2),
    ],
    createdAt: _now.subtract(const Duration(days: 1)),
    updatedAt: _now.subtract(const Duration(hours: 18)),
  ),
  'j-004': JobDetail(
    id: 'j-004',
    title: 'Systems Engineer',
    location: 'Remote',
    locationType: 'remote',
    jobType: 'full_time',
    seniorityLevel: 'senior',
    applyUrl: 'https://boards.greenhouse.io/cloudflare',
    company: _cloudflare,
    postedAt: _now.subtract(const Duration(days: 1)),
    discoveredAt: _now.subtract(const Duration(days: 1)),
    salaryMin: 5000,
    salaryMax: 9000,
    salaryCurrency: 'USD',
    description:
        'Build and maintain edge infrastructure serving millions of requests '
        'per second globally. Work on Cloudflare Workers, network protocols, '
        'and performance-critical systems written in Rust and Go.',
    skills: const [
      JobSkillResponse(skillName: 'Rust', skillCategory: 'language', isRequired: true, minYearsExperience: 2),
      JobSkillResponse(skillName: 'Go', skillCategory: 'language', isRequired: true, minYearsExperience: 2),
      JobSkillResponse(skillName: 'Linux', skillCategory: 'tool', isRequired: true, minYearsExperience: 3),
      JobSkillResponse(skillName: 'Networking', skillCategory: 'concept', isRequired: true, minYearsExperience: 2),
    ],
    createdAt: _now.subtract(const Duration(days: 1)),
    updatedAt: _now.subtract(const Duration(days: 1)),
  ),
};

// ─── Skill Gap Analysis ────────────────────────────────────────

final mockSkillGaps = <String, SkillGapResponse>{
  'j-001': const SkillGapResponse(
    jobId: 'j-001',
    jobTitle: 'Senior Backend Engineer',
    matchPercentage: 72.0,
    recommendation:
        'Strong match! You have most required skills. Focus on gaining '
        'Kubernetes experience to close the gap.',
    matchingSkills: [
      SkillMatch(skillName: 'Python', userLevel: '4 years', requiredLevel: '3 years'),
      SkillMatch(skillName: 'Django', userLevel: '3 years', requiredLevel: '2 years'),
      SkillMatch(skillName: 'PostgreSQL', userLevel: '3 years', requiredLevel: '2 years'),
    ],
    missingSkills: [
      MissingSkill(skillName: 'Kubernetes', category: 'cloud'),
    ],
    partialSkills: [
      PartialSkill(skillName: 'Docker', userYears: 0.5, requiredYears: 1),
    ],
  ),
  'j-003': const SkillGapResponse(
    jobId: 'j-003',
    jobTitle: 'Software Engineer, Cloud Platform',
    matchPercentage: 45.0,
    recommendation:
        'Partial match. You have Python but need Go and distributed systems '
        'experience. Consider open-source contributions to build these skills.',
    matchingSkills: [
      SkillMatch(skillName: 'Python', userLevel: '4 years', requiredLevel: '2 years'),
    ],
    missingSkills: [
      MissingSkill(skillName: 'Go', isRequired: true, category: 'language'),
      MissingSkill(skillName: 'gRPC', category: 'framework'),
      MissingSkill(skillName: 'Distributed Systems', isRequired: true, category: 'concept'),
    ],
    partialSkills: [
      PartialSkill(skillName: 'Kubernetes', userYears: 0.5, requiredYears: 1),
    ],
  ),
  'j-004': const SkillGapResponse(
    jobId: 'j-004',
    jobTitle: 'Systems Engineer',
    matchPercentage: 25.0,
    recommendation:
        'Low match. This role requires Rust and deep networking knowledge '
        'which are not in your current skill set. Consider a learning path if '
        'this direction interests you.',
    matchingSkills: [],
    missingSkills: [
      MissingSkill(skillName: 'Rust', isRequired: true, category: 'language'),
      MissingSkill(skillName: 'Go', isRequired: true, category: 'language'),
      MissingSkill(skillName: 'Networking', isRequired: true, category: 'concept'),
    ],
    partialSkills: [
      PartialSkill(skillName: 'Linux', userYears: 1, requiredYears: 3),
    ],
  ),
};

// ─── Alerts ────────────────────────────────────────────────────

final mockAlerts = <AlertResponse>[
  AlertResponse(
    id: 'a-001',
    isRead: false,
    job: mockJobs[0], // Senior Backend Engineer @ Safaricom
    notifiedAt: _now.subtract(const Duration(hours: 1)),
    notificationChannel: 'push',
  ),
  AlertResponse(
    id: 'a-002',
    isRead: false,
    job: mockJobs[2], // Cloud Platform @ Twilio
    notifiedAt: _now.subtract(const Duration(hours: 5)),
    notificationChannel: 'push',
  ),
  AlertResponse(
    id: 'a-003',
    isRead: false,
    isSaved: true,
    job: mockJobs[3], // Systems Engineer @ Cloudflare
    notifiedAt: _now.subtract(const Duration(days: 1)),
    notificationChannel: 'email',
  ),
  AlertResponse(
    id: 'a-004',
    isRead: true,
    isSaved: true,
    job: mockJobs[4], // SRE @ GitLab
    notifiedAt: _now.subtract(const Duration(days: 2)),
    notificationChannel: 'push',
  ),
  AlertResponse(
    id: 'a-005',
    isRead: true,
    isApplied: true,
    job: mockJobs[5], // Full Stack @ Spotify
    notifiedAt: _now.subtract(const Duration(days: 3)),
    notificationChannel: 'push',
    appliedAt: _now.subtract(const Duration(days: 2)),
  ),
  AlertResponse(
    id: 'a-006',
    isRead: true,
    job: mockJobs[6], // Backend @ Plaid
    notifiedAt: _now.subtract(const Duration(days: 4)),
    notificationChannel: 'email',
  ),
];

// ─── Dashboard Stats ───────────────────────────────────────────

final mockDashboardStats = {
  'totalJobs': mockJobs.length,
  'newToday': 3,
  'unreadAlerts': mockAlerts.where((a) => !a.isRead).length,
  'savedJobs': mockAlerts.where((a) => a.isSaved).length,
  'applied': mockAlerts.where((a) => a.isApplied).length,
};
