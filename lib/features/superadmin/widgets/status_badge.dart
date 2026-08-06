import 'package:flutter/material.dart';

import '../theme.dart';

/// Status pill with the design's color mapping:
/// Actif → green, Suspendu → red, Administrateur Général → gold,
/// Responsable d'Agence → gray.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'Actif' => (SuperAdminTheme.greenSoft, SuperAdminTheme.green),
      'Suspendu' => (SuperAdminTheme.redSoft, SuperAdminTheme.red),
      'Administrateur Général' =>
        (SuperAdminTheme.goldSoft, SuperAdminTheme.goldDim),
      _ => (const Color(0xFFEFEDE5), SuperAdminTheme.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: SuperAdminTheme.inter(
              10.5,
              weight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
