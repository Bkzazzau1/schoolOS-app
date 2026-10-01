/// Static guidance copy for the Community sidebar - not data about this school, so it never needs a real
/// backend source. Real activity (posts, comments, reports) lives in [CommunityRepository] instead.
const communityParticipationRules = <String, String>{
  'Staff': 'Post, comment and react according to role scope.',
  'Parents / Guardians':
      'Comment, react and create posts where school policy allows.',
  'Secondary students':
      'Can be enabled for approved class/club spaces with moderation.',
  'Primary / Early Years children':
      'Direct accounts are off by default; adults represent classroom and family participation.',
};

const communityModerationRules = <String, String>{
  'Reports awaiting review': 'Moderators can hide, restore or escalate content.',
  'Public showcase approval':
      'Public-facing posts should require authorized approval and media/privacy checks.',
  'Audit trail':
      'Review the history of edits and moderation actions.',
};

const communityNoticeboardBoundary =
    'Community is conversational. Official instructions, emergency notices and acknowledgement-required messages belong on the Noticeboard.';
