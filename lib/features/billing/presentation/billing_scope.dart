import 'package:flutter/widgets.dart';

import '../data/billing_repository.dart';

/// Makes the account's subscription and billing calls available to the owner
/// workspace. Absent on demo data, where there is no server to bill against -
/// the same reason OwnerAccessScope is absent there too.
class BillingScope extends InheritedWidget {
  const BillingScope({super.key, required this.repository, required super.child});

  final BillingRepository repository;

  static BillingRepository? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BillingScope>()?.repository;

  @override
  bool updateShouldNotify(BillingScope oldWidget) => repository != oldWidget.repository;
}
