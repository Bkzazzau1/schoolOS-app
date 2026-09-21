import '../domain/administrator_admissions_models.dart';
import '../domain/administrator_dashboard_models.dart';
import '../domain/administrator_lifecycle_models.dart';
import '../domain/administrator_records_models.dart';
import '../domain/administrator_staff_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_admissions_repository.dart';
import 'administrator_lifecycle_repository.dart';
import 'administrator_records_repository.dart';
import 'administrator_staff_repository.dart';
import 'administrator_students_repository.dart';

/// What the administrator's desk shows, worked out from the school's real records.
class AdministratorOverview {
  const AdministratorOverview({required this.kpis, required this.queue, required this.pipeline});

  final List<AdministratorKpi> kpis;
  final List<AdministratorQueueItem> queue;

  /// Applicants at each admissions stage: title is the stage, detail the count.
  final List<AdministratorDeskActivity> pipeline;
}

bool _documentsPending(AdmissionApplicant a) =>
    a.birthCertificate == AdmissionDocumentStatus.pending ||
    a.previousSchoolReport == AdmissionDocumentStatus.pending ||
    a.guardianId == AdmissionDocumentStatus.pending;

AdministratorOverview buildAdministratorOverview({
  required List<AdministratorStudentRecord> students,
  required List<AdmissionApplicant> applicants,
  required List<AdministratorDocumentRecord> records,
  required List<AdministratorLifecycleRecord> lifecycle,
  required List<AdministratorStaffRecord> staff,
}) {
  final active = students.where((s) => s.status == AdministratorStudentStatus.active).length;
  final inProgress = applicants.where((a) => a.stage != AdmissionStage.registered && !a.isClosed).toList();
  final awaitingDocuments = inProgress.where(_documentsPending).toList();
  final recordTasks = records.where((r) => r.needsAttention).toList();
  final pendingLifecycle = lifecycle.where((l) => l.isPending).toList();
  final transfers = pendingLifecycle.where((l) => l.isTransferOut).length;
  final incompleteStaff = staff.where((s) => s.needsAttention).toList();

  final kpis = [
    AdministratorKpi(
      label: 'Active students',
      value: '$active',
      detail: students.length == active ? 'On the school register' : '${students.length - active} with a transfer pending',
    ),
    AdministratorKpi(
      label: 'Admissions in progress',
      value: '${inProgress.length}',
      detail: '${awaitingDocuments.length} awaiting documents',
    ),
    AdministratorKpi(
      label: 'Records tasks',
      value: '${recordTasks.length}',
      detail: recordTasks.isEmpty ? 'Nothing to follow up' : 'Needs admin follow-up',
    ),
    AdministratorKpi(
      label: 'Transfers / withdrawals',
      value: '$transfers',
      detail: '${pendingLifecycle.length} lifecycle changes pending',
    ),
    AdministratorKpi(
      label: 'Staff files',
      value: '${staff.length}',
      detail: '${incompleteStaff.length} incomplete',
    ),
  ];

  final queue = [
    for (final a in awaitingDocuments)
      AdministratorQueueItem(
        title: 'Admission awaiting documents: ${a.name}',
        detail: '${a.reference} · ${a.className}',
        area: 'Admissions',
      ),
    for (final l in pendingLifecycle)
      AdministratorQueueItem(
        title: '${l.workflow} pending: ${l.studentName}',
        detail: l.change,
        area: 'Lifecycle',
      ),
    for (final r in recordTasks)
      AdministratorQueueItem(
        title: '${r.document} is ${r.status.label.toLowerCase()}',
        detail: '${r.id} · ${r.recordOwner}',
        area: 'Records',
      ),
    for (final s in incompleteStaff)
      AdministratorQueueItem(
        title: 'Staff file incomplete: ${s.name}',
        detail: '${s.id} · ${s.role}',
        area: 'Staff records',
      ),
  ];

  final pipeline = [
    for (final stage in AdmissionStage.values)
      AdministratorDeskActivity(
        title: stage.label,
        detail: '${applicants.where((a) => a.stage == stage && !a.isClosed).length}',
      ),
  ];

  return AdministratorOverview(kpis: kpis, queue: queue, pipeline: pipeline);
}

class AdministratorOverviewRepository {
  AdministratorOverviewRepository({
    required this.students,
    required this.admissions,
    required this.records,
    required this.lifecycle,
    required this.staff,
  });

  final AdministratorStudentsRepository students;
  final AdministratorAdmissionsRepository admissions;
  final AdministratorRecordsRepository records;
  final AdministratorLifecycleRepository lifecycle;
  final AdministratorStaffRepository staff;

  Future<AdministratorOverview> load() async => buildAdministratorOverview(
        students: (await students.load()).students,
        applicants: (await admissions.load()).applicants,
        records: (await records.load()).records,
        lifecycle: (await lifecycle.load()).records,
        staff: (await staff.load()).staff,
      );
}
