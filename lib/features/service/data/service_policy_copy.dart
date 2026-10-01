import '../domain/service_models.dart';

/// Static guidance copy for Community Service & Volunteering - not data about this school, so it
/// never needs a real backend source. Real activity (projects) lives in [ServiceRepository] instead.
const servicePrinciples = <String, String>{
  'Voluntary where appropriate':
      'Community-service programmes should follow school policy and age-appropriate participation.',
  'Supervised':
      'Named staff or coordinators own safety and attendance.',
  'Recognizable, not academic':
      'Service can support awards or certificates but should not silently alter grades.',
};

const serviceConnectedModules =
    'Completed projects can feed Community posts, Awards & Recognition, Houses/Teams points and the Media Gallery after appropriate review.';

/// Computed entirely from [projects] - the real, locally-held service projects a school has
/// actually created, never fixed sample counts.
List<ServiceStat> serviceStats(List<ServiceProject> projects) {
  final participants = projects.fold<int>(0, (sum, project) => sum + project.participants);
  final hours = projects.fold<int>(0, (sum, project) => sum + project.hours);
  final active = projects.where((project) => project.status == ServiceProjectStatus.active).length;
  final verified = projects.where((project) => project.verified).length;

  return <ServiceStat>[
    ServiceStat('Projects', '${projects.length}', 'Across the whole term'),
    ServiceStat('Participants', '$participants', 'Across all real projects'),
    ServiceStat('Recorded hours', '$hours', 'Project participation hours'),
    ServiceStat('Active projects', '$active', 'Currently running'),
    ServiceStat('Verified records', '$verified', 'Local review status'),
  ];
}
