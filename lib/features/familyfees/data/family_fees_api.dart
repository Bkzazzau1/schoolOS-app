import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/json_read.dart';
import '../domain/family_fees_models.dart';

/// Talks to the school's server about families and where each one pays.
///
/// Online-only on purpose: an account number is the school's own record, so nothing here is kept on the phone or made
/// up when there is no server. School fees are the school's money - they go straight to the school through its own
/// collection provider, and SchoolOS neither receives nor holds them. (A family's account is made by a collection batch:
/// see the Smart Money Collection API.)
class FamilyFeesApi {
  FamilyFeesApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership m) => 'schools/${m.schoolId}/receivables/';
  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  // -- a parent ------------------------------------------------------------------------------------------------

  /// The families this parent's children belong to, each with the accounts it pays into.
  Future<List<MyFamily>> myFamilies(SchoolMembership m) async {
    final data = readMap(await _api.get('${_base(m)}me/families/', query: _who(m)));
    return [for (final f in readMaps(data['families'])) MyFamily.fromJson(f)];
  }

  // -- the school's finance side --------------------------------------------------------------------------------

  Future<FamilyPage> families(
    SchoolMembership m, {
    String query = '',
    String? accounts,
    int limit = 30,
    int offset = 0,
  }) async =>
      FamilyPage.fromJson(
        readMap(
          await _api.get(
            '${_base(m)}families/',
            query: {
              ..._who(m),
              'withAccounts': '1',
              if (query.trim().isNotEmpty) 'q': query.trim(),
              if (accounts != null) 'accounts': accounts,
              'limit': '$limit',
              'offset': '$offset',
            },
          ),
        ),
      );

  /// suspend and close need a [reason]; reinstate does not.
  Future<FamilyPayAccount> accountAction(SchoolMembership m, String accountId, String action, {String? reason}) async {
    final data = readMap(
      await _api.post('${_base(m)}collection-accounts/$accountId/$action/', query: _who(m), body: {if (reason != null) 'reason': reason}),
    );
    return FamilyPayAccount.fromJson(readMap(data['account']));
  }

  Future<MergePreview> mergePreview(SchoolMembership m, String familyId, String intoId) async => MergePreview.fromJson(
        readMap(readMap(await _api.get('${_base(m)}families/$familyId/merge-preview/', query: {..._who(m), 'into': intoId}))['preview']),
      );

  /// Fold a family into another. Not reversible; needs billing authority, which the server checks.
  Future<void> merge(SchoolMembership m, String familyId, String intoId, String reason) async {
    await _api.post('${_base(m)}families/$familyId/merge/', query: _who(m), body: {'intoFamilyId': intoId, 'reason': reason.trim()});
  }
}

/// Hands the API to screens that need it. Absent when the app has no school server: those screens then say so.
class FamilyFeesScope extends InheritedWidget {
  const FamilyFeesScope({super.key, required this.api, required super.child});

  final FamilyFeesApi api;

  static FamilyFeesApi? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<FamilyFeesScope>()?.api;

  @override
  bool updateShouldNotify(FamilyFeesScope oldWidget) => api != oldWidget.api;
}
