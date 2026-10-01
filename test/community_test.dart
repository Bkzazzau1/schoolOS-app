import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/community/data/community_policy_copy.dart';
import 'package:schoolos_app/features/community/domain/community_models.dart';

CommunityPost _post({
  CommunityAudience audience = CommunityAudience.primary,
  CommunityVisibility visibility = CommunityVisibility.publicShowcase,
  List<CommunityComment> comments = const [],
}) {
  return CommunityPost(
    id: 'POST-TEST',
    author: 'Mrs Headmistress',
    role: 'Headmistress · Primary',
    audience: audience,
    visibility: visibility,
    title: 'Primary reading week discussion',
    body: 'What books are your children enjoying this week?',
    createdAt: DateTime.utc(2026, 9, 18, 12, 20),
    timeLabel: 'Yesterday · 1:20 PM',
    reactions: 61,
    comments: comments,
    mediaLabel: 'Event photos · 12 items',
  );
}

void main() {
  test('Community post filtering searches content and audience', () {
    final post = _post();
    expect(post.matches('reading', null), isTrue);
    expect(post.matches('guardian', null), isFalse);
    expect(post.matches('', CommunityAudience.primary), isTrue);
    expect(post.matches('', CommunityAudience.secondary), isFalse);
  });

  test('Community post serialization preserves moderation-relevant fields', () {
    final comment = CommunityComment(
      id: 'POST-TEST-C1',
      author: 'Mr Principal',
      text: 'Well done to all four houses for excellent sportsmanship.',
      createdAt: DateTime.utc(2026, 9, 18, 15, 30),
    );
    final original = _post(comments: [comment]);
    final restored = CommunityPost.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.audience, original.audience);
    expect(restored.visibility, CommunityVisibility.publicShowcase);
    expect(restored.reactions, 61);
    expect(restored.comments, hasLength(1));
    expect(restored.mediaLabel, 'Event photos · 12 items');
  });

  test('Community keeps the Noticeboard boundary explicit', () {
    expect(communityNoticeboardBoundary, contains('Official instructions'));
    expect(communityNoticeboardBoundary, contains('Noticeboard'));
  });

  test('Community participation and moderation policies remain complete', () {
    expect(communityParticipationRules.keys, contains('Staff'));
    expect(communityParticipationRules.keys, contains('Parents / Guardians'));
    expect(communityParticipationRules.keys, contains('Secondary students'));
    expect(communityParticipationRules.keys, contains('Primary / Early Years children'));
    expect(communityModerationRules.keys, contains('Public showcase approval'));
    expect(communityModerationRules.keys, contains('Audit trail'));
  });
}
