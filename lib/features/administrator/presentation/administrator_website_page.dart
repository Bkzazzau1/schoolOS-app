import 'package:flutter/material.dart';

import '../data/administrator_website_demo_data.dart';
import '../data/administrator_website_repository.dart';
import '../domain/administrator_website_models.dart';

class AdministratorWebsitePage extends StatefulWidget {
  const AdministratorWebsitePage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onSettingsChanged,
  });

  final String schoolName;
  final AdministratorWebsiteRepository repository;
  final VoidCallback onSettingsChanged;

  @override
  State<AdministratorWebsitePage> createState() =>
      _AdministratorWebsitePageState();
}

class _AdministratorWebsitePageState extends State<AdministratorWebsitePage> {
  late Future<AdministratorWebsiteSnapshot> _future;
  final _headlineController = TextEditingController();
  final _supportingController = TextEditingController();
  bool _admissionsOpen = true;
  String _admissionSession = '2026/2027';
  bool _hydrated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _supportingController.dispose();
    super.dispose();
  }

  void _hydrate(AdministratorWebsiteSettings settings) {
    if (_hydrated) return;
    _headlineController.text = settings.heroHeadline;
    _supportingController.text = settings.heroSupportingText;
    _admissionsOpen = settings.admissionsOpen;
    _admissionSession = settings.admissionSession;
    _hydrated = true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.save(
      AdministratorWebsiteSettings(
        heroHeadline: _headlineController.text,
        heroSupportingText: _supportingController.text,
        admissionsOpen: _admissionsOpen,
        admissionSession: _admissionSession,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      widget.onSettingsChanged();
      setState(() {
        _hydrated = false;
        _future = widget.repository.load();
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  void _preview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(administratorWebsitePreviewBoundary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdministratorWebsiteSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text('Website settings could not be loaded.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() {
                      _hydrated = false;
                      _future = widget.repository.load();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        _hydrate(data.settings);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 18,
                22,
                wide ? 28 : 18,
                32,
              ),
              children: [
                _Header(
                  schoolName: widget.schoolName,
                  onPreview: _preview,
                  onSave: data.permissions.canManageWebsite ? _save : null,
                  saving: _saving,
                ),
                const SizedBox(height: 20),
                _KpiGrid(
                  admissionsOpen: _admissionsOpen,
                  admissionSession: _admissionSession,
                ),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HomepageCard(
                          headlineController: _headlineController,
                          supportingController: _supportingController,
                          admissionsOpen: _admissionsOpen,
                          admissionSession: _admissionSession,
                          enabled: data.permissions.canManageWebsite,
                          onAdmissionsChanged: (value) {
                            setState(() => _admissionsOpen = value);
                          },
                          onSessionChanged: (value) {
                            setState(() => _admissionSession = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(child: _PublicSectionsCard()),
                    ],
                  )
                else ...[
                  _HomepageCard(
                    headlineController: _headlineController,
                    supportingController: _supportingController,
                    admissionsOpen: _admissionsOpen,
                    admissionSession: _admissionSession,
                    enabled: data.permissions.canManageWebsite,
                    onAdmissionsChanged: (value) {
                      setState(() => _admissionsOpen = value);
                    },
                    onSessionChanged: (value) {
                      setState(() => _admissionSession = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const _PublicSectionsCard(),
                ],
                const SizedBox(height: 16),
                if (wide)
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _AdmissionsFormCard()),
                      SizedBox(width: 16),
                      Expanded(child: _BrandingCard()),
                    ],
                  )
                else ...[
                  const _AdmissionsFormCard(),
                  const SizedBox(height: 16),
                  const _BrandingCard(),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.onPreview,
    required this.onSave,
    required this.saving,
  });

  final String schoolName;
  final VoidCallback onPreview;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 18,
      runSpacing: 14,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRATION · SCHOOL WEBSITE',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Website Manager',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage the public-facing $schoolName website while SchoolOS remains invisible to parents and visitors.',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Preview website'),
            ),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.admissionsOpen,
    required this.admissionSession,
  });

  final bool admissionsOpen;
  final String admissionSession;

  @override
  Widget build(BuildContext context) {
    final dynamicKpis = <AdministratorWebsiteKpi>[
      administratorWebsiteKpis[0],
      AdministratorWebsiteKpi(
        label: 'Admissions',
        value: admissionsOpen ? 'Open' : 'Closed',
        detail: '$admissionSession intake',
      ),
      ...administratorWebsiteKpis.skip(2),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in dynamicKpis)
          SizedBox(
            width: 210,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label),
                    const SizedBox(height: 8),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.detail),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomepageCard extends StatelessWidget {
  const _HomepageCard({
    required this.headlineController,
    required this.supportingController,
    required this.admissionsOpen,
    required this.admissionSession,
    required this.enabled,
    required this.onAdmissionsChanged,
    required this.onSessionChanged,
  });

  final TextEditingController headlineController;
  final TextEditingController supportingController;
  final bool admissionsOpen;
  final String admissionSession;
  final bool enabled;
  final ValueChanged<bool> onAdmissionsChanged;
  final ValueChanged<String> onSessionChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Homepage',
      subtitle: 'Control the main public message and admission status.',
      child: Column(
        children: [
          TextField(
            controller: headlineController,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Hero headline'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: supportingController,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Hero supporting text'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
          isExpanded: true,
            initialValue: admissionsOpen ? 'open' : 'closed',
            decoration: const InputDecoration(labelText: 'Admissions status'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Admissions open')),
              DropdownMenuItem(value: 'closed', child: Text('Admissions closed')),
            ],
            onChanged: enabled
                ? (value) => onAdmissionsChanged(value == 'open')
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
          isExpanded: true,
            initialValue: admissionSession,
            decoration: const InputDecoration(labelText: 'Admission session'),
            items: const [
              DropdownMenuItem(value: '2026/2027', child: Text('2026/2027')),
              DropdownMenuItem(value: '2027/2028', child: Text('2027/2028')),
            ],
            onChanged: enabled && admissionSession != '2027/2028'
                ? (value) {
                    if (value != null) onSessionChanged(value);
                  }
                : enabled
                    ? (value) {
                        if (value != null) onSessionChanged(value);
                      }
                    : null,
          ),
        ],
      ),
    );
  }
}

class _PublicSectionsCard extends StatelessWidget {
  const _PublicSectionsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Public website sections',
      subtitle: 'Choose what the school publishes publicly.',
      child: Column(
        children: [
          for (final item in administratorPublicWebsiteSections)
            _ListRow(
              title: item.title,
              description: item.description,
              status: item.status,
            ),
        ],
      ),
    );
  }
}

class _AdmissionsFormCard extends StatelessWidget {
  const _AdmissionsFormCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Admissions form settings',
      subtitle: 'What applicants are asked to provide online.',
      child: Column(
        children: [
          for (final item in administratorAdmissionFormRequirements)
            _ListRow(
              title: item.title,
              description: item.description,
              status: item.status,
            ),
        ],
      ),
    );
  }
}

class _BrandingCard extends StatelessWidget {
  const _BrandingCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Branding & identity',
      subtitle: 'The public website belongs to the school brand.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in administratorWebsiteBrandIdentity)
                SizedBox(
                  width: 220,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label),
                        const SizedBox(height: 5),
                        Text(
                          item.value,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'White-label principle',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5),
                Text(administratorWebsiteWhiteLabelPrinciple),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
