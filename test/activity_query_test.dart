import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_ai/domain/ledger.dart';
import 'package:spendwise_ai/presentation/activity_query.dart';

const accounts = [
  Account('bank', 'Synthetic Bank', AccountType.bank, 100000),
  Account('wallet', 'Synthetic Wallet', AccountType.cash, 20000),
  Account('card', 'Synthetic Card', AccountType.creditCard, 5000),
];

AuditOperation audit(String id, DateTime date, OperationKind kind, String from,
    {String? to, String note = '', int amount = 100}) {
  final command = LedgerCommand(id: id, kind: kind, amountSen: amount,
    accountId: from, otherAccountId: to, note: note);
  return AuditOperation(command, date.toUtc(), kind == OperationKind.opening
    ? [Posting(from, amount)] : Ledger.plan(command, accounts));
}

void main() {
  final sameTime = DateTime(2026, 1, 2, 12);
  final operations = [
    audit('repay-ref', sameTime, OperationKind.repayment, 'bank', to: 'card',
      note: 'Synthetic payment', amount: 1234),
    audit('purchase-ref', sameTime, OperationKind.purchase, 'card',
      note: 'Synthetic groceries'),
    audit('transfer-ref', DateTime(2026, 1, 1), OperationKind.transfer, 'bank',
      to: 'wallet', note: 'Synthetic top-up'),
    audit('expense-ref', DateTime(2025, 12, 31, 23, 59), OperationKind.expense,
      'wallet', note: 'Synthetic mamak lunch'),
    audit('income-ref', DateTime(2025, 12, 1), OperationKind.income, 'bank',
      note: 'Synthetic salary'),
    audit('opening-ref', DateTime(2024, 12, 31), OperationKind.opening, 'wallet'),
  ];
  List<String> ids(Iterable<AuditOperation> items) =>
      items.map((e) => e.command.id).toList();

  test('account history includes both transfer and repayment sides and openings', () {
    expect(ids(filterActivity(operations, accounts, '', accountId: 'bank')),
      ['repay-ref', 'transfer-ref', 'income-ref']);
    expect(ids(filterActivity(operations, accounts, '', accountId: 'wallet')),
      ['transfer-ref', 'expense-ref', 'opening-ref']);
    expect(ids(filterActivity(operations, accounts, '', accountId: 'card')),
      ['repay-ref', 'purchase-ref']);
    expect(filterActivity(operations, accounts, '', accountId: 'unknown'), isEmpty);
    expect(ids(operations).first, 'repay-ref');
  });

  test('search combines case-insensitive terms across notes, accounts, type, money, date and reference', () {
    final cases = {
      '  MAMAK   LUNCH ': ['expense-ref'],
      'bank wallet': ['transfer-ref'],
      'credit card groceries': ['purchase-ref'],
      'repayment RM12.34': ['repay-ref'],
      '-12.34': ['repay-ref'],
      '2025-12-31': ['expense-ref'],
      'december 2025 salary': ['income-ref'],
      'repay-ref': ['repay-ref'],
      'unmatched synthetic text': <String>[],
    };
    for (final entry in cases.entries) {
      expect(ids(filterActivity(operations, accounts, entry.key)), entry.value,
        reason: entry.key);
    }
    expect(ids(filterActivity(operations, accounts, 'wallet', accountId: 'bank')),
      ['transfer-ref']);
    expect(filterActivity(operations, accounts, 'salary', accountId: 'card'), isEmpty);
    expect(ids(filterActivity(operations, accounts, '   ')), ids(operations));
  });

  test('calendar grouping separates days, months and years while preserving ledger tie order', () {
    final days = groupActivity(operations, ActivityGrouping.day);
    expect(days.map((e) => e.period), [DateTime(2026, 1, 2), DateTime(2026, 1, 1),
      DateTime(2025, 12, 31), DateTime(2025, 12, 1), DateTime(2024, 12, 31)]);
    expect(ids(days.first.operations), ['repay-ref', 'purchase-ref']);
    final months = groupActivity(operations, ActivityGrouping.month);
    expect(months.map((e) => e.period), [DateTime(2026, 1), DateTime(2025, 12),
      DateTime(2024, 12)]);
    expect(ids(months[1].operations), ['expense-ref', 'income-ref']);
    final years = groupActivity(operations, ActivityGrouping.year);
    expect(years.map((e) => e.period.year), [2026, 2025, 2024]);
    expect(ids(years.first.operations), ['repay-ref', 'purchase-ref', 'transfer-ref']);
    expect(groupActivity([], ActivityGrouping.year), isEmpty);
    expect(() => days.first.operations.clear(), throwsUnsupportedError);
    expect(ids(operations).first, 'repay-ref');
  });

  test('group labels use local calendar dates across a year boundary', () {
    final now = DateTime(2026, 1, 1, 0, 1);
    expect(activityGroupLabel(DateTime(2026, 1, 1), ActivityGrouping.day, now: now), 'Today');
    expect(activityGroupLabel(DateTime(2025, 12, 31), ActivityGrouping.day, now: now), 'Yesterday');
    expect(activityGroupLabel(DateTime(2025, 12, 1), ActivityGrouping.day, now: now), '1 December 2025');
    expect(activityGroupLabel(DateTime(2026, 1), ActivityGrouping.month), 'January 2026');
    expect(activityGroupLabel(DateTime(2025), ActivityGrouping.year), '2025');
  });
}
