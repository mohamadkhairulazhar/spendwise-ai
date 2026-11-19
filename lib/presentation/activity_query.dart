import '../domain/ledger.dart';
import 'ui_helpers.dart';

enum ActivityGrouping { day, month, year }

class ActivityGroup {
  const ActivityGroup(this.period, this.operations);
  final DateTime period;
  final List<AuditOperation> operations;
}

/// Read-only projection of the ledger. Both sides of paired operations belong
/// in account history; postings are the authority for account participation.
List<AuditOperation> filterActivity(
  List<AuditOperation> operations,
  List<Account> accounts,
  String query, {
  String? accountId,
}) {
  final terms = _normalize(query).split(' ').where((term) => term.isNotEmpty);
  final names = {for (final account in accounts) account.id: account};
  return List.unmodifiable(
    operations.where((operation) {
      if (accountId != null &&
          !operation.postings.any(
            (posting) => posting.accountId == accountId,
          )) {
        return false;
      }
      final command = operation.command;
      final date = operation.recordedAt.toLocal();
      final text = _normalize(
        [
          command.note,
          command.id,
          operationLabel(command.kind),
          myr(command.amountSen),
          date.toIso8601String(),
          '${date.day} ${activityMonths[date.month - 1]} ${date.year}',
          for (final posting in operation.postings) ...[
            posting.accountId,
            names[posting.accountId]?.name ?? '',
            if (names.containsKey(posting.accountId))
              accountLabel(names[posting.accountId]!.type),
            myr(posting.deltaSen),
          ],
        ].join(' '),
      );
      return terms.every(text.contains);
    }),
  );
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\brm\s*(?=-?\d)'), 'rm ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Calendar periods use device-local time. Keep the ledger's sequence order
/// inside each period, including operations with identical timestamps.
List<ActivityGroup> groupActivity(
  List<AuditOperation> operations,
  ActivityGrouping grouping,
) {
  final groups = <DateTime, List<AuditOperation>>{};
  for (final operation in operations) {
    final date = operation.recordedAt.toLocal();
    final period = DateTime(
      date.year,
      grouping == ActivityGrouping.year ? 1 : date.month,
      grouping == ActivityGrouping.day ? date.day : 1,
    );
    (groups[period] ??= []).add(operation);
  }
  final periods = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return List.unmodifiable([
    for (final period in periods)
      ActivityGroup(period, List.unmodifiable(groups[period]!)),
  ]);
}

String activityGroupLabel(
  DateTime period,
  ActivityGrouping grouping, {
  DateTime? now,
}) {
  if (grouping == ActivityGrouping.year) return '${period.year}';
  final month = activityMonths[period.month - 1];
  if (grouping == ActivityGrouping.month) return '$month ${period.year}';
  final today = (now ?? DateTime.now()).toLocal();
  final day = DateTime(today.year, today.month, today.day);
  if (period == day) return 'Today';
  if (period == DateTime(today.year, today.month, today.day - 1)) {
    return 'Yesterday';
  }
  return '${period.day} $month ${period.year}';
}

const activityMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
