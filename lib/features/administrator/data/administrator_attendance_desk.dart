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

/// A morning of gate scans for the demo, so the desk has a day to show. Deterministic: the same student gets the same
/// scan on the same day. About nine in ten students arrive, a few late; one scan is not recognised.
///
/// Only the demo uses this. With a school server the scans come from real devices.
List<AdministratorAttendanceEvent> demoScansFor(List<AdministratorStudentRecord> students, DateTime now) {
  final day = schoolDay(now);
  final events = <AdministratorAttendanceEvent>[];
  for (final s in students) {
    final h = _hash('$day-${s.id}');
    if (h % 10 == 0) continue; // absent today
    final late = h % 10 == 1;
    final minute = late ? 5 + h % 25 : 20 + h % 39; // late: 08:05-08:29, on time: 07:20-07:58
    final hour = late ? 8 : 7;
    final time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final section = sectionOfClass(s.className);
    events.add(AdministratorAttendanceEvent(
      time: time,
      student: s.name,
      className: s.className,
      device: section == 'Early Years' ? 'Early Years Check-in' : (section == 'Primary' ? 'Primary Gate NFC' : 'Main Gate Face Terminal'),
      method: section == 'Early Years' ? 'Guardian QR' : (section == 'Primary' ? 'NFC Card' : 'Face'),
      status: late ? AdministratorAttendanceEventStatus.late : AdministratorAttendanceEventStatus.checkedIn,
      parentState: 'Sent',
      date: day,
    ));
  }
  events.add(AdministratorAttendanceEvent(
    time: '08:02',
    student: 'Unknown credential',
    className: '—',
    device: 'Main Gate Face Terminal',
    method: 'Face',
    status: AdministratorAttendanceEventStatus.unknownScan,
    parentState: 'Not sent',
    date: day,
  ));
  events.sort((a, b) => a.time.compareTo(b.time));
  return events;
}

/// A few sample correction requests for the demo, deterministic like the gate scans and drawn from the real
/// student register rather than fixed names, so a demo school never shows a fabricated request attributed to a
/// specific real student who never actually submitted one.
///
/// Only the demo uses this. With a school server, correction requests come from real teachers and administrators.
List<AdministratorAttendanceCorrection> demoCorrectionsFor(List<AdministratorStudentRecord> students) {
  const templates = [
    ('Absent → Present', 'Teacher submitted correction'),
    ('Late → Present', 'Arrival log attached'),
    ('Present → Excused', 'Leadership review required'),
  ];
  final sorted = [...students]..sort((a, b) => a.id.compareTo(b.id));
  final picked = sorted.take(templates.length).toList(growable: false);
  return [
    for (var i = 0; i < picked.length; i++)
      AdministratorAttendanceCorrection(
        id: 'ATT-0${81 + i}',
        student: picked[i].name,
        className: picked[i].className,
        requestedChange: templates[i].$1,
        evidence: templates[i].$2,
      ),
  ];
}

int _hash(String value) {
  var h = 17;
  for (final unit in value.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  return h;
}
