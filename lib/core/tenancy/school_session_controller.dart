import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import 'school_session_store.dart';

class SchoolSessionController extends ChangeNotifier {
  SchoolSessionController({required SchoolSessionStore store}) : _store = store;

  final SchoolSessionStore _store;

  SchoolMembership? _activeMembership;
  List<SchoolMembership> _memberships = const [];
  bool _restored = false;

  SchoolMembership? get activeMembership => _activeMembership;
  List<SchoolMembership> get memberships => List.unmodifiable(_memberships);
  String? get activeTenantId => _activeMembership?.schoolId;
  String? get activeMembershipId => _activeMembership?.id;
  bool get isRestored => _restored;
  bool get hasActiveSchool => _activeMembership != null;
  bool get canSwitchSchool => _memberships.length > 1;

  Future<void> restore() async {
    if (_restored) return;

    final restoredMemberships = await _store.readMemberships();
    final restoredActive = await _store.readActiveMembership();

    if (restoredMemberships.isEmpty && restoredActive != null) {
      _memberships = [restoredActive];
    } else {
      _memberships = restoredMemberships;
    }

    if (restoredActive != null &&
        _memberships.any((membership) => membership.id == restoredActive.id)) {
      _activeMembership = restoredActive;
    }

    _restored = true;
    notifyListeners();
  }

  Future<void> setMemberships(List<SchoolMembership> memberships) async {
    final unique = <String, SchoolMembership>{
      for (final membership in memberships) membership.id: membership,
    }.values.toList(growable: false);

    _memberships = unique;
    await _store.saveMemberships(unique);

    final active = _activeMembership;
    if (active != null && !unique.any((item) => item.id == active.id)) {
      _activeMembership = null;
    }
    notifyListeners();
  }

  Future<void> selectSchool(SchoolMembership membership) async {
    if (_memberships.isNotEmpty &&
        !_memberships.any((item) => item.id == membership.id)) {
      throw StateError('Cannot select a school outside this account session.');
    }

    _activeMembership = membership;
    await _store.saveActiveMembership(membership);
    notifyListeners();
  }

  Future<void> clear() async {
    _activeMembership = null;
    _memberships = const [];
    await _store.clear();
    notifyListeners();
  }

  SchoolMembership requireActiveMembership() {
    final membership = _activeMembership;
    if (membership == null) {
      throw StateError('No active school membership is selected.');
    }
    return membership;
  }
}
