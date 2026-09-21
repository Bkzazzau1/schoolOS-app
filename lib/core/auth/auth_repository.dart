import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import '../network/api_exceptions.dart';
import '../tenancy/school_session_controller.dart';
import 'token_store.dart';

class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.memberships,
  });

  final String id;
  final String email;
  final String name;
  final List<SchoolMembership> memberships;

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        name: (json['name'] as String?) ?? '',
        memberships: [
          for (final item in (json['memberships'] as List? ?? const []))
            ?_membership(Map<String, dynamic>.from(item as Map)),
        ],
      );

  /// A role this version of the app does not know is skipped, not a crash.
  static SchoolMembership? _membership(Map<String, dynamic> json) {
    if (!SchoolRole.values.any((role) => role.name == json['role'])) return null;
    return SchoolMembership.fromJson(json);
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

  /// Signs in and loads the person's schools. Wrong details come back as an
  /// [ApiException] whose message is fit to show.
  Future<AuthProfile> signIn(String email, String password) async {
    final data = await _api.post(
      'auth/token/',
      body: {'email': email.trim().toLowerCase(), 'password': password},
      authenticated: false,
    );
    if (data is! Map || data['access'] is! String || data['refresh'] is! String) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    await _tokens.write(AuthTokens(access: data['access'] as String, refresh: data['refresh'] as String));
    return refreshProfile();
  }

  /// Asks the server who the person is and which schools they can act in, and
  /// keeps that list. Offline, the last known list stays as it was.
  Future<AuthProfile> refreshProfile() async {
    final data = await _api.get('me/');
    if (data is! Map) throw const ApiException(500, 'The server sent an unexpected answer.');
    final profile = AuthProfile.fromJson(Map<String, dynamic>.from(data));
    await _schoolSession.setMemberships(profile.memberships);
    return profile;
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
    await _tokens.write(AuthTokens(access: data['access'] as String, refresh: data['refresh'] as String));
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
