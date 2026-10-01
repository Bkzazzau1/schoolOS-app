import '../../../shared/models/school_membership.dart';
import '../domain/alumni_directory_models.dart';
import 'alumni_server_api.dart';

/// Online-only, the same shape `AlumniProfileRepository` already uses: with no school server
/// connected there is nothing real to show, so this stays an honest empty list rather than a
/// fabricated one.
class AlumniDirectoryRepository {
  AlumniDirectoryRepository({
    required SchoolMembership membership,
    required AlumniServerApi? remote,
  })  : _membership = membership,
        _remote = remote;

  final SchoolMembership _membership;
  final AlumniServerApi? _remote;

  bool get hasServer => _remote != null;

  Future<List<AlumniDirectoryEntry>> load() async {
    final remote = _remote;
    if (remote == null) return const [];
    return remote.loadDirectory(_membership);
  }
}
