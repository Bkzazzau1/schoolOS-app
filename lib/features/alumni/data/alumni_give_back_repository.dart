import '../../../shared/models/school_membership.dart';
import '../domain/alumni_pledge_models.dart';
import 'alumni_server_api.dart';

/// Online-only, the same shape `AlumniEventsRepository` already uses: with no school server
/// connected there is nothing real to show, so this stays an honest empty list rather than a
/// fabricated one.
class AlumniGiveBackRepository {
  AlumniGiveBackRepository({
    required SchoolMembership membership,
    required AlumniServerApi? remote,
  })  : _membership = membership,
        _remote = remote;

  final SchoolMembership _membership;
  final AlumniServerApi? _remote;

  bool get hasServer => _remote != null;

  Future<List<AlumniPledge>> load() async {
    final remote = _remote;
    if (remote == null) return const [];
    return remote.loadMyPledges(_membership);
  }

  Future<AlumniPledge> create({
    required AlumniPledgeCategory category,
    required String description,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Making a pledge requires the SchoolOS server.');
    }
    final clean = description.trim();
    if (clean.length < 5) {
      throw ArgumentError.value(description, 'description', 'Describe what you can offer first.');
    }
    return remote.createPledge(_membership, category: category, description: clean);
  }

  Future<AlumniPledge> withdraw(String pledgeId) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Withdrawing a pledge requires the SchoolOS server.');
    }
    return remote.withdrawPledge(_membership, pledgeId);
  }
}
