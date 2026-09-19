import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_operations_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_operations_models.dart';

void main() {
  test('website operations seed preserves five exact queue items', () {
    expect(administratorOperationsWebsiteSeed, hasLength(5));

    expect(administratorOperationsWebsiteSeed[0].title, 'Transport enrollment');
    expect(administratorOperationsWebsiteSeed[0].count, '3 students');
    expect(administratorOperationsWebsiteSeed[0].note, 'Needs route confirmation');

    expect(administratorOperationsWebsiteSeed[1].title, 'Meal-plan enrollment');
    expect(administratorOperationsWebsiteSeed[1].count, '5 students');
    expect(administratorOperationsWebsiteSeed[1].note, 'Guardian choices received');

    expect(administratorOperationsWebsiteSeed[2].title, 'Visitor pass requests');
    expect(administratorOperationsWebsiteSeed[2].count, '4 today');
    expect(administratorOperationsWebsiteSeed[2].note, 'Reception review');

    expect(administratorOperationsWebsiteSeed[3].title, 'ID card printing');
    expect(administratorOperationsWebsiteSeed[3].count, '7 cards');
    expect(administratorOperationsWebsiteSeed[3].note, 'Ready for batch print');

    expect(administratorOperationsWebsiteSeed[4].title, 'Inventory request');
    expect(administratorOperationsWebsiteSeed[4].count, 'Primary office');
    expect(administratorOperationsWebsiteSeed[4].note, 'Stationery request pending');
  });

  test('website preserves all three operational boundaries', () {
    expect(administratorOperationsBoundaries, hasLength(3));
    expect(administratorOperationsBoundaries[0].title, 'Transport');
    expect(
      administratorOperationsBoundaries[0].detail,
      contains('detailed routes remain need-to-know'),
    );
    expect(administratorOperationsBoundaries[1].title, 'Meals');
    expect(
      administratorOperationsBoundaries[1].detail,
      contains('without broadly exposing health or religious data'),
    );
    expect(administratorOperationsBoundaries[2].title, 'Visitors');
    expect(
      administratorOperationsBoundaries[2].detail,
      contains('never automatically authorizes child pickup'),
    );
  });

  test('operations serialization preserves exact queue fields', () {
    final original = administratorOperationsWebsiteSeed[3];
    final restored = AdministratorOperationTask.fromJson(original.toJson());
    expect(restored.title, 'ID card printing');
    expect(restored.count, '7 cards');
    expect(restored.note, 'Ready for batch print');
  });

  test('operations scope does not broaden transport route visibility', () {
    final transport = administratorOperationsBoundaries.first;
    expect(transport.detail, contains('pickup-service records'));
    expect(transport.detail, contains('need-to-know'));
  });

  test('operations scope does not expose sensitive meal attributes broadly', () {
    final meals = administratorOperationsBoundaries[1];
    expect(meals.detail, contains('meal-plan choices'));
    expect(meals.detail, contains('health or religious data'));
  });

  test('visitor registration never implies child-pickup authorization', () {
    final visitors = administratorOperationsBoundaries[2];
    expect(visitors.detail, contains('never automatically authorizes child pickup'));
  });
}
