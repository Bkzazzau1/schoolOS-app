import 'package:flutter/material.dart';

import '../data/community_demo_data.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    required this.onCommunityChanged,
  });

  final String schoolName;
  final CommunityRepository repository;
  final VoidCallback onBack;
  final VoidCallback onCommunityChanged;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _mediaController = TextEditingController();
  final _searchController = TextEditingController();

  CommunitySnapshot? _snapshot;
  CommunityAudience? _audienceFilter;
  CommunityAudience _draftAudience = CommunityAudience.wholeSchool;
  CommunityVisibility _draftVisibility = CommunityVisibility.schoolOnly;
  String _notice = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _mediaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  List<CommunityPost> get _visiblePosts {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    final query = _searchController.text;
    return snapshot.posts
        .where((post) => post.matches(query, _audienceFilter))
        .toList(growable: false);
  }

  Future<void> _publish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.publish(
      authorName: _authorController.text,
      title: _titleController.text,
      body: _bodyController.text,
      audience: _draftAudience,
      visibility: _draftVisibility,
      mediaLabel: _mediaController.text,
    );
    if (!mounted) return;
    if (result.success) {
      _titleController.clear();
      _bodyController.clear();
      _mediaController.clear();
      widget.onCommunityChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _saving = false;
    });
  }

  Future<void> _react(CommunityPost post) async {
    final result = await widget.repository.react(post.id);
    widget.onCommunityChanged();
    await _load();
    if (!mounted) return;
    setState(() => _notice = result.message);
  }

  Future<void> _report(CommunityPost post) async {
    final result = await widget.repository.report(post.id);
    widget.onCommunityChanged();
    await _load();
    if (!mounted) return;
    setState(() => _notice = result.message);
  }

  Future<void> _comment(CommunityPost post) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comment on ${post.id}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment',
            hintText: 'Write a constructive community reply...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Comment'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    final result = await widget.repository.comment(postId: post.id, text: text);
    if (result.success) {
      widget.onCommunityChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() => _notice = result.message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final snapshot = _snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 22, compact ? 16 : 26, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityHeader(
                      schoolName: widget.schoolName,
                      onBack: widget.onBack,
                      compact: compact,
                    ),
                    const SizedBox(height: 16),
                    const _ScopeCard(),
                    const SizedBox(height: 16),
                    _StatGrid(
                      localReports: snapshot.localReportsAwaitingReview,
                      compact: compact,
                    ),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildFeedColumn(snapshot),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            flex: 3,
                            child: _CommunitySidebar(),
                          ),
                        ],
                      )
                    else ...[
                      _buildFeedColumn(snapshot),
                      const SizedBox(height: 16),
                      const _CommunitySidebar(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedColumn(CommunitySnapshot snapshot) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'School feed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Posts, photos, discussions and reactions for the audiences each member is allowed to see.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            _Composer(
              permissions: snapshot.permissions,
              authorController: _authorController,
              titleController: _titleController,
              bodyController: _bodyController,
              mediaController: _mediaController,
              audience: _draftAudience,
              visibility: _draftVisibility,
              saving: _saving,
              notice: _notice,
              onAudienceChanged: (value) => setState(() => _draftAudience = value),
              onVisibilityChanged: (value) => setState(() => _draftVisibility = value),
              onPublish: _publish,
            ),
            const SizedBox(height: 18),
            _Filters(
              searchController: _searchController,
              audienceFilter: _audienceFilter,
              onSearchChanged: (_) => setState(() {}),
              onAudienceChanged: (value) => setState(() => _audienceFilter = value),
            ),
            const SizedBox(height: 16),
            if (_visiblePosts.isEmpty)
              const _EmptyFeed()
            else
              for (final post in _visiblePosts) ...[
                _CommunityPostCard(
                  post: post,
                  onReact: () => _react(post),
                  onComment: () => _comment(post),
                  onReport: () => _report(post),
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.schoolName,
    required this.onBack,
    required this.compact,
  });

  final String schoolName;
  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCHOOL LIFE · $schoolName'.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Community',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'A private, moderated school social space for updates, discussion and shared moments.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.45,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final back = OutlinedButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('School Life'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 14), back],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: text), const SizedBox(width: 18), back],
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'School Community',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Chip(
            avatar: const Icon(Icons.lock_outline_rounded, size: 17),
            label: const Text('Private school social space · moderated'),
          ),
          Text(
            'Conversation is school-scoped by default. Public showcase posts still require child privacy, guardian permissions and moderation.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.localReports, required this.compact});

  final int localReports;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Community members', '$communityMembers', 'Staff, guardians and eligible students'),
      ('Posts this week', '$communityPostsThisWeek', 'Across all school audiences'),
      ('Comments', '$communityCommentsThisWeek', 'Moderated discussion'),
      ('Public showcase', '$communityPublicShowcaseCount', 'Approved school-facing posts'),
      (
        'Reports awaiting review',
        '${communityReportsAwaitingReview + localReports}',
        localReports == 0 ? 'Community moderation queue' : '$localReports saved offline on this device',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = compact ? 1 : width >= 1180 ? 5 : width >= 760 ? 3 : 2;
        final gap = 12.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cardWidth,
                child: _StatCard(label: stat.$1, value: stat.$2, note: stat.$3),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.permissions,
    required this.authorController,
    required this.titleController,
    required this.bodyController,
    required this.mediaController,
    required this.audience,
    required this.visibility,
    required this.saving,
    required this.notice,
    required this.onAudienceChanged,
    required this.onVisibilityChanged,
    required this.onPublish,
  });

  final CommunityPermissions permissions;
  final TextEditingController authorController;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final TextEditingController mediaController;
  final CommunityAudience audience;
  final CommunityVisibility visibility;
  final bool saving;
  final String notice;
  final ValueChanged<CommunityAudience> onAudienceChanged;
  final ValueChanged<CommunityVisibility> onVisibilityChanged;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!permissions.canPost) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('This membership has read-only Community access.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: authorController,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(hintText: 'Post title...'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: bodyController,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: 'Share an update, activity, question or school moment...',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: mediaController,
            decoration: const InputDecoration(
              labelText: 'Photos (optional)',
              hintText: 'e.g. Sports Day photos, 12 items - a caption only, no file upload yet',
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final audienceField = DropdownButtonFormField<CommunityAudience>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: [
                  for (final item in permissions.allowedAudiences)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: (value) {
                  if (value != null) onAudienceChanged(value);
                },
              );
              final visibilityField = DropdownButtonFormField<CommunityVisibility>(
                initialValue: visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: [
                  const DropdownMenuItem(
                    value: CommunityVisibility.schoolOnly,
                    child: Text('School only'),
                  ),
                  if (permissions.canPublishPublicShowcase)
                    const DropdownMenuItem(
                      value: CommunityVisibility.publicShowcase,
                      child: Text('Public showcase'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onVisibilityChanged(value);
                },
              );
              if (stacked) {
                return Column(
                  children: [audienceField, const SizedBox(height: 10), visibilityField],
                );
              }
              return Row(
                children: [
                  Expanded(child: audienceField),
                  const SizedBox(width: 10),
                  Expanded(child: visibilityField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 520,
                child: Text(
                  'Publishing uses role scope, moderation and audit-ready offline mutations. Public showcase still requires privacy/consent checks.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onPublish,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Publish post'),
              ),
            ],
          ),
          if (notice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(notice, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.audienceFilter,
    required this.onSearchChanged,
    required this.onAudienceChanged,
  });

  final TextEditingController searchController;
  final CommunityAudience? audienceFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CommunityAudience?> onAudienceChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 620;
        final search = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search community posts...',
          ),
        );
        final filter = DropdownButtonFormField<CommunityAudience?>(
          initialValue: audienceFilter,
          decoration: const InputDecoration(labelText: 'Audience filter'),
          items: [
            const DropdownMenuItem<CommunityAudience?>(
              value: null,
              child: Text('All audiences'),
            ),
            for (final item in CommunityAudience.values)
              DropdownMenuItem<CommunityAudience?>(
                value: item,
                child: Text(item.label),
              ),
          ],
          onChanged: onAudienceChanged,
        );
        if (stacked) {
          return Column(children: [search, const SizedBox(height: 10), filter]);
        }
        return Row(
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: 10),
            Expanded(child: filter),
          ],
        );
      },
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.onReact,
    required this.onComment,
    required this.onReport,
  });

  final CommunityPost post;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = post.author
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part.characters.first)
        .take(2)
        .join();
    final isPublic = post.visibility == CommunityVisibility.publicShowcase;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(child: Text(initials)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                        '${post.role} · ${post.timeLabel}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(post.audience.label)),
                  Chip(
                    avatar: Icon(
                      isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                      size: 16,
                    ),
                    label: Text(post.visibility.label),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(post.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
          if (post.mediaLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_outlined),
                  const SizedBox(width: 9),
                  Text(post.mediaLabel!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text('${post.reactions} reactions'),
              Text('${post.comments.length} comments'),
              Text(post.id),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onReact,
                icon: const Icon(Icons.favorite_border_rounded),
                label: const Text('React'),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Comment'),
              ),
              TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report'),
              ),
            ],
          ),
          if (post.comments.isNotEmpty) ...[
            const Divider(),
            for (final comment in post.comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.author, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(comment.text),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CommunitySidebar extends StatelessWidget {
  const _CommunitySidebar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PolicyCard(
          title: 'Who can participate?',
          subtitle: 'Configurable by school and age group.',
          rules: communityParticipationRules,
        ),
        const SizedBox(height: 14),
        _PolicyCard(
          title: 'Moderation',
          subtitle: 'Community should feel social without becoming uncontrolled.',
          rules: communityModerationRules,
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community ≠ Noticeboard',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(communityNoticeboardBoundary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.title,
    required this.subtitle,
    required this.rules,
  });

  final String title;
  final String subtitle;
  final Map<String, String> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final entry in rules.entries) ...[
              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(entry.value, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.forum_outlined, size: 34),
          SizedBox(height: 8),
          Text('No Community posts match this filter.'),
        ],
      ),
    );
  }
}
