import '../../features/account/domain/organization_membership.dart';
import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import '../network/api_exceptions.dart';
import '../tenancy/school_session_controller.dart';
import 'token_store.dart';

class OnboardingStep {
  const OnboardingStep({
    required this.key,
    required this.label,
    required this.completed,
  });

  final String key;
  final String label;
  final bool completed;

  factory OnboardingStep.fromJson(Map<String, dynamic> json) => OnboardingStep(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
      );
}

class AccountOnboardingStatus {
  const AccountOnboardingStatus({
    required this.applicable,
    required this.ready,
    required this.completedCount,
    required this.totalCount,
    required this.steps,
  });

  const AccountOnboardingStatus.notApplicable()
      : applicable = false,
        ready = true,
        completedCount = 0,
        totalCount = 0,
        steps = const [];

  final bool applicable;
  final bool ready;
  final int completedCount;
  final int totalCount;
  final List<OnboardingStep> steps;

  factory AccountOnboardingStatus.fromJson(Map<String, dynamic> json) =>
      AccountOnboardingStatus(
        applicable: json['applicable'] as bool? ?? false,
        ready: json['ready'] as bool? ?? true,
        completedCount: json['completedCount'] as int? ?? 0,
        totalCount: json['totalCount'] as int? ?? 0,
        steps: [
          for (final item in (json['steps'] as List? ?? const []))
            if (item is Map)
              OnboardingStep.fromJson(Map<String, dynamic>.from(item)),
        ],
      );
}

class EmailVerificationDispatch {
  const EmailVerificationDispatch({
    required this.verified,
    required this.sent,
    this.expiresAt,
  });

  final bool verified;
  final bool sent;
  final DateTime? expiresAt;

  factory EmailVerificationDispatch.fromJson(Map<String, dynamic> json) {
    final rawExpiresAt = json['expiresAt'];
    return EmailVerificationDispatch(
      verified: json['verified'] as bool? ?? false,
      sent: json['sent'] as bool? ?? false,
      expiresAt: rawExpiresAt is String ? DateTime.tryParse(rawExpiresAt) : null,
    );
  }
}

class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.memberships,
    this.organizations = const [],
    this.mustChangePassword = false,
    this.emailVerified = true,
    this.onboarding = const AccountOnboardingStatus.notApplicable(),
  });

  final String id;
  final String email;
  final String name;
  final List<SchoolMembership> memberships;

  /// Account-level memberships sit above individual school tenants. They are
  /// optional so older SchoolOS backends remain compatible while the SaaS layer
  /// is rolled out.
  final List<OrganizationMembership> organizations;

  /// School-provisioned Student/Parent accounts start with the school's initial
  /// password rule and replace it after their first successful sign-in.
  final bool mustChangePassword;

  /// Account-level trust state returned by the backend. It is not inferred from
  /// school membership or local state. Missing state from an older backend is
  /// treated as already verified so rollout never removes existing access.
  final bool emailVerified;
  final AccountOnboardingStatus onboarding;

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: (json['name'] as String?) ?? '',
        mustChangePassword: json['mustChangePassword'] as bool? ?? false,
        emailVerified: json['emailVerified'] as bool? ?? true,
        onboarding: json['onboarding'] is Map
            ? AccountOnboardingStatus.fromJson(
                Map<String, dynamic>.from(json['onboarding'] as Map),
              )
            : const AccountOnboardingStatus.notApplicable(),
        memberships: [
          for (final item in (json['memberships'] as List? ?? const []))
            ?_membership(Map<String, dynamic>.from(item as Map)),
        ],
        organizations: [
          for (final item in ((json['organizations'] ?? json['organizationMemberships']) as List? ?? const []))
            ?_organizationMembership(Map<String, dynamic>.from(item as Map)),
        ],
      );

  /// A role this version of the app does not know is skipped, not a crash.
  static SchoolMembership? _membership(Map<String, dynamic> json) {
    if (!SchoolRole.values.any((role) => role.name == json['role'])) return null;
    return SchoolMembership.fromJson(json);
  }

  /// The account layer follows the same forward-compatibility rule as school
  /// roles: a role introduced by a newer server does not stop the person from
  /// signing in to schools this app version still understands.
  static OrganizationMembership? _organizationMembership(Map<String, dynamic> json) {
    try {
      return OrganizationMembership.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}

/// What an invitation link is for, shown before the person does anything.
class InvitationPreview {
  const InvitationPreview({
    required this.schoolName,
    required this.staffName,
    required this.maskedEmail,
    required this.expiresAt,
    required this.accountExists,
  });

  final String schoolName;
  final String staffName;

  /// Only the shape of the email (`m***@school.ng`); the link alone never reveals it.
  final String maskedEmail;
  final DateTime expiresAt;

  /// This email already has a SchoolOS account, so the person signs in instead of choosing a password.
  final bool accountExists;

  factory InvitationPreview.fromJson(Map<String, dynamic> json) => InvitationPreview(
        schoolName: json['schoolName'] as String? ?? '',
        staffName: json['staffName'] as String? ?? '',
        maskedEmail: json['email'] as String? ?? '',
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        accountExists: json['accountExists'] as bool? ?? false,
      );
}

class AcceptedInvitation {
  const AcceptedInvitation({required this.profile, required this.membership, required this.staffId});

  final AuthProfile profile;

  /// The school and role they now belong to.
  final SchoolMembership membership;
  final String staffId;
}

/// Signing in and out against the backend, and keeping the person's schools
/// (their memberships) in the school session.
class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required TokenStore tokens,
    required SchoolSessionController schoolSession,
  })  : _api = api,
        _tokens = tokens,
        _schoolSession = schoolSession;

  final ApiClient _api;
  final TokenStore _tokens;
  final SchoolSessionController _schoolSession;

  /// Signs in with an email, Student admission ID, or Parent phone number and
  /// then loads the person's school/account memberships.
  Future<AuthProfile> signIn(String identifier, String password) async {
    final data = await _api.post(
      'auth/token/',
      body: {'identifier': identifier.trim(), 'password': password},
      authenticated: false,
    );
    await _storeTokenPair(data);
    return refreshProfile();
  }

  /// Creates a new proprietor account and its first commercial organization,
  /// stores the returned session securely, then loads the canonical profile.
  Future<AuthProfile> registerProprietor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String organizationName,
  }) async {
    final data = await _api.post(
      'auth/register/',
      authenticated: false,
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'organizationName': organizationName.trim(),
      },
    );
    await _storeTokenPair(data);
    return refreshProfile();
  }

  Future<void> _storeTokenPair(Object? data) async {
    if (data is! Map || data['access'] is! String || data['refresh'] is! String) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    await _tokens.write(
      AuthTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      ),
    );
  }

  /// Asks the server who the person is, which organizations they can manage and
  /// which schools they can act in. The school list is kept for offline access.
  Future<AuthProfile> refreshProfile() async {
    final data = await _api.get('me/');
    if (data is! Map) throw const ApiException(500, 'The server sent an unexpected answer.');
    final profile = AuthProfile.fromJson(Map<String, dynamic>.from(data));
    await _schoolSession.setMemberships(profile.memberships);
    return profile;
  }

  Future<AuthProfile> completeInitialPassword(String newPassword) async {
    final data = await _api.post(
      'auth/password/initial-change/',
      body: {'newPassword': newPassword},
    );
    if (data is! Map || data['changed'] != true) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return refreshProfile();
  }

  Future<EmailVerificationDispatch> sendEmailVerification() async {
    final data = await _api.post(
      'auth/email-verification/send/',
      body: const {},
    );
    if (data is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return EmailVerificationDispatch.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<AuthProfile> confirmEmailVerification(String code) async {
    final data = await _api.post(
      'auth/email-verification/confirm/',
      body: {'code': code.trim()},
    );
    if (data is! Map || data['verified'] != true) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return refreshProfile();
  }

  /// What an invitation link is for. Needs no sign-in. A link that is unknown, expired, replaced or
  /// meant for another school is the same "not valid" answer, on purpose.
  Future<InvitationPreview> previewInvitation(String token) async {
    final data = await _api.get('invitations/$token/', authenticated: false);
    return InvitationPreview.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Accepts an invitation with a **new** account: they choose a password, and are signed in.
  Future<AcceptedInvitation> acceptInvitation(
    String token, {
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    final data = await _api.post(
      'invitations/$token/accept/',
      authenticated: false,
      body: {'firstName': firstName.trim(), 'lastName': lastName.trim(), 'password': password},
    );
    return _finishAccepting(data);
  }

  /// Accepts an invitation with an account that already exists. The link alone is not enough:
  /// they sign in as that account first, and the server checks it is the invited email.
  Future<AcceptedInvitation> acceptInvitationWithAccount(String token, {required String email, required String password}) async {
    await signIn(email, password);
    final data = await _api.post('invitations/$token/accept/', body: const {});
    return _finishAccepting(data);
  }

  Future<AcceptedInvitation> _finishAccepting(Object? data) async {
    if (data is! Map || data['access'] is! String || data['refresh'] is! String || data['membership'] is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    await _storeTokenPair(data);
    final membership = SchoolMembership.fromJson(Map<String, dynamic>.from(data['membership'] as Map));
    final profile = await refreshProfile();
    return AcceptedInvitation(profile: profile, membership: membership, staffId: data['staffId'] as String? ?? '');
  }

  /// Whether a sign-in from an earlier visit is still on the device.
  Future<bool> hasSession() async => await _tokens.read() != null;

  /// Signs out: the tokens and the chosen school are forgotten. Records already
  /// on the device stay (encrypted) so unsent work is not lost.
  Future<void> signOut() async {
    await _tokens.clear();
    await _schoolSession.clear();
  }
}
