import '../core/database/local_database.dart';
import '../core/security/payload_cipher.dart';
import '../core/tenancy/school_session_controller.dart';
import '../core/tenancy/school_session_store.dart';

class AppServices {
  AppServices._({
    required this.localDatabase,
    required this.schoolSession,
  });

  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;

  static Future<AppServices> bootstrap() async {
    final cipher = PayloadCipher();
    final localDatabase = LocalDatabase(cipher: cipher);
    await localDatabase.initialize();

    final schoolSession = SchoolSessionController(
      store: SchoolSessionStore(),
    );
    await schoolSession.restore();

    return AppServices._(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
    );
  }
}
