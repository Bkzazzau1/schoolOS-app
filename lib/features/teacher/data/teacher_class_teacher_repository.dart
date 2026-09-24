import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/domain/report_card_models.dart';
import '../../principal/domain/class_teacher_models.dart';

class TeacherClassTeacherSnapshot {
  const TeacherClassTeacherSnapshot({required this.myClasses, required this.reportCards});

  /// The classes this Teacher is currently the class/form teacher for.
  final List<MyClassTeacherLink> myClasses;

  /// This class's report cards, not yet released, that this Teacher may
  /// still comment on.
  final List<ReportCard> reportCards;
}

class TeacherClassTeacherActionResult {
  const TeacherClassTeacherActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// A class/form teacher's own remark on a student's report card - separate
/// from, and no authority over, subject scores or Principal's review. See
/// PrincipalClassTeachersRepository for how this role is assigned.
class TeacherClassTeacherRepository {
  TeacherClassTeacherRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _linkType = classTeacherLinkEntityType;
  static const _reportCardType = reportCardEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<TeacherClassTeacherSnapshot> load() async {
    final membership = _requireTeacherMembership();
    final linkRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkType,
      entityId: membership.id,
    );
    final myClasses = (linkRecord?.payload['classes'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => MyClassTeacherLink.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    if (myClasses.isEmpty) {
      return const TeacherClassTeacherSnapshot(myClasses: [], reportCards: []);
    }
    final myClassNames = {for (final item in myClasses) item.className};

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _reportCardType,
    );
    final reportCards = records
        .map((r) => ReportCard.fromJson(r.payload))
        .where((card) => myClassNames.contains(card.className) && card.state != ReportCardState.released)
        .toList(growable: false)
      ..sort((a, b) => a.studentName.compareTo(b.studentName));

    return TeacherClassTeacherSnapshot(myClasses: myClasses, reportCards: reportCards);
  }

  Future<TeacherClassTeacherActionResult> comment(ReportCard card, String comment) async {
    final membership = _requireTeacherMembership();
    if (!LocalDatabase.blockDemoSeeds) {
      return const TeacherClassTeacherActionResult(
        success: false,
        message: 'A class-teacher comment is a canonical server workflow in connected mode.',
      );
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _reportCardType,
      entityId: card.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherClassTeacherActionResult(
        success: false,
        message: 'Synchronize this report card before commenting on it.',
      );
    }
    final current = ReportCard.fromJson(existing.payload);
    if (current.state == ReportCardState.released) {
      return const TeacherClassTeacherActionResult(
        success: false,
        message: 'A released report card\'s class-teacher comment cannot be silently rewritten.',
      );
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _reportCardType,
      entityId: card.id,
      payload: {..._localPayloadWithComment(existing.payload, comment.trim())},
      serverVersion: existing.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _reportCardType,
      entityId: card.id,
      operation: SyncOperation.update,
      payload: {'id': card.id, 'action': 'classTeacherComment', 'comment': comment.trim()},
      baseVersion: existing.serverVersion,
    );
    return const TeacherClassTeacherActionResult(
      success: true,
      message: 'Comment queued for synchronization.',
    );
  }

  Map<String, Object?> _localPayloadWithComment(Map<String, Object?> payload, String comment) =>
      {...payload, 'classTeacherComment': comment};

  SchoolMembership _requireTeacherMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.teacher) {
      throw StateError('Class-teacher comments require an active Teacher membership.');
    }
    return membership;
  }
}
