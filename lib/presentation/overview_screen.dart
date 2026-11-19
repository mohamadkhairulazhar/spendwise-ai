import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/ledger.dart';
import 'app_chrome.dart';
import 'finance_controller.dart';
import 'forms.dart';
import 'ui_helpers.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key});
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  bool? _showAccounts;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<FinanceController>();
    final data = model.snapshot;
    final showAccounts = _showAccounts ?? data.accounts.isEmpty;
    final colors = Theme.of(context).colorScheme;
    final assets = data.accounts
        .where((a) => !a.isLiability)
        .fold(0, (sum, a) => sum + a.balanceSen);
    final debt = data.accounts
        .where((a) => a.isLiability)
        .fold(0, (sum, a) => sum + a.balanceSen);
    void open(Widget screen) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChangeNotifierProvider.value(value: model, child: screen),
        ),
      );
    }

    return FinanceScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 24,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 592),
            child: Row(
              children: [
                const Expanded(child: Text(
                  'spendwise', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                )),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: model.busy ? null : model.refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 21),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await model.refresh();
        },
        child: ListView(
          key: ValueKey(showAccounts),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
          children: [
            Row(
              children: [
                Expanded(child: Semantics(
                  header: true,
                  child: Text(
                    'Overview', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                )),
                Semantics(
                  container: true,
                  label: 'MYR · Stored on this device · Offline',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'ALL TIME · MYR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: 'Net worth ${myr(assets - debt)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net worth',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        myr(assets - debt),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Income',
                    semanticLabel: 'All-time income',
                    amount: data.incomeSen,
                    icon: Icons.south_west_rounded,
                    positive: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    label: 'Expenses',
                    semanticLabel: 'All-time expenses',
                    amount: data.expenseSen,
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _BalanceNote(label: 'Cash & banks', amount: assets),
                _BalanceNote(label: 'Card debt', amount: debt),
              ],
            ),
            if (model.busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (model.error != null) ErrorNotice(model.error!),
            const SizedBox(height: 28),
            _PanelSwitch(
              showAccounts: showAccounts,
              onChanged: (value) => setState(() => _showAccounts = value),
            ),
            const SizedBox(height: 16),
            if (showAccounts) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your accounts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: model.busy
                        ? null
                        : () {
                            setState(() => _showAccounts = true);
                            open(const AccountForm());
                          },
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add account'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (data.accounts.isEmpty)
                const _EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Your money starts here',
                  description:
                      'Add a bank account, cash wallet or credit card.',
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.accounts.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 70, right: 18),
                            child: Divider(),
                          ),
                        _AccountRow(
                          account: data.accounts[i],
                          onTap: model.busy
                              ? null
                              : () => open(
                                  AccountForm(account: data.accounts[i]),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
            ] else ...[
              if (data.operations.isEmpty)
                const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  description:
                      'Your income, expenses and transfers will appear here.',
                )
              else ...[
                for (var i = 0; i < data.operations.length; i++) ...[
                  if (i == 0 ||
                      !_sameDay(
                        data.operations[i - 1].recordedAt,
                        data.operations[i].recordedAt,
                      ))
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        _dayLabel(data.operations[i].recordedAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  _ActivityRow(
                    operation: data.operations[i],
                    accounts: data.accounts,
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          disabledElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: model.busy || data.accounts.isEmpty
              ? null
              : () => open(const TransactionForm()),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Transaction',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.semanticLabel,
    required this.amount,
    required this.icon,
    this.positive = false,
  });
  final String label;
  final String semanticLabel;
  final int amount;
  final IconData icon;
  final bool positive;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = positive
        ? Color(dark ? 0xffa3d3b4 : 0xff4c7560)
        : colors.onSurfaceVariant;
    return Semantics(
      container: true,
      label: '$semanticLabel ${myr(amount)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: tone),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                myr(amount),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceNote extends StatelessWidget {
  const _BalanceNote({required this.label, required this.amount});
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Text(
    '$label ${myr(amount)}',
    style: TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, this.onTap});
  final Account account;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          switch (account.type) {
            AccountType.bank => Icons.account_balance_outlined,
            AccountType.cash => Icons.account_balance_wallet_outlined,
            AccountType.creditCard => Icons.credit_card_rounded,
          },
          size: 19,
          color: colors.onSurface,
        ),
      ),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${accountLabel(account.type)}${account.isLiability ? ' · Amount owed' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
      ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 380 ? 100 : 150,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            myr(account.balanceSen),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.operation, required this.accounts});
  final AuditOperation operation;
  final List<Account> accounts;
  @override
  Widget build(BuildContext context) {
    final command = operation.command;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final income = command.kind == OperationKind.income;
    final spending =
        command.kind == OperationKind.expense ||
        command.kind == OperationKind.purchase;
    final tone = income
        ? Color(dark ? 0xffa3d3b4 : 0xff4c7560)
        : colors.onSurface;
    final accountName = accounts
        .firstWhere((a) => a.id == command.accountId)
        .name;
    final otherName = command.otherAccountId == null
        ? null
        : accounts.firstWhere((a) => a.id == command.otherAccountId).name;
    final local = operation.recordedAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            switch (command.kind) {
              OperationKind.income => Icons.south_west_rounded,
              OperationKind.expense => Icons.north_east_rounded,
              OperationKind.purchase => Icons.shopping_bag_outlined,
              OperationKind.transfer => Icons.swap_horiz_rounded,
              OperationKind.repayment => Icons.credit_score_outlined,
              OperationKind.opening => Icons.account_balance_wallet_outlined,
            },
            size: 18,
            color: tone,
          ),
        ),
        title: Text(
          command.note.isEmpty ? operationLabel(command.kind) : command.note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${operationLabel(command.kind)} · $accountName${otherName == null ? '' : ' → $otherName'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
        ),
        trailing: SizedBox(
          width: MediaQuery.sizeOf(context).width < 380 ? 100 : 130,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${income
                      ? '+'
                      : spending
                      ? '−'
                      : ''}${myr(command.amountSen)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Ledger details',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Reference: ${command.id}',
            excludeSemantics: true,
            child: SelectableText(
              'Reference: ${command.id}',
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
          ),
          for (final posting in operation.postings)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                accounts.firstWhere((a) => a.id == posting.accountId).name,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text(
                'Account: ${posting.accountId}',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: Text(
                '${posting.deltaSen >= 0 ? '+' : ''}${myr(posting.deltaSen)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String _dayLabel(DateTime value) {
  final date = value.toLocal();
  final now = DateTime.now();
  if (_sameDay(date, now)) return 'Today';
  if (_sameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _PanelSwitch extends StatelessWidget {
  const _PanelSwitch({required this.showAccounts, required this.onChanged});
  final bool showAccounts;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget tab(String label, bool accounts) => Expanded(
      child: Semantics(
        selected: showAccounts == accounts,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: showAccounts == accounts
                ? colors.primary
                : Colors.transparent,
            foregroundColor: showAccounts == accounts
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => onChanged(accounts),
          child: Text(label),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          tab('Activity', false),
          const SizedBox(width: 4),
          tab('Accounts', true),
        ],
      ),
    );
  }
}
