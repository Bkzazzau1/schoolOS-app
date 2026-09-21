import 'owner_attention_repository.dart';
import 'owner_enrollment.dart';
import 'owner_finance_overview.dart';
import 'owner_staff_overview.dart';

/// A group of lines in a report, under a heading.
class ReportSection {
  const ReportSection(this.heading, this.lines);

  final String heading;
  final List<String> lines;
}

/// One report the owner can open. A report that cannot be produced yet says why instead of showing made-up figures.
class ReportDoc {
  const ReportDoc({required this.title, required this.coverage, this.sections = const [], this.unavailableReason});

  final String title;
  final String coverage;
  final List<ReportSection> sections;

  /// Set when the school has no data for this report yet.
  final String? unavailableReason;

  bool get available => unavailableReason == null;
}

class OwnerReports {
  const OwnerReports({
    required this.docs,
    required this.generatedOn,
    required this.staff,
    required this.finance,
    required this.attention,
    this.enrollment,
  });

  /// Null when enrollment could not be read.
  final OwnerEnrollment? enrollment;

  final List<ReportDoc> docs;
  final DateTime generatedOn;

  /// The records the reports were built from (the AI assistant answers from the same ones).
  final StaffOverview staff;
  final OwnerFinanceOverview finance;
  final OwnerAttention attention;

  Iterable<ReportDoc> get available => docs.where((d) => d.available);
  Iterable<ReportDoc> get unavailable => docs.where((d) => !d.available);
}

const reportingPrinciple =
    'Reports keep the source behind each figure, tell missing data apart from poor performance, and say plainly when '
    'something cannot be reported yet. Nothing here is estimated or made up.';

OwnerReports buildOwnerReports({
  required StaffOverview staff,
  required OwnerFinanceOverview finance,
  required OwnerAttention attention,
  required DateTime now,
  OwnerEnrollment? enrollment,
}) {
  final docs = <ReportDoc>[
    ReportDoc(
      title: 'Executive summary',
      coverage: 'What is waiting on you, people and money at a glance',
      sections: [
        ReportSection('Waiting on the owner', [
          if (attention.items.isEmpty) 'Nothing is waiting.',
          for (final i in attention.items) '${i.title}. ${i.detail}',
        ]),
        ReportSection('People', [for (final k in staff.kpis) '${k.label}: ${k.value} (${k.note})']),
        ReportSection('Money', [for (final k in finance.kpis) '${k.label}: ${k.value} (${k.note})']),
      ],
    ),
    ReportDoc(
      title: 'Staff & leadership',
      coverage: 'Staff on record, sections, leadership and open people issues',
      sections: [
        ReportSection('Staff', [for (final k in staff.kpis) '${k.label}: ${k.value} (${k.note})']),
        ReportSection('Staff by section', [
          if (staff.mix.isEmpty) 'No staff on record.',
          for (final m in staff.mix) '${m.section}: ${m.count} (${m.note})',
        ]),
        ReportSection('Leadership', [
          if (staff.leaders.isEmpty) 'No leadership appointed.',
          for (final l in staff.leaders) '${l.name}, ${l.role} (${l.scope}): ${l.team}. ${l.signal}',
        ]),
        ReportSection('Open people issues', [
          if (staff.attention.isEmpty) 'None.',
          for (final a in staff.attention) '${a.title}. ${a.detail}',
        ]),
      ],
    ),
    ReportDoc(
      title: 'Scholarships, discounts & payroll',
      coverage: 'Concessions decided and waiting, and monthly payroll',
      sections: [
        ReportSection('Figures', [for (final k in finance.kpis) '${k.label}: ${k.value} (${k.note})']),
        ReportSection('Waiting on the owner', [
          if (finance.attention.isEmpty) 'Nothing is waiting.',
          for (final a in finance.attention) '${a.title}. ${a.detail}',
        ]),
        ReportSection('Recent decisions', [
          if (finance.decidedRecently.isEmpty) 'No decisions yet.',
          for (final d in finance.decidedRecently) '${d.title}. ${d.detail}',
        ]),
      ],
    ),
    const ReportDoc(
      title: 'Fee collection',
      coverage: 'Billing, collections, outstanding fees and aging',
      unavailableReason: 'The Finance role has not recorded fees or payments yet.',
    ),
    if (enrollment == null || enrollment.empty)
      const ReportDoc(
        title: 'Enrollment & admissions',
        coverage: 'Applications, offers, registered students and the register',
        unavailableReason: 'No students or applications have been recorded yet.',
      )
    else
      ReportDoc(
        title: 'Enrollment & admissions',
        coverage: 'Applications, offers, registered students and the register',
        sections: [
          ReportSection('Figures', [for (final k in enrollment.kpis) '${k.label}: ${k.value} (${k.note})']),
          ReportSection('By section', [
            for (final r in enrollment.sections)
              '${r.section}: ${r.activeStudents} students, ${r.applications} applications, ${r.offers} offers, ${r.accepted} accepted, ${r.registered} registered',
          ]),
          ReportSection('Worth a look', [
            if (enrollment.watch.isEmpty) 'Nothing stands out.',
            for (final w in enrollment.watch) '${w.title}. ${w.detail}',
          ]),
          const ReportSection('Not available yet', ['Retention and the enrollment trend need students recorded across earlier terms.']),
        ],
      ),
    const ReportDoc(
      title: 'Academic & attendance',
      coverage: 'Results and attendance by section',
      unavailableReason: 'Teachers have not recorded results or attendance yet.',
    ),
    const ReportDoc(
      title: 'School life & operations',
      coverage: 'Activities, transport, events and incidents',
      unavailableReason: 'These are recorded by other roles and are not in yet.',
    ),
  ];
  return OwnerReports(docs: docs, generatedOn: now, staff: staff, finance: finance, attention: attention, enrollment: enrollment);
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The text of one report.
String renderReport(ReportDoc doc) {
  final b = StringBuffer()..writeln(doc.title)..writeln(doc.coverage)..writeln();
  if (!doc.available) {
    b.writeln('Not available yet: ${doc.unavailableReason}');
    return b.toString();
  }
  for (final s in doc.sections) {
    b.writeln(s.heading.toUpperCase());
    for (final line in s.lines) {
      b.writeln('- $line');
    }
    b.writeln();
  }
  return b.toString();
}

/// The whole pack, as saved by "Create report pack".
String renderReportPack({required String schoolName, required OwnerReports reports}) {
  final b = StringBuffer()
    ..writeln('SchoolOS Executive Report Pack')
    ..writeln(schoolName)
    ..writeln('Generated: ${_date(reports.generatedOn)}')
    ..writeln()
    ..writeln(reportingPrinciple)
    ..writeln();
  for (final doc in reports.available) {
    b.writeln('=' * 40);
    b.write(renderReport(doc));
  }
  if (reports.unavailable.isNotEmpty) {
    b.writeln('=' * 40);
    b.writeln('NOT AVAILABLE YET');
    for (final d in reports.unavailable) {
      b.writeln('- ${d.title}: ${d.unavailableReason}');
    }
  }
  return b.toString();
}

class OwnerReportsRepository {
  OwnerReportsRepository({
    required this.staff,
    required this.finance,
    required this.attention,
    this.enrollment,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OwnerStaffOverviewRepository staff;
  final OwnerFinanceOverviewRepository finance;
  final OwnerAttentionRepository attention;
  final OwnerEnrollmentRepository? enrollment;
  final DateTime Function() _clock;

  Future<OwnerReports> load() async => buildOwnerReports(
        staff: await staff.load(),
        finance: await finance.load(),
        attention: await attention.load(),
        enrollment: await enrollment?.load(),
        now: _clock(),
      );
}
