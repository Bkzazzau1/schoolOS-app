import '../domain/community_models.dart';

const communityMembers = 1084;
const communityPostsThisWeek = 46;
const communityCommentsThisWeek = 183;
const communityPublicShowcaseCount = 7;
const communityReportsAwaitingReview = 2;

final communitySeedPosts = <CommunityPost>[
  CommunityPost(
    id: 'POST-001',
    author: 'Mrs. Mary Daniel',
    role: 'Head Teacher · Early Years',
    audience: CommunityAudience.wholeSchool,
    visibility: CommunityVisibility.schoolOnly,
    title: 'Reception A nature walk highlights',
    body:
        'The children explored leaves, shapes and sounds around the school garden today. Families can continue the conversation at home by asking children what they noticed and compared.',
    createdAt: DateTime.utc(2026, 9, 19, 10, 42),
    timeLabel: 'Today · 11:42 AM',
    reactions: 34,
    comments: [
      CommunityComment(
        id: 'POST-001-C1',
        author: 'Guardian Fatima',
        text: 'She told us about the yellow leaves already. Lovely activity.',
        createdAt: DateTime.utc(2026, 9, 19, 11),
      ),
      CommunityComment(
        id: 'POST-001-C2',
        author: 'Mrs. Hauwa Sule',
        text: 'Beautiful way to connect observation and language.',
        createdAt: DateTime.utc(2026, 9, 19, 11, 10),
      ),
    ],
    mediaLabel: 'Photo gallery · 8 items',
  ),
  CommunityPost(
    id: 'POST-002',
    author: 'Sports Committee',
    role: 'School activity team',
    audience: CommunityAudience.wholeSchool,
    visibility: CommunityVisibility.publicShowcase,
    title: 'Blue House wins inter-house relay',
    body:
        'Congratulations to Blue House for winning the senior relay final. Full inter-house sports points will be published after all events are completed.',
    createdAt: DateTime.utc(2026, 9, 18, 15, 15),
    timeLabel: 'Yesterday · 4:15 PM',
    reactions: 61,
    comments: [
      CommunityComment(
        id: 'POST-002-C1',
        author: 'Mr. Ibrahim Danladi',
        text: 'Well done to all four houses for excellent sportsmanship.',
        createdAt: DateTime.utc(2026, 9, 18, 15, 30),
      ),
    ],
    mediaLabel: 'Event photos · 12 items',
  ),
  CommunityPost(
    id: 'POST-003',
    author: 'Mrs. Hauwa Sule',
    role: 'Headmistress · Primary',
    audience: CommunityAudience.primary,
    visibility: CommunityVisibility.schoolOnly,
    title: 'Primary reading week discussion',
    body:
        'What books are your children enjoying this week? Parents can share titles or short recommendations in the comments. Teachers will compile age-appropriate suggestions for each class.',
    createdAt: DateTime.utc(2026, 9, 18, 12, 20),
    timeLabel: 'Yesterday · 1:20 PM',
    reactions: 27,
    comments: [
      CommunityComment(
        id: 'POST-003-C1',
        author: 'Guardian Hauwa',
        text: 'We are reading The Clever Tortoise at home.',
        createdAt: DateTime.utc(2026, 9, 18, 12, 30),
      ),
      CommunityComment(
        id: 'POST-003-C2',
        author: 'Primary 4 Teacher',
        text: "Great choice. We will add folktales to Friday's sharing session.",
        createdAt: DateTime.utc(2026, 9, 18, 12, 40),
      ),
    ],
  ),
  CommunityPost(
    id: 'POST-004',
    author: 'Mr. Ibrahim Danladi',
    role: 'Principal · Secondary',
    audience: CommunityAudience.jss2A,
    visibility: CommunityVisibility.schoolOnly,
    title: 'Science project showcase',
    body:
        'JSS 2A teams may use this thread to share project photos, questions and peer feedback. Keep comments constructive and focused on the work.',
    createdAt: DateTime.utc(2026, 9, 14, 14, 5),
    timeLabel: 'Monday · 3:05 PM',
    reactions: 19,
    comments: [
      CommunityComment(
        id: 'POST-004-C1',
        author: 'Science Teacher',
        text:
            'Remember to label your materials and explain the observation, not only the final model.',
        createdAt: DateTime.utc(2026, 9, 14, 14, 20),
      ),
    ],
  ),
];

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
  '2 reports awaiting review': 'Moderators can hide, restore or escalate content.',
  'Public showcase approval':
      'Public-facing posts should require authorized approval and media/privacy checks.',
  'Audit trail':
      'Edits, removals and moderation actions should be logged in the backend.',
};

const communityNoticeboardBoundary =
    'Community is conversational. Official instructions, emergency notices and acknowledgement-required messages belong on the Noticeboard.';
