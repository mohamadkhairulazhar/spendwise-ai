import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'activity_section.dart';
import 'app_chrome.dart';
import 'finance_controller.dart';
import 'forms.dart';
import 'ui_helpers.dart';

class AccountHistoryScreen extends StatelessWidget {
  const AccountHistoryScreen({super.key, required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FinanceController>();
    final data = model.snapshot;
    final account = data.accounts.firstWhere((a) => a.id == accountId);
    final colors = Theme.of(context).colorScheme;
    return FinanceScaffold(
      appBar: AppBar(
        title: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Rename account',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: model.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: model,
                        child: AccountForm(account: account),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await model.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Text(
              accountLabel(account.type),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              account.isLiability ? 'Amount owed' : 'Current balance',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Semantics(
              label:
                  '${account.isLiability ? 'Amount owed' : 'Account balance'} ${myr(account.balanceSen)}',
              excludeSemantics: true,
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    myr(account.balanceSen),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              account.isLiability
                  ? 'Positive amounts increase debt; negative amounts reduce it.'
                  : 'Money in is positive; money out is negative.',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
            if (model.busy) const LinearProgressIndicator(minHeight: 2),
            if (model.error != null) ErrorNotice(model.error!),
            const SizedBox(height: 28),
            Text(
              'Account history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ActivitySection(
              operations: data.operations,
              accounts: data.accounts,
              accountId: accountId,
            ),
          ],
        ),
      ),
    );
  }
}
