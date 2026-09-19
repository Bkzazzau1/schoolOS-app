import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_profile_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_profile_models.dart';

void main() {
  test('principal profile preserves exact website identity defaults', () {
    expect(principalDefaultProfile.fullName, 'Mr. Ibrahim Danladi');
    expect(principalDefaultProfile.displayName, 'Ibrahim Danladi');
    expect(principalDefaultProfile.email, 'principal@brightgate.example');
    expect(principalDefaultProfile.phone, '+234 800 000 0101');
    expect(principalDefaultProfile.role, 'Principal');
    expect(principalDefaultProfile.academicSection, 'Secondary School');
  });

  test('all six notification preferences are enabled by default', () {
    expect(PrincipalPreferenceKey.values, hasLength(6));
    for (final key in PrincipalPreferenceKey.values) {
      expect(principalDefaultPreferences.isEnabled(key), isTrue);
    }
  });

  test('profile and preferences serialize cleanly', () {
    final profile = PrincipalAccountProfile.fromJson(principalDefaultProfile.toJson());
    expect(profile.fullName, principalDefaultProfile.fullName);
    expect(profile.email, principalDefaultProfile.email);

    final prefs = PrincipalNotificationPreferences.fromJson(principalDefaultPreferences.toJson());
    expect(prefs.values.length, 6);
    expect(prefs.isEnabled(PrincipalPreferenceKey.aiBrief), isTrue);
    expect(prefs.toggled(PrincipalPreferenceKey.aiBrief).isEnabled(PrincipalPreferenceKey.aiBrief), isFalse);
  });

  test('workspace boundary keeps principal secondary-only and owner settings controlled', () {
    expect(principalProfileRoleBoundary, contains('Secondary School section'));
    expect(principalProfileRoleBoundary, contains('Primary and Nursery remain separate leadership scopes'));
    expect(principalProfileRoleBoundary, contains('Official school identity and ownership settings remain proprietor-controlled'));
    expect(principalSchoolIdentityBoundary, contains('Only the proprietor'));
  });

  test('exact school identity and activity records are preserved', () {
    expect(principalSchoolIdentity.name, 'BrightGate Academy');
    expect(principalSchoolIdentity.address, '12 Learning Avenue, Kaduna, Kaduna State, Nigeria');
    expect(principalSchoolIdentity.phone, '+234 800 000 0000');
    expect(principalSchoolIdentity.branches, ['Kaduna Campus', 'Zaria Campus']);
    expect(principalProfileRecentActivity, hasLength(4));
    expect(principalProfileRecentActivity.first.action, 'Approved JSS 2B report-card batch');
    expect(principalProfileLastSignIn, 'Today · 7:18 AM');
  });

  test('security boundary remains prototype-only rather than faking auth changes', () {
    expect(principalWorkspaceAccessInfo, contains('tenant, campus, section, membership, role and permissions'));
  });
}
