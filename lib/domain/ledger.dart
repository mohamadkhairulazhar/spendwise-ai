import 'money.dart';

enum AccountType { bank, cash, creditCard }
enum OperationKind { opening, income, expense, transfer, purchase, repayment }

class LedgerException implements Exception {
  const LedgerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Account {
  const Account(this.id, this.name, this.type, this.balanceSen);
  final String id;
  final String name;
  final AccountType type;
  /// Positive for assets held or credit card debt owed.
  final int balanceSen;
  bool get isLiability => type == AccountType.creditCard;
}

class LedgerCommand {
  const LedgerCommand({
    required this.id,
    required this.kind,
    required this.amountSen,
    required this.accountId,
    this.otherAccountId,
    this.note = '',
  });
  final String id;
  final OperationKind kind;
  final int amountSen;
  final String accountId;
  final String? otherAccountId;
  final String note;
}

class Posting {
  const Posting(this.accountId, this.deltaSen);
  final String accountId;
  final int deltaSen;
}

class AuditOperation {
  const AuditOperation(this.command, this.recordedAt, this.postings);
  final LedgerCommand command;
  final DateTime recordedAt;
  final List<Posting> postings;
}

class LedgerSnapshot {
  const LedgerSnapshot(this.accounts, this.operations);
  final List<Account> accounts;
  final List<AuditOperation> operations;
  int get incomeSen => _total({OperationKind.income});
  int get expenseSen => _total({OperationKind.expense, OperationKind.purchase});
  int _total(Set<OperationKind> kinds) => operations
      .where((e) => kinds.contains(e.command.kind))
      .fold(0, (sum, e) => sum + e.command.amountSen);
  int get netWorthSen => accounts.fold(
      0, (sum, a) => sum + (a.isLiability ? -a.balanceSen : a.balanceSen));
}

/// Pure, deterministic rules. Storage calls this inside its write transaction.
abstract final class Ledger {
  static List<Posting> plan(LedgerCommand command, List<Account> accounts) {
    if (command.id.trim().isEmpty || command.note.length > 240) {
      throw const LedgerException('Invalid reference or note (maximum 240 characters).');
    }
    final opening = command.kind == OperationKind.opening;
    if (command.amountSen < (opening ? 0 : 1) ||
        command.amountSen > Money.maxSen) {
      throw const LedgerException('Enter a valid positive amount in sen.');
    }
    Account find(String? id) => accounts.firstWhere((a) => a.id == id,
        orElse: () => throw const LedgerException('Account does not exist.'));
    final account = find(command.accountId);
    final paired = command.kind == OperationKind.transfer ||
        command.kind == OperationKind.repayment;
    if (!paired && command.otherAccountId != null) {
      throw const LedgerException('This operation takes one account.');
    }
    final other = paired ? find(command.otherAccountId) : null;
    if (paired && account.id == other!.id) {
      throw const LedgerException('Choose two different accounts.');
    }
    void requireCash(Account a) {
      if (a.isLiability) throw const LedgerException('Choose a bank or cash account.');
    }
    final amount = command.amountSen;
    final List<Posting> postings;
    switch (command.kind) {
      case OperationKind.opening:
        if (account.balanceSen != 0) {
          throw const LedgerException('Opening balance requires a new account.');
        }
        postings = [Posting(account.id, amount)];
      case OperationKind.income:
        requireCash(account);
        postings = [Posting(account.id, amount)];
      case OperationKind.expense:
        requireCash(account);
        postings = [Posting(account.id, -amount)];
      case OperationKind.purchase:
        if (!account.isLiability) {
          throw const LedgerException('Choose a credit card for a purchase.');
        }
        postings = [Posting(account.id, amount)];
      case OperationKind.transfer:
        requireCash(account);
        requireCash(other!);
        postings = [Posting(account.id, -amount), Posting(other.id, amount)];
      case OperationKind.repayment:
        requireCash(account);
        if (!other!.isLiability) {
          throw const LedgerException('Repayments must go to a credit card.');
        }
        postings = [Posting(account.id, -amount), Posting(other.id, -amount)];
    }
    for (final posting in postings) {
      final balance = find(posting.accountId).balanceSen + posting.deltaSen;
      if (balance < 0 || balance > Money.maxSen) {
        throw const LedgerException('Insufficient balance, excess repayment, or balance limit exceeded.');
      }
    }
    return List.unmodifiable(postings);
  }
}
