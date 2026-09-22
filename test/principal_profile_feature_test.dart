import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/principal/data/principal_approvals_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_communication_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_incidents_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_profile_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_profile_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_approvals_models.dart';
import 'package:schoolos_app/features/principal/domain/principal_communication_models.dart';
import 'package:schoolos_app/features/principal/domain/principal_incidents_models.dart';
import 'package:schoolos_app/features/principal/domain/principal_profile_models.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_lesson_plan_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalProfileRepository profile;
  late PrincipalIncidentsRepository incidents;
  late PrincipalCommunicationRepository communication;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    incidents = PrincipalIncidentsRepository(localDatabase: database, schoolSession: session);
    final approvals = PrincipalApprovalsRepository(localDatabase: database, schoolSession: session);
    communication = PrincipalCommunicationRepository(localDatabase: database, schoolSession: session);
    profile = PrincipalProfileRepository(
      localDatabase: database,
      schoolSession: session,
      incidents: incidents,
      approvals: approvals,
      communication: communication,
    );
  }

  tearDown(() => db?.close());

  test('the default account profile is blank, not a fabricated named person', () {
    expect(principalDefaultProfile.fullName, isEmpty);
    expect(principalDefaultProfile.displayName, isEmpty);
    expect(principalDefaultProfile.email, isEmpty);
    expect(principalDefaultProfile.phone, isEmpty);
    expect(principalDefaultProfile.role, 'Principal');
    expect(principalDefaultProfile.academicSection, 'Secondary School');
  });

  test('all six notification preferences are enabled by default', () {
    expect(PrincipalPreferenceKey.values, hasLength(6));
    for (final key in PrincipalPreferenceKey.values) {
      expect(principalDefaultPreferences.isEnabled(key), isTrue);
    }
  });

  test('profile and preferences serialize cleanly', () {
    final profile = PrincipalAccountProfile.fromJson(principalDefaultProfile.toJson());
    expect(profile.fullName, principalDefaultProfile.fullName);
    expect(profile.email, principalDefaultProfile.email);

    final prefs = PrincipalNotificationPreferences.fromJson(principalDefaultPreferences.toJson());
    expect(prefs.values.length, 6);
    expect(prefs.isEnabled(PrincipalPreferenceKey.aiBrief), isTrue);
    expect(prefs.toggled(PrincipalPreferenceKey.aiBrief).isEnabled(PrincipalPreferenceKey.aiBrief), isFalse);
  });

  test('workspace boundary keeps principal secondary-only and owner settings controlled', () {
    expect(principalProfileRoleBoundary, contains('Secondary School section'));
    expect(principalProfileRoleBoundary, contains('Primary and Nursery remain separate leadership scopes'));
    expect(principalProfileRoleBoundary, contains('Official school identity and ownership settings remain proprietor-controlled'));
    expect(principalSchoolIdentityBoundary, contains('Only the proprietor'));
  });

  test('school identity uses the real active school name; nothing else is invented', () async {
    await setUpSchool();
    final snapshot = await profile.load();
    expect(snapshot.schoolIdentity.name, 'BrightGate');
    expect(snapshot.schoolIdentity.address, isNull);
    expect(snapshot.schoolIdentity.phone, isNull);
    expect(snapshot.schoolIdentity.branches, isEmpty);
  });

  test('a fresh demo school has no recorded activity for this Principal', () async {
    await setUpSchool();
    final snapshot = await profile.load();
    expect(snapshot.activity, isEmpty);
  });

  test('saving the account profile round-trips and queues for sync', () async {
    await setUpSchool();
    final loaded = await profile.load();
    final result = await profile.saveAccount(loaded.account.copyWith(fullName: 'Amina Bello', displayName: 'Amina Bello', email: 'amina@brightgate.example', phone: '+234 800 000 0000'));
    expect(result.success, isTrue, reason: result.message);
    final after = await profile.load();
    expect(after.account.fullName, 'Amina Bello');
    expect(db!.pendingCount(tenantId: principal.schoolId), greaterThan(0));
  });

  test('a real incident note by this Principal appears in real recent activity', () async {
    await setUpSchool();
    const item = PrincipalIncident(
      id: 'case-1',
      title: 'Recorded concern',
      category: PrincipalIncidentCategory.property,
      severity: PrincipalIncidentSeverity.low,
      status: PrincipalIncidentStatus.open,
      person: 'Reported by staff',
      context: 'JSS 2A',
      reportedBy: 'm-principal',
      owner: 'm-principal',
      reportedAt: '2026-09-22',
      location: 'Classroom',
      guardianContact: PrincipalGuardianContact.notRequired,
      evidenceCount: 0,
      summary: 'A staff-entered report.',
      nextAction: 'Review evidence',
    );
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'principal_recorded_incident_case', entityId: item.id, payload: item.toJson());
    final noteResult = await incidents.saveNote(incidentId: item.id, note: 'Followed up with the class teacher.');
    expect(noteResult.success, isTrue, reason: noteResult.message);

    final snapshot = await profile.load();
    expect(snapshot.activity, isNotEmpty);
    expect(snapshot.activity.single.action, contains('Recorded concern'));
  });

  test('a real queued announcement by this Principal appears in real recent activity', () async {
    await setUpSchool();
    final result = await communication.queueAnnouncement(
      audience: PrincipalCommunicationAudience.staff,
      channel: PrincipalCommunicationChannel.portal,
      subject: 'Staff meeting',
      message: 'Please attend the Friday briefing.',
    );
    expect(result.success, isTrue, reason: result.message);
    final snapshot = await profile.load();
    expect(snapshot.activity.single.action, contains('Staff meeting'));
  });

  test('a real approval decision by this Principal appears in real recent activity, newest first', () async {
    await setUpSchool();
    final plan = TeacherLessonPlan(
      id: 'PLAN-1',
      className: 'JSS 2A',
      week: 'Week 1',
      topic: 'Fractions',
      status: TeacherLessonPlanStatus.submitted,
      updatedLabel: 'Just now',
    );
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'teacher_lesson_plan', entityId: plan.id, payload: plan.toJson());
    final event = TeacherLessonPlanEvent(
      id: 'EVT-1',
      planId: plan.id,
      action: TeacherLessonPlanEventAction.submitted,
      actorMembershipId: 'm-teacher',
      version: 1,
      occurredAt: '2020-01-01T00:00:00Z',
    );
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'teacher_lesson_plan_event', entityId: event.id, payload: event.toJson());
    final decideResult = await PrincipalApprovalsRepository(localDatabase: db!, schoolSession: session).decide(
      approvalId: 'teacher_lesson_plan:PLAN-1:v1',
      status: PrincipalApprovalStatus.approved,
      comment: 'Looks good.',
    );
    expect(decideResult.success, isTrue, reason: decideResult.message);
    await communication.queueAnnouncement(audience: PrincipalCommunicationAudience.staff, channel: PrincipalCommunicationChannel.portal, subject: 'Later', message: 'x');

    final snapshot = await profile.load();
    expect(snapshot.activity.length, 2);
    // The announcement (queued "now") is more recent than the 2020 lesson-plan approval.
    expect(snapshot.activity.first.action, contains('Later'));
    expect(snapshot.activity.last.action, contains('Approved'));
  });

  test('activity, notes and announcements only reflect this membership, not another principal in the same school', () async {
    await setUpSchool();
    await communication.queueAnnouncement(audience: PrincipalCommunicationAudience.staff, channel: PrincipalCommunicationChannel.portal, subject: 'Mine', message: 'x');
    const other = SchoolMembership(id: 'm-other-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
    await session.setMemberships([principal, other]);
    await session.selectSchool(other);
    final snapshot = await profile.load();
    expect(snapshot.activity, isEmpty);
  });

  test('a non-principal membership cannot save profile or preferences', () async {
    await setUpSchool(teacher);
    final loaded = await profile.load();
    final accountResult = await profile.saveAccount(loaded.account.copyWith(fullName: 'x'));
    expect(accountResult.success, isFalse);
    final prefResult = await profile.savePreferences(loaded.preferences.toggled(PrincipalPreferenceKey.approvals));
    expect(prefResult.success, isFalse);
  });
}
