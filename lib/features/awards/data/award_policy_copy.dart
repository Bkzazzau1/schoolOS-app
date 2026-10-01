import '../domain/award_models.dart';

/// Static guidance copy for Awards & Recognition - not data about this school, so it never needs a
/// real backend source. Real activity (recognitions) lives in [AwardRepository] instead.
const awardRecognitionCategories = <String, String>{
  'Academic growth':
      'Improvement, effort, research or project work—not only highest marks.',
  'Teaching excellence':
      'Recognition for preparation, support, innovation and contribution.',
  'Sports & activities':
      'Individual, team, club and house achievement.',
  'Character & service':
      'Kindness, leadership, attendance, community service and school contribution.',
  'Creative & innovation':
      'Music, drama, art, coding, science, design and other creative work.',
};

const awardVisibilityDestinations = <String, String>{
  'School dashboards':
      'Current community recognitions and recent achievements.',
  'Parent portal':
      'Recognition involving their child plus approved school-wide highlights.',
  'Community feed':
      'Authorized award posts can generate celebration threads.',
  'Public showcase':
      'Only approved recognition with appropriate privacy/media consent.',
};

const earlyYearsRecognitionGuardrail =
    'Recognition should celebrate participation, kindness, creativity, confidence and developmental milestones without creating a public “best child” league table or fixed ability label.';

const recognitionRankingBoundary =
    'Recognition should celebrate meaningful achievements without creating permanent high-stakes rankings.';

/// Computed entirely from [awards] - the real, locally-held recognitions a school has actually
/// created, never fixed sample counts.
List<AwardStat> awardStats(List<AwardRecognition> awards) => [
      AwardStat('Total recognitions', '${awards.length}', 'Students, teachers, teams and clubs'),
      AwardStat(
        'Teacher awards',
        '${awards.where((a) => a.recipientType == AwardRecipientType.teacher).length}',
        'Supportive recognition',
      ),
      AwardStat(
        'Student recognitions',
        '${awards.where((a) => a.recipientType == AwardRecipientType.student).length}',
        'Achievement + growth + contribution',
      ),
      AwardStat(
        'Team / house awards',
        '${awards.where((a) => const {AwardRecipientType.team, AwardRecipientType.house, AwardRecipientType.club}.contains(a.recipientType)).length}',
        'Sports, clubs and service',
      ),
      AwardStat(
        'Public showcase',
        '${awards.where((award) => award.isPublic).length}',
        'Approved public-facing items',
      ),
    ];
