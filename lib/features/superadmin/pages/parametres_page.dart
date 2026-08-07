import 'package:flutter/material.dart';

import '../theme.dart';

class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 880;

        final platformCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: SuperAdminTheme.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform',
                style: SuperAdminTheme.sora(14.5, weight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _SettingField(label: 'Platform name', value: 'WastePro'),
              const SizedBox(height: 14),
              _SettingField(
                label: 'Support email',
                value: 'support@wastepro.cm',
              ),
              const SizedBox(height: 14),
              _SettingField(
                label: 'Time zone',
                value: 'Africa/Douala (GMT+1)',
              ),
            ],
          ),
        );

        final securityCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: SuperAdminTheme.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security',
                style: SuperAdminTheme.sora(14.5, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const _SecurityItem(
                color: SuperAdminTheme.green,
                title: 'Two-factor authentication (2FA)',
                subtitle: 'Required for General Administrators',
              ),
              const _SecurityItem(
                color: SuperAdminTheme.gold,
                title: 'Action logging',
                subtitle: 'Enabled — 12-month retention',
              ),
            ],
          ),
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: wide
              ? [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: platformCard),
                      const SizedBox(width: 16),
                      Expanded(child: securityCard),
                    ],
                  ),
                ]
              : [
                  platformCard,
                  const SizedBox(height: 16),
                  securityCard,
                ],
        );
      },
    );
  }
}

class _SettingField extends StatelessWidget {
  const _SettingField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SuperAdminTheme.inter(
            11.5,
            weight: FontWeight.w600,
            color: SuperAdminTheme.muted,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: SuperAdminTheme.bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: SuperAdminTheme.border),
          ),
          child: Text(
            value,
            style: SuperAdminTheme.inter(13),
          ),
        ),
      ],
    );
  }
}

class _SecurityItem extends StatelessWidget {
  const _SecurityItem({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final String title;
  final String subtitle;

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
                  subtitle,
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
