import 'ledger.dart';

/// Invented fixtures only; no names or identifiers from real customers.
abstract final class DemoData {
  static const accounts = [
    Account('demo-bank', 'Synthetic Bank', AccountType.bank, 300000),
    Account('demo-cash', 'Synthetic Wallet', AccountType.cash, 20000),
    Account('demo-card', 'Synthetic Credit Card', AccountType.creditCard, 10000),
  ];
  static const commands = [
    LedgerCommand(id: 'demo-income', kind: OperationKind.income, amountSen: 250000,
      accountId: 'demo-bank', note: 'Synthetic monthly income'),
    LedgerCommand(id: 'demo-transfer', kind: OperationKind.transfer, amountSen: 15000,
      accountId: 'demo-bank', otherAccountId: 'demo-cash', note: 'Synthetic wallet top-up'),
    LedgerCommand(id: 'demo-expense', kind: OperationKind.expense, amountSen: 2500,
      accountId: 'demo-cash', note: 'Synthetic lunch'),
    LedgerCommand(id: 'demo-purchase', kind: OperationKind.purchase, amountSen: 8500,
      accountId: 'demo-card', note: 'Synthetic groceries'),
    LedgerCommand(id: 'demo-repayment', kind: OperationKind.repayment, amountSen: 10000,
      accountId: 'demo-bank', otherAccountId: 'demo-card', note: 'Synthetic card repayment'),
  ];
}
