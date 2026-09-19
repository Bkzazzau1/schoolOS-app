import '../core/appearance/school_appearance_controller.dart';
import '../core/database/local_database.dart';
import '../core/security/payload_cipher.dart';
import '../core/tenancy/school_session_controller.dart';
import '../core/tenancy/school_session_store.dart';

class AppServices {
  AppServices._({
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
  });

  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;

  static Future<AppServices> bootstrap() async {
    final cipher = PayloadCipher();
    final localDatabase = LocalDatabase(cipher: cipher);
    await localDatabase.initialize();

    final schoolSession = SchoolSessionController(
      store: SchoolSessionStore(),
    );
    await schoolSession.restore();

    final schoolAppearance = SchoolAppearanceController(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
    );
    await schoolAppearance.initialize();

    return AppServices._(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
      schoolAppearance: schoolAppearance,
    );
  }
}
