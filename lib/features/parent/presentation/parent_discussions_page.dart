import 'package:flutter/material.dart';

import '../data/parent_discussions_repository.dart';
import '../domain/parent_discussions_models.dart';

enum _DiscussionTab { feed, trending, following }

class ParentDiscussionsPage extends StatefulWidget {
  const ParentDiscussionsPage({
    super.key,
    required this.repository,
    required this.onQueueChanged,
  });

  final ParentDiscussionsRepository repository;
  final VoidCallback onQueueChanged;

  @override
  State<ParentDiscussionsPage> createState() => _ParentDiscussionsPageState();
}

class _ParentDiscussionsPageState extends State<ParentDiscussionsPage> {
  late Future<ParentDiscussionsSnapshot> _snapshot;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  _DiscussionTab _tab = _DiscussionTab.feed;
  ParentDiscussionScope? _filterScope;
  ParentDiscussionScope _postScope = ParentDiscussionScope.parentsOnly;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _snapshot = widget.repository.load());
  }

  Future<void> _publish() async {
    if (_busy) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _notice = 'Add a discussion title and message first.');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.repository.queuePost(
        title: title,
        body: body,
        scope: _postScope,
      );
      _titleController.clear();
      _bodyController.clear();
      if (!mounted) return;
      setState(() {
        _tab = _DiscussionTab.feed;
        _notice = 'Discussion queued locally. It is not published until synchronization and moderation confirm it.';
        _snapshot = widget.repository.load();
      });
      widget.onQueueChanged();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(Future<void> Function() action, String notice) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _notice = notice;
        _snapshot = widget.repository.load();
      });
      widget.onQueueChanged();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(String postId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final queued = await widget.repository.report(postId);
      if (!mounted) return;
      setState(() {
        _notice = queued
            ? '$postId queued for moderation review.'
            : '$postId has already been reported from this device.';
        _snapshot = widget.repository.load();
      });
      if (queued) widget.onQueueChanged();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentDiscussionsSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(
                    onFeed: () => setState(() => _tab = _DiscussionTab.feed),
                    onTrending: () => setState(() => _tab = _DiscussionTab.trending),
                  ),
                  const SizedBox(height: 18),
                  _Stats(snapshot: data),
                  const SizedBox(height: 14),
                  _Tabs(tab: _tab, onChanged: (value) => setState(() => _tab = value)),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    _Callout(text: _notice!),
                  ],
                  const SizedBox(height: 14),
                  if (_tab == _DiscussionTab.trending)
                    _TrendingView(snapshot: data)
                  else
                    _FeedView(
                      snapshot: data,
                      tab: _tab,
                      filterScope: _filterScope,
                      postScope: _postScope,
                      titleController: _titleController,
                      bodyController: _bodyController,
                      busy: _busy,
                      onFilterChanged: (value) => setState(() => _filterScope = value),
                      onPostScopeChanged: (value) => setState(() => _postScope = value),
                      onPublish: _publish,
                      onReact: (id) => _act(
                        () => widget.repository.queueReaction(id),
                        'Reaction queued locally. Community totals may change after synchronization.',
                      ),
                      onComment: (id) => _act(
                        () => widget.repository.queueCommentAction(id),
                        'Comment interaction queued locally.',
                      ),
                      onFollow: (id) => _act(
                        () async {
                          await widget.repository.toggleFollow(id);
                        },
                        'Following preference queued locally.',
                      ),
                      onReport: _report,
                      onOpenTrends: () => setState(() => _tab = _DiscussionTab.trending),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onFeed, required this.onTrending});

  final VoidCallback onFeed;
  final VoidCallback onTrending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAMILY COMMUNITY · MODERATED DISCUSSIONS',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'School Discussions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Join approved school conversations, follow active topics and see what the community is discussing.',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: onFeed, child: const Text('Latest discussions')),
            FilledButton(onPressed: onTrending, child: const Text('View trends')),
          ],
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.snapshot});
  final ParentDiscussionsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Active discussions', '${snapshot.activeDiscussions}', 'This week'),
      ('Parent posts', '${snapshot.parentPosts}', 'Across approved spaces'),
      ('Comments', '${snapshot.commentCount}', 'Moderated conversation'),
      ('Trending topics', '${snapshot.trends.length}', 'Based on recent activity'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1),
                        const SizedBox(height: 6),
                        Text(item.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.onChanged});
  final _DiscussionTab tab;
  final ValueChanged<_DiscussionTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_DiscussionTab>(
      segments: const [
        ButtonSegment(value: _DiscussionTab.feed, label: Text('Discussion feed'), icon: Icon(Icons.forum_outlined)),
        ButtonSegment(value: _DiscussionTab.trending, label: Text('Trending'), icon: Icon(Icons.trending_up_rounded)),
        ButtonSegment(value: _DiscussionTab.following, label: Text('Following'), icon: Icon(Icons.bookmark_border_rounded)),
      ],
      selected: {tab},
      onSelectionChanged: (value) => onChanged(value.first),
      showSelectedIcon: false,
    );
  }
}

class _TrendingView extends StatelessWidget {
  const _TrendingView({required this.snapshot});
  final ParentDiscussionsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final trending = _SectionCard(
          title: 'Trending now',
          subtitle: 'Topics gaining the most recent posts, comments and reactions.',
          child: Column(
            children: [
              for (final item in snapshot.trends)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('#${item.rank}')),
                  title: Text(item.topic, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.note}\n${item.posts} active posts · ${item.tag}'),
                  isThreeLine: true,
                  trailing: Text(item.engagement, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        );
        final pulse = _SectionCard(
          title: 'Community pulse',
          subtitle: 'Aggregate discussion activity only.',
          child: Column(
            children: [
              for (final item in snapshot.pulse) ...[
                Row(children: [Expanded(child: Text(item.label)), Text('${item.value}', style: const TextStyle(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: item.value / 100),
                const SizedBox(height: 14),
              ],
              const _Callout(text: 'Trend signals summarize discussion activity. They do not rank families, infer parent sentiment, or score individual children.'),
            ],
          ),
        );
        if (!wide) return Column(children: [trending, const SizedBox(height: 12), pulse]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: trending), const SizedBox(width: 12), Expanded(child: pulse)]);
      },
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView({
    required this.snapshot,
    required this.tab,
    required this.filterScope,
    required this.postScope,
    required this.titleController,
    required this.bodyController,
    required this.busy,
    required this.onFilterChanged,
    required this.onPostScopeChanged,
    required this.onPublish,
    required this.onReact,
    required this.onComment,
    required this.onFollow,
    required this.onReport,
    required this.onOpenTrends,
  });

  final ParentDiscussionsSnapshot snapshot;
  final _DiscussionTab tab;
  final ParentDiscussionScope? filterScope;
  final ParentDiscussionScope postScope;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool busy;
  final ValueChanged<ParentDiscussionScope?> onFilterChanged;
  final ValueChanged<ParentDiscussionScope> onPostScopeChanged;
  final VoidCallback onPublish;
  final ValueChanged<String> onReact;
  final ValueChanged<String> onComment;
  final ValueChanged<String> onFollow;
  final ValueChanged<String> onReport;
  final VoidCallback onOpenTrends;

  @override
  Widget build(BuildContext context) {
    final visible = snapshot.posts.where((post) {
      if (filterScope != null && post.scope != filterScope) return false;
      if (tab == _DiscussionTab.following && !post.followed) return false;
      return true;
    }).toList(growable: false);

    final main = Column(
      children: [
        _SectionCard(
          title: 'Start a discussion',
          subtitle: 'Post only to communities linked to your family account.',
          child: Column(
            children: [
              TextField(controller: titleController, maxLength: 160, decoration: const InputDecoration(labelText: 'Discussion title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: bodyController, minLines: 3, maxLines: 6, maxLength: 4000, decoration: const InputDecoration(labelText: 'Share a question, suggestion or school-community topic...', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ParentDiscussionScope>(
                      value: postScope,
                      decoration: const InputDecoration(labelText: 'Community', border: OutlineInputBorder()),
                      items: [for (final scope in ParentDiscussionScope.values) DropdownMenuItem(value: scope, child: Text(scope.label))],
                      onChanged: busy ? null : (value) { if (value != null) onPostScopeChanged(value); },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(onPressed: busy ? null : onPublish, icon: const Icon(Icons.send_outlined), label: const Text('Post discussion')),
                ],
              ),
              const SizedBox(height: 10),
              const _Callout(text: 'Offline posting creates a queued draft for synchronization and moderation. Queued does not mean published.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: tab == _DiscussionTab.following ? 'Following' : 'Community feed',
          subtitle: 'Approved school-community discussions visible to this family account.',
          trailing: SizedBox(
            width: 190,
            child: DropdownButtonFormField<ParentDiscussionScope?>(
              value: filterScope,
              decoration: const InputDecoration(labelText: 'Scope', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<ParentDiscussionScope?>(value: null, child: Text('All')),
                for (final scope in ParentDiscussionScope.values) DropdownMenuItem<ParentDiscussionScope?>(value: scope, child: Text(scope.label)),
              ],
              onChanged: onFilterChanged,
            ),
          ),
          child: visible.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No discussions match this view.')))
              : Column(
                  children: [
                    for (final post in visible) ...[
                      _PostCard(post: post, busy: busy, onReact: onReact, onComment: onComment, onFollow: onFollow, onReport: onReport),
                      if (post != visible.last) const Divider(height: 28),
                    ],
                  ],
                ),
        ),
      ],
    );

    final side = Column(
      children: [
        _SectionCard(
          title: 'Trending topics',
          subtitle: 'Fast-moving school discussions.',
          child: Column(
            children: [
              for (final item in snapshot.trends.take(4))
                ListTile(
                  onTap: onOpenTrends,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('#${item.rank}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  title: Text(item.topic, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.engagement} activity'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Forum rules',
          subtitle: 'Community conversation stays safe and useful.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Rule(title: 'Respect privacy', text: 'Do not post another child’s private academic, health or family information.'),
              _Rule(title: 'Moderated space', text: 'Posts and comments can be reported and reviewed by authorized moderators.'),
              _Rule(title: 'Discussions are not notices', text: 'Official instructions and emergency communication remain on the school Noticeboard.'),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) return Column(children: [main, const SizedBox(height: 12), side]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: main), const SizedBox(width: 12), Expanded(child: side)]);
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.busy, required this.onReact, required this.onComment, required this.onFollow, required this.onReport});
  final ParentDiscussionPost post;
  final bool busy;
  final ValueChanged<String> onReact;
  final ValueChanged<String> onComment;
  final ValueChanged<String> onFollow;
  final ValueChanged<String> onReport;

  @override
  Widget build(BuildContext context) {
    final initials = post.author.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text(initials)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(post.author, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${post.scope.label} · ${post.timeLabel}', style: Theme.of(context).textTheme.bodySmall)])),
            Wrap(spacing: 6, children: [Chip(label: Text(post.tag)), if (post.isQueued) const Chip(label: Text('Queued'))]),
          ],
        ),
        const SizedBox(height: 12),
        Text(post.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(post.body),
        if (post.isQueued) ...[
          const SizedBox(height: 10),
          const _Callout(text: 'This post is stored locally and waiting for synchronization/moderation. It is not yet published to the school community.'),
        ],
        if (post.reported) ...[
          const SizedBox(height: 10),
          const _Callout(text: 'Report queued for moderation review.'),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [Text('${post.reactions} reactions'), Text('${post.comments} comments'), Text(post.id)]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(onPressed: busy ? null : () => onReact(post.id), icon: const Icon(Icons.favorite_border_rounded), label: const Text('React')),
            OutlinedButton.icon(onPressed: busy ? null : () => onComment(post.id), icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('Comment')),
            OutlinedButton.icon(onPressed: busy ? null : () => onFollow(post.id), icon: Icon(post.followed ? Icons.bookmark_rounded : Icons.bookmark_border_rounded), label: Text(post.followed ? 'Following' : 'Follow')),
            TextButton.icon(onPressed: busy || post.reported ? null : () => onReport(post.id), icon: const Icon(Icons.flag_outlined), label: Text(post.reported ? 'Reported' : 'Report')),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])), if (trailing != null) ...[const SizedBox(width: 12), trailing!]]),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(text)]))]),
      );
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(text),
      );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 42),
              const SizedBox(height: 12),
              const Text('School discussions could not be loaded.', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
