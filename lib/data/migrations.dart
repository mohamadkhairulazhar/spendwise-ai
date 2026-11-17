import 'package:sqflite/sqflite.dart';

/// Ordered, forward-only migrations. Never drop user data during an upgrade.
abstract final class Migrations {
  static const version = 2;
  static Future<void> upgrade(DatabaseExecutor db, int from, int to) async {
    if (from < 1 && to >= 1) {
      await db.execute('''CREATE TABLE accounts (
        id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
        type TEXT NOT NULL CHECK(type IN ('bank','cash','creditCard')),
        created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE operations (
        sequence INTEGER PRIMARY KEY AUTOINCREMENT,
        id TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL CHECK(kind IN ('opening','income','expense','transfer','purchase','repayment')),
        amount_sen INTEGER NOT NULL CHECK(typeof(amount_sen) = 'integer' AND amount_sen BETWEEN 0 AND 999999999999),
        account_id TEXT NOT NULL REFERENCES accounts(id),
        other_account_id TEXT REFERENCES accounts(id),
        note TEXT NOT NULL CHECK(length(note) <= 240), recorded_at TEXT NOT NULL,
        CHECK(kind = 'opening' OR amount_sen > 0))''');
      await db.execute('''CREATE TABLE postings (
        operation_id TEXT NOT NULL REFERENCES operations(id),
        account_id TEXT NOT NULL REFERENCES accounts(id),
        delta_sen INTEGER NOT NULL CHECK(typeof(delta_sen) = 'integer' AND abs(delta_sen) <= 999999999999),
        PRIMARY KEY(operation_id, account_id))''');
    }
    if (from < 2 && to >= 2) {
      await db.execute('CREATE INDEX postings_account ON postings(account_id)');
      await db.execute("CREATE UNIQUE INDEX one_opening_per_account ON operations(account_id) WHERE kind = 'opening'");
      for (final table in ['operations', 'postings']) {
        for (final action in ['UPDATE', 'DELETE']) {
          await db.execute('''CREATE TRIGGER ${table}_${action.toLowerCase()}_forbidden
            BEFORE $action ON $table BEGIN
            SELECT RAISE(ABORT, 'Ledger history is immutable'); END''');
        }
      }
      await db.execute('''CREATE TRIGGER account_identity_immutable
        BEFORE UPDATE OF id, type, created_at ON accounts BEGIN
        SELECT RAISE(ABORT, 'Account identity is immutable'); END''');
    }
  }
}
