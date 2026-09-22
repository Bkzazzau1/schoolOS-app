import '../domain/principal_profile_models.dart';

/// The blank starting record the Principal is expected to fill in with their own real details
/// on first use of the Profile screen, not a claim about a real, specific person.
const principalDefaultProfile = PrincipalAccountProfile(
  fullName: '',
  displayName: '',
  email: '',
  phone: '',
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

const principalProfileRoleBoundary =
    'You can oversee academics, teachers, teaching assignments, students, attendance, approvals, results, communication and incidents inside the Secondary School section. Primary and Nursery remain separate leadership scopes unless you also hold an authorized membership there. Official school identity and ownership settings remain proprietor-controlled.';
const principalWorkspaceAccessInfo =
    'Workspace switching will recalculate tenant, campus, section, membership, role and permissions before any data is shown.';
const principalSchoolIdentityBoundary =
    'Only the proprietor or another explicitly authorized school owner can change official identity and letterhead information.';
