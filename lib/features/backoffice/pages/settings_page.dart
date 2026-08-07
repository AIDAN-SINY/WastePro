import 'package:flutter/material.dart';

import '../data/backoffice_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/item_card.dart';
import '../widgets/sheets.dart';
import '../widgets/toast.dart';

/// Paramètres: ramassage frequencies (editable) + company info (display).
class BoSettingsPage extends StatelessWidget {
  const BoSettingsPage({super.key, required this.store});

  final BackofficeStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          children: [
            _title('Pickup frequencies'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BackofficeTheme.card(),
              child: Column(
                children: [
                  for (var i = 0; i < store.frequences.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: BackofficeTheme.border),
                    _FrequenceRow(
                      frequence: store.frequences[i],
                      onEdit: () => showBoFormSheet(
                        context,
                        store: store,
                        type: BoEntity.frequence,
                        existing: store.frequences[i],
                      ),
                      onDelete: () {
                        store.deleteFrequence(store.frequences[i].id);
                        BoToastService.show('frequency deleted');
                      },
                    ),
                  ],
                ],
              ),
            ),
            _title('Company information'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BackofficeTheme.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoField('Company name', 'WastePro'),
                  const SizedBox(height: 15),
                  _infoField('City of operation', 'Douala'),
                  const SizedBox(height: 15),
                  _infoField('Support number', '+237 6XX XXX XXX'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
        child: Text(text, style: BackofficeTheme.sora(14, weight: FontWeight.w700)),
      );

  Widget _infoField(String label, String value) {
    // Read-only display (no controller needed).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: BackofficeTheme.inter(11, weight: FontWeight.w600, color: BackofficeTheme.muted),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: BackofficeTheme.bg,
            border: Border.all(color: BackofficeTheme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value, style: BackofficeTheme.inter(14)),
        ),
      ],
    );
  }
}

class _FrequenceRow extends StatelessWidget {
  const _FrequenceRow({
    required this.frequence,
    required this.onEdit,
    required this.onDelete,
  });

  final FrequenceModel frequence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return BoItemCard(
      avatarText: '🔄',
      title: frequence.libelle,
      subtitle: 'Every ${frequence.jours} days',
      status: 'Active',
      onKebab: () {
        showBoActionSheet(context, onEdit: onEdit, onDelete: onDelete);
      },
    );
  }
}
