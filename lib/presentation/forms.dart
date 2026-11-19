import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'app_chrome.dart';
import 'finance_controller.dart';
import 'ui_helpers.dart';

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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Account name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name.' : null,
            ),
            const SizedBox(height: 12),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 14),
              const Text('Opening balances are recorded once. For cards, enter the amount you owe, not your credit limit.'),
            ],
            if (model.error != null) ErrorNotice(model.error!),
            const SizedBox(height: 24),
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            TextFormField(
              controller: _amount,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w600, letterSpacing: -1.5),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (MYR)',
                hintText: '0.00',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 24),
              ),
              validator: validateAmount,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
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
            if (paired) const SizedBox(height: 16),
            if (paired) DropdownButtonFormField<String>(
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
            const SizedBox(height: 16),
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
            if (model.error != null) ErrorNotice(model.error!),
            const SizedBox(height: 24),
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

