import 'package:flutter/material.dart';

import '../data/parent_documents_demo_data.dart';
import '../data/parent_documents_repository.dart';
import '../domain/parent_documents_models.dart';

class ParentDocumentsPage extends StatefulWidget {
  const ParentDocumentsPage({
    super.key,
    required this.repository,
    required this.onQueueChanged,
    required this.onNavigate,
  });

  final ParentDocumentsRepository repository;
  final VoidCallback onQueueChanged;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentDocumentsPage> createState() => _ParentDocumentsPageState();
}

class _ParentDocumentsPageState extends State<ParentDocumentsPage> {
  late Future<ParentDocumentsSnapshot> _snapshot;
  final Map<String, bool> _reviewed = {};
  final Set<String> _submitting = {};

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  Future<void> _submitConsent(ParentConsentRequest request) async {
    if (_reviewed[request.id] != true || request.localDecisionQueued) return;
    setState(() => _submitting.add(request.id));
    try {
      await widget.repository.queueConsent(requestId: request.id);
      widget.onQueueChanged();
      if (!mounted) return;
      _reviewed[request.id] = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Consent decision queued. It is not recorded by the school until synchronization succeeds.',
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not queue consent: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentDocumentsSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _Failure(onRetry: _reload);
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
                    onDashboard: () => widget.onNavigate('dashboard'),
                    onUpload: () {},
                  ),
                  const SizedBox(height: 18),
                  _DocumentsCard(documents: data.documents),
                  const SizedBox(height: 16),
                  _ResponsivePair(
                    left: _ConsentRequestsCard(
                      requests: data.consentRequests,
                      reviewed: _reviewed,
                      submitting: _submitting,
                      onReviewedChanged: (id, value) {
                        setState(() => _reviewed[id] = value);
                      },
                      onSubmit: _submitConsent,
                    ),
                    right: _ConsentHistoryCard(items: data.consentHistory),
                  ),
                  const SizedBox(height: 16),
                  const _BoundaryCard(),
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
  const _Header({required this.onDashboard, required this.onUpload});

  final VoidCallback onDashboard;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAMILY ACCOUNT · DOCUMENTS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Documents & Consent',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Family-visible reports, receipts, forms and consent records for your linked children.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Dashboard'),
            ),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload family document'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.documents});

  final List<ParentFamilyDocument> documents;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Available documents',
      subtitle: 'Only records approved for guardian visibility appear here.',
      child: documents.isEmpty
          ? const _EmptyLine('No family-visible documents are available.')
          : Column(
              children: [
                for (final document in documents)
                  _DocumentRow(document: document),
              ],
            ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final ParentFamilyDocument document;

  @override
  Widget build(BuildContext context) {
    final needsAction = document.status == ParentDocumentStatus.actionNeeded;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text('${document.ownerLabel} · ${document.typeLabel}'),
            ],
          );
          final status = Chip(
            avatar: Icon(
              needsAction ? Icons.schedule_rounded : Icons.check_circle_outline,
              size: 17,
            ),
            label: Text(document.status.label),
            visualDensity: VisualDensity.compact,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 8), status],
            );
          }
          return Row(
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 12),
              Expanded(child: details),
              status,
            ],
          );
        },
      ),
    );
  }
}

class _ConsentRequestsCard extends StatelessWidget {
  const _ConsentRequestsCard({
    required this.requests,
    required this.reviewed,
    required this.submitting,
    required this.onReviewedChanged,
    required this.onSubmit,
  });

  final List<ParentConsentRequest> requests;
  final Map<String, bool> reviewed;
  final Set<String> submitting;
  final void Function(String id, bool value) onReviewedChanged;
  final Future<void> Function(ParentConsentRequest request) onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Consent request',
      subtitle: requests.isEmpty
          ? 'No pending family consent requests.'
          : '${requests.first.contextLabel} · ${requests.first.childName}',
      child: requests.isEmpty
          ? const _EmptyLine('No consent action is currently required.')
          : Column(
              children: [
                for (final request in requests)
                  _ConsentRequestBody(
                    request: request,
                    reviewed: reviewed[request.id] ?? false,
                    submitting: submitting.contains(request.id),
                    onReviewedChanged: (value) =>
                        onReviewedChanged(request.id, value),
                    onSubmit: () => onSubmit(request),
                  ),
              ],
            ),
    );
  }
}

class _ConsentRequestBody extends StatelessWidget {
  const _ConsentRequestBody({
    required this.request,
    required this.reviewed,
    required this.submitting,
    required this.onReviewedChanged,
    required this.onSubmit,
  });

  final ParentConsentRequest request;
  final bool reviewed;
  final bool submitting;
  final ValueChanged<bool> onReviewedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final queued = request.localDecisionQueued;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${request.dateLabel} · ${request.schoolSection}'),
          const SizedBox(height: 12),
          Text(request.description),
          const SizedBox(height: 12),
          if (queued)
            const _QueuedConsentNotice()
          else ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: reviewed,
              onChanged: (value) => onReviewedChanged(value ?? false),
              title: const Text(
                'I have reviewed the information and give consent.',
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: reviewed && !submitting ? onSubmit : null,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  reviewed ? 'Submit consent' : 'Review before consenting',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueuedConsentNotice extends StatelessWidget {
  const _QueuedConsentNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Consent decision queued for synchronization. Queued does not mean the school has received or recorded it yet.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentHistoryCard extends StatelessWidget {
  const _ConsentHistoryCard({required this.items});

  final List<ParentConsentHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Consent history',
      subtitle: 'Auditable family decisions.',
      child: items.isEmpty
          ? const _EmptyLine('No consent history is available.')
          : Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconForDecision(item.decision)),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${item.dateLabel} · ${item.subjectLabel}'),
                    trailing: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(item.decision.label),
                    ),
                  ),
              ],
            ),
    );
  }

  IconData _iconForDecision(ParentConsentDecision decision) => switch (decision) {
        ParentConsentDecision.approved => Icons.check_circle_outline_rounded,
        ParentConsentDecision.declined => Icons.cancel_outlined,
        ParentConsentDecision.confirmed => Icons.verified_outlined,
        ParentConsentDecision.queued => Icons.cloud_upload_outlined,
      };
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
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
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text(parentDocumentsVisibilityBoundary)),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            const Text(
              'Documents & Consent could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
