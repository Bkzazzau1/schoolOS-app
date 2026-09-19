import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  static const foundationClasses = <AttendanceClass>[
    AttendanceClass(id: 'jss-1-a', name: 'JSS 1A'),
    AttendanceClass(id: 'jss-2-b', name: 'JSS 2B'),
  ];

  Future<List<AttendanceStudent>> loadRoster(String classId) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'class_roster',
      entityId: classId,
    );

    if (record == null) {
      // Foundation data only. The real roster will be downloaded by the sync
      // API and cached through the same local_records boundary.
      final students = _foundationRoster(classId);
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: 'class_roster',
        entityId: classId,
        payload: {
          'classId': classId,
          'students': students.map((student) => student.toJson()).toList(),
        },
      );
      return students;
    }

    final rawStudents = record.payload['students'];
    if (rawStudents is! List) return const [];

    return rawStudents
        .whereType<Map>()
        .map(
          (item) => AttendanceStudent.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveAttendance({
    required AttendanceClass schoolClass,
    required DateTime date,
    required List<AttendanceEntry> entries,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final dateKey = _dateKey(date);
    final entityId = '${schoolClass.id}:$dateKey';
    final payload = <String, Object?>{
      'classId': schoolClass.id,
      'className': schoolClass.name,
      'date': dateKey,
      'recordedByMembershipId': membership.id,
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'attendance_session',
      entityId: entityId,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'attendance_session',
      entityId: entityId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: 'attendance_session',
      entityId: entityId,
      operation:
          existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  Future<Map<String, AttendanceStatus>?> loadSavedAttendance({
    required AttendanceClass schoolClass,
    required DateTime date,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final entityId = '${schoolClass.id}:${_dateKey(date)}';
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'attendance_session',
      entityId: entityId,
    );

    if (record == null) return null;
    final rawEntries = record.payload['entries'];
    if (rawEntries is! List) return null;

    final statuses = <String, AttendanceStatus>{};
    for (final rawEntry in rawEntries.whereType<Map>()) {
      final entry = rawEntry.cast<String, dynamic>();
      final studentId = entry['studentId'];
      final status = entry['status'];
      if (studentId is String && status is String) {
        statuses[studentId] = AttendanceStatus.values.byName(status);
      }
    }
    return statuses;
  }
}

String _dateKey(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

List<AttendanceStudent> _foundationRoster(String classId) {
  final prefix = classId == 'jss-2-b' ? 'J2B' : 'J1A';
  const names = [
    'Aisha Musa',
    'Abdullahi Sani',
    'Fatima Bello',
    'Muhammad Umar',
    'Maryam Ibrahim',
    'Yusuf Abdullahi',
    'Zainab Aliyu',
    'Ibrahim Suleiman',
    'Hauwa Mohammed',
    'Usman Ahmad',
    'Khadija Garba',
    'Sadiq Hassan',
  ];

  return List<AttendanceStudent>.generate(
    names.length,
    (index) => AttendanceStudent(
      id: '$classId-student-${index + 1}',
      admissionNumber: '$prefix-${(index + 1).toString().padLeft(3, '0')}',
      name: names[index],
    ),
    growable: false,
  );
}
