import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_attention_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_reports.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_ai_brief_exporter.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_ai_service.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_ai_text.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_overview_models.dart';

OwnerReports factsWith({bool waiting = true, bool staff = true}) {
  final people = staff
      ? [
          StaffOverviewPerson(
            record: const AdministratorStaffRecord(
              id: '1',
              name: 'Grace Musa',
              role: 'Teacher',
              section: 'Primary',
              fileStatus: AdministratorStaffFileStatus.missingDocument,
            ),
            profile: const StaffProfile(staffId: '1'),
          ),
        ]
      : <StaffOverviewPerson>[];
  return buildOwnerReports(
    staff: buildStaffOverview(people: people, sections: const [], leaders: const [], now: DateTime(2026, 9, 21)),
    finance: buildFinanceOverview(
      concessions: const [],
      payroll: const PayrollSnapshot(staff: [], profiles: {}, authorizers: []),
      batches: const [],
    ),
    attention: OwnerAttention(
      items: waiting
          ? const [
              ProprietorAttentionItem(
                title: 'Approve new staff: Amina',
                detail: 'Teacher.',
                owner: 'Proprietor',
                tone: ProprietorAttentionTone.high,
              ),
            ]
          : const [],
      leadership: const [],
    ),
    now: DateTime(2026, 9, 21),
  );
}

void main() {
  test('priorities come from what is really waiting, with the evidence separate from the interpretation', () {
    final r = ProprietorAiService(factsWith()).answer('Which owner priorities need action this week?');
    expect(r.answer, contains('1 item is waiting'));
    expect(r.evidence.single, contains('Approve new staff: Amina'));
    expect(r.interpretation, contains('do not say what the right decision is'));
  });

  test('with nothing waiting it says so and does not claim everything is fine', () {
    final r = ProprietorAiService(factsWith(waiting: false)).answer('What is waiting for my decision?');
    expect(r.answer, contains('No approval or decision'));
    final p = ProprietorAiService(factsWith(waiting: false)).answer('priorities this week');
    expect(p.interpretation, contains('not that everything is fine'));
  });

  test('staffing answers use the recorded files and are not treated as performance', () {
    final r = ProprietorAiService(factsWith()).answer('Summarize staffing and staff files');
    expect(r.answer, contains('1 staff are on record'));
    expect(r.evidence.any((e) => e.contains('Grace Musa')), isTrue);
    expect(r.interpretation, contains('not performance scores'));
  });

  test('an empty school is reported as empty, not filled with sample numbers', () {
    final r = ProprietorAiService(factsWith(staff: false, waiting: false)).answer('staff summary');
    expect(r.answer, 'No staff are on record yet.');
  });

  test('fees, attendance, enrollment and results say nothing is recorded instead of inventing figures', () {
    final service = ProprietorAiService(factsWith());
    for (final q in ['Compare fee collection by section', 'Why is Secondary attendance below target?', 'enrollment risk', 'exam results']) {
      final r = service.answer(q);
      expect(r.answer, contains('nothing has been recorded'), reason: q);
      expect(r.interpretation, contains('Nothing is guessed'), reason: q);
      expect(r.evidence.join(' '), isNot(contains('%')), reason: q);
    }
  });

  test('the assistant can list what cannot be reported yet', () {
    final r = ProprietorAiService(factsWith()).answer('What can not be reported yet?');
    expect(r.evidence.length, 4);
    expect(r.evidence.first, contains('Fee collection'));
  });

  test('an unrelated question is bounded instead of fabricated', () {
    final r = ProprietorAiService(factsWith()).answer('Predict which parent will default next term');
    expect(r.evidence.single, contains('does not match anything recorded'));
  });

  test('every suggested question gets a real answer and there are no invented numbers in the brief', () {
    final service = ProprietorAiService(factsWith());
    for (final prompt in proprietorAiPrompts) {
      expect(service.answer(prompt.question).answer, isNotEmpty, reason: prompt.question);
    }
    final brief = renderAiBrief(schoolName: 'BrightGate', date: DateTime(2026, 9, 21), sections: service.briefSections());
    expect(brief, contains('Generated: 2026-09-21'));
    expect(brief, contains('NOT AVAILABLE YET'));
    expect(brief, isNot(contains('648')));
    expect(brief, isNot(contains('94%')));
  });

  test('context and decision safeguards remain explicit', () {
    expect(proprietorAiContextBoundary, contains('tenant'));
    expect(proprietorAiContextBoundary, contains('record sensitivity'));
    expect(proprietorAiDecisionBoundary, contains('must not autonomously fire staff'));
    expect(proprietorAiDecisionBoundary, contains('financial action'));
  });
}
