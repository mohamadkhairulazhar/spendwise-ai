import 'package:flutter/material.dart';

import '../domain/ledger.dart';
import 'activity_query.dart';
import 'ui_helpers.dart';

/// Shared searchable history for the overview and a single account.
class ActivitySection extends StatefulWidget {
  const ActivitySection({
    super.key,
    required this.operations,
    required this.accounts,
    this.accountId,
  });
  final List<AuditOperation> operations;
  final List<Account> accounts;
  final String? accountId;

  @override
  State<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<ActivitySection> {
  final _search = TextEditingController();
  ActivityGrouping _grouping = ActivityGrouping.day;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final matches = filterActivity(
      widget.operations,
      widget.accounts,
      _search.text,
      accountId: widget.accountId,
    );
    final groups = groupActivity(matches, _grouping);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search activity',
            helperText: 'Notes, accounts, type, amount, date or reference',
            helperMaxLines: 2,
            helperStyle: const TextStyle(fontSize: 11),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Group by',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final grouping in ActivityGrouping.values)
              Expanded(
                child: Semantics(
                  selected: _grouping == grouping,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: _grouping == grouping
                          ? colors.onSurface.withValues(alpha: 0.08)
                          : Colors.transparent,
                      foregroundColor: _grouping == grouping
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _grouping = grouping),
                    child: Text(switch (grouping) {
                      ActivityGrouping.day => 'Day',
                      ActivityGrouping.month => 'Month',
                      ActivityGrouping.year => 'Year',
                    }),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          liveRegion: true,
          child: Text(
            '${matches.length} ${matches.length == 1 ? 'entry' : 'entries'}',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Semantics(
              container: true,
              child: Text(
                _search.text.trim().isEmpty
                    ? 'No transactions yet'
                    : 'No matching activity. Try another search or clear the field.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Semantics(
              header: true,
              child: Text(
                activityGroupLabel(group.period, _grouping),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final operation in group.operations)
            _ActivityRow(
              key: ValueKey(operation.command.id),
              operation: operation,
              accounts: widget.accounts,
              accountId: widget.accountId,
            ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    super.key,
    required this.operation,
    required this.accounts,
    this.accountId,
  });
  final AuditOperation operation;
  final List<Account> accounts;
  final String? accountId;
  @override
  Widget build(BuildContext context) {
    final command = operation.command;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final income = command.kind == OperationKind.income;
    final spending =
        command.kind == OperationKind.expense ||
        command.kind == OperationKind.purchase;
    final tone = income
        ? Color(dark ? 0xffa3d3b4 : 0xff4c7560)
        : colors.onSurface;
    final accountName = accounts
        .firstWhere((a) => a.id == command.accountId)
        .name;
    final otherName = command.otherAccountId == null
        ? null
        : accounts.firstWhere((a) => a.id == command.otherAccountId).name;
    final movement = accountId == null
        ? null
        : operation.postings
              .firstWhere((posting) => posting.accountId == accountId)
              .deltaSen;
    final amount = movement == null
        ? '${income
              ? '+'
              : spending
              ? '−'
              : ''}${myr(command.amountSen)}'
        : '${movement >= 0 ? '+' : '−'}${myr(movement.abs())}';
    final local = operation.recordedAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            switch (command.kind) {
              OperationKind.income => Icons.south_west_rounded,
              OperationKind.expense => Icons.north_east_rounded,
              OperationKind.purchase => Icons.shopping_bag_outlined,
              OperationKind.transfer => Icons.swap_horiz_rounded,
              OperationKind.repayment => Icons.credit_score_outlined,
              OperationKind.opening => Icons.account_balance_wallet_outlined,
            },
            size: 18,
            color: tone,
          ),
        ),
        title: Text(
          command.note.isEmpty ? operationLabel(command.kind) : command.note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${operationLabel(command.kind)} · $accountName${otherName == null ? '' : ' → $otherName'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
        ),
        trailing: SizedBox(
          width: MediaQuery.sizeOf(context).width < 380 ? 100 : 130,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Ledger details',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: 'Reference: ${command.id}',
            excludeSemantics: true,
            child: SelectionArea(
              child: Text(
                'Reference: ${command.id}',
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recorded: ${local.toIso8601String()} (device time)',
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
          if (command.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${command.note}', style: const TextStyle(fontSize: 12)),
          ],
          for (final posting in operation.postings)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                accounts.firstWhere((a) => a.id == posting.accountId).name,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text(
                'Account: ${posting.accountId}',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: Text(
                '${posting.deltaSen >= 0 ? '+' : ''}${myr(posting.deltaSen)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
