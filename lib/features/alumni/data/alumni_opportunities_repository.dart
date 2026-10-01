import '../../../shared/models/school_membership.dart';
import '../domain/alumni_opportunity_models.dart';
import 'alumni_server_api.dart';

/// Online-only, the same shape `AlumniGiveBackRepository` already uses: with no school server
/// connected there is nothing real to show, so this stays an honest empty list rather than a
/// fabricated one.
class AlumniOpportunitiesRepository {
  AlumniOpportunitiesRepository({
    required SchoolMembership membership,
    required AlumniServerApi? remote,
  })  : _membership = membership,
        _remote = remote;

  final SchoolMembership _membership;
  final AlumniServerApi? _remote;

  bool get hasServer => _remote != null;

  Future<List<AlumniOpportunity>> load() async {
    final remote = _remote;
    if (remote == null) return const [];
    return remote.loadOpportunities(_membership);
  }

  Future<AlumniOpportunity> post({
    required String title,
    required String organisation,
    required AlumniOpportunityType type,
    String locationText = '',
    required String description,
    String contactInfo = '',
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Posting an opportunity requires the SchoolOS server.');
    }
    final cleanDescription = description.trim();
    if (cleanDescription.length < 5) {
      throw ArgumentError.value(description, 'description', 'Describe the opportunity first.');
    }
    if (contactInfo.trim().isEmpty && cleanDescription.length < 20) {
      throw ArgumentError.value(
        contactInfo,
        'contactInfo',
        'Add a contact method, or describe how an interested alumnus can follow up.',
      );
    }
    return remote.postOpportunity(
      _membership,
      title: title,
      organisation: organisation,
      type: type,
      locationText: locationText,
      description: cleanDescription,
      contactInfo: contactInfo,
    );
  }

  Future<AlumniOpportunity> close(String opportunityId) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Closing a posting requires the SchoolOS server.');
    }
    return remote.closeOpportunity(_membership, opportunityId);
  }
}
