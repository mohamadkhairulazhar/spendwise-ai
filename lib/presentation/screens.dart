import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'finance_controller.dart';

String myr(int sen) =>
    'RM ${sen < 0 ? '-' : ''}${sen.abs() ~/ 100}.${(sen.abs() % 100).toString().padLeft(2, '0')}';
String accountLabel(AccountType type) => switch (type) {
  AccountType.bank => 'Bank account',
  AccountType.cash => 'Cash wallet',
  AccountType.creditCard => 'Credit card',
};
String operationLabel(OperationKind kind) => switch (kind) {
  OperationKind.opening => 'Opening balance',
  OperationKind.income => 'Income',
  OperationKind.expense => 'Expense',
  OperationKind.transfer => 'Transfer',
  OperationKind.purchase => 'Card purchase',
  OperationKind.repayment => 'Card repayment',
};

class FinanceHome extends StatelessWidget {
  const FinanceHome({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<FinanceController>();
    final data = model.snapshot;
    final assets = data.accounts
        .where((a) => !a.isLiability)
        .fold(0, (s, a) => s + a.balanceSen);
    final debt = data.accounts
        .where((a) => a.isLiability)
        .fold(0, (s, a) => s + a.balanceSen);
    return FinanceScaffold(
      appBar: AppBar(
        title: const Text('SpendWise AI'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: model.busy ? null : model.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await model.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('MYR · Stored on this device · Offline'),
            if (model.busy) const LinearProgressIndicator(),
            if (model.error != null)
              Text(
                model.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net worth ${myr(assets - debt)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Cash & banks ${myr(assets)}   •   Card debt ${myr(debt)}',
                    ),
                    Text('All-time income ${myr(data.incomeSen)}'),
                    Text('All-time expenses ${myr(data.expenseSen)}'),
                  ],
                ),
              ),
            ),
            Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
            if (data.accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Add a bank account, cash wallet or credit card to begin.',
                ),
              ),
            for (final account in data.accounts)
              Card(
                child: ListTile(
                  title: Text(account.name),
                  subtitle: Text(
                    '${accountLabel(account.type)}${account.isLiability ? ' · Amount owed' : ''}',
                  ),
                  trailing: Text(myr(account.balanceSen)),
                  onTap: model.busy
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
              ),
            OutlinedButton.icon(
              onPressed: model.busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: model,
                          child: const AccountForm(),
                        ),
                      ),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
            const SizedBox(height: 16),
            Text(
              'Audit history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.operations.isEmpty) const Text('No operations yet.'),
            for (final op in data.operations)
              ExpansionTile(
                title: Text(
                  '${operationLabel(op.command.kind)} · ${myr(op.command.amountSen)}',
                ),
                subtitle: Text(
                  '${op.recordedAt.toLocal()}${op.command.note.isEmpty ? '' : '\n${op.command.note}'}',
                ),
                children: [
                  SelectableText('Reference: ${op.command.id}'),
                  for (final posting in op.postings)
                    ListTile(
                      title: Text(
                        data.accounts
                            .firstWhere((a) => a.id == posting.accountId)
                            .name,
                      ),
                      subtitle: Text('Account: ${posting.accountId}'),
                      trailing: Text(
                        '${posting.deltaSen >= 0 ? '+' : ''}${myr(posting.deltaSen)}',
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: model.busy || data.accounts.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: model,
                    child: const TransactionForm(),
                  ),
                ),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
    );
  }
}

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, this.account});
  final Account? account;
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _opening = TextEditingController(text: '0.00');
  AccountType _type = AccountType.bank;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.account?.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FinanceController>();
    return FinanceScaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Add account' : 'Rename account'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Account name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name.' : null,
            ),
            if (widget.account == null) ...[
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Account type'),
                items: AccountType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(accountLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: model.busy
                    ? null
                    : (t) => setState(() {
                        _type = t!;
                      }),
              ),
              TextFormField(
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _type == AccountType.creditCard
                      ? 'Opening debt (MYR)'
                      : 'Opening balance (MYR)',
                ),
                validator: (v) => validateAmount(v, allowZero: true),
              ),
              const Text(
                'Opening balances are audited and cannot be edited. Card opening debt is not an expense.',
              ),
            ],
            if (model.error != null) Text(model.error!),
            FilledButton(
              onPressed: model.busy
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      final success = widget.account == null
                          ? await model.createAccount(
                              _name.text,
                              _type,
                              Money.parse(_opening.text),
                            )
                          : await model.renameAccount(
                              widget.account!.id,
                              _name.text,
                            );
                      if (context.mounted && success) Navigator.pop(context);
                    },
              child: Text(model.busy ? 'Saving…' : 'Save account'),
            ),
          ],
        ),
      ),
    );
  }
}

String? validateAmount(String? value, {bool allowZero = false}) {
  try {
    final amount = Money.parse(value ?? '');
    if ((!allowZero && amount == 0) || amount > Money.maxSen) {
      return 'Enter a positive MYR amount within the limit.';
    }
    return null;
  } on FormatException catch (e) {
    return e.message;
  }
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key});
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  // Stable for this form: retries cannot create duplicate ledger entries.
  final _operationId = const Uuid().v4();
  OperationKind _kind = OperationKind.expense;
  String? _source;
  String? _destination;
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FinanceController>();
    final paired =
        _kind == OperationKind.transfer || _kind == OperationKind.repayment;
    final accounts = model.snapshot.accounts;
    final sources = accounts
        .where(
          (a) =>
              _kind == OperationKind.purchase ? a.isLiability : !a.isLiability,
        )
        .toList();
    final destinations = accounts
        .where(
          (a) =>
              a.id != _source &&
              (_kind == OperationKind.repayment
                  ? a.isLiability
                  : !a.isLiability),
        )
        .toList();
    return FinanceScaffold(
      appBar: AppBar(title: const Text('New transaction')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<OperationKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Transaction type'),
              items: OperationKind.values
                  .where((k) => k != OperationKind.opening)
                  .map(
                    (k) => DropdownMenuItem(
                      value: k,
                      child: Text(operationLabel(k)),
                    ),
                  )
                  .toList(),
              onChanged: model.busy
                  ? null
                  : (value) => setState(() {
                      _kind = value!;
                      _source = null;
                      _destination = null;
                    }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('source-$_kind'),
              initialValue: _source,
              decoration: InputDecoration(
                labelText: paired ? 'From bank / cash' : 'Account',
              ),
              items: sources
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              validator: (v) => v == null
                  ? 'Choose an account (add one first if needed).'
                  : null,
              onChanged: model.busy
                  ? null
                  : (value) => setState(() {
                      _source = value;
                      _destination = null;
                    }),
            ),
            if (paired)
              DropdownButtonFormField<String>(
                key: ValueKey('destination-$_kind-$_source'),
                initialValue: _destination,
                decoration: InputDecoration(
                  labelText: _kind == OperationKind.repayment
                      ? 'Credit card to repay'
                      : 'To bank / cash',
                ),
                items: destinations
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                validator: (v) => v == null ? 'Choose a destination.' : null,
                onChanged: model.busy
                    ? null
                    : (v) => setState(() {
                        _destination = v;
                      }),
              ),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (MYR)',
                hintText: '12.50',
              ),
              validator: validateAmount,
            ),
            TextFormField(
              controller: _note,
              maxLength: 240,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_kind == OperationKind.repayment)
              const Text(
                'Reduces cash and debt. Does not add another expense.',
              ),
            if (_kind == OperationKind.transfer)
              const Text(
                'Moves your money. Does not count as income or expense.',
              ),
            if (_kind == OperationKind.purchase)
              const Text('Adds an expense and card debt. Cash is unchanged.'),
            if (model.error != null) Text(model.error!),
            FilledButton(
              onPressed: model.busy
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      final success = await model.record(
                        LedgerCommand(
                          id: _operationId,
                          kind: _kind,
                          amountSen: Money.parse(_amount.text),
                          accountId: _source!,
                          otherAccountId: paired ? _destination : null,
                          note: _note.text,
                        ),
                      );
                      if (context.mounted && success) Navigator.pop(context);
                    },
              child: Text(model.busy ? 'Saving…' : 'Record transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the demo label inside the active route's accessibility tree.
class FinanceScaffold extends StatelessWidget {
  const FinanceScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: Column(
      children: [
        if (const bool.fromEnvironment('SPENDWISE_DEMO'))
          Material(
            color: Colors.amber.shade100,
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'SYNTHETIC DEMO · Invented MYR data · Do not enter real financial information',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        Expanded(child: body),
      ],
    ),
    floatingActionButton: floatingActionButton,
  );
}
