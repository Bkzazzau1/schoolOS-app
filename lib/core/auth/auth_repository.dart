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

  /// Whether a sign-in from an earlier visit is still on the device.
  Future<bool> hasSession() async => await _tokens.read() != null;

  /// Signs out: the tokens and the chosen school are forgotten. Records already
  /// on the device stay (encrypted) so unsent work is not lost.
  Future<void> signOut() async {
    await _tokens.clear();
    await _schoolSession.clear();
  }
}
