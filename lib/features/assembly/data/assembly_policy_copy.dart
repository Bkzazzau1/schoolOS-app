import '../domain/assembly_models.dart';

/// Static guidance copy for Assembly & Faith Activities - not data about this school, so it never
/// needs a real backend source. Real activity (sessions) lives in [AssemblyRepository] instead.
const assemblyConfigurationPrinciples = <String, String>{
  'No hard-coded faith model':
      'Each school configures programmes that match its identity and obligations.',
  'Audience-aware': 'Whole-school and section gatherings remain distinct.',
  'Alternatives supported':
      'Participation rules and alternatives can be configured later where needed.',
};

/// Computed from [sessions] - the real, locally-held sessions a school has actually configured,
/// never a fixed sample count.
List<AssemblyStat> assemblyStats(List<AssemblySession> sessions) => [
      AssemblyStat(
        'Configured sessions',
        '${sessions.length}',
        'Across every real session',
      ),
      AssemblyStat(
        'Whole-school',
        '${sessions.where((s) => s.audience == 'Whole school').length}',
        'Whole-school audience',
      ),
      AssemblyStat(
        'Section sessions',
        '${sessions.where((s) => const {'Primary', 'Secondary', 'Early Years'}.contains(s.audience)).length}',
        'Primary, Secondary, Early Years',
      ),
      AssemblyStat(
        'Faith programmes',
        '${sessions.where((s) => s.type == AssemblySessionType.faithReligious).length}',
        'Tenant-configurable',
      ),
      const AssemblyStat(
        'Participation policy',
        'Config',
        'School-defined',
      ),
    ];
