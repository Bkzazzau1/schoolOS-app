import '../domain/administrator_lifecycle_models.dart';
import '../domain/administrator_students_models.dart';

/// The student register as it stands after the lifecycle changes.
///
/// Changes are never written over the student: they are kept as a history and applied in the order they were completed.
/// A completed promotion or class change puts the student in the new class, a completed transfer out takes them off the
/// active register, and a transfer that is still pending shows as "Transfer pending". A cancelled change has no effect.
List<AdministratorStudentRecord> applyLifecycle(
  List<AdministratorStudentRecord> students,
  List<AdministratorLifecycleRecord> records,
) {
  final completed = records.where((r) => r.status == AdministratorLifecycleStatus.completed).toList()
    ..sort((a, b) {
      final byTime = a.completedAt.compareTo(b.completedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  final pendingTransfer = {
    for (final r in records)
      if (r.isPending && r.isTransferOut) r.student,
  };

  return [
    for (final s in students)
      () {
        var className = s.className;
        var status = s.status == AdministratorStudentStatus.transferPending ? AdministratorStudentStatus.active : s.status;
        for (final r in completed) {
          if (r.student != s.id) continue;
          if (r.movesClass) className = r.toClass;
          if (r.isTransferOut) status = AdministratorStudentStatus.transferredOut;
        }
        if (status == AdministratorStudentStatus.active && pendingTransfer.contains(s.id)) {
          status = AdministratorStudentStatus.transferPending;
        }
        return s.copyWith(className: className, status: status);
      }(),
  ];
}

/// The completed changes for one student, oldest first: where they have been.
List<AdministratorLifecycleRecord> historyOf(String studentId, List<AdministratorLifecycleRecord> records) => [
      for (final r in records)
        if (r.student == studentId && r.status == AdministratorLifecycleStatus.completed) r,
    ]..sort((a, b) => a.completedAt.compareTo(b.completedAt));
