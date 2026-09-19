import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_communication_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_communication_models.dart';

void main() {
  test('principal communication preserves exact website seed and KPI state', () {
    expect(principalCommunicationThreads.length, 4);
    expect(principalCommunicationThreads.map((item) => item.id).toList(), ['MSG-201', 'MSG-202', 'MSG-203', 'MSG-204']);
    expect(principalCommunicationThreads.where((item) => item.unread).length, 2);
    expect(principalRecentAnnouncements.length, 3);
    expect(principalCommunicationFollowUps.length, 3);
    expect(principalCommunicationFollowUps.where((item) => item.status == 'Due today').length, 2);
    expect(principalCommunicationTermAnnouncementCount, 12);
    expect(principalCommunicationDeliveryRate, 97);
    expect(principalGuardianResponseRate, 84);
  });

  test('website audiences and channels are preserved exactly', () {
    expect(
      principalCommunicationAudiences.map((item) => item.label).toList(),
      ['Staff', 'Guardians', 'Class Guardians', 'Individual', 'Whole School'],
    );
    expect(
      principalCommunicationChannels.map((item) => item.label).toList(),
      ['Portal', 'SMS', 'Email', 'WhatsApp'],
    );
  });

  test('urgent guardian thread and attendance template remain exact', () {
    final urgent = principalCommunicationThreads.first;
    expect(urgent.id, 'MSG-201');
    expect(urgent.title, 'JSS 2B attendance follow-up');
    expect(urgent.person, 'Guardian C');
    expect(urgent.context, 'Student Gamma · JSS 2B');
    expect(urgent.priority, PrincipalCommunicationPriority.urgent);
    expect(principalAttendanceTemplateSubject, 'Attendance follow-up');
    expect(principalAttendanceTemplateMessage, contains('recent attendance concerns'));
  });

  test('recent announcement delivery and read tracking match website', () {
    final first = principalRecentAnnouncements.first;
    expect(first.id, 'ANN-61');
    expect(first.title, 'First Term Mid-Term Review');
    expect(first.audience, 'Whole School');
    expect(first.channel, 'Portal + SMS');
    expect(first.delivered, '97%');
    expect(first.read, '82%');
  });

  test('communication records serialize without losing delivery or actor context', () {
    final thread = PrincipalCommunicationThread.fromJson(principalCommunicationThreads.first.toJson());
    expect(thread.id, 'MSG-201');
    expect(thread.priority, PrincipalCommunicationPriority.urgent);

    final outgoing = PrincipalOutgoingCommunication(
      id: 'announcement-1',
      kind: PrincipalOutgoingKind.announcement,
      message: 'School notice',
      channel: PrincipalCommunicationChannel.sms,
      deliveryState: PrincipalDeliveryState.queued,
      sectionScope: 'Secondary',
      createdByMembershipId: 'MEM-PRINCIPAL-01',
      createdAt: '2026-09-19T17:50:00Z',
      audience: PrincipalCommunicationAudience.classGuardians,
      subject: 'Attendance follow-up',
    );
    final restored = PrincipalOutgoingCommunication.fromJson(outgoing.toJson());
    expect(restored.kind, PrincipalOutgoingKind.announcement);
    expect(restored.channel, PrincipalCommunicationChannel.sms);
    expect(restored.deliveryState, PrincipalDeliveryState.queued);
    expect(restored.sectionScope, 'Secondary');
    expect(restored.createdByMembershipId, 'MEM-PRINCIPAL-01');
    expect(restored.audience, PrincipalCommunicationAudience.classGuardians);
  });

  test('privacy and offline boundaries prevent cross-school and false delivery claims', () {
    expect(principalCommunicationPermissions.canViewSecondaryCommunication, isTrue);
    expect(principalCommunicationPermissions.canQueueMessages, isTrue);
    expect(principalCommunicationPermissions.canMessagePrimaryOrEarlyYears, isFalse);
    expect(principalCommunicationPermissions.canCrossSchoolMessage, isFalse);
    expect(principalCommunicationPrivacyBoundary, contains('linked guardians'));
    expect(principalCommunicationPrivacyBoundary, contains('Cross-school'));
    expect(principalCommunicationOfflineBoundary, contains('queued fully offline'));
    expect(principalCommunicationOfflineBoundary, contains('never claimed'));
    expect(principalCommunicationScopeBoundary, contains('Secondary'));
    expect(principalCommunicationScopeBoundary, contains('Primary and Early Years'));
  });
}
