import 'package:flutter/material.dart';

import '../data/backoffice_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/badge.dart';
import '../widgets/chips.dart';

/// Page « Issues » : client-reported issues (overflowing bins, missed
/// collections, illegal dumping, etc.) that the agency manager can review
/// and resolve.
class BoIssuesPage extends StatefulWidget {
  const BoIssuesPage({
    super.key,
    required this.store,
    this.desktop = false,
  });

  final BackofficeStore store;
  final bool desktop;

  @override
  State<BoIssuesPage> createState() => _BoIssuesPageState();
}

class _BoIssuesPageState extends State<BoIssuesPage> {
  String _filter = 'All';

  static const _labels = <String, String>{
    'open': 'Open',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
  };

  static const _statusColors = <String, Color>{
    'open': BackofficeTheme.red,
    'in_progress': BackofficeTheme.gold,
    'resolved': BackofficeTheme.green,
  };

  List<IssueModel> get _items {
    final all = widget.store.issues;
    if (_filter == 'All') return all;
    return all.where((i) => i.status == _filter.toLowerCase().replaceAll(' ', '_')).toList();
  }

  Future<void> _resolve(IssueModel issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Resolve Issue',
          style: BackofficeTheme.inter(16, weight: FontWeight.w700),
        ),
        content: Text(
          'Mark this issue as resolved?\n\n${issue.category}: ${issue.description}',
          style: BackofficeTheme.inter(13, color: BackofficeTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: BackofficeTheme.inter(13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Resolve',
              style: BackofficeTheme.inter(13, weight: FontWeight.w600, color: BackofficeTheme.green),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.store.resolveIssue(issue);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue marked as resolved'),
            backgroundColor: BackofficeTheme.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: BackofficeTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final items = _items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            BoChipRow(
              options: const ['All', 'Open', 'In Progress', 'Resolved'],
              selected: _filter,
              onSelect: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(text: 'No issues found')
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        widget.desktop ? 2 : 16,
                        0,
                        widget.desktop ? 2 : 16,
                        widget.desktop ? 24 : 110,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, i) => _card(context, items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, IssueModel issue) {
    final isOpen = issue.status == 'open';
    final isResolved = issue.status == 'resolved';
    final statusColor = _statusColors[issue.status] ?? BackofficeTheme.muted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BackofficeTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: category + status badge
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isOpen ? BackofficeTheme.redSoft : BackofficeTheme.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOpen ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 16,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BackofficeTheme.inter(13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${issue.clientName} · ${issue.createdAt}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BackofficeTheme.inter(11, color: BackofficeTheme.muted),
                    ),
                  ],
                ),
              ),
              BoBadge(status: _labels[issue.status] ?? issue.status),
            ],
          ),
          // Description
          const SizedBox(height: 10),
          Text(
            issue.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BackofficeTheme.inter(12, color: BackofficeTheme.muted),
          ),
          // Location (if present)
          if (issue.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: BackofficeTheme.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    issue.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BackofficeTheme.inter(11, color: BackofficeTheme.muted),
                  ),
                ),
              ],
            ),
          ],
          // Action button
          if (!isResolved) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: BackofficeTheme.green,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => _resolve(issue),
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text(
                        'Resolve',
                        style: BackofficeTheme.inter(
                          11.5,
                          weight: FontWeight.w600,
                          color: BackofficeTheme.cream,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_off_outlined, size: 34, color: BackofficeTheme.border),
            const SizedBox(height: 10),
            Text(text, style: BackofficeTheme.inter(12.5, color: BackofficeTheme.muted)),
          ],
        ),
      ),
    );
  }
}
