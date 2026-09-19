import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_campus_demo_data.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_campus_models.dart';

void main() {
  test('active campus totals exclude planned campuses', () {
    expect(activeCampusEnrollment, 648);
    expect(activeCampusStaff, 64);

    final planned = proprietorCampuses.singleWhere(
      (campus) => campus.status == CampusStatus.planned,
    );
    expect(planned.name, 'Zaria Campus');
    expect(planned.students, 0);
    expect(planned.staff, 0);
  });

  test('campus comparison keeps expansion controls and isolation boundary', () {
    expect(proprietorCampusExpansionChecklist.length, 4);
    expect(
      proprietorCampusExpansionChecklist.map((item) => item.title),
      containsAll(<String>[
        'Governance & leadership',
        'Capacity & staffing',
        'Finance configuration',
        'Safety & operations',
      ]),
    );
    expect(
      proprietorCampusIsolationPrinciple,
      contains('should not automatically see or manage Zaria Campus'),
    );
    expect(proprietorCampusIsolationPrinciple, contains('AI context'));
  });

  test('website campus KPI snapshot is preserved', () {
    final values = {for (final item in proprietorCampusKpis) item.label: item.value};
    expect(values['Active campuses'], '1');
    expect(values['Planned campuses'], '1');
    expect(values['Total enrollment'], '648');
    expect(values['Staff'], '64');
    expect(values['Expansion readiness'], 'Planning');
  });
}
