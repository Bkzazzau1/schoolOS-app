import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_attendance_repository.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../finance_office/data/finance_ledger_repository.dart';
import '../domain/parent_children_models.dart';

const _notRecorded = 'Not recorded yet';

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
}

class ParentChildrenRepository {
  ParentChildrenRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    required AdministratorAttendanceRepository attendance,
    required FinanceLedgerRepository ledger,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _students = students,
        _attendance = attendance,
        _ledger = ledger;

  /// Which real students are linked to a guardian family account. There is no real guardian
  /// onboarding/linking workflow anywhere in the app yet, so this starts from a fixed seed —
  /// the same "a real workflow will replace this seed later" pattern used for Admissions and
  /// Registration — but every field about the linked child below is computed live from the
  /// real student, attendance and finance registers, not invented.
  static const _linkEntityType = 'parent_family_link';
  static const _linkId = 'link';
  static const _seedChildIds = ['STU-001', 'PRI-003'];

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final AdministratorAttendanceRepository _attendance;
  final FinanceLedgerRepository _ledger;

  Future<List<String>> _linkedChildIds(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkEntityType,
      entityId: _linkId,
    );
    if (existing != null) {
      return List<String>.from(existing.payload['childIds'] as List? ?? _seedChildIds);
    }
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkEntityType,
      entityId: _linkId,
      payload: {'childIds': _seedChildIds},
    );
    return _seedChildIds;
  }

  Future<ParentChildrenSnapshot> load() async {
    final membership = _requireParentMembership();
    final childIds = await _linkedChildIds(membership);
    final register = (await _students.load()).students;
    final accounts = await _ledger.accounts();
    final attendanceSnapshot = await _attendance.load(students: register);

    String key(String name) => name.trim().toLowerCase();
    final children = <ParentLinkedChild>[];
    for (final id in childIds) {
      AdministratorStudentRecord? student;
      for (final s in register) {
        if (s.id == id) {
          student = s;
          break;
        }
      }
      if (student == null) continue;

      final account = accounts.where((a) => a.student.id == id).firstOrNull;
      final todayEvent = attendanceSnapshot.events
          .where((e) => !e.isUnknown && key(e.student) == key(student!.name))
          .firstOrNull;
      final attendanceLabel = todayEvent == null ? _notRecorded : (todayEvent.countsAsPresent ? 'Present today' : todayEvent.status.label);

      children.add(ParentLinkedChild(
        id: student.id,
        name: student.name,
        initials: _initialsOf(student.name),
        className: student.className,
        section: sectionOfClass(student.className),
        admissionNumber: _notRecorded,
        classTeacher: _notRecorded,
        attendanceLabel: attendanceLabel,
        learningLabel: _notRecorded,
        house: _notRecorded,
        currentBalance: account?.balance ?? 0,
        transport: _notRecorded,
        paymentAccount: _notRecorded,
        paymentPlan: _notRecorded,
        activities: _notRecorded,
        subjects: const [],
        timeline: const [],
        active: student.status == AdministratorStudentStatus.active,
        presentToday: todayEvent?.countsAsPresent ?? false,
      ));
    }

    return ParentChildrenSnapshot(
      familyAccountId: membership.id,
      academicPeriod: _notRecorded,
      children: children,
    );
  }

  Future<ParentLinkedChild> childById(String childId) async {
    if (childId.trim().isEmpty) {
      throw ArgumentError.value(childId, 'childId', 'Child id is required.');
    }

    final snapshot = await load();
    for (final child in snapshot.children) {
      if (child.id == childId) return child;
    }

    throw StateError(
      'The requested child is not linked to the active guardian membership.',
    );
  }

  /// With a school server, the family's real linked-child list and confirmed identity details
  /// arrive this way instead of the local seed.
  Future<void> replaceLinkedChildren({
    required List<String> childIds,
  }) async {
    final membership = _requireParentMembership();
    final ids = <String>{};
    for (final id in childIds) {
      if (id.trim().isEmpty || !ids.add(id)) {
        throw StateError('Server family payload contains an invalid linked child id.');
      }
    }
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkEntityType,
      entityId: _linkId,
      payload: {'childIds': childIds},
      isDirty: false,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Linked family records require an active Parent membership.');
    }
    return membership;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
