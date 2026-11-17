import 'ledger.dart';

abstract interface class FinanceRepository {
  Future<LedgerSnapshot> load();
  Future<void> createAccount({required String id, required String operationId,
    required String name, required AccountType type, required int openingSen});
  Future<void> renameAccount(String id, String name);
  Future<void> record(LedgerCommand command);
  Future<void> close();
}
