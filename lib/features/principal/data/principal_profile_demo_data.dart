import '../domain/principal_profile_models.dart';

const principalDefaultProfile = PrincipalAccountProfile(
  fullName: 'Mr. Ibrahim Danladi',
  displayName: 'Ibrahim Danladi',
  email: 'principal@brightgate.example',
  phone: '+234 800 000 0101',
  role: 'Principal',
  academicSection: 'Secondary School',
);

const principalDefaultPreferences = PrincipalNotificationPreferences(values: {
  PrincipalPreferenceKey.approvals: true,
  PrincipalPreferenceKey.attendance: true,
  PrincipalPreferenceKey.incidents: true,
  PrincipalPreferenceKey.reports: true,
  PrincipalPreferenceKey.messages: true,
  PrincipalPreferenceKey.aiBrief: true,
});

const principalProfileRecentActivity = <PrincipalProfileActivity>[
  PrincipalProfileActivity(time: 'Today · 11:42 AM', action: 'Approved JSS 2B report-card batch'),
  PrincipalProfileActivity(time: 'Today · 10:32 AM', action: 'Opened restricted incident INC-2402'),
  PrincipalProfileActivity(time: 'Today · 9:18 AM', action: 'Reviewed Mrs. Amina Yusuf lesson plan'),
  PrincipalProfileActivity(time: 'Yesterday · 3:12 PM', action: 'Sent JSS 2B attendance follow-up'),
];

const principalSchoolIdentity = PrincipalSchoolIdentity(
  name: 'BrightGate Academy',
  address: '12 Learning Avenue, Kaduna, Kaduna State, Nigeria',
  phone: '+234 800 000 0000',
  branches: ['Kaduna Campus', 'Zaria Campus'],
);

const principalProfileLastSignIn = 'Today · 7:18 AM';
const principalProfileTermLabel = 'Kaduna Campus · Secondary School · 1st Term 2026/27';
const principalProfileRoleBoundary =
    'You can oversee academics, teachers, teaching assignments, students, attendance, approvals, results, communication and incidents inside the Secondary School section. Primary and Nursery remain separate leadership scopes unless you also hold an authorized membership there. Official school identity and ownership settings remain proprietor-controlled.';
const principalWorkspaceAccessInfo =
    'Workspace switching will recalculate tenant, campus, section, membership, role and permissions before any data is shown.';
const principalSchoolIdentityBoundary =
    'Only the proprietor or another explicitly authorized school owner can change official identity and letterhead information.';
