import 'package:flutter/widgets.dart';

import 'owner_access_source.dart';

/// Makes the owner's access calls available to the owner workspace. Absent on
/// demo data, where there is no server to decide access on.
class OwnerAccessScope extends InheritedWidget {
  const OwnerAccessScope({super.key, required this.repository, required super.child});

  final OwnerAccessSource repository;

  static OwnerAccessSource? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OwnerAccessScope>()?.repository;

  @override
  bool updateShouldNotify(OwnerAccessScope oldWidget) => repository != oldWidget.repository;
}
