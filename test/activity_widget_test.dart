import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise_ai/domain/ledger.dart';
import 'package:spendwise_ai/presentation/activity_section.dart';
import 'package:spendwise_ai/presentation/finance_controller.dart';
import 'package:spendwise_ai/presentation/screens.dart';

import 'widget_test.dart' show FakeRepository;

void main() {
  const accounts = [
    Account('bank', 'Synthetic Bank', AccountType.bank, 9000),
    Account('wallet', 'Synthetic Wallet', AccountType.cash, 1000),
    Account('card', 'Synthetic Card', AccountType.creditCard, 500),
  ];
  final operations = [
    AuditOperation(
      const LedgerCommand(
        id: 'transfer-reference',
        kind: OperationKind.transfer,
        amountSen: 1000,
        accountId: 'bank',
        otherAccountId: 'wallet',
        note: 'Synthetic wallet top-up',
      ),
      DateTime(2026, 1, 2),
      const [Posting('bank', -1000), Posting('wallet', 1000)],
    ),
    AuditOperation(
      const LedgerCommand(
        id: 'repay-reference',
        kind: OperationKind.repayment,
        amountSen: 500,
        accountId: 'bank',
        otherAccountId: 'card',
        note: 'Synthetic card payment',
      ),
      DateTime(2025, 12, 31),
      const [Posting('bank', -500), Posting('card', -500)],
    ),
    AuditOperation(
      const LedgerCommand(
        id: 'purchase-reference',
        kind: OperationKind.purchase,
        amountSen: 1000,
        accountId: 'card',
        note: 'Synthetic groceries',
      ),
      DateTime(2025, 12, 30),
      const [Posting('card', 1000)],
    ),
  ];

  testWidgets(
    'activity search, clear and grouping retain correct audit entries',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivitySection(
                operations: operations,
                accounts: accounts,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('January 2026'), findsOneWidget);
      expect(find.text('December 2025'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'payment');
      await tester.pumpAndSettle();
      expect(find.text('1 entry'), findsOneWidget);
      expect(find.text('Synthetic wallet top-up'), findsNothing);
      expect(find.text('January 2026'), findsNothing);
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no synthetic match');
      await tester.pumpAndSettle();
      expect(find.text('0 entries'), findsOneWidget);
      expect(find.textContaining('No matching activity.'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('3 entries'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening an account shows only its postings and keeps rename accessible',
    (tester) async {
      final controller = FinanceController(FakeRepository())
        ..snapshot = LedgerSnapshot(accounts, operations);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: FinanceHome()),
        ),
      );
      await tester.ensureVisible(find.text('Accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Synthetic Wallet'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic Wallet'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountHistoryScreen), findsOneWidget);
      expect(find.text('Account history'), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
      expect(find.text('Synthetic wallet top-up'), findsOneWidget);
      expect(find.text('+RM 10.00'), findsOneWidget);
      expect(find.text('Synthetic card payment'), findsNothing);
      await tester.ensureVisible(find.text('Synthetic wallet top-up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic wallet top-up'));
      await tester.pumpAndSettle();
      expect(find.text('Reference: transfer-reference'), findsOneWidget);
      expect(find.text('Account: bank'), findsOneWidget);
      expect(find.text('Account: wallet'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'payment');
      await tester.pumpAndSettle();
      expect(find.text('0 entries'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'top-up');
      await tester.pumpAndSettle();
      expect(find.text('1 entry'), findsOneWidget);
      await tester.tap(find.byTooltip('Rename account'));
      await tester.pumpAndSettle();
      expect(find.text('Rename account'), findsOneWidget);
      expect(find.text('Synthetic Wallet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'card history shows debt increases and repayments with opposite signs',
    (tester) async {
      final controller = FinanceController(FakeRepository())
        ..snapshot = LedgerSnapshot(accounts, operations);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(
            home: AccountHistoryScreen(accountId: 'card'),
          ),
        ),
      );
      expect(find.text('Amount owed'), findsOneWidget);
      expect(find.text('2 entries'), findsOneWidget);
      expect(find.text('−RM 5.00'), findsOneWidget);
      expect(find.text('+RM 10.00'), findsOneWidget);
      expect(find.text('Synthetic wallet top-up'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
