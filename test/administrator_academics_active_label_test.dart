import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_academics_models.dart';

AdministratorAcademicSession _session(String id, {required String status}) =>
    AdministratorAcademicSession(
      id: id,
      code: id,
      name: '2026/2027',
      startsOn: '2026-09-08',
      endsOn: '2027-07-10',
      status: status,
    );

AdministratorAcademicTerm _term(String id, String sessionId, {required String status}) =>
    AdministratorAcademicTerm(
      id: id,
      sessionId: sessionId,
      code: id,
      name: 'Term 1',
      sequence: 1,
      startsOn: '2026-09-08',
      endsOn: '2026-12-12',
      status: status,
    );

AdministratorAcademicsSnapshot _snapshot({
  List<AdministratorAcademicSession> sessions = const [],
  List<AdministratorAcademicTerm> terms = const [],
}) =>
    AdministratorAcademicsSnapshot(
      sessions: sessions,
      terms: terms,
      classes: const [],
      subjects: const [],
      classSubjects: const [],
      topics: const [],
      batches: const [],
    );

void main() {
  test('no active session at all gives a null label, never an invented one', () {
    final snapshot = _snapshot(
      sessions: [_session('s1', status: 'planned')],
    );
    expect(snapshot.activeAcademicLabel, isNull);
  });

  test('an active session with no active term yet shows just the session name', () {
    final snapshot = _snapshot(
      sessions: [_session('s1', status: 'active')],
      terms: [_term('t1', 's1', status: 'planned')],
    );
    expect(snapshot.activeAcademicLabel, '2026/2027');
  });

  test('an active session with an active term shows both, joined', () {
    final snapshot = _snapshot(
      sessions: [_session('s1', status: 'active')],
      terms: [_term('t1', 's1', status: 'active')],
    );
    expect(snapshot.activeAcademicLabel, '2026/2027 · Term 1');
  });

  test('a term active in a different (non-active) session is never picked up', () {
    final snapshot = _snapshot(
      sessions: [_session('s1', status: 'active'), _session('s0', status: 'closed')],
      terms: [_term('t0', 's0', status: 'active')],
    );
    expect(snapshot.activeAcademicLabel, '2026/2027');
  });
}
