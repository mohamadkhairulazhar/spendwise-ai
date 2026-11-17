import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/finance_repository.dart';
import '../domain/ledger.dart';

class FinanceController extends ChangeNotifier {
  FinanceController(this.repository);
  final FinanceRepository repository;
  LedgerSnapshot snapshot = const LedgerSnapshot([], []);
  bool busy = false;
  String? error;

  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on LedgerException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Could not access local data. Retry; no partial transaction is saved.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> refresh() => _run(() async { snapshot = await repository.load(); });

  Future<void> _reloadAfterWrite() async {
    try { snapshot = await repository.load(); } catch (_) {
      error = 'Saved locally. Could not refresh the view; tap Refresh before recording more.';
    }
  }

  Future<bool> createAccount(String name, AccountType type, int openingSen) => _run(() async {
    await repository.createAccount(id: const Uuid().v4(), operationId: const Uuid().v4(),
      name: name, type: type, openingSen: openingSen);
    await _reloadAfterWrite();
  });

  Future<bool> renameAccount(String id, String name) => _run(() async {
    await repository.renameAccount(id, name);
    await _reloadAfterWrite();
  });

  Future<bool> record(LedgerCommand command) => _run(() async {
    await repository.record(command);
    await _reloadAfterWrite();
  });
}
