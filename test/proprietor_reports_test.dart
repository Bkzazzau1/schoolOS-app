import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_reports_demo_data.dart';

void main() {
  test('proprietor report catalog matches website scope', () {
    expect(proprietorExecutiveReports.length, 5);
    expect(
      proprietorExecutiveReports.every((report) => report.status == 'Ready'),
      isTrue,
    );
    expect(
      proprietorExecutiveReports.first.title,
      'Executive Term Review',
    );
  });

  test('board owner pack contains four evidence sections', () {
    expect(proprietorReportPackSections.length, 4);
    expect(proprietorReportPackSections.first.number, 1);
    expect(proprietorReportPackSections.last.number, 4);
  });

  test('report cadence covers weekly monthly and termly review', () {
    expect(
      proprietorReportCadence.map((item) => item.frequency).toList(),
      ['Weekly', 'Monthly', 'Termly'],
    );
  });

  test('owner reporting principle requires source context', () {
    expect(proprietorReportingPrinciple, contains('source context'));
    expect(proprietorReportingPrinciple, contains('missing data'));
  });
}
