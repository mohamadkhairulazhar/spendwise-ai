import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendwise_ai/data/migrations.dart';
import 'package:spendwise_ai/data/sqlite_finance_repository.dart';
import 'package:spendwise_ai/domain/ledger.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String dbPath;
  late SqliteFinanceRepository repository;
  final clock = DateTime.utc(2026, 1, 1);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spendwise_test_');
    dbPath = path.join(directory.path, 'test.db');
    repository = await SqliteFinanceRepository.open(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
      clock: () => clock,
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  Future<void> account(String id, AccountType type, int balance) =>
      repository.createAccount(
        id: id,
        operationId: 'opening-$id',
        name: 'Synthetic $id',
        type: type,
        openingSen: balance,
      );
  Future<void> record(
    String id,
    OperationKind kind,
    int amount,
    String from, [
    String? to,
  ]) => repository.record(
    LedgerCommand(
      id: id,
      kind: kind,
      amountSen: amount,
      accountId: from,
      otherAccountId: to,
    ),
  );

  test(
    'complete synthetic lifecycle is exact, auditable and survives restart',
    () async {
      await account('bank', AccountType.bank, 100000);
      await account('cash', AccountType.cash, 0);
      await account('card', AccountType.creditCard, 5000);
      await record('salary', OperationKind.income, 10000, 'bank');
      await record('transfer', OperationKind.transfer, 20000, 'bank', 'cash');
      await record('lunch', OperationKind.expense, 1234, 'cash');
      await record('purchase', OperationKind.purchase, 3000, 'card');
      await record('repay', OperationKind.repayment, 4000, 'bank', 'card');
      await repository.renameAccount('cash', 'Synthetic Pocket');
      await repository.close();
      repository = await SqliteFinanceRepository.open(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      final data = await repository.load();
      expect(
        {for (final a in data.accounts) a.id: a.balanceSen},
        {'bank': 86000, 'cash': 18766, 'card': 4000},
      );
      expect(data.incomeSen, 10000);
      expect(
        data.expenseSen,
        4234,
      ); // Purchase once; repayment and transfers excluded.
      expect(data.operations, hasLength(8));
      expect(
        data.operations.every(
          (op) => op.recordedAt == clock && op.postings.isNotEmpty,
        ),
        isTrue,
      );
      expect(
        data.accounts.singleWhere((a) => a.id == 'cash').name,
        'Synthetic Pocket',
      );
      expect(data.operations.first.command.id, 'repay');
    },
  );
  test(
    'duplicate reference and failed operations leave no partial changes',
    () async {
      await account('bank', AccountType.bank, 1000);
      await account('cash', AccountType.cash, 0);
      await record('once', OperationKind.transfer, 100, 'bank', 'cash');
      await expectLater(
        record('once', OperationKind.transfer, 100, 'bank', 'cash'),
        throwsA(anything),
      );
      await expectLater(
        record('bad', OperationKind.transfer, 901, 'bank', 'cash'),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        account('invalid', AccountType.cash, -1),
        throwsA(isA<LedgerException>()),
      );
      final data = await repository.load();
      expect(data.accounts, hasLength(2));
      expect(data.operations, hasLength(3));
      expect(data.accounts.singleWhere((a) => a.id == 'bank').balanceSen, 900);
      await expectLater(
        record('new-opening', OperationKind.opening, 2, 'cash'),
        throwsA(isA<LedgerException>()),
      );
    },
  );
  test('synthetic demo seeds once and preserves later changes', () async {
    await repository.seedSyntheticDemo();
    final first = await repository.load();
    expect(first.accounts, hasLength(3));
    expect(first.operations, hasLength(10));
    expect(first.incomeSen, 250000);
    expect(first.expenseSen, 11000);
    expect(first.netWorthSen, 549000);
    await repository.renameAccount('demo-cash', 'Synthetic Edited');
    await repository.seedSyntheticDemo();
    final reloaded = await repository.load();
    expect(reloaded.operations, hasLength(10));
    expect(reloaded.accounts.singleWhere((a) => a.id == 'demo-cash').name, 'Synthetic Edited');
  });

  test('failure inserting second transfer posting rolls back the first', () async {
    await account('bank', AccountType.bank, 1000);
    await account('cash', AccountType.cash, 0);
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    await db.execute("""CREATE TRIGGER synthetic_failure BEFORE INSERT ON postings
      WHEN NEW.account_id = 'cash' BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END""");
    await expectLater(record('atomic', OperationKind.transfer, 100, 'bank', 'cash'), throwsA(anything));
    final data = await repository.load();
    expect(data.operations, hasLength(2));
    expect(data.accounts.singleWhere((a) => a.id == 'bank').balanceSen, 1000);
  });

  test('concurrent spending cannot overdraw an account', () async {
    await account('bank', AccountType.bank, 1000);
    Future<bool> spend(String id) async {
      try {
        await record(id, OperationKind.expense, 700, 'bank');
        return true;
      } on LedgerException {
        return false;
      }
    }

    expect(
      await Future.wait([spend('a'), spend('b')]),
      containsAll([true, false]),
    );
    expect((await repository.load()).accounts.single.balanceSen, 300);
  });
  test(
    'migration v1 to v2 preserves balances and protects audit history',
    () async {
      await repository.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
      final old = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => Migrations.upgrade(db, 0, version),
        ),
      );
      await old.insert('accounts', {
        'id': 'old',
        'name': 'Synthetic Legacy',
        'type': 'cash',
        'created_at': clock.toIso8601String(),
      });
      await old.insert('operations', {
        'id': 'op',
        'kind': 'opening',
        'amount_sen': 12345,
        'account_id': 'old',
        'recorded_at': clock.toIso8601String(),
        'note': 'Opening balance',
      });
      await old.insert('postings', {
        'operation_id': 'op',
        'account_id': 'old',
        'delta_sen': 12345,
      });
      await old.close();
      repository = await SqliteFinanceRepository.open(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      expect((await repository.load()).accounts.single.balanceSen, 12345);
      final db = await databaseFactoryFfi.openDatabase(dbPath);
      expect(await db.getVersion(), 2);
      await expectLater(
        db.update('postings', {'delta_sen': 5}),
        throwsA(anything),
      );
      await expectLater(db.delete('operations'), throwsA(anything));
      await expectLater(
        db.insert('postings', {
          'operation_id': 'missing',
          'account_id': 'old',
          'delta_sen': 5,
        }),
        throwsA(anything),
      );
      // singleInstance shares the repository's handle; repository closes it in tearDown.
    },
  );
}
