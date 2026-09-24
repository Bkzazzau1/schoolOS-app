import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
import '../../administrator/data/administrator_attendance_repository.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../finance_office/data/finance_ledger_repository.dart';
import '../domain/parent_children_models.dart';

const _notRecorded = 'Not recorded yet';

String _initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  return parts.length == 1
      ? parts.first[0].toUpperCase()
      : (parts.first[0] + parts.last[0]).toUpperCase();
}

String _progressionDescription(Map<String, Object?> item) {
  final workflow = item['workflow'] as String? ?? 'Class update';
  final from = item['fromClass'] as String? ?? '';
  final to = item['toClass'] as String? ?? '';
  if (from.isNotEmpty && to.isNotEmpty) return '$workflow · $from → $to';
  if (from.isNotEmpty) return '$workflow · $from';
  if (to.isNotEmpty) return '$workflow · $to';
  return workflow;
}

String _dateLabel(Object? value) {
  if (value is! String || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

class ParentChildrenRepository {
  ParentChildrenRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    required AdministratorAttendanceRepository attendance,
    required FinanceLedgerRepository ledger,
  }) : _localDatabase = localDatabase,
       _schoolSession = schoolSession,
       _students = students,
       _attendance = attendance,
       _ledger = ledger;

  /// Server-connected schools receive a private family-link record whose entity
  /// id is the Parent membership id. Standalone demo mode keeps the old fixed
  /// sample links. A real parent account never falls back to those demo pupils.
  static const _linkEntityType = 'parent_family_link';
  static const _seedChildIds = ['STU-001', 'PRI-003'];

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final AdministratorAttendanceRepository _attendance;
  final FinanceLedgerRepository _ledger;

  Future<Map<String, Object?>?> _familyPayload(
    SchoolMembership membership,
  ) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkEntityType,
      entityId: membership.id,
    );
    if (existing != null) {
      return Map<String, Object?>.from(existing.payload);
    }
    if (LocalDatabase.blockDemoSeeds) return null;
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkEntityType,
      entityId: membership.id,
      payload: {'childIds': _seedChildIds},
    );
    return {'childIds': _seedChildIds};
  }

  Future<List<String>> _linkedChildIds(SchoolMembership membership) async {
    final payload = await _familyPayload(membership);
    return List<String>.from(
      payload?['childIds'] as List? ?? const <String>[],
    );
  }

  Future<ParentChildrenSnapshot> load() async {
    final membership = _requireParentMembership();
    final familyPayload = await _familyPayload(membership);
    final canonicalChildren = [
      for (final item in (familyPayload?['children'] as List? ?? const []))
        if (item is Map) Map<String, Object?>.from(item),
    ];
    final childIds = canonicalChildren.isNotEmpty
        ? canonicalChildren
            .map((item) => item['studentId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList(growable: false)
        : await _linkedChildIds(membership);

    final register = (await _students.load()).students;
    final accounts = await _ledger.accounts();
    final attendanceSnapshot = await _attendance.load(students: register);

    String key(String name) => name.trim().toLowerCase();
    final children = <ParentLinkedChild>[];
    for (final id in childIds) {
      AdministratorStudentRecord? student;
      for (final candidate in register) {
        if (candidate.id == id) {
          student = candidate;
          break;
        }
      }
      Map<String, Object?>? canonical;
      for (final candidate in canonicalChildren) {
        if (candidate['studentId'] == id) {
          canonical = candidate;
          break;
        }
      }
      if (student == null && canonical == null) continue;

      final name = canonical?['name'] as String? ?? student!.name;
      final className = canonical?['className'] as String? ?? student?.className ?? '';
      final section = canonical?['academicSection'] as String? ??
          (className.isEmpty ? _notRecorded : sectionOfClass(className));
      final account = accounts.where((item) => item.student.id == id).firstOrNull;
      final todayEvent = attendanceSnapshot.events
          .where(
            (event) => !event.isUnknown && key(event.student) == key(name),
          )
          .firstOrNull;
      final attendanceLabel = todayEvent == null
          ? _notRecorded
          : (todayEvent.countsAsPresent
                ? 'Present today'
                : todayEvent.status.label);
      final progression = [
        for (final item in (canonical?['progressionHistory'] as List? ?? const []))
          if (item is Map) Map<String, Object?>.from(item),
      ];

      children.add(
        ParentLinkedChild(
          id: id,
          name: name,
          initials: _initialsOf(name),
          className: className.isEmpty ? _notRecorded : className,
          section: section,
          admissionNumber:
              canonical?['admissionNumber'] as String? ?? _notRecorded,
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
          timeline: [
            for (final event in progression)
              ParentChildTimelineEvent(
                dateLabel: _dateLabel(
                  event['completedAt'] ?? event['requestedAt'],
                ),
                description: _progressionDescription(event),
              ),
          ],
          active: canonical?['active'] as bool? ??
              (student?.status == AdministratorStudentStatus.active),
          presentToday: todayEvent?.countsAsPresent ?? false,
        ),
      );
    }

    return ParentChildrenSnapshot(
      familyAccountId: membership.id,
      academicPeriod: canonicalChildren.isNotEmpty
          ? 'Canonical enrollment history'
          : _notRecorded,
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

  /// Stores a server-confirmed family link under the active Parent membership.
  Future<void> replaceLinkedChildren({
    required List<String> childIds,
  }) async {
    final membership = _requireParentMembership();
    final ids = <String>{};
    for (final id in childIds) {
      if (id.trim().isEmpty || !ids.add(id)) {
        throw StateError(
          'Server family payload contains an invalid linked child id.',
        );
      }
    }
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _linkEntityType,
      entityId: membership.id,
      payload: {'childIds': childIds},
      isDirty: false,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError(
        'Linked family records require an active Parent membership.',
      );
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
