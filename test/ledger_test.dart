import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_ai/domain/ledger.dart';
import 'package:spendwise_ai/domain/money.dart';

void main() {
  const accounts = [Account('bank', 'Synthetic Bank', AccountType.bank, 100000),
    Account('cash', 'Synthetic Wallet', AccountType.cash, 5000),
    Account('card', 'Synthetic Card', AccountType.creditCard, 20000)];
  LedgerCommand command(OperationKind kind, String account, {String? other, int amount = 1000}) =>
    LedgerCommand(id: 'test', kind: kind, amountSen: amount, accountId: account, otherAccountId: other);

  test('MYR parsing and boundaries are exact integer sen', () {
    expect(Money.parse('0.01'), 1);
    expect(Money.parse('12.5'), 1250);
    expect(Money.parse('9999999999.99'), Money.maxSen);
    expect(Money.parse('0'), 0);
    for (final invalid in ['1.001', '-1', '1e3', 'NaN', '1,000', '', '.1']) {
      expect(() => Money.parse(invalid), throwsFormatException);
    }
  });
  test('income and debit expenses change assets', () {
    expect(Ledger.plan(command(OperationKind.income, 'bank'), accounts).single.deltaSen, 1000);
    expect(Ledger.plan(command(OperationKind.expense, 'cash'), accounts).single.deltaSen, -1000);
  });
  test('card purchase adds only liability', () {
    final legs = Ledger.plan(command(OperationKind.purchase, 'card'), accounts);
    expect(legs.single.accountId, 'card');
    expect(legs.single.deltaSen, 1000);
  });
  test('repayment reduces cash and liability, transfer conserves assets', () {
    final repayment = Ledger.plan(command(OperationKind.repayment, 'bank', other: 'card'), accounts);
    expect(repayment.map((p) => p.deltaSen), [-1000, -1000]);
    final transfer = Ledger.plan(command(OperationKind.transfer, 'bank', other: 'cash'), accounts);
    expect(transfer.map((p) => p.deltaSen), [-1000, 1000]);
  });
  test('reject invalid topology, insufficient cash and over-repayments', () {
    for (final invalid in [
      command(OperationKind.income, 'card'), command(OperationKind.expense, 'card'),
      command(OperationKind.purchase, 'bank'), command(OperationKind.transfer, 'bank', other: 'card'),
      command(OperationKind.transfer, 'bank', other: 'bank'), command(OperationKind.transfer, 'bank'),
      command(OperationKind.repayment, 'bank', other: 'cash'),
      command(OperationKind.repayment, 'bank', other: 'card', amount: 20001),
      command(OperationKind.expense, 'cash', amount: 5001), command(OperationKind.expense, 'missing'),
      command(OperationKind.expense, 'cash', amount: 0), command(OperationKind.expense, 'cash', amount: -1),
      command(OperationKind.income, 'bank', amount: Money.maxSen),
      command(OperationKind.income, 'bank', other: 'cash'),
    ]) {
      expect(() => Ledger.plan(invalid, accounts), throwsA(isA<LedgerException>()));
    }
  });
  test('deterministic plans and opening zero', () {
    final cmd = command(OperationKind.transfer, 'bank', other: 'cash');
    expect(Ledger.plan(cmd, accounts).map((p) => '${p.accountId}:${p.deltaSen}'),
      Ledger.plan(cmd, accounts).map((p) => '${p.accountId}:${p.deltaSen}'));
    expect(Ledger.plan(command(OperationKind.opening, 'new', amount: 0),
      [const Account('new', 'New', AccountType.cash, 0)]).single.deltaSen, 0);
  });
}
