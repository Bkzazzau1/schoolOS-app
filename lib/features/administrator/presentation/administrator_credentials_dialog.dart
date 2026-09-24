import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';
import '../../proprietor/data/staff_server_api.dart';

Future<void> showStudentCredentialManagement(
  BuildContext context, {
  required StaffServerApi api,
  required SchoolMembership membership,
  required String studentId,
}) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CredentialManagementPage(
          api: api,
          membership: membership,
          studentId: studentId,
        ),
      ),
    );

Future<void> showCredentialRecoveryQueue(
  BuildContext context, {
  required StaffServerApi api,
  required SchoolMembership membership,
}) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RecoveryQueuePage(
          api: api,
          membership: membership,
        ),
      ),
    );

class _CredentialManagementPage extends StatefulWidget {
  const _CredentialManagementPage({
    required this.api,
    required this.membership,
    required this.studentId,
  });

  final StaffServerApi api;
  final SchoolMembership membership;
  final String studentId;

  @override
  State<_CredentialManagementPage> createState() =>
      _CredentialManagementPageState();
}

class _CredentialManagementPageState
    extends State<_CredentialManagementPage> {
  StudentCredentialHandoff? _handoff;
  bool _loading = true;
  bool _busy = false;
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
      final handoff = await widget.api.studentCredentials(
        widget.membership,
        widget.studentId,
      );
      if (!mounted) return;
      setState(() => _handoff = handoff);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Student & Parent credentials')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: const Text(
                          'SchoolOS never shows a person’s private permanent password. '
                          'A temporary password appears only while that account is required '
                          'to change it on the next sign-in.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _CredentialPartyCard(
                        title: 'Student account',
                        icon: Icons.school_outlined,
                        party: _handoff!.student,
                        onReset: _busy
                            ? null
                            : () => _confirmReset(parent: false),
                      ),
                      const SizedBox(height: 16),
                      _CredentialPartyCard(
                        title: 'Parent account',
                        icon: Icons.family_restroom_outlined,
                        party: _handoff!.parent,
                        onReset: _busy
                            ? null
                            : () => _confirmReset(parent: true),
                        onChangePhone:
                            _busy ? null : () => _changeParentPhone(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _busy ? null : _copyHandoff,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copy credential handoff note'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Give credentials privately to the student/guardian. Do not post the temporary password in a class group or public notice.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _confirmReset({required bool parent}) async {
    final party = parent ? _handoff!.parent : _handoff!.student;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset ${parent ? 'Parent' : 'Student'} password?'),
        content: Text(
          '${party.name} will be signed out of existing SchoolOS sessions. '
          'The password returns to the registered first name temporarily, and '
          'SchoolOS will require a new private password at the next sign-in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(() async {
      _handoff = parent
          ? await widget.api.resetParentCredentials(
              widget.membership,
              widget.studentId,
            )
          : await widget.api.resetStudentCredentials(
              widget.membership,
              widget.studentId,
            );
    });
  }

  Future<void> _changeParentPhone() async {
    final controller = TextEditingController(text: _handoff!.parent.loginId);
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Parent login phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This changes the Parent login ID for all linked children in this school and signs out existing Parent sessions.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Parent phone number',
                hintText: '0803 123 4567',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Change phone'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (phone == null || phone.isEmpty || !mounted) return;

    await _run(() async {
      _handoff = await widget.api.changeParentPhone(
        widget.membership,
        widget.studentId,
        phone,
      );
    });
  }

  Future<void> _copyHandoff() async {
    final handoff = _handoff!;
    String line(String label, CredentialParty party) {
      final password = party.temporaryPassword;
      return '$label\nLogin ID: ${party.loginId}\n'
          '${password == null ? 'Password: private password already set' : 'Temporary password: $password\nChange password on first sign-in: Yes'}';
    }

    final text = 'SchoolOS credentials\n\n'
        '${line('Student · ${handoff.student.name}', handoff.student)}\n\n'
        '${line('Parent · ${handoff.parent.name}', handoff.parent)}\n\n'
        'Keep these details private.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credential handoff copied.')),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credential change saved by SchoolOS.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CredentialPartyCard extends StatelessWidget {
  const _CredentialPartyCard({
    required this.title,
    required this.icon,
    required this.party,
    this.onReset,
    this.onChangePhone,
  });

  final String title;
  final IconData icon;
  final CredentialParty party;
  final VoidCallback? onReset;
  final VoidCallback? onChangePhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(party.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SelectableText('Login ID: ${party.loginId}'),
            if (party.temporaryPassword != null) ...[
              const SizedBox(height: 6),
              SelectableText(
                'Temporary password: ${party.temporaryPassword}',
              ),
              const SizedBox(height: 6),
              const Text('Must create a private password on next sign-in.'),
            ] else ...[
              const SizedBox(height: 6),
              const Text('Private password already set. It is not visible to the school.'),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Reset password'),
                ),
                if (onChangePhone != null)
                  OutlinedButton.icon(
                    onPressed: onChangePhone,
                    icon: const Icon(Icons.phone_iphone_rounded),
                    label: const Text('Change login phone'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryQueuePage extends StatefulWidget {
  const _RecoveryQueuePage({required this.api, required this.membership});

  final StaffServerApi api;
  final SchoolMembership membership;

  @override
  State<_RecoveryQueuePage> createState() => _RecoveryQueuePageState();
}

class _RecoveryQueuePageState extends State<_RecoveryQueuePage> {
  List<CredentialRecoveryItem> _items = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final items = await widget.api.credentialRecoveryRequests(widget.membership);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credential recovery requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No pending Student or Parent recovery requests.'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final parent = item.identityKind == 'parent_phone';
                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        parent
                                            ? Icons.family_restroom_outlined
                                            : Icons.school_outlined,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.name.isEmpty
                                              ? item.requestedIdentifier
                                              : item.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText('Login ID: ${item.requestedIdentifier}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Requested ${_dateLabel(item.requestedAt)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (item.linkedStudentIds.isNotEmpty)
                                        FilledButton.icon(
                                          onPressed: _busyId == null
                                              ? () async {
                                                  await showStudentCredentialManagement(
                                                    context,
                                                    api: widget.api,
                                                    membership: widget.membership,
                                                    studentId: item.linkedStudentIds.first,
                                                  );
                                                  if (mounted) await _load();
                                                }
                                              : null,
                                          icon: const Icon(Icons.manage_accounts_outlined),
                                          label: const Text('Manage credentials'),
                                        ),
                                      TextButton(
                                        onPressed: _busyId == null
                                            ? () => _dismiss(item)
                                            : null,
                                        child: Text(
                                          _busyId == item.id ? 'Dismissing…' : 'Dismiss',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Future<void> _dismiss(CredentialRecoveryItem item) async {
    setState(() => _busyId = item.id);
    try {
      await widget.api.dismissCredentialRecovery(widget.membership, item.id);
      if (!mounted) return;
      setState(() => _items = _items.where((row) => row.id != item.id).toList());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _message(Object error) {
  if (error is ApiOfflineException) {
    return 'Could not reach SchoolOS. Credential changes require the server.';
  }
  if (error is ApiException) return error.message;
  if (error is SessionExpiredException) return error.message;
  return 'SchoolOS could not complete this credential action. Please retry.';
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
