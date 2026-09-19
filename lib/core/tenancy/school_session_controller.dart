import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import 'school_session_store.dart';

class SchoolSessionController extends ChangeNotifier {
  SchoolSessionController({required SchoolSessionStore store}) : _store = store;

  final SchoolSessionStore _store;

  SchoolMembership? _activeMembership;
  bool _restored = false;

  SchoolMembership? get activeMembership => _activeMembership;
  String? get activeTenantId => _activeMembership?.schoolId;
  String? get activeMembershipId => _activeMembership?.id;
  bool get isRestored => _restored;
  bool get hasActiveSchool => _activeMembership != null;

  Future<void> restore() async {
    if (_restored) return;
    _activeMembership = await _store.readActiveMembership();
    _restored = true;
    notifyListeners();
  }

  Future<void> selectSchool(SchoolMembership membership) async {
    _activeMembership = membership;
    await _store.saveActiveMembership(membership);
    notifyListeners();
  }

  Future<void> clear() async {
    _activeMembership = null;
    await _store.clearActiveMembership();
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
