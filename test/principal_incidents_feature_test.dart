import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_incidents_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_incidents_models.dart';

void main() {
  test('principal incidents preserve exact website seed and KPI state', () {
    expect(principalIncidentCases.length, 5);
    expect(principalIncidentCases.map((e) => e.id).toList(), ['INC-2401','INC-2402','INC-2403','INC-2399','INC-2398']);
    expect(principalIncidentCases.where((e) => e.status != PrincipalIncidentStatus.resolved).length, 3);
    expect(principalIncidentCases.where((e) => e.status != PrincipalIncidentStatus.resolved && (e.severity == PrincipalIncidentSeverity.high || e.severity == PrincipalIncidentSeverity.critical)).length, 1);
    expect(principalIncidentCases.where((e) => e.category == PrincipalIncidentCategory.safeguarding && e.status != PrincipalIncidentStatus.resolved).length, 1);
    expect(principalIncidentCases.where((e) => e.guardianContact == PrincipalGuardianContact.pending).length, 2);
    expect(principalIncidentResolvedThisTerm, 18);
  });

  test('safeguarding case exposes minimum necessary general-list detail', () {
    final item = principalIncidentCases.firstWhere((e) => e.id == 'INC-2402');
    expect(item.isRestricted, isTrue);
    expect(item.summary, contains('Detailed sensitive notes are intentionally not shown'));
    expect(principalIncidentRestrictedBoundary, contains('minimum necessary'));
  });

  test('incident and audit event serialize without losing status history', () {
    final original = principalIncidentCases.first.copyWith(status: PrincipalIncidentStatus.resolved, lastUpdatedByMembershipId: 'MEM-P', lastUpdatedAt: '2026-09-19T17:00:00Z');
    final restored = PrincipalIncident.fromJson(original.toJson());
    expect(restored.status, PrincipalIncidentStatus.resolved);
    expect(restored.lastUpdatedByMembershipId, 'MEM-P');

    final event = PrincipalIncidentAuditEvent(id: 'EV-1', incidentId: original.id, action: 'status_change', actorMembershipId: 'MEM-P', createdAt: '2026-09-19T17:00:00Z', previousStatus: PrincipalIncidentStatus.monitoring, newStatus: PrincipalIncidentStatus.resolved, note: 'Reviewed.');
    final eventRestored = PrincipalIncidentAuditEvent.fromJson(event.toJson());
    expect(eventRestored.previousStatus, PrincipalIncidentStatus.monitoring);
    expect(eventRestored.newStatus, PrincipalIncidentStatus.resolved);
    expect(eventRestored.actorMembershipId, 'MEM-P');
  });

  test('governance keeps authority scoped and human-led', () {
    expect(principalIncidentAuthorityBoundary, contains('Secondary'));
    expect(principalIncidentAuthorityBoundary, contains('Primary and Early Years'));
    expect(principalIncidentAuditBoundary, contains('append-only'));
    expect(principalIncidentAiBoundary, contains('cannot determine'));
    expect(principalIncidentAiInsight, contains('human review'));
  });
}
