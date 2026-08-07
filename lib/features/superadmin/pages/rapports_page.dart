import 'package:flutter/material.dart';

import '../theme.dart';

class RapportsPage extends StatelessWidget {
  const RapportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: SuperAdminTheme.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available exports',
                style: SuperAdminTheme.sora(14.5, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const _ReportItem(
                color: SuperAdminTheme.gold,
                title: 'Monthly report — July 2026',
                formats: 'PDF · Excel · CSV',
              ),
              const _ReportItem(
                color: SuperAdminTheme.green,
                title: 'Consolidated report — H2 2026',
                formats: 'PDF · Excel',
              ),
              const _ReportItem(
                color: SuperAdminTheme.blue,
                title: 'Payment log',
                formats: 'CSV',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Report generation — module to be connected to a real data source.',
          style: SuperAdminTheme.inter(11.5, color: SuperAdminTheme.muted),
        ),
      ],
    );
  }
}

class _ReportItem extends StatelessWidget {
  const _ReportItem({
    required this.color,
    required this.title,
    required this.formats,
  });

  final Color color;
  final String title;
  final String formats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SuperAdminTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SuperAdminTheme.inter(12.5, weight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  formats,
                  style: SuperAdminTheme.inter(11, color: SuperAdminTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
