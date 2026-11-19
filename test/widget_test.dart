import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise_ai/domain/finance_repository.dart';
import 'package:spendwise_ai/domain/ledger.dart';
import 'package:spendwise_ai/presentation/finance_controller.dart';
import 'package:spendwise_ai/presentation/screens.dart';

class FakeRepository implements FinanceRepository {
  String? savedName;
  bool fail = false;
  @override
  Future<LedgerSnapshot> load() async => const LedgerSnapshot([], []);
  @override
  Future<void> createAccount({
    required String id,
    required String operationId,
    required String name,
    required AccountType type,
    required int openingSen,
  }) async {
    if (fail) throw const LedgerException('Synthetic storage failure');
    savedName = name;
  }

  @override
  Future<void> record(LedgerCommand command) async {}
  @override
  Future<void> renameAccount(String id, String name) async {}
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('empty accounts screen gives an offline starting point', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FinanceController(FakeRepository()),
        child: const MaterialApp(home: FinanceHome()),
      ),
    );
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(find.text('Activity')), alignment: 0.35);
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions yet'), findsOneWidget);
  });
  testWidgets('account form validates input and displays repository errors', (
    tester,
  ) async {
    final repository = FakeRepository()..fail = true;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FinanceController(repository),
        child: const MaterialApp(home: AccountForm()),
      ),
    );
    await tester.ensureVisible(find.text('Save account'));
    await tester.tap(find.text('Save account'));
    await tester.pump();
    expect(find.text('Enter a name.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Synthetic Wallet',
    );
    await tester.enterText(find.byType(TextFormField).last, '1.005');
    await tester.ensureVisible(find.text('Save account'));
    await tester.tap(find.text('Save account'));
    await tester.pump();
    expect(repository.savedName, isNull);
    await tester.enterText(find.byType(TextFormField).last, '10.01');
    await tester.ensureVisible(find.text('Save account'));
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic storage failure'), findsOneWidget);
  });
  test('integer MYR display keeps trailing sen and negative net worth', () {
    expect(myr(1), 'RM 0.01');
    expect(myr(-10001), 'RM -100.01');
    expect(validateAmount('12.345'), isNotNull);
    expect(validateAmount('0'), isNotNull);
    expect(validateAmount('0', allowZero: true), isNull);
  });
}
