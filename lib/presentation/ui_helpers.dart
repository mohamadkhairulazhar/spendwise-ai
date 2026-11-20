import '../domain/ledger.dart';

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
