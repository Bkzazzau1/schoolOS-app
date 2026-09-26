import 'package:flutter/material.dart';

import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// What someone can do to a connection from its card.
enum ConnectionCommand {
  confirm,
  cancel,
  sync,
  test,
  payments,
  reconnect,
  rotate,
  rename,
  webhook,
  history,
  disable,
  enable,
  disconnect,
}

/// One connected account. It shows only what is safe to show: the bank's name for it, the last four
/// digits, its status. The commands offered depend on its status and on whether the person may manage
/// accounts; the server checks both again when the command is sent.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.connection, required this.canManage, required this.onCommand, this.busy = false});

  final BankConnection connection;
  final bool canManage;
  final bool busy;
  final void Function(ConnectionCommand command) onCommand;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(c.connectionType == 'collection_provider' ? Icons.payments_outlined : Icons.account_balance_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('${c.bankTitle} · ${c.accountMask}'),
                      if (c.accountName.isNotEmpty) Text(c.accountName, style: const TextStyle(color: Color(0xFF5F6B7A))),
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
                StatusChip(label: purposeLabel(c.purpose), color: const Color(0xFF3B5BA5)),
                if (c.isSandbox) const SandboxTag(),
                if (c.connectionType == 'collection_provider')
                  const StatusChip(label: 'Provider collections, not the bank account', color: Color(0xFF5F6B7A)),
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

  String _summaryLine(BankConnection c) {
    if (c.isPending) return 'Waiting for you to confirm this is the school\'s account.';
    if (c.isClosed) return 'Disconnected. Its earlier payments are kept.';
    if (c.isDisabled) return 'Disabled: no new payments are being read.';
    return c.capabilities.supportsTransactionSync ? 'Last checked ${whenLabel(c.lastSyncedAt)}' : 'Reports payments as they happen.';
  }

  Widget _actions(BuildContext context) {
    final c = connection;
    Widget button(String label, ConnectionCommand command, {bool primary = false}) {
      final onPressed = busy ? null : () => onCommand(command);
      return primary ? FilledButton(onPressed: onPressed, child: Text(label)) : OutlinedButton(onPressed: onPressed, child: Text(label));
    }

    final buttons = <Widget>[];
    final menu = <(ConnectionCommand, String)>[];
    if (c.isPending) {
      if (canManage) {
        buttons
          ..add(button('Confirm account', ConnectionCommand.confirm, primary: true))
          ..add(button('Not my account', ConnectionCommand.cancel));
      }
    } else if (c.isClosed) {
      buttons.add(button('Payments', ConnectionCommand.payments));
      menu.add((ConnectionCommand.history, 'Activity'));
    } else {
      if (c.needsAttention && canManage) buttons.add(button('Reconnect', ConnectionCommand.reconnect, primary: true));
      if (c.isDisabled && canManage) buttons.add(button('Enable', ConnectionCommand.enable, primary: true));
      if (c.isConnected && c.capabilities.supportsTransactionSync) {
        buttons.add(button('Sync now', ConnectionCommand.sync, primary: true));
      }
      if (canManage && !c.isDisabled) buttons.add(button('Test', ConnectionCommand.test));
      buttons.add(button('Payments', ConnectionCommand.payments));
      menu.add((ConnectionCommand.history, 'Activity'));
      if (canManage) {
        menu.add((ConnectionCommand.rename, 'Rename or change purpose'));
        menu.add((ConnectionCommand.rotate, 'Change credentials'));
        if (c.capabilities.supportsWebhooks) menu.add((ConnectionCommand.webhook, 'New callback address'));
        if (c.isConnected || c.needsAttention) menu.add((ConnectionCommand.disable, 'Disable'));
        menu.add((ConnectionCommand.disconnect, 'Disconnect'));
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...buttons,
        if (menu.isNotEmpty)
          PopupMenuButton<ConnectionCommand>(
            enabled: !busy,
            tooltip: 'More',
            onSelected: onCommand,
            itemBuilder: (_) => [for (final (command, label) in menu) PopupMenuItem(value: command, child: Text(label))],
          ),
      ],
    );
  }
}
