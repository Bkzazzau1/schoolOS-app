import 'package:flutter/material.dart';

import '../data/gallery_demo_data.dart';
import '../data/gallery_repository.dart';
import '../domain/gallery_models.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
  });

  final String schoolName;
  final GalleryRepository repository;
  final VoidCallback onBack;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  GallerySnapshot? _snapshot;
  GalleryVisibility? _visibility;
  String _query = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  List<GalleryMediaItem> get _visibleItems {
    final items = _snapshot?.items ?? const <GalleryMediaItem>[];
    return items
        .where((item) => item.matches(_query, _visibility))
        .toList(growable: false);
  }

  Future<void> _showUploadBoundary() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload media'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The website prototype does not store media files yet, and the native app keeps the same safety boundary.',
              ),
              const SizedBox(height: 12),
              Text(
                galleryProductionBoundary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Before production upload is enabled, SchoolOS must connect secure object storage, signed URLs, audience authorization, moderation and guardian/media-consent enforcement.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_outlined, size: 42),
              const SizedBox(height: 12),
              Text('Could not load Media Gallery\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 32),
          children: [
            _Header(
              schoolName: widget.schoolName,
              onBack: widget.onBack,
              onUpload: _showUploadBoundary,
            ),
            const SizedBox(height: 18),
            const _ScopeCard(),
            const SizedBox(height: 16),
            _StatsGrid(wide: wide),
            const SizedBox(height: 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildLibrary()),
                  const SizedBox(width: 18),
                  const Expanded(flex: 2, child: _GallerySidebar()),
                ],
              )
            else ...[
              _buildLibrary(),
              const SizedBox(height: 16),
              const _GallerySidebar(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLibrary() {
    final theme = Theme.of(context);
    final items = _visibleItems;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('School media library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Albums remain audience-scoped even when they belong to the same school.'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _showUploadBoundary,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Upload media'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search album, event or owner...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<GalleryVisibility?>(
                    initialValue: _visibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibility',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<GalleryVisibility?>(
                        value: null,
                        child: Text('All visibility'),
                      ),
                      for (final visibility in GalleryVisibility.values)
                        DropdownMenuItem<GalleryVisibility?>(
                          value: visibility,
                          child: Text(visibility.label),
                        ),
                    ],
                    onChanged: (value) => setState(() => _visibility = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('No media albums match the current search and visibility filter.'),
              )
            else
              for (final item in items) ...[
                _MediaRow(item: item),
                if (item != items.last) const Divider(height: 24),
              ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.onBack,
    required this.onUpload,
  });

  final String schoolName;
  final VoidCallback onBack;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCHOOL LIFE · MEDIA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            const Text('Media Gallery', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text(schoolName),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('School Life'),
            ),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Upload media'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 28,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Media Gallery', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text('Photos, videos and school memories'),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: const Text(
                'Store and publish school media by album, audience and consent status. Public showcase content is a separate approval decision from normal parent/internal viewing.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final stat in galleryStats)
          SizedBox(
            width: wide ? 190 : 165,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(stat.value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(stat.detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({required this.item});

  final GalleryMediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.photo_library_outlined, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _Chip(item.album),
                    _Chip(item.visibility.label),
                    _Chip(item.audience),
                  ],
                ),
                const SizedBox(height: 7),
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                Text('${item.date} · ${item.count} media items · ${item.owner}'),
                const SizedBox(height: 4),
                Text(item.note, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                const SizedBox(height: 5),
                Text('Consent: ${item.consent}', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(child: Text('${item.count}')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _GallerySidebar extends StatelessWidget {
  const _GallerySidebar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEDIA SAFETY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                for (final entry in gallerySafetyRules.entries) ...[
                  Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(entry.value, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
                  if (entry.key != gallerySafetyRules.keys.last) const Divider(height: 20),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRODUCTION LATER',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(galleryProductionBoundary, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
