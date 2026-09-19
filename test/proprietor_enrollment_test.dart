import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_enrollment_demo_data.dart';

void main() {
  test('proprietor enrollment snapshot matches website totals', () {
    expect(proprietorEnrollmentSnapshot.activeStudents, 648);
    expect(proprietorEnrollmentSnapshot.totalApplications, 131);
    expect(proprietorEnrollmentSnapshot.totalOffers, 100);
    expect(proprietorEnrollmentSnapshot.totalAccepted, 79);
    expect(proprietorEnrollmentSnapshot.trend.last, 648);
  });

  test('section conversion metrics are internally consistent', () {
    final primary = proprietorEnrollmentPipeline[1];

    expect(primary.section, 'Primary School');
    expect(primary.offerRate, closeTo(35 / 46, 0.0001));
    expect(primary.acceptanceRate, closeTo(29 / 35, 0.0001));
    expect(primary.retentionPercent, 97);
  });
}
