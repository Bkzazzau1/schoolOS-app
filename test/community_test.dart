import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/community/data/community_demo_data.dart';
import 'package:schoolos_app/features/community/domain/community_models.dart';

void main() {
  test('Community seed data matches the website feed', () {
    expect(communitySeedPosts, hasLength(4));
    expect(communitySeedPosts.first.id, 'POST-001');
    expect(communitySeedPosts.first.title, 'Reception A nature walk highlights');
    expect(communitySeedPosts[1].visibility, CommunityVisibility.publicShowcase);
    expect(communitySeedPosts[2].audience, CommunityAudience.primary);
    expect(communitySeedPosts[3].audience, CommunityAudience.jss2A);
  });

  test('Community KPI values match the website prototype', () {
    expect(communityMembers, 1084);
    expect(communityPostsThisWeek, 46);
    expect(communityCommentsThisWeek, 183);
    expect(communityPublicShowcaseCount, 7);
    expect(communityReportsAwaitingReview, 2);
  });

  test('Community post filtering searches content and audience', () {
    final post = communitySeedPosts[2];
    expect(post.matches('reading', null), isTrue);
    expect(post.matches('guardian', null), isFalse);
    expect(post.matches('', CommunityAudience.primary), isTrue);
    expect(post.matches('', CommunityAudience.secondary), isFalse);
  });

  test('Community post serialization preserves moderation-relevant fields', () {
    final original = communitySeedPosts[1];
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
