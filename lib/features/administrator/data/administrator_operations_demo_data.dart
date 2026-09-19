import '../domain/administrator_operations_models.dart';

const administratorOperationsWebsiteSeed = <AdministratorOperationTask>[
  AdministratorOperationTask(
    title: 'Transport enrollment',
    count: '3 students',
    note: 'Needs route confirmation',
  ),
  AdministratorOperationTask(
    title: 'Meal-plan enrollment',
    count: '5 students',
    note: 'Guardian choices received',
  ),
  AdministratorOperationTask(
    title: 'Visitor pass requests',
    count: '4 today',
    note: 'Reception review',
  ),
  AdministratorOperationTask(
    title: 'ID card printing',
    count: '7 cards',
    note: 'Ready for batch print',
  ),
  AdministratorOperationTask(
    title: 'Inventory request',
    count: 'Primary office',
    note: 'Stationery request pending',
  ),
];

const administratorOperationsBoundaries = <AdministratorOperationBoundary>[
  AdministratorOperationBoundary(
    title: 'Transport',
    detail:
        'Enroll students and maintain pickup-service records; detailed routes remain need-to-know.',
  ),
  AdministratorOperationBoundary(
    title: 'Meals',
    detail:
        'Record meal-plan choices without broadly exposing health or religious data.',
  ),
  AdministratorOperationBoundary(
    title: 'Visitors',
    detail:
        'Visitor registration never automatically authorizes child pickup.',
  ),
];
