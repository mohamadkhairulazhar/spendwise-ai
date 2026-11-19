import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise_ai/domain/ledger.dart';
import 'package:spendwise_ai/domain/money.dart';
import 'package:spendwise_ai/presentation/app_theme.dart';
import 'package:spendwise_ai/presentation/finance_controller.dart';
import 'package:spendwise_ai/presentation/screens.dart';

import 'widget_test.dart' show FakeRepository;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'overview and entry fit a narrow ${brightness.name} device with larger text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final controller = FinanceController(FakeRepository())
          ..snapshot = const LedgerSnapshot([
            Account(
              'bank',
              'A long synthetic bank account name',
              AccountType.bank,
              Money.maxSen,
            ),
            Account(
              'card',
              'A long synthetic credit card name',
              AccountType.creditCard,
              12000,
            ),
          ], []);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: SpendWiseTheme.light,
              darkTheme: SpendWiseTheme.dark,
              themeMode: ThemeMode.system,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const FinanceHome(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(FinanceHome))).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull);
        await Scrollable.ensureVisible(tester.element(find.text('Accounts')), alignment: 0.35);
        await tester.tap(find.text('Accounts'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Transaction'));
        await tester.pumpAndSettle();
        expect(find.text('New transaction'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Switching the system appearance updates the same live route.
        final next = brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        tester.platformDispatcher.platformBrightnessTestValue = next;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(TransactionForm))).brightness,
          next,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
