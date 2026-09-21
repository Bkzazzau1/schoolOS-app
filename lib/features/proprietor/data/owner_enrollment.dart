import '../../administrator/data/administrator_admissions_repository.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_admissions_models.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../domain/proprietor_enrollment_models.dart';

/// One section's admissions and students.
class EnrollmentSectionRow {
  const EnrollmentSectionRow({
    required this.section,
    required this.applications,
    required this.offers,
    required this.accepted,
    required this.registered,
    required this.activeStudents,
  });

  final String section;
  final int applications;

  /// Applications that reached an offer (offered, accepted or registered).
  final int offers;

  /// Offers the guardian accepted (accepted or registered).
  final int accepted;
  final int registered;
  final int activeStudents;

  double get offerRate => applications == 0 ? 0 : offers / applications;
  double get acceptanceRate => offers == 0 ? 0 : accepted / offers;
}

/// What the owner's Enrollment page shows, worked out from the school's real applicants and student register.
///
/// Retention and enrollment trends need history from earlier terms, which is not recorded, so they are not shown.
class OwnerEnrollment {
  const OwnerEnrollment({required this.kpis, required this.sections, required this.watch, required this.empty});

  final List<OwnerEnrollmentKpi> kpis;
  final List<EnrollmentSectionRow> sections;
  final List<OwnerCapacityWatchItem> watch;

  /// No students and no applications yet.
  final bool empty;

  int get applications => sections.fold(0, (n, s) => n + s.applications);
  int get offers => sections.fold(0, (n, s) => n + s.offers);
  int get accepted => sections.fold(0, (n, s) => n + s.accepted);
  int get activeStudents => sections.fold(0, (n, s) => n + s.activeStudents);
}

const _sectionOrder = ['Early Years', 'Primary', 'Secondary'];

String _applicantSection(AdmissionApplicant a) => a.section == 'Nursery' ? 'Early Years' : a.section;

OwnerEnrollment buildOwnerEnrollment({
  required List<AdministratorStudentRecord> students,
  required List<AdmissionApplicant> applicants,
}) {
  final open = applicants.where((a) => !a.isClosed).toList();
  bool reachedOffer(AdmissionApplicant a) =>
      a.stage == AdmissionStage.offer || a.stage == AdmissionStage.accepted || a.stage == AdmissionStage.registered;
  bool reachedAccepted(AdmissionApplicant a) => a.stage == AdmissionStage.accepted || a.stage == AdmissionStage.registered;
  final active = students.where((s) => s.status != AdministratorStudentStatus.transferredOut).toList();

  final sections = [
    for (final name in _sectionOrder)
      EnrollmentSectionRow(
        section: name,
        applications: open.where((a) => _applicantSection(a) == name).length,
        offers: open.where((a) => _applicantSection(a) == name && reachedOffer(a)).length,
        accepted: open.where((a) => _applicantSection(a) == name && reachedAccepted(a)).length,
        registered: open.where((a) => _applicantSection(a) == name && a.stage == AdmissionStage.registered).length,
        activeStudents: active.where((s) => sectionOfClass(s.className) == name).length,
      ),
  ];

  final total = sections.fold<int>(0, (n, s) => n + s.applications);
  final offers = sections.fold<int>(0, (n, s) => n + s.offers);
  final accepted = sections.fold<int>(0, (n, s) => n + s.accepted);
  final registered = sections.fold<int>(0, (n, s) => n + s.registered);
  String pct(int part, int whole) => whole == 0 ? 'none yet' : '${(part * 100 / whole).round()}%';

  final kpis = [
    OwnerEnrollmentKpi(label: 'Active students', value: '${active.length}', note: 'On the school register'),
    OwnerEnrollmentKpi(label: 'Applications', value: '$total', note: '${applicants.length - open.length} closed'),
    OwnerEnrollmentKpi(label: 'Offers issued', value: '$offers', note: '${pct(offers, total)} of applications'),
    OwnerEnrollmentKpi(label: 'Accepted', value: '$accepted', note: '${pct(accepted, offers)} of offers'),
    OwnerEnrollmentKpi(label: 'Registered', value: '$registered', note: 'Now on the register'),
  ];

  final waitingRegistration = open.where((a) => a.stage == AdmissionStage.accepted).toList();
  final waitingDocuments = open.where(
    (a) => a.stage.index < AdmissionStage.screening.index && AdministratorAdmissionsRepository.pendingDocuments(a).isNotEmpty,
  );
  final busiest = sections.where((s) => s.applications > 0).toList()..sort((a, b) => b.applications.compareTo(a.applications));

  final watch = [
    if (waitingRegistration.isNotEmpty)
      OwnerCapacityWatchItem(
        title: '${waitingRegistration.length} accepted ${waitingRegistration.length == 1 ? 'child is' : 'children are'} waiting to be registered',
        detail: waitingRegistration.map((a) => '${a.name} (${a.className})').join(', '),
        action: 'The Administrator completes registration; ask if a place, class or fee setup is holding it up.',
      ),
    if (waitingDocuments.isNotEmpty)
      OwnerCapacityWatchItem(
        title: '${waitingDocuments.length} ${waitingDocuments.length == 1 ? 'application is' : 'applications are'} waiting on documents',
        detail: waitingDocuments.map((a) => a.name).join(', '),
        action: 'Documents come before screening; follow up with the guardians.',
      ),
    if (busiest.isNotEmpty && total > 0)
      OwnerCapacityWatchItem(
        title: '${busiest.first.section} has the most applications',
        detail: '${busiest.first.applications} of $total applications, with ${busiest.first.activeStudents} active students there now.',
        action: 'Check classroom and teacher capacity before offering more places. Capacity limits are not configured yet.',
      ),
  ];

  return OwnerEnrollment(kpis: kpis, sections: sections, watch: watch, empty: students.isEmpty && applicants.isEmpty);
}

class OwnerEnrollmentRepository {
  OwnerEnrollmentRepository({required this.students, required this.admissions});

  final AdministratorStudentsRepository students;
  final AdministratorAdmissionsRepository admissions;

  Future<OwnerEnrollment> load() async => buildOwnerEnrollment(
        students: (await students.load()).students,
        applicants: (await admissions.load()).applicants,
      );
}

/// The text of the enrollment brief.
String renderEnrollmentBrief({required String schoolName, required DateTime date, required OwnerEnrollment enrollment}) {
  final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final b = StringBuffer()
    ..writeln('SchoolOS Enrollment Brief')
    ..writeln(schoolName)
    ..writeln('Generated: $day')
    ..writeln()
    ..writeln('EXECUTIVE SNAPSHOT');
  for (final k in enrollment.kpis) {
    b.writeln('${k.label}: ${k.value} (${k.note})');
  }
  b
    ..writeln()
    ..writeln('ADMISSIONS PIPELINE BY SECTION');
  for (final r in enrollment.sections) {
    b.writeln('${r.section}: ${r.applications} applications, ${r.offers} offers, ${r.accepted} accepted, ${r.registered} registered, ${r.activeStudents} active students');
  }
  b
    ..writeln()
    ..writeln('WORTH A LOOK');
  if (enrollment.watch.isEmpty) b.writeln('- Nothing stands out.');
  for (final w in enrollment.watch) {
    b
      ..writeln('- ${w.title}')
      ..writeln('  ${w.detail}')
      ..writeln('  ${w.action}');
  }
  b
    ..writeln()
    ..writeln('NOT AVAILABLE YET')
    ..writeln('- Retention and enrollment trend: they need records from earlier terms, which are not recorded.');
  return b.toString();
}
