import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// Asks for a new credential for an account that is already connected, and sends it. The text boxes are
/// cleared as soon as the request finishes and nothing is kept: the server replaces its own encrypted copy.
/// [reconnect] restores an account that stopped working; otherwise this rotates a working credential.
Future<ConnectionActionResult?> showRenewCredentialsDialog(
  BuildContext context, {
  required BankConnectApi api,
  required SchoolMembership membership,
  required BankConnection connection,
  required BankProvider provider,
  required bool reconnect,
}) => showDialog<ConnectionActionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RenewDialog(api: api, membership: membership, connection: connection, provider: provider, reconnect: reconnect),
    );

class _RenewDialog extends StatefulWidget {
  const _RenewDialog({
    required this.api,
    required this.membership,
    required this.connection,
    required this.provider,
    required this.reconnect,
  });

  final BankConnectApi api;
  final SchoolMembership membership;
  final BankConnection connection;
  final BankProvider provider;
  final bool reconnect;

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog> {
  late final Map<String, TextEditingController> _fields = {
    for (final f in widget.provider.credentialFields) f.name: TextEditingController(),
  };
  final _code = TextEditingController();
  AuthorizationStart? _authorization;
  bool _busy = false;
  String? _error;

  bool get _byApproval => !widget.provider.usesCredentials && widget.provider.usesAuthorization;

  @override
  void dispose() {
    _wipe();
    for (final c in _fields.values) {
      c.dispose();
    }
    _code.dispose();
    super.dispose();
  }

  void _wipe() {
    _code.clear();
    for (final c in _fields.values) {
      c.clear();
    }
  }

  Future<void> _startApproval() async {
    setState(() => _busy = true);
    try {
      final start = await widget.api.beginAuthorization(
        widget.membership,
        provider: widget.provider.code,
        redirectUri: 'schoolos://bank/return',
      );
      _authorization = start;
      final uri = Uri.tryParse(start.url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      _error = describeBankError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credentials = _byApproval ? null : {for (final e in _fields.entries) e.key: e.value.text};
      final code = _byApproval ? _code.text : null;
      final state = _byApproval ? _authorization?.state : null;
      final result = widget.reconnect
          ? await widget.api.reconnect(widget.membership, widget.connection.id, credentials: credentials, authorizationCode: code, state: state)
          : await widget.api.rotate(widget.membership, widget.connection.id, credentials: credentials, authorizationCode: code, state: state);
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      _wipe();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.reconnect ? 'Reconnect ${widget.connection.title}' : 'Change credentials'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter new credentials for the same account (${widget.connection.accountMask}). They go straight to the '
                'server, are stored encrypted, and are not kept on this device. Credentials for a different account are refused.',
              ),
              const SizedBox(height: 12),
              if (_byApproval) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _startApproval,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open the bank\'s approval page'),
                ),
                const SizedBox(height: 8),
                TextField(controller: _code, decoration: const InputDecoration(labelText: 'Approval code'), autocorrect: false),
              ] else
                for (final field in widget.provider.credentialFields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _fields[field.name],
                      obscureText: field.secret,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: field.label),
                    ),
                  ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(widget.reconnect ? 'Reconnect' : 'Save')),
        ],
      );
}
