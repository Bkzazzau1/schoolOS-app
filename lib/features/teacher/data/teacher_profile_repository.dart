import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/data/payroll_batch_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../domain/teacher_profile_models.dart';
import 'teacher_classes_repository.dart';
import 'teacher_roster.dart';

class TeacherProfileSnapshot {
  const TeacherProfileSnapshot({
    required this.profile,
    required this.permissions,
  });

  final TeacherProfileSnapshotData profile;
  final TeacherProfilePermissions permissions;
}

class TeacherProfileUpdateResult {
  const TeacherProfileUpdateResult({
    required this.success,
    required this.message,
    this.contact,
  });

  final bool success;
  final String message;
  final TeacherProfileContact? contact;
}

abstract interface class TeacherProfileDataSource {
  TeacherProfilePermissions permissionsFor(SchoolMembership membership);
  Future<TeacherProfileSnapshot> load();
  Future<TeacherProfileUpdateResult> saveContact(TeacherProfileContact contact);
}

const _defaultContact = TeacherProfileContact(
  phone: '',
  email: '',
  address: '',
  nextOfKin: '',
  emergencyPhone: '',
);

/// Builds the Teacher's own profile strictly from the same real staff records
/// every other staff-facing screen already uses - [OwnerStaffProfileRepository]
/// (academics, credentials, documents, payment) matched to this membership via
/// `linkedMembershipId`, [AdministratorStaffRepository] (name, role, section),
/// the real [TeacherClassesRepository] roster (teaching load) and the
/// school's own [PayrollBatch] records (net-pay-only payslip history - no
/// itemized gross/deductions breakdown survives anywhere in the app once a
/// batch is prepared, so none is invented here). Nothing is seeded: a teacher
/// not yet linked to a staff record honestly sees blank identity fields
/// instead of a placeholder person.
class TeacherProfileRepository implements TeacherProfileDataSource {
  TeacherProfileRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _classes = TeacherClassesRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        );

  static const _contactType = 'teacher_profile_contact';
  static const _contactEventType = 'teacher_profile_contact_event';
  static const _staffAttendanceType = 'administrator_staff_attendance';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherClassesRepository _classes;

  @override
  TeacherProfilePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherProfilePermissions(
      canViewOwnProfile: teacher,
      canUpdateOwnContact: teacher,
      canEditEmploymentAuthority: false,
      canEditPayroll: false,
      canEditTeachingAssignments: false,
      canViewOtherStaffPayroll: false,
      canSelfApproveSecurityChanges: false,
    );
  }

  @override
  Future<TeacherProfileSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();

    final staffProfile = await _linkedStaffProfile(membership);
    final directoryRecord = staffProfile == null
        ? null
        : await _localDatabase.getLocalRecord(
            tenantId: membership.schoolId,
            entityType: AdministratorStaffRepository.directoryEntityType,
            entityId: staffProfile.staffId,
          );
    final directory = directoryRecord == null
        ? null
        : AdministratorStaffRecord.fromJson(directoryRecord.payload);

    final teachingLoad = await _teachingLoad();

    TeacherProfileSnapshotData profile;
    if (staffProfile == null) {
      profile = TeacherProfileSnapshotData(
        hasLinkedStaffRecord: false,
        displayName: 'Teacher',
        staffId: '',
        department: '',
        jobTitle: '',
        employmentType: '',
        hireDate: '',
        campus: '',
        bank: '',
        account: '',
        contact: _defaultContact,
        qualifications: const [],
        teachingLoad: teachingLoad,
        documents: const [],
        attendance: const TeacherAttendanceSummary(),
        payslips: const [],
        profileCompleteness: 0,
        timeline: const [],
      );
    } else {
      final attendance = await _attendanceSummary(membership, staffProfile.staffId);
      final payslips = await _payslips(membership, staffProfile.staffId);
      profile = TeacherProfileSnapshotData(
        hasLinkedStaffRecord: true,
        displayName: directory?.name.trim().isNotEmpty == true ? directory!.name : 'Teacher',
        staffId: staffProfile.staffId,
        department: directory?.section ?? '',
        jobTitle: directory?.role ?? '',
        employmentType: staffProfile.personal.employmentType,
        hireDate: staffProfile.personal.employmentDate,
        campus: directory?.section ?? '',
        bank: staffProfile.payment.bankName,
        account: staffProfile.payment.maskedAccountNumber,
        contact: _defaultContact,
        qualifications: _qualifications(staffProfile),
        teachingLoad: teachingLoad,
        documents: [
          for (final doc in staffProfile.documents)
            (doc.name, _documentStatusLabel(doc.status), doc.reference.isEmpty ? 'Not recorded' : doc.reference),
        ],
        attendance: attendance,
        payslips: payslips,
        profileCompleteness: _completeness(staffProfile),
        timeline: _timeline(payslips, staffProfile),
      );
    }

    final contactRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _contactType,
    );
    if (contactRecords.isNotEmpty) {
      final contact = TeacherProfileContact.fromJson(contactRecords.first.payload);
      profile = profile.copyWith(
        contact: contact.copyWith(pendingSync: contactRecords.first.isDirty),
      );
    }

    return TeacherProfileSnapshot(
      profile: profile,
      permissions: permissionsFor(membership),
    );
  }

  Future<StaffProfile?> _linkedStaffProfile(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
    );
    for (final record in records) {
      final profile = StaffProfile.fromJson(record.payload);
      if (profile.linkedMembershipId == membership.id) return profile;
    }
    return null;
  }

  Future<List<(String, String, String)>> _teachingLoad() async {
    final snapshot = await _classes.load();
    return [
      for (final assignment in snapshot.assignments)
        (
          '${assignment.name} · ${assignment.subject}',
          '${assignment.periodsPerWeek} periods/week${assignment.room.isEmpty ? '' : ' · Room ${assignment.room}'}',
          assignment.currentTerm.isEmpty ? 'Current assignment' : assignment.currentTerm,
        ),
    ];
  }

  List<(String, String, String)> _qualifications(StaffProfile staffProfile) => [
        for (final record in staffProfile.academics)
          (
            '${record.level} · ${record.course}'.trim(),
            '${record.institution}${record.year > 0 ? ' · ${record.year}' : ''}',
            record.grade.isEmpty ? 'Academic' : record.grade,
          ),
        for (final credential in staffProfile.credentials)
          (
            credential.title,
            credential.issuer,
            credential.verified ? 'Verified' : 'Unverified',
          ),
      ];

  String _documentStatusLabel(StaffDocumentStatus status) => switch (status) {
        StaffDocumentStatus.requested => 'Requested',
        StaffDocumentStatus.received => 'Received',
        StaffDocumentStatus.verified => 'Verified',
      };

  int _completeness(StaffProfile staffProfile) {
    if (staffProfile.documents.isEmpty) return 0;
    final verified = staffProfile.documents
        .where((doc) => doc.status == StaffDocumentStatus.verified)
        .length;
    return ((verified / staffProfile.documents.length) * 100).round();
  }

  Future<TeacherAttendanceSummary> _attendanceSummary(
    SchoolMembership membership,
    String staffId,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _staffAttendanceType,
    );
    for (final record in records) {
      if (record.entityId != staffId) continue;
      final expected = record.payload['expected'] as int? ?? 0;
      final present = record.payload['present'] as int? ?? 0;
      return TeacherAttendanceSummary(
        presentPercent: expected == 0 ? 0 : ((present / expected) * 100).round(),
        lateArrivals: record.payload['late'] as int? ?? 0,
        approvedLeaveDays: record.payload['leave'] as int? ?? 0,
        unapprovedAbsence: record.payload['unexplained'] as int? ?? 0,
      );
    }
    return const TeacherAttendanceSummary();
  }

  Future<List<TeacherPayslip>> _payslips(
    SchoolMembership membership,
    String staffId,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: PayrollBatchRepository.entityType,
    );
    final payslips = <TeacherPayslip>[];
    for (final record in records) {
      final batch = PayrollBatch.fromPayload(record.payload);
      for (final line in batch.lines) {
        if (line['staffId'] != staffId) continue;
        payslips.add(
          TeacherPayslip(
            period: batch.period,
            reference: 'PAY/$staffId/${batch.period}',
            net: line['net'] as int? ?? 0,
            status: _batchStatusLabel(batch.status),
          ),
        );
      }
    }
    payslips.sort((a, b) => b.period.compareTo(a.period));
    return payslips;
  }

  String _batchStatusLabel(PayrollBatchStatus status) => switch (status) {
        PayrollBatchStatus.prepared => 'Prepared',
        PayrollBatchStatus.approved => 'Approved',
        PayrollBatchStatus.rejected => 'Rejected',
        PayrollBatchStatus.disbursementInstructed => 'Disbursement instructed',
      };

  List<(String, String, String)> _timeline(
    List<TeacherPayslip> payslips,
    StaffProfile staffProfile,
  ) {
    final rows = <(String, String, String)>[];
    if (staffProfile.personal.employmentDate.isNotEmpty) {
      rows.add((
        staffProfile.personal.employmentDate,
        'Employment started',
        'Joined as a staff member.',
      ));
    }
    for (final slip in payslips) {
      if (slip.status != 'Disbursement instructed') continue;
      rows.add((slip.period, 'Payroll disbursement instructed', slip.reference));
    }
    return rows;
  }

  @override
  Future<TeacherProfileUpdateResult> saveContact(
    TeacherProfileContact contact,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canUpdateOwnContact) {
      return const TeacherProfileUpdateResult(
        success: false,
        message: 'This membership cannot update the Teacher self-service profile.',
      );
    }

    if (contact.phone.trim().isEmpty ||
        contact.email.trim().isEmpty ||
        contact.address.trim().isEmpty ||
        contact.emergencyPhone.trim().isEmpty) {
      return const TeacherProfileUpdateResult(
        success: false,
        message: 'Phone, email, address and emergency contact are required.',
      );
    }

    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _contactType,
    );
    final current = existing.isEmpty
        ? _defaultContact
        : TeacherProfileContact.fromJson(existing.first.payload);
    final updated = TeacherProfileContact(
      phone: contact.phone.trim(),
      email: contact.email.trim(),
      address: contact.address.trim(),
      nextOfKin: contact.nextOfKin.trim(),
      emergencyPhone: contact.emergencyPhone.trim(),
      version: current.version + 1,
      pendingSync: true,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _contactType,
      entityId: membership.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _contactType,
      entityId: membership.id,
      operation: existing.isEmpty ? SyncOperation.create : SyncOperation.update,
      payload: updated.toJson(),
    );

    final occurredAt = DateTime.now().toUtc().toIso8601String();
    final eventId = '${membership.id}-${DateTime.now().microsecondsSinceEpoch}';
    final event = <String, Object?>{
      'id': eventId,
      'actorMembershipId': membership.id,
      'action': 'updatedSelfServiceContact',
      'version': updated.version,
      'occurredAt': occurredAt,
      'fields': const ['phone', 'email', 'address', 'nextOfKin', 'emergencyPhone'],
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _contactEventType,
      entityId: eventId,
      payload: event,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _contactEventType,
      entityId: eventId,
      operation: SyncOperation.create,
      payload: event,
    );

    return TeacherProfileUpdateResult(
      success: true,
      message: 'Contact changes saved locally and queued for HR synchronization. Employment, payroll and teaching assignments are unchanged.',
      contact: updated,
    );
  }
}
