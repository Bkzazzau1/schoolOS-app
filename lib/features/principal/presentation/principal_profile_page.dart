import 'package:flutter/material.dart';

import '../data/principal_profile_demo_data.dart';
import '../data/principal_profile_repository.dart';
import '../domain/principal_profile_models.dart';

class PrincipalProfilePage extends StatefulWidget {
  const PrincipalProfilePage({
    super.key,
    required this.repository,
    required this.schoolName,
    required this.onNavigate,
    this.onMutationQueued,
  });

  final PrincipalProfileRepository repository;
  final String schoolName;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalProfilePage> createState() => _PrincipalProfilePageState();
}

class _PrincipalProfilePageState extends State<PrincipalProfilePage> {
  final _fullName = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  PrincipalProfileSnapshot? _snapshot;
  String? _error;
  String? _securityNotice;
  bool _savingProfile = false;
  bool _savingPreferences = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _fullName.text = snapshot.account.fullName;
        _displayName.text = snapshot.account.displayName;
        _email.text = snapshot.account.email;
        _phone.text = snapshot.account.phone;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _saveProfile() async {
    final snapshot = _snapshot;
    if (snapshot == null || _savingProfile) return;
    setState(() => _savingProfile = true);
    final account = snapshot.account.copyWith(
      fullName: _fullName.text.trim(),
      displayName: _displayName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
    );
    final result = await widget.repository.saveAccount(account);
    if (!mounted) return;
    if (result.success) {
      widget.onMutationQueued?.call();
      await _load();
    }
    if (!mounted) return;
    setState(() => _savingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _togglePreference(PrincipalPreferenceKey key) async {
    final snapshot = _snapshot;
    if (snapshot == null || _savingPreferences) return;
    setState(() => _savingPreferences = true);
    final next = snapshot.preferences.toggled(key);
    final result = await widget.repository.savePreferences(next);
    if (!mounted) return;
    if (result.success) {
      widget.onMutationQueued?.call();
      final refreshed = await widget.repository.load();
      if (mounted) setState(() => _snapshot = refreshed);
    }
    if (!mounted) return;
    setState(() => _savingPreferences = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 40),
        const SizedBox(height: 8),
        const Text('Could not load Principal profile.'),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    return ListView(padding: const EdgeInsets.all(20), children: [
      _Header(onNavigate: widget.onNavigate),
      const SizedBox(height: 16),
      _Overview(account: snapshot.account, schoolName: widget.schoolName),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final account = _AccountCard(
          snapshot: snapshot,
          fullName: _fullName,
          displayName: _displayName,
          email: _email,
          phone: _phone,
          saving: _savingProfile,
          onSave: _saveProfile,
        );
        final workspace = _WorkspaceCard(
          schoolName: widget.schoolName,
          permissions: snapshot.permissions,
          onInfo: () => setState(() => _securityNotice = principalWorkspaceAccessInfo),
          notice: _securityNotice,
        );
        return constraints.maxWidth >= 980
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: account), const SizedBox(width: 16), Expanded(flex: 5, child: workspace)])
            : Column(children: [account, const SizedBox(height: 16), workspace]);
      }),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final prefs = _PreferencesCard(snapshot: snapshot, saving: _savingPreferences, onToggle: _togglePreference);
        final security = _SecurityCard(
          notice: _securityNotice,
          onNotice: (text) => setState(() => _securityNotice = text),
        );
        return constraints.maxWidth >= 980
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: prefs), const SizedBox(width: 16), Expanded(child: security)])
            : Column(children: [prefs, const SizedBox(height: 16), security]);
      }),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        const activity = _ActivityCard();
        const identity = _SchoolIdentityCard();
        return constraints.maxWidth >= 980
            ? const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: activity), SizedBox(width: 16), Expanded(child: identity)])
            : const Column(children: [activity, SizedBox(height: 16), identity]);
      }),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 16,
        children: [
          const SizedBox(
            width: 680,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRINCIPAL · SECONDARY SCHOOL · PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              SizedBox(height: 4),
              Text('Profile & Preferences', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
              SizedBox(height: 4),
              Text('Manage your principal account, notifications, security and active section workspace.'),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('assignments'), child: const Text('Teaching Assignments')),
            OutlinedButton(onPressed: () => onNavigate('ai'), child: const Text('Principal AI')),
          ]),
        ],
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.account, required this.schoolName});
  final PrincipalAccountProfile account;
  final String schoolName;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
          width: 380,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const CircleAvatar(radius: 28, child: Text('ID')),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ACTIVE PRINCIPAL PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  Text(account.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text('Principal · Secondary School · Kaduna Campus'),
                ])),
                const Chip(label: Text('Active')),
              ]),
            ),
          ),
        ),
        _ContextCard(label: 'ROLE CONTEXT', value: 'Principal', note: 'Secondary School academic and operational leadership'),
        _ContextCard(label: 'ACTIVE WORKSPACE', value: schoolName, note: principalProfileTermLabel),
        const _ContextCard(label: 'LAST SIGN-IN', value: principalProfileLastSignIn, note: 'Prototype security activity'),
      ]);
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.label, required this.value, required this.note});
  final String label, value, note;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ]))),
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.snapshot,
    required this.fullName,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.saving,
    required this.onSave,
  });
  final PrincipalProfileSnapshot snapshot;
  final TextEditingController fullName, displayName, email, phone;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Account information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Personal contact details for your SchoolOS account.'),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              final fields = <Widget>[
                _Field(label: 'Full name', controller: fullName),
                _Field(label: 'Display name', controller: displayName),
                _Field(label: 'Email address', controller: email),
                _Field(label: 'Phone number', controller: phone),
                const _ReadonlyField(label: 'Role', value: 'Principal'),
                const _ReadonlyField(label: 'Academic section', value: 'Secondary School'),
              ];
              if (constraints.maxWidth >= 650) {
                return Wrap(spacing: 12, runSpacing: 12, children: [for (final field in fields) SizedBox(width: (constraints.maxWidth - 12) / 2, child: field)]);
              }
              return Column(children: [for (final field in fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: field)]);
            }),
            FilledButton.icon(
              onPressed: saving || !snapshot.permissions.canEditOwnContactProfile ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save profile'),
            ),
          ]),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => TextFormField(initialValue: value, readOnly: true, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.schoolName, required this.permissions, required this.onInfo, required this.notice});
  final String schoolName;
  final PrincipalProfilePermissions permissions;
  final VoidCallback onInfo;
  final String? notice;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Workspace & permissions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Your access is derived from the active school, campus, section and role membership.'),
            const SizedBox(height: 12),
            _Line('School', schoolName),
            const _Line('Campus', 'Kaduna Campus'),
            const _Line('Section', 'Secondary School'),
            const _Line('Membership', 'Active'),
            const _Line('Role', 'Principal'),
            const _Line('Academic scope', 'Secondary School only'),
            _Line('Finance scope', permissions.canAccessFinance ? 'Allowed' : 'Restricted'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ROLE BOUNDARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(principalProfileRoleBoundary),
              ]),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onInfo, child: const Text('Workspace access info')),
            if (notice != null) ...[const SizedBox(height: 10), Text(notice!, style: const TextStyle(fontWeight: FontWeight.w600))],
          ]),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Expanded(child: Text(label)), Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900)))]),
      );
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.snapshot, required this.saving, required this.onToggle});
  final PrincipalProfileSnapshot snapshot;
  final bool saving;
  final Future<void> Function(PrincipalPreferenceKey) onToggle;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notification preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Choose which Secondary School leadership events should demand your attention.'),
            const SizedBox(height: 12),
            for (final key in PrincipalPreferenceKey.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: snapshot.preferences.isEnabled(key) ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: saving || !snapshot.permissions.canEditNotificationPreferences ? null : () => onToggle(key),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(key.label, style: const TextStyle(fontWeight: FontWeight.w900)), Text(key.description)])),
                        const SizedBox(width: 12),
                        Text(snapshot.preferences.isEnabled(key) ? 'On' : 'Off', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.notice, required this.onNotice});
  final String? notice;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Account protection and access history.'),
            const SizedBox(height: 12),
            _SecurityRow(label: 'Password', value: 'Last changed 42 days ago', action: 'Change password', onTap: () => onNotice('Password-change flow is UI-only in the current prototype.')),
            _SecurityRow(label: 'Two-step verification', value: 'Recommended', action: 'Set up', onTap: () => onNotice('Two-step verification setup will be connected when authentication is wired.')),
            _SecurityRow(label: 'Active sessions', value: '1 current session', action: 'Review sessions', onTap: () => onNotice('Session-management controls are UI-only in the current prototype.')),
            if (notice != null) ...[const SizedBox(height: 10), Text(notice!, style: const TextStyle(fontWeight: FontWeight.w600))],
          ]),
        ),
      );
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.label, required this.value, required this.action, required this.onTap});
  final String label, value, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))])),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: onTap, child: Text(action)),
        ]),
      );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent principal activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Prototype audit trail of Secondary School leadership actions.'),
            const SizedBox(height: 10),
            for (final item in principalProfileRecentActivity)
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history), title: Text(item.action, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.time)),
          ]),
        ),
      );
}

class _SchoolIdentityCard extends StatelessWidget {
  const _SchoolIdentityCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('School identity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Read-only in the principal portal.'),
            const SizedBox(height: 12),
            _Line('School', principalSchoolIdentity.name),
            _Line('Address', principalSchoolIdentity.address),
            _Line('Phone', principalSchoolIdentity.phone),
            _Line('Branches', principalSchoolIdentity.branches.join(' · ')),
            const SizedBox(height: 10),
            const Text(principalSchoolIdentityBoundary, style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
