import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Resolve assets against the document path, including GitHub Pages' repository
// subdirectory. The worker uses IndexedDB, without COOP/COEP headers or OPFS.
final DatabaseFactory platformDatabaseFactory = createDatabaseFactoryFfiWeb(
  options: SqfliteFfiWebOptions(
    sqlite3WasmUri: Uri.base.resolve('sqlite3.wasm'),
    sharedWorkerUri: Uri.base.resolve('sqflite_sw.js'),
    indexedDbName: 'spendwise_demo_sqlite',
  ),
);
