import 'package:flutter/material.dart';

import '../data/parent_dashboard_repository.dart';
import '../domain/parent_dashboard_models.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({
    super.key,
    required this.repository,
    required this.schoolName,
    required this.onNavigate,
  });

  final ParentDashboardDataSource repository;
  final String schoolName;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  late Future<ParentDashboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadDashboard();
  }

  void _reload() {
    setState(() => _future = widget.repository.loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentDashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ParentErrorState(error: snapshot.error, onRetry: _reload);
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final wide = constraints.maxWidth >= 1180;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 22, compact ? 16 : 28, 36),
                children: [
                  _Header(
                    guardianName: data.family.guardianName,
                    compact: compact,
                    onMessages: () => widget.onNavigate('messages'),
                    onFinance: () => widget.onNavigate('finance'),
                  ),
                  const SizedBox(height: 18),
                  _FamilyBanner(family: data.family),
                  const SizedBox(height: 18),
                  _KpiGrid(data: data, compact: compact),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _ChildrenSection(data: data, onNavigate: widget.onNavigate)),
                        const SizedBox(width: 18),
                        Expanded(flex: 2, child: _AttentionSection(items: data.attentionItems, onNavigate: widget.onNavigate)),
                      ],
                    )
                  else ...[
                    _ChildrenSection(data: data, onNavigate: widget.onNavigate),
                    const SizedBox(height: 18),
                    _AttentionSection(items: data.attentionItems, onNavigate: widget.onNavigate),
                  ],
                  const SizedBox(height: 18),
                  _TwoColumn(
                    compact: compact,
                    left: _FinanceSection(data: data, onNavigate: widget.onNavigate),
                    right: _MessagesSection(messages: data.messages, onNavigate: widget.onNavigate),
                  ),
                  const SizedBox(height: 18),
                  _TwoColumn(
                    compact: compact,
                    left: _NoticesSection(notices: data.notices, onNavigate: widget.onNavigate),
                    right: _AiSection(prompts: data.aiPrompts, onNavigate: widget.onNavigate),
                  ),
                  const SizedBox(height: 18),
                  _PrivacyBoundary(schoolName: widget.schoolName),
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
  const _Header({
    required this.guardianName,
    required this.compact,
    required this.onMessages,
    required this.onFinance,
  });

  final String guardianName;
  final bool compact;
  final VoidCallback onMessages;
  final VoidCallback onFinance;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARENT / GUARDIAN · FAMILY ACCOUNT',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Good evening, $guardianName',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Here is what needs your attention across your linked children today.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(onPressed: onMessages, icon: const Icon(Icons.mail_outline_rounded), label: const Text('Message school')),
        FilledButton.icon(onPressed: onFinance, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Pay school fees')),
      ],
    );

    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 14), actions]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: title), const SizedBox(width: 18), actions]);
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner({required this.family});

  final ParentFamilyAccount family;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primaryContainer, scheme.secondaryContainer]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final balance = Column(
            crossAxisAlignment: constraints.maxWidth < 620 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(_money(family.currentTermBalanceNaira), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const Text('Total current-term balance'),
            ],
          );
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FAMILY SUMMARY · ${family.familyId}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 6),
              Text('Two children. One family workspace.', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Track learning, attendance, school notices, transport, activities, fees and approved family records without switching between separate accounts.'),
              const SizedBox(height: 10),
              const Text('One family collection identity · separate child fee ledgers', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [summary, const SizedBox(height: 18), balance]);
          }
          return Row(children: [Expanded(child: summary), const SizedBox(width: 24), balance]);
        },
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data, required this.compact});

  final ParentDashboardSnapshot data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Kpi('Linked children', '${data.family.linkedChildren}', 'Secondary + Primary', Icons.family_restroom_rounded),
      _Kpi('Present today', '${data.presentTodayCount}/${data.children.length}', 'Both marked present', Icons.how_to_reg_rounded),
      _Kpi('Current balance', _shortMoney(data.family.currentTermBalanceNaira), 'Across separate child ledgers', Icons.account_balance_wallet_outlined),
      _Kpi('Next scheduled debit', _shortMoney(data.family.nextScheduledDebitNaira), '20 Sep · parent-authorized', Icons.event_repeat_rounded),
      _Kpi('Unread messages', '${data.family.unreadMessages}', 'From school staff', Icons.mark_email_unread_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = compact ? 1 : constraints.maxWidth >= 1100 ? 5 : 3;
        final width = (constraints.maxWidth - ((count - 1) * 12)) / count;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) => SizedBox(width: width, child: item)).toList(growable: false),
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.note, this.icon);

  final String label;
  final String value;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _ChildrenSection extends StatelessWidget {
  const _ChildrenSection({required this.data, required this.onNavigate});

  final ParentDashboardSnapshot data;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'My children',
      subtitle: 'Only children linked to this guardian account are visible.',
      child: Column(
        children: [
          for (var index = 0; index < data.children.length; index++) ...[
            _ChildCard(child: data.children[index], onNavigate: onNavigate),
            if (index != data.children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.onNavigate});

  final ParentLinkedChild child;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 24, child: Text(child.initials, style: const TextStyle(fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('${child.className} · ${child.section}'),
          ])),
          _StatusPill(label: child.presentToday ? 'Present today' : 'Attendance pending', positive: child.presentToday),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 18, runSpacing: 10, children: [
          _MiniMetric(label: 'Attendance', value: '${child.attendancePercent}%'),
          _MiniMetric(label: child.isPrimary ? 'Learning' : 'Average', value: '${child.academicPercent}%'),
          _MiniMetric(label: 'Fee balance', value: _money(child.ledgerBalanceNaira)),
        ]),
        const SizedBox(height: 12),
        Text('Child ledger allocation reference · ${child.allocationReference}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(onPressed: () => onNavigate('children'), child: const Text('Open profile')),
          OutlinedButton(onPressed: () => onNavigate('children'), child: const Text('View report')),
          OutlinedButton(onPressed: () => onNavigate('messages'), child: const Text('Message school')),
        ]),
      ]),
    );
  }
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({required this.items, required this.onNavigate});

  final List<ParentAttentionItem> items;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'What needs attention',
      subtitle: 'Supportive family actions, not automated judgments.',
      child: Column(children: [
        for (var index = 0; index < items.length; index++) ...[
          _AttentionRow(item: items[index], onTap: () => onNavigate(_attentionRoute(items[index].kind))),
          if (index != items.length - 1) const Divider(height: 24),
        ],
      ]),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap});

  final ParentAttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_attentionIcon(item.kind), color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(item.description),
            const SizedBox(height: 6),
            Text(item.meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

class _FinanceSection extends StatelessWidget {
  const _FinanceSection({required this.data, required this.onNavigate});

  final ParentDashboardSnapshot data;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Family finance snapshot',
      subtitle: 'Current-term accounts for your linked children.',
      actionLabel: 'Open finance',
      onAction: () => onNavigate('finance'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 28, runSpacing: 12, children: [
          _MiniMetric(label: 'Total billed', value: _money(data.finance.totalBilledNaira), note: 'Term 1'),
          _MiniMetric(label: 'Paid', value: _money(data.finance.totalPaidNaira), note: 'Receipts available'),
          _MiniMetric(label: 'Balance', value: _money(data.finance.balanceNaira), note: 'Across 2 child ledgers'),
        ]),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Family collection identity: ${data.family.familyId}. Credits must be explicitly allocated to Maryam or Hafsa before a child ledger changes.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        for (final child in data.children)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(child.initials)),
            title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Allocation ref ${child.allocationReference} · Balance ${_money(child.ledgerBalanceNaira)}'),
          ),
        const Divider(),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('A scheduled debit or payment plan is not a confirmed payment. Child balances change only after authoritative payment confirmation and allocation.')),
        ]),
      ]),
    );
  }
}

class _MessagesSection extends StatelessWidget {
  const _MessagesSection({required this.messages, required this.onNavigate});

  final List<ParentMessagePreview> messages;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent messages',
      subtitle: 'School communication linked to your children.',
      actionLabel: 'View all',
      onAction: () => onNavigate('messages'),
      child: Column(children: [
        for (var index = 0; index < messages.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: Text(messages[index].sender, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(messages[index].message),
            trailing: Text(messages[index].whenLabel, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (index != messages.length - 1) const Divider(height: 1),
        ],
      ]),
    );
  }
}

class _NoticesSection extends StatelessWidget {
  const _NoticesSection({required this.notices, required this.onNavigate});

  final List<ParentNoticePreview> notices;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Notices & upcoming school life',
      subtitle: 'Official notices relevant to this family.',
      actionLabel: 'School Life',
      onAction: () => onNavigate('school-life'),
      child: Column(children: [
        for (var index = 0; index < notices.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.campaign_outlined),
            title: Text(notices[index].title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(notices[index].description),
            trailing: Chip(label: Text(notices[index].category)),
            onTap: notices[index].category == 'Action' ? () => onNavigate('documents') : () => onNavigate('school-life'),
          ),
          if (index != notices.length - 1) const Divider(height: 1),
        ],
      ]),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({required this.prompts, required this.onNavigate});

  final List<String> prompts;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parent AI',
      subtitle: 'Ask questions about your own linked children and family account.',
      actionLabel: 'Open Parent AI',
      onAction: () => onNavigate('ai'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Try:', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(label: Text('“$prompt”'), onPressed: () => onNavigate('ai')),
          ),
        const SizedBox(height: 8),
        const Text('Parent AI cannot rank parenting, infer private family circumstances, diagnose a child, expose staff-only notes, or change school records.', style: TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _PrivacyBoundary extends StatelessWidget {
  const _PrivacyBoundary({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_user_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Private family access', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('This $schoolName workspace only exposes children and family records linked to the active guardian membership. Other families, staff-private notes and restricted safeguarding records remain outside this portal.'),
        ])),
      ]),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.compact, required this.left, required this.right});

  final bool compact;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(children: [left, const SizedBox(height: 18), right]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 18), Expanded(child: right)]);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text('$actionLabel →')),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      if (note != null) Text(note!, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: positive ? scheme.primaryContainer : scheme.errorContainer, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _ParentErrorState extends StatelessWidget {
  const _ParentErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 12),
          const Text('Family dashboard could not be loaded.', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ]),
      ),
    );
  }
}

String _attentionRoute(ParentAttentionKind kind) => switch (kind) {
      ParentAttentionKind.attendance => 'attendance',
      ParentAttentionKind.finance => 'finance',
      ParentAttentionKind.consent => 'documents',
    };

IconData _attentionIcon(ParentAttentionKind kind) => switch (kind) {
      ParentAttentionKind.attendance => Icons.fact_check_outlined,
      ParentAttentionKind.finance => Icons.payments_outlined,
      ParentAttentionKind.consent => Icons.description_outlined,
    };

String _money(int naira) => '₦${_groupDigits(naira)}';

String _shortMoney(int naira) {
  if (naira >= 1000000 && naira % 1000000 == 0) return '₦${naira ~/ 1000000}m';
  if (naira >= 1000 && naira % 1000 == 0) return '₦${naira ~/ 1000}k';
  return _money(naira);
}

String _groupDigits(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
