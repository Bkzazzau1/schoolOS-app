import 'package:flutter/material.dart';

import '../data/administrator_admissions_demo_data.dart';
import '../data/administrator_admissions_repository.dart';
import '../domain/administrator_admissions_models.dart';

class AdministratorAdmissionsPage extends StatefulWidget {
  const AdministratorAdmissionsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onRegistrationRequested,
    required this.onOpenPublicWebsite,
    required this.onAdmissionsChanged,
  });

  final String schoolName;
  final AdministratorAdmissionsRepository repository;
  final ValueChanged<AdmissionApplicant> onRegistrationRequested;
  final VoidCallback onOpenPublicWebsite;
  final VoidCallback onAdmissionsChanged;

  @override
  State<AdministratorAdmissionsPage> createState() =>
      _AdministratorAdmissionsPageState();
}

class _AdministratorAdmissionsPageState
    extends State<AdministratorAdmissionsPage> {
  AdministratorAdmissionsSnapshot? _snapshot;
  AdmissionStage? _filter;
  String? _selectedReference;
  bool _loading = true;
  String? _error;

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
      final references = snapshot.applicants.map((item) => item.reference).toSet();
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        if (_selectedReference == null || !references.contains(_selectedReference)) {
          _selectedReference = snapshot.applicants.isEmpty
              ? null
              : snapshot.applicants.first.reference;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<AdmissionApplicant> get _filteredApplicants {
    final applicants = _snapshot?.applicants ?? const <AdmissionApplicant>[];
    return applicants
        .where((applicant) => applicant.matchesStage(_filter))
        .toList(growable: false);
  }

  AdmissionApplicant? get _currentApplicant {
    final applicants = _snapshot?.applicants ?? const <AdmissionApplicant>[];
    if (applicants.isEmpty) return null;
    for (final applicant in applicants) {
      if (applicant.reference == _selectedReference) return applicant;
    }
    return applicants.first;
  }

  Future<void> _runAction(
    Future<AdministratorAdmissionsActionResult> Function() action,
  ) async {
    final result = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (!result.success) return;
    await _load();
    widget.onAdmissionsChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Admissions could not be loaded',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 700 ? 16 : 24,
            22,
            constraints.maxWidth < 700 ? 16 : 24,
            30,
          ),
          children: [
            _AdmissionsHeader(
              schoolName: widget.schoolName,
              compact: constraints.maxWidth < 760,
              onOpenPublicWebsite: widget.onOpenPublicWebsite,
              onRegisterAccepted: () {
                final applicant = _currentApplicant;
                if (applicant != null) {
                  widget.onRegistrationRequested(applicant);
                }
              },
            ),
            const SizedBox(height: 18),
            _KpiStrip(compact: constraints.maxWidth < 720),
            const SizedBox(height: 18),
            _StageFilterCard(
              selected: _filter,
              onSelected: (stage) => setState(() => _filter = stage),
            ),
            const SizedBox(height: 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildApplicantQueue()),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: _buildApplicantDetail()),
                ],
              )
            else ...[
              _buildApplicantQueue(),
              const SizedBox(height: 16),
              _buildApplicantDetail(),
            ],
            const SizedBox(height: 18),
            _BoundaryCallout(
              text: administratorAdmissionsBoundary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildApplicantQueue() {
    final rows = _filteredApplicants;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applicant queue',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 3),
            Text('${rows.length} sample applications shown'),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No sample applicant is currently in this stage.',
                ),
              )
            else
              for (final applicant in rows) ...[
                _ApplicantQueueTile(
                  applicant: applicant,
                  selected: applicant.reference == _selectedReference,
                  onTap: () => setState(
                    () => _selectedReference = applicant.reference,
                  ),
                ),
                if (applicant != rows.last) const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantDetail() {
    final applicant = _currentApplicant;
    final permissions = _snapshot?.permissions ??
        const AdmissionPermissions(canManagePipeline: false);
    if (applicant == null) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No applicant records are available.'),
        ),
      );
    }

    final canSchedule = permissions.canManagePipeline &&
        applicant.stage.index <= AdmissionStage.screening.index;
    final canIssueOffer = permissions.canManagePipeline &&
        applicant.stage.index <= AdmissionStage.offer.index;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicant.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${applicant.reference} · submitted ${applicant.submitted}',
                      ),
                    ],
                  ),
                ),
                _StagePill(stage: applicant.stage),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoBox(
                  label: 'Applying for',
                  value: '${applicant.section} · ${applicant.className}',
                ),
                _InfoBox(label: 'Guardian', value: applicant.guardian),
                _InfoBox(label: 'Phone', value: applicant.phone),
                _InfoBox(label: 'Source', value: applicant.source),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Application documents',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _DocumentRow(
              label: 'Birth certificate',
              status: applicant.birthCertificate,
            ),
            _DocumentRow(
              label: 'Previous school report',
              status: applicant.previousSchoolReport,
            ),
            _DocumentRow(
              label: 'Guardian ID',
              status: applicant.guardianId,
            ),
            if (applicant.documentRequestQueued) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.outbox_outlined, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document follow-up is queued locally and will sync when connected.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: permissions.canManagePipeline &&
                          !applicant.documentRequestQueued
                      ? () => _runAction(
                            () => widget.repository.requestDocument(
                              applicant.reference,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    applicant.documentRequestQueued
                        ? 'Document request queued'
                        : 'Request document',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: canSchedule
                      ? () => _runAction(
                            () => widget.repository.scheduleScreening(
                              applicant.reference,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Schedule screening'),
                ),
                OutlinedButton.icon(
                  onPressed: canIssueOffer
                      ? () => _runAction(
                            () => widget.repository.issueOffer(
                              applicant.reference,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Issue offer'),
                ),
                FilledButton.icon(
                  onPressed: () => widget.onRegistrationRequested(applicant),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Proceed to registration'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pipeline actions update the applicant record only. Proceeding to Registration does not activate the child automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdmissionsHeader extends StatelessWidget {
  const _AdmissionsHeader({
    required this.schoolName,
    required this.compact,
    required this.onOpenPublicWebsite,
    required this.onRegisterAccepted,
  });

  final String schoolName;
  final bool compact;
  final VoidCallback onOpenPublicWebsite;
  final VoidCallback onRegisterAccepted;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION · ADMISSIONS',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Admissions Pipeline',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage online applications for $schoolName from the school website through document review, screening, offer and final registration.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onOpenPublicWebsite,
          icon: const Icon(Icons.open_in_browser_rounded),
          label: const Text('Open public website'),
        ),
        FilledButton.icon(
          onPressed: onRegisterAccepted,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Register accepted child'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 14),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 18),
        actions,
      ],
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = compact
            ? constraints.maxWidth
            : ((constraints.maxWidth - 48) / 5).clamp(150.0, 250.0);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final kpi in administratorAdmissionsKpis)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kpi.label),
                        const SizedBox(height: 5),
                        Text(
                          kpi.value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          kpi.detail,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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

class _StageFilterCard extends StatelessWidget {
  const _StageFilterCard({
    required this.selected,
    required this.onSelected,
  });

  final AdmissionStage? selected;
  final ValueChanged<AdmissionStage?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Application stages',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 3),
            const Text(
              'Each online application moves through a controlled admissions journey.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                ),
                for (final stage in AdmissionStage.values)
                  FilterChip(
                    label: Text(stage.label),
                    selected: selected == stage,
                    onSelected: (_) => onSelected(stage),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantQueueTile extends StatelessWidget {
  const _ApplicantQueueTile({
    required this.applicant,
    required this.selected,
    required this.onTap,
  });

  final AdmissionApplicant applicant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                applicant.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${applicant.reference} · ${applicant.section} · ${applicant.className}',
              ),
              const SizedBox(height: 3),
              Text(
                '${applicant.guardian} · ${applicant.phone} · ${applicant.stage.label}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.label, required this.status});

  final String label;
  final AdmissionDocumentStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            status == AdmissionDocumentStatus.received
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(label)),
          Text(
            status.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final AdmissionStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stage.label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _BoundaryCallout extends StatelessWidget {
  const _BoundaryCallout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.policy_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admissions boundary',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
