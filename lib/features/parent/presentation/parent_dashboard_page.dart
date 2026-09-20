import 'package:flutter/material.dart';

import '../data/parent_dashboard_repository.dart';
import '../domain/parent_dashboard_models.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({
    super.key,
    required this.repository,
    required this.schoolName,
    required this.onNavigate,
  });

  final ParentDashboardRepository repository;
  final String schoolName;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  late Future<ParentDashboardSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentDashboardSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }
        return _DashboardBody(
          data: snapshot.data!,
          schoolName: widget.schoolName,
          onNavigate: widget.onNavigate,
          onRefresh: _reload,
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.schoolName,
    required this.onNavigate,
    required this.onRefresh,
  });

  final ParentDashboardSnapshot data;
  final String schoolName;
  final ValueChanged<String> onNavigate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 900 ? 28.0 : 16.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
            children: [
              _Header(
                data: data,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 18),
              _FamilyBanner(data: data),
              const SizedBox(height: 16),
              _KpiGrid(data: data),
              const SizedBox(height: 16),
              _ResponsivePair(
                leftFlex: 3,
                rightFlex: 2,
                left: _SectionCard(
                  title: 'My children',
                  subtitle: 'Only children linked to this guardian account are visible.',
                  child: Column(
                    children: [
                      for (var i = 0; i < data.children.length; i++) ...[
                        _ChildCard(
                          child: data.children[i],
                          onOpen: () => onNavigate('children'),
                          onReport: () => onNavigate('progress'),
                          onMessage: () => onNavigate('messages'),
                        ),
                        if (i != data.children.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                right: _SectionCard(
                  title: 'What needs attention',
                  subtitle: 'Supportive family actions, not automated judgments.',
                  child: Column(
                    children: [
                      for (var i = 0; i < data.attentionItems.length; i++) ...[
                        _AttentionRow(
                          item: data.attentionItems[i],
                          onTap: () => onNavigate(data.attentionItems[i].destinationKey),
                        ),
                        if (i != data.attentionItems.length - 1) const Divider(height: 22),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                left: _SectionCard(
                  title: 'Family finance snapshot',
                  subtitle: 'Current-term accounts for your linked children.',
                  trailing: TextButton(
                    onPressed: () => onNavigate('finance'),
                    child: const Text('Open finance →'),
                  ),
                  child: _FinanceSnapshot(finance: data.finance),
                ),
                right: _SectionCard(
                  title: 'Recent messages',
                  subtitle: 'School communication linked to your children.',
                  trailing: TextButton(
                    onPressed: () => onNavigate('messages'),
                    child: const Text('View all →'),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.messages.length; i++) ...[
                        _MessageRow(message: data.messages[i]),
                        if (i != data.messages.length - 1) const Divider(height: 22),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                left: _SectionCard(
                  title: 'Notices & upcoming school life',
                  subtitle: 'Official notices relevant to this family.',
                  trailing: TextButton(
                    onPressed: () => onNavigate('school-life'),
                    child: const Text('School Life →'),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.notices.length; i++) ...[
                        _NoticeRow(notice: data.notices[i]),
                        if (i != data.notices.length - 1) const Divider(height: 22),
                      ],
                    ],
                  ),
                ),
                right: _SectionCard(
                  title: 'Parent AI',
                  subtitle: 'Ask questions about your own linked children and family account.',
                  trailing: TextButton(
                    onPressed: () => onNavigate('ai'),
                    child: const Text('Open Parent AI →'),
                  ),
                  child: _AiCallout(onOpen: () => onNavigate('ai')),
                ),
              ),
              const SizedBox(height: 16),
              _PrivacyCard(schoolName: schoolName),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.onNavigate});

  final ParentDashboardSnapshot data;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PARENT / GUARDIAN · FAMILY ACCOUNT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Good evening, ${data.guardianName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Here is what needs your attention across your linked children today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => onNavigate('messages'),
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('Message school'),
            ),
            FilledButton.icon(
              onPressed: () => onNavigate('finance'),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text('Pay school fees'),
            ),
          ],
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Expanded(child: text), const SizedBox(width: 20), actions],
        );
      },
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner({required this.data});
  final ParentDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: .82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAMILY SUMMARY · ${data.familyAccountId}',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: .78),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${_numberWord(data.linkedChildrenCount)} children. One family workspace.',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Track learning, attendance, school notices, transport, activities, fees and approved family records without switching between separate accounts.',
                style: TextStyle(color: scheme.onPrimary.withValues(alpha: .84), height: 1.45),
              ),
            ],
          );
          final balance = Column(
            crossAxisAlignment: constraints.maxWidth < 680
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                _naira(data.totalCurrentBalance),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Total current-term balance',
                style: TextStyle(color: scheme.onPrimary.withValues(alpha: .75), fontSize: 12),
              ),
            ],
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 18), balance],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: summary), const SizedBox(width: 24), balance],
          );
        },
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final ParentDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, String detail, IconData icon})>[
      (
        label: 'Linked children',
        value: '${data.linkedChildrenCount}',
        detail: 'Secondary + Primary',
        icon: Icons.family_restroom_rounded,
      ),
      (
        label: 'Present today',
        value: '${data.presentTodayCount}/${data.linkedChildrenCount}',
        detail: 'Both marked present',
        icon: Icons.how_to_reg_rounded,
      ),
      (
        label: 'Current balance',
        value: _shortNaira(data.totalCurrentBalance),
        detail: 'Across ${data.linkedChildrenCount} accounts',
        icon: Icons.account_balance_wallet_outlined,
      ),
      (
        label: 'Next scheduled debit',
        value: _shortNaira(data.finance.nextScheduledDebit),
        detail: data.finance.nextScheduledDebitLabel,
        icon: Icons.event_repeat_rounded,
      ),
      (
        label: 'Unread messages',
        value: '${data.unreadMessageCount}',
        detail: 'From school staff',
        icon: Icons.mark_email_unread_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120 ? 5 : width >= 720 ? 3 : width >= 430 ? 2 : 1;
        final gap = 10.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _KpiCard(
                  label: item.label,
                  value: item.value,
                  detail: item.detail,
                  icon: item.icon,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
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
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.onOpen,
    required this.onReport,
    required this.onMessage,
  });

  final ParentChildSummary child;
  final VoidCallback onOpen;
  final VoidCallback onReport;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(child.initials, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      '${child.className} · ${child.section}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: child.presentToday ? 'Present today' : 'Not marked present',
                positive: child.presentToday,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Attendance', value: '${child.attendancePercent}%')),
              Expanded(child: _Metric(label: child.academicLabel, value: '${child.academicPercent}%')),
              Expanded(child: _Metric(label: 'Fee balance', value: _naira(child.feeBalance))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: onOpen, child: const Text('Open profile')),
              OutlinedButton(onPressed: onReport, child: const Text('View report')),
              TextButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: const Text('Message school'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = positive ? scheme.tertiaryContainer : scheme.errorContainer;
    final foreground = positive ? scheme.onTertiaryContainer : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.arrow_circle_right_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(item.detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 5),
                  Text(item.area, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceSnapshot extends StatelessWidget {
  const _FinanceSnapshot({required this.finance});
  final ParentFinanceSnapshot finance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _Metric(label: 'Total billed', value: _naira(finance.totalBilled))),
            Expanded(child: _Metric(label: 'Paid', value: _naira(finance.totalPaid))),
            Expanded(child: _Metric(label: 'Balance', value: _naira(finance.balance))),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < finance.accounts.length; i++) ...[
          _AccountRow(account: finance.accounts[i]),
          if (i != finance.accounts.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final ParentPaymentAccount account;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.account_balance_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${account.childName} · ${account.accountNumber}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('${account.description} · Balance ${_naira(account.balance)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});
  final ParentMessagePreview message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.unread)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 9),
            child: Container(width: 7, height: 7, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
          )
        else
          const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.sender, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(message.message, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(message.timeLabel, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});
  final ParentNoticePreview notice;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notice.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(notice.detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text(notice.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _AiCallout extends StatelessWidget {
  const _AiCallout({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Family-context assistant', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Try: “Why is Hafsa’s attendance lower this term?”, “What fees are still outstanding?”, or “Summarize Maryam’s latest academic report.”',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 10),
          Text(
            'Parent AI cannot rank your parenting, infer private family circumstances, diagnose a child, or expose staff-only notes.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
            label: const Text('Open Parent AI'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.schoolName});
  final String schoolName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: scheme.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Private family access', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  'This $schoolName family workspace only shows children and family records linked to this guardian account. Staff-private notes, other families and restricted safeguarding records are not exposed here.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.family_restroom_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text('Family dashboard unavailable', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('SchoolOS could not read the cached family dashboard. Retry without leaving the workspace.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _naira(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}

String _shortNaira(int value) {
  if (value >= 1000000) {
    final amount = value / 1000000;
    return '₦${amount == amount.roundToDouble() ? amount.toInt() : amount.toStringAsFixed(1)}m';
  }
  if (value >= 1000) {
    final amount = value / 1000;
    return '₦${amount == amount.roundToDouble() ? amount.toInt() : amount.toStringAsFixed(1)}k';
  }
  return _naira(value);
}

String _numberWord(int value) => switch (value) {
      0 => 'No',
      1 => 'One',
      2 => 'Two',
      3 => 'Three',
      4 => 'Four',
      _ => '$value',
    };
