import 'package:flutter/material.dart';

import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// What someone can do to a provider connection from its card.
enum ProviderCommand {
  activate,
  scheduleSwitch,
  test,
  replaceCredentials,
  webhook,
  payments,
  rename,
  history,
  disable,
  enable,
  disconnect,
}

/// One connected collection provider. It shows only what is safe to show: the provider, live or test, the merchant's name and a
/// masked reference, whether it is the ACTIVE provider, and whether its webhook is known to work. Never a credential.
///
/// The commands offered depend on its state and on whether the person may manage providers; the server checks both again.
class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.connection,
    required this.canManage,
    required this.hasActiveProvider,
    required this.onCommand,
    this.busy = false,
  });

  final ProviderConnection connection;
  final bool canManage;

  /// The school already has an active provider, so choosing this one is a switch rather than a first choice.
  final bool hasActiveProvider;
  final bool busy;
  final void Function(ProviderCommand command) onCommand;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: c.isActiveProvider ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF1B7F3B), width: 1.5)) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.providerName.isNotEmpty ? c.providerName : c.provider, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (c.merchantName.isNotEmpty || c.merchantReference.isNotEmpty)
                        Text([c.merchantName, c.merchantReference].where((p) => p.isNotEmpty).join(' · ')),
                      if (c.label.isNotEmpty && c.label != c.providerName) Text(c.label, style: const TextStyle(color: Color(0xFF5F6B7A))),
                    ],
                  ),
                ),
                ConnectionStatusChip(c.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (c.isActiveProvider) const StatusChip(label: 'Active provider', color: Color(0xFF1B7F3B)),
                StatusChip(label: environmentLabel(c.environment), color: c.isLive ? const Color(0xFF3B5BA5) : const Color(0xFF6B4FBB)),
                if (c.isSandbox) const SandboxTag(),
                if (c.capabilities.supportsWebhooks && !c.isClosed)
                  StatusChip(
                    label: webhookStatusLabel(c.webhookStatus),
                    color: c.webhookActive ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_summaryLine(c), style: const TextStyle(color: Color(0xFF5F6B7A))),
            if (c.needsAttention && c.lastErrorCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(bankErrorLabel(c.lastErrorCode), style: const TextStyle(color: Color(0xFFB3261E))),
              ),
            const SizedBox(height: 8),
            _actions(context),
          ],
        ),
      ),
    );
  }

  String _summaryLine(ProviderConnection c) {
    if (c.isClosed) return 'Disconnected. Its earlier payments and accounts are kept.';
    if (c.isDisabled) return 'Disabled: SchoolOS is not using it.';
    final verified = 'Last verified ${whenLabel(c.lastVerifiedAt)}.';
    if (c.isActiveProvider) return 'New family accounts are made with this provider. $verified';
    return verified;
  }

  Widget _actions(BuildContext context) {
    final c = connection;

    Widget button(String label, ProviderCommand command, {bool primary = false}) {
      final onPressed = busy ? null : () => onCommand(command);
      return primary ? FilledButton(onPressed: onPressed, child: Text(label)) : OutlinedButton(onPressed: onPressed, child: Text(label));
    }

    final buttons = <Widget>[];
    final menu = <(ProviderCommand, String)>[];
    if (c.isClosed) {
      buttons.add(button('Payments', ProviderCommand.payments));
      menu.add((ProviderCommand.history, 'Activity'));
    } else {
      if (canManage) {
        if (c.needsAttention) buttons.add(button('Replace credentials', ProviderCommand.replaceCredentials, primary: true));
        if (c.isDisabled) buttons.add(button('Enable', ProviderCommand.enable, primary: true));
        if (c.isConnected && !c.isActiveProvider && !hasActiveProvider) buttons.add(button('Make active provider', ProviderCommand.activate, primary: true));
        if (c.isConnected && !c.isActiveProvider && hasActiveProvider) buttons.add(button('Schedule switch to this provider', ProviderCommand.scheduleSwitch));
        if (!c.isDisabled) buttons.add(button('Test connection', ProviderCommand.test));
        if (c.capabilities.supportsWebhooks) buttons.add(button('Webhook setup', ProviderCommand.webhook));
      }
      buttons.add(button('Payments', ProviderCommand.payments));
      menu.add((ProviderCommand.history, 'Activity'));
      if (canManage) {
        menu.add((ProviderCommand.rename, 'Rename'));
        if (!c.needsAttention) menu.add((ProviderCommand.replaceCredentials, 'Replace credentials'));
        if ((c.isConnected || c.needsAttention) && !c.isActiveProvider) menu.add((ProviderCommand.disable, 'Disable'));
        if (!c.isActiveProvider) menu.add((ProviderCommand.disconnect, 'Disconnect'));
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...buttons,
        if (menu.isNotEmpty)
          PopupMenuButton<ProviderCommand>(
            enabled: !busy,
            tooltip: 'More',
            onSelected: onCommand,
            itemBuilder: (_) => [for (final (command, label) in menu) PopupMenuItem(value: command, child: Text(label))],
          ),
      ],
    );
  }
}
