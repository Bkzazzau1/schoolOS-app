import '../../../shared/models/school_membership.dart';
import '../domain/alumni_event_models.dart';
import 'alumni_server_api.dart';

/// Online-only, the same shape `AlumniDirectoryRepository` already uses: with no school server
/// connected there is nothing real to show, so this stays an honest empty list rather than a
/// fabricated one.
class AlumniEventsRepository {
  AlumniEventsRepository({
    required SchoolMembership membership,
    required AlumniServerApi? remote,
  })  : _membership = membership,
        _remote = remote;

  final SchoolMembership _membership;
  final AlumniServerApi? _remote;

  bool get hasServer => _remote != null;

  Future<List<AlumniEvent>> load() async {
    final remote = _remote;
    if (remote == null) return const [];
    return remote.loadEvents(_membership);
  }

  Future<AlumniEvent> rsvp(String eventId, {required bool attending}) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Responding to a reunion requires the SchoolOS server.');
    }
    return remote.rsvp(_membership, eventId, attending: attending);
  }
}
