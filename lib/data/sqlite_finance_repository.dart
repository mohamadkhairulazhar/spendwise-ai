import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/finance_repository.dart';
import '../domain/ledger.dart';
import 'migrations.dart';

class SqliteFinanceRepository implements FinanceRepository {
  SqliteFinanceRepository._(this._db, this._clock);
  final Database _db;
  final DateTime Function() _clock;

  static Future<SqliteFinanceRepository> open({
    DatabaseFactory? factory,
    String? databasePath,
    DateTime Function()? clock,
  }) async {
    final driver = factory ?? databaseFactory;
    final location = databasePath ?? path.join(await driver.getDatabasesPath(), 'spendwise.db');
    final db = await driver.openDatabase(location, options: OpenDatabaseOptions(
      version: Migrations.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => Migrations.upgrade(db, 0, version),
      onUpgrade: Migrations.upgrade,
      onDowngrade: (db, oldVersion, newVersion) async {
        throw const LedgerException('Database is newer than this app. Please update the app.');
      },
    ));
    return SqliteFinanceRepository._(db, clock ?? DateTime.now);
  }

  Future<List<Account>> _accounts(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''SELECT a.*, COALESCE(SUM(p.delta_sen),0) AS balance
      FROM accounts a LEFT JOIN postings p ON p.account_id = a.id
      GROUP BY a.id ORDER BY a.created_at, a.id''');
    return rows.map((r) => Account(r['id'] as String, r['name'] as String,
      AccountType.values.byName(r['type'] as String), r['balance'] as int)).toList();
  }

  @override
  Future<LedgerSnapshot> load() => _db.transaction((txn) async {
    final accounts = await _accounts(txn);
    final rows = await txn.query('operations', orderBy: 'sequence DESC');
    final postings = await txn.query('postings', orderBy: 'account_id');
    final operations = rows.map((r) => AuditOperation(LedgerCommand(
      id: r['id'] as String, kind: OperationKind.values.byName(r['kind'] as String),
      amountSen: r['amount_sen'] as int, accountId: r['account_id'] as String,
      otherAccountId: r['other_account_id'] as String?, note: r['note'] as String,
    ), DateTime.parse(r['recorded_at'] as String), postings
      .where((p) => p['operation_id'] == r['id'])
      .map((p) => Posting(p['account_id'] as String, p['delta_sen'] as int)).toList())).toList();
    return LedgerSnapshot(List.unmodifiable(accounts), List.unmodifiable(operations));
  });

  String _validateName(String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 60) {
      throw const LedgerException('Account name must contain 1–60 characters.');
    }
    return value;
  }

  @override
  Future<void> createAccount({required String id, required String operationId,
    required String name, required AccountType type, required int openingSen}) async {
    final cleanName = _validateName(name);
    if (id.trim().isEmpty) throw const LedgerException('Invalid account reference.');
    await _db.transaction((txn) async {
      await txn.insert('accounts', {'id': id, 'name': cleanName, 'type': type.name,
        'created_at': _clock().toUtc().toIso8601String()});
      await _record(txn, LedgerCommand(id: operationId, kind: OperationKind.opening,
        amountSen: openingSen, accountId: id, note: 'Opening balance'));
    });
  }

  @override
  Future<void> renameAccount(String id, String name) async {
    final count = await _db.update('accounts', {'name': _validateName(name)},
      where: 'id = ?', whereArgs: [id]);
    if (count != 1) throw const LedgerException('Account does not exist.');
  }

  @override
  Future<void> record(LedgerCommand command) async {
    if (command.kind == OperationKind.opening) {
      throw const LedgerException('Opening balances are only set when creating an account.');
    }
    await _db.transaction((txn) => _record(txn, command));
  }

  Future<void> _record(Transaction txn, LedgerCommand command) async {
    // Validation and both legs share the same SQLite write transaction.
    final postings = Ledger.plan(command, await _accounts(txn));
    await txn.insert('operations', {
      'id': command.id, 'kind': command.kind.name, 'amount_sen': command.amountSen,
      'account_id': command.accountId, 'other_account_id': command.otherAccountId,
      'note': command.note.trim(), 'recorded_at': _clock().toUtc().toIso8601String(),
    });
    for (final posting in postings) {
      await txn.insert('postings', {'operation_id': command.id,
        'account_id': posting.accountId, 'delta_sen': posting.deltaSen});
    }
  }

  @override
  Future<void> close() => _db.close();
}
