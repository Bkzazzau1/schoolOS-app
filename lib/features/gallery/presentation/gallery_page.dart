import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_academics_models.dart';
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

  Future<void> _showMediaFilesInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About photo and video files'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  'Before real photo/video upload is enabled, SchoolOS must connect secure object storage, signed URLs, audience authorization and a moderation pipeline.',
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

  Future<void> _openNewAlbum() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    if (snapshot.availableTerms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No academic term is set up yet. Ask an Administrator to set up Academic Structure first.',
          ),
        ),
      );
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _NewAlbumDialog(
        repository: widget.repository,
        sessions: snapshot.availableSessions,
        terms: snapshot.availableTerms,
        classes: snapshot.availableClasses,
        canApproveVisibility: snapshot.permissions.canApproveVisibility,
      ),
    );
    if (created == true) {
      await _load();
    }
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

    final snapshot = _snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 32),
          children: [
            _Header(
              schoolName: widget.schoolName,
              onBack: widget.onBack,
              onAddAlbum: snapshot.permissions.canCreateAlbum ? _openNewAlbum : null,
            ),
            const SizedBox(height: 18),
            const _ScopeCard(),
            const SizedBox(height: 16),
            _StatsGrid(wide: wide, items: snapshot.items),
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
                TextButton.icon(
                  onPressed: _showMediaFilesInfo,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('About photo files'),
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
    required this.onAddAlbum,
  });

  final String schoolName;
  final VoidCallback onBack;
  final VoidCallback? onAddAlbum;

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
            if (onAddAlbum != null)
              FilledButton.icon(
                onPressed: onAddAlbum,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add album'),
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
  const _StatsGrid({required this.wide, required this.items});

  final bool wide;
  final List<GalleryMediaItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final stat in galleryStats(items))
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
                    if (item.hasCanonicalTerm)
                      _Chip('${item.termName} · ${item.sessionName}')
                    else
                      const _Chip('No academic term linked (legacy)'),
                    if (item.excursionTitle.isNotEmpty)
                      _Chip('Trip: ${item.excursionTitle}'),
                  ],
                ),
                const SizedBox(height: 7),
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                Text('${item.date} · ${item.count} media items (manual count) · ${item.owner}'),
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

class _NewAlbumDialog extends StatefulWidget {
  const _NewAlbumDialog({
    required this.repository,
    required this.sessions,
    required this.terms,
    required this.classes,
    required this.canApproveVisibility,
  });

  final GalleryRepository repository;
  final List<AdministratorAcademicSession> sessions;
  final List<AdministratorAcademicTerm> terms;
  final List<AdministratorAcademicClass> classes;
  final bool canApproveVisibility;

  @override
  State<_NewAlbumDialog> createState() => _NewAlbumDialogState();
}

class _NewAlbumDialogState extends State<_NewAlbumDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _albumController = TextEditingController();
  final _ownerController = TextEditingController();
  final _dateController = TextEditingController();
  final _countController = TextEditingController(text: '0');
  final _consentController = TextEditingController();
  final _noteController = TextEditingController();
  late AdministratorAcademicTerm _term;
  AdministratorAcademicClass? _academicClass;
  GalleryVisibility _visibility = GalleryVisibility.internal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _term = widget.terms.firstWhere(
      (term) => term.status == 'active',
      orElse: () => widget.terms.first,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _albumController.dispose();
    _ownerController.dispose();
    _dateController.dispose();
    _countController.dispose();
    _consentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await widget.repository.createAlbum(
      title: _titleController.text,
      album: _albumController.text,
      owner: _ownerController.text,
      date: _dateController.text,
      count: int.tryParse(_countController.text) ?? 0,
      visibility: _visibility,
      consent: _consentController.text,
      note: _noteController.text,
      term: _term,
      session: widget.sessions.firstWhere(
        (session) => session.id == _term.sessionId,
        orElse: () => AdministratorAcademicSession(
          id: _term.sessionId,
          code: '',
          name: '',
          startsOn: '',
          endsOn: '',
          status: '',
        ),
      ),
      academicClass: _academicClass,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add album'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _albumController,
                  decoration: const InputDecoration(
                    labelText: 'Album (optional)',
                    hintText: 'e.g. Sports Day',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AdministratorAcademicTerm>(
                  initialValue: _term,
                  decoration: const InputDecoration(labelText: 'Academic term'),
                  items: [
                    for (final term in widget.terms)
                      DropdownMenuItem(value: term, child: Text(term.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _term = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AdministratorAcademicClass?>(
                  initialValue: _academicClass,
                  decoration: const InputDecoration(
                    labelText: 'Class (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<AdministratorAcademicClass?>(
                      value: null,
                      child: Text('Not a single class (whole school/club)'),
                    ),
                    for (final academicClass in widget.classes)
                      DropdownMenuItem(
                        value: academicClass,
                        child: Text(academicClass.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _academicClass = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<GalleryVisibility>(
                  initialValue: _visibility,
                  decoration: const InputDecoration(labelText: 'Visibility'),
                  items: [
                    for (final visibility in GalleryVisibility.values)
                      DropdownMenuItem(
                        value: visibility,
                        enabled: visibility != GalleryVisibility.publicShowcase ||
                            widget.canApproveVisibility,
                        child: Text(
                          visibility == GalleryVisibility.publicShowcase &&
                                  !widget.canApproveVisibility
                              ? '${visibility.label} (Proprietor/Principal only)'
                              : visibility.label,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _visibility = value);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ownerController,
                  decoration: const InputDecoration(labelText: 'Owner'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'e.g. 12 Nov 2026',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _countController,
                  decoration: const InputDecoration(
                    labelText: 'Media items (a manual count, not a real upload)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _consentController,
                  decoration: const InputDecoration(labelText: 'Consent status'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add album'),
        ),
      ],
    );
  }
}
