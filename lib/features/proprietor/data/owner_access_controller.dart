import 'package:flutter/foundation.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_repository.dart';

/// What the Access & Activities screen shows, and the changes it makes.
///
/// Everything is read from the server, and every change goes to the server first
/// and is then read back, so what the owner sees is what the server holds.
class OwnerAccessController extends ChangeNotifier {
  OwnerAccessController({required OwnerAccessRepository repository, required SchoolMembership owner})
      : _repository = repository,
        _owner = owner;

  final OwnerAccessRepository _repository;
  final SchoolMembership _owner;

  AccessCatalogData? catalog;
  List<RoleAccess> roles = const [];
  List<PersonAccess> people = const [];
  List<AccessChangeEntry> history = const [];

  bool loading = false;

  /// Why the last load failed, in words for the owner. Null when it worked.
  String? loadError;

  bool get loaded => catalog != null;

  PersonAccess? person(String membershipId) {
    for (final p in people) {
      if (p.membershipId == membershipId) return p;
    }
    return null;
  }

  RoleAccess? role(String role) {
    for (final r in roles) {
      if (r.role == role) return r;
    }
    return null;
  }

  /// Blocks the owner has made that the person's app has not settled yet.
  List<({PersonAccess person, AccessOverride block})> get waiting => [
        for (final p in people)
          for (final o in p.overrides)
            if (o.isBlock && o.state == OverrideState.waitingForSync) (person: p, block: o),
      ];

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.loadCatalog(_owner),
        _repository.loadRoles(_owner),
        _repository.loadPeople(_owner),
        _repository.loadHistory(_owner),
      ]);
      catalog = results[0] as AccessCatalogData;
      roles = results[1] as List<RoleAccess>;
      people = results[2] as List<PersonAccess>;
      history = results[3] as List<AccessChangeEntry>;
      loadError = null;
    } catch (error) {
      loadError = describe(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Runs one change, then reads everything back. Returns null on success, or the
  /// words to show the owner when the change was refused or could not be sent.
  Future<String?> change(Future<void> Function(OwnerAccessRepository repository, SchoolMembership owner) action) async {
    try {
      await action(_repository, _owner);
    } catch (error) {
      return describe(error);
    }
    await load();
    return null;
  }

  static String describe(Object error) {
    if (error is ApiOfflineException) return 'You need a connection to change who can see what. Try again when you are online.';
    if (error is SessionExpiredException) return 'Your sign-in has ended. Sign in again to continue.';
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }
}
