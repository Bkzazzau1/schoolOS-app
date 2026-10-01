import '../domain/administrator_attendance_models.dart';
import '../domain/administrator_students_models.dart';

/// A section's attendance for the day.
class AttendanceSectionSummary {
  const AttendanceSectionSummary({
    required this.name,
    required this.expected,
    required this.present,
    required this.late,
    required this.excused,
  });

  final String name;
  final int expected;
  final int present;
  final int late;
  final int excused;

  int get absent => expected - present - excused;
  int get rate => expected == 0 ? 0 : (present * 100 / expected).round();
}

/// The day's attendance, worked out from the scans and the student register.
class AttendanceDesk {
  const AttendanceDesk({
    required this.expected,
    required this.present,
    required this.late,
    required this.excused,
    required this.absentNames,
    required this.unknownScans,
    required this.pendingCorrections,
    required this.sections,
  });

  final int expected;
  final int present;
  final int late;
  final int excused;

  /// Students on the register with no arrival, no excuse: who to follow up in the normal way.
  final List<String> absentNames;
  final int unknownScans;
  final int pendingCorrections;
  final List<AttendanceSectionSummary> sections;

  int get absent => absentNames.length;
  int get rate => expected == 0 ? 0 : (present * 100 / expected).round();
}

/// The section a class belongs to.
String sectionOfClass(String className) {
  final c = className.toLowerCase();
  if (c.startsWith('nursery') || c.startsWith('creche') || c.startsWith('kg') || c.startsWith('reception')) return 'Early Years';
  if (c.startsWith('primary') || c.startsWith('basic')) return 'Primary';
  return 'Secondary';
}

String _key(String name) => name.trim().toLowerCase();

/// [students] are the students who should be at school today (active on the register).
AttendanceDesk buildAttendanceDesk({
  required List<AdministratorStudentRecord> students,
  required List<AdministratorAttendanceEvent> events,
  required List<AdministratorAttendanceCorrection> corrections,
}) {
  final identified = events.where((e) => !e.isUnknown).toList();
  final presentNames = {for (final e in identified) if (e.countsAsPresent) _key(e.student)};
  final lateNames = {for (final e in identified) if (e.status == AdministratorAttendanceEventStatus.late) _key(e.student)};
  final excusedNames = {for (final e in identified) if (e.status == AdministratorAttendanceEventStatus.excused) _key(e.student)};

  final absent = [
    for (final s in students)
      if (!presentNames.contains(_key(s.name)) && !excusedNames.contains(_key(s.name))) s.name,
  ];

  final bySection = <String, List<AdministratorStudentRecord>>{};
  for (final s in students) {
    bySection.putIfAbsent(sectionOfClass(s.className), () => []).add(s);
  }
  const order = ['Early Years', 'Primary', 'Secondary'];
  final sections = [
    for (final name in order)
      if (bySection.containsKey(name))
        AttendanceSectionSummary(
          name: name,
          expected: bySection[name]!.length,
          present: bySection[name]!.where((s) => presentNames.contains(_key(s.name))).length,
          late: bySection[name]!.where((s) => lateNames.contains(_key(s.name))).length,
          excused: bySection[name]!.where((s) => excusedNames.contains(_key(s.name))).length,
        ),
  ];

  return AttendanceDesk(
    expected: students.length,
    present: students.where((s) => presentNames.contains(_key(s.name))).length,
    late: students.where((s) => lateNames.contains(_key(s.name))).length,
    excused: students.where((s) => excusedNames.contains(_key(s.name))).length,
    absentNames: absent,
    unknownScans: events.where((e) => e.isUnknown).length,
    pendingCorrections: corrections.where((c) => c.isPending).length,
    sections: sections,
  );
}

/// The school day as yyyy-MM-dd.
String schoolDay(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
