import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// Replace a provider's credentials: after a key was rotated at the provider, or when the provider stopped accepting the saved ones.
/// They must be for the SAME merchant account: the family accounts already made belong to it. The new credentials go to the server
/// once, are stored encrypted, and are not kept or shown here.
Future<ConnectionActionResult?> showReplaceCredentialsDialog(
  BuildContext context, {
  required BankConnectApi api,
  required SchoolMembership membership,
  required ProviderConnection connection,
  required CollectionProvider provider,
}) =>
    showDialog<ConnectionActionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReplaceDialog(api: api, membership: membership, connection: connection, provider: provider),
    );

class _ReplaceDialog extends StatefulWidget {
  const _ReplaceDialog({required this.api, required this.membership, required this.connection, required this.provider});

  final BankConnectApi api;
  final SchoolMembership membership;
  final ProviderConnection connection;
  final CollectionProvider provider;

  @override
  State<_ReplaceDialog> createState() => _ReplaceDialogState();
}

class _ReplaceDialogState extends State<_ReplaceDialog> {
  late final Map<String, TextEditingController> _fields = {for (final f in widget.provider.credentialFields) f.name: TextEditingController()};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final credentials = <String, String>{};
    for (final f in widget.provider.credentialFields) {
      final value = _fields[f.name]!.text.trim();
      if (f.required && value.isEmpty) {
        setState(() => _error = 'Enter ${f.label}.');
        return;
      }
      if (value.isNotEmpty) credentials[f.name] = value;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.replaceCredentials(widget.membership, widget.connection.id, credentials: credentials);
      for (final c in _fields.values) {
        c.clear();
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Replace ${widget.provider.displayName} credentials'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the credentials ${widget.provider.displayName} now gives your school. They must be for the same merchant account '
                '(${widget.connection.merchantReference.isEmpty ? 'the one already connected' : widget.connection.merchantReference}). '
                'The old ones are removed.',
              ),
              const SizedBox(height: 12),
              for (final f in widget.provider.credentialFields) ...[
                TextField(
                  key: ValueKey('replace-${f.name}'),
                  controller: _fields[f.name],
                  obscureText: f.secret,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableInteractiveSelection: !f.secret,
                  decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
              ],
              if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('replace-save'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Checking…' : 'Replace credentials')),
        ],
      );
}
