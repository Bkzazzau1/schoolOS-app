import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_staff_demo_data.dart';

void main() {
  test('proprietor staff totals match section staffing', () {
    expect(proprietorTeachingStaffTotal, 64);
    expect(
      proprietorStaffKpis.firstWhere((item) => item.label == 'Teaching staff').value,
      '64',
    );
  });

  test('proprietor leadership data carries review signal', () {
    final reviewRows = proprietorLeadershipRows.where((row) => row.needsReview);
    expect(reviewRows.length, 1);
    expect(reviewRows.single.name, 'Mr. Ibrahim Danladi');
  });

  test('staff attention queue contains owner-level issues', () {
    expect(proprietorPeopleAttention.length, 3);
    expect(
      proprietorPeopleAttention.any(
        (item) => item.title.contains('Primary 6 class-teacher gap'),
      ),
      isTrue,
    );
  });
}
