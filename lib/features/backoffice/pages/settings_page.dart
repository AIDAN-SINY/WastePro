import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/backoffice_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/item_card.dart';
import '../widgets/sheets.dart';
import '../widgets/toast.dart';

/// Paramètres: ramassage frequencies (editable) + company info (display).
class BoSettingsPage extends StatelessWidget {
  const BoSettingsPage({super.key, required this.store, this.desktop = false});

  final BackofficeStore store;

  /// Layout desktop (web-first) : padding adapté (pas de tab bar ni FAB).
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 2 : 16,
            6,
            desktop ? 2 : 16,
            desktop ? 24 : 110,
          ),
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
                  _infoField('City of operation', 'Yaoundé'),
                  const SizedBox(height: 15),
                  _infoField('Support number', '+237 696 713 899'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _title('Development'),
            const _DevBypassCard(),
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
      avatarText: 'Fq',
      title: frequence.libelle,
      subtitle: 'Every ${frequence.jours} days',
      status: 'Active',
      onKebab: () {
        showBoActionSheet(context, onEdit: onEdit, onDelete: onDelete);
      },
    );
  }
}

class _DevBypassCard extends StatefulWidget {
  const _DevBypassCard();

  @override
  State<_DevBypassCard> createState() => _DevBypassCardState();
}

class _DevBypassCardState extends State<_DevBypassCard> {
  bool _bypass = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _bypass = doc.data()?['devPaymentBypass'] == true;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _bypass = value;
      _loading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .set({'devPaymentBypass': value}, SetOptions(merge: true));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BackofficeTheme.card(),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            color: _bypass ? const Color(0xFFD4A853) : BackofficeTheme.muted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skip payment (dev mode)',
                  style: BackofficeTheme.inter(13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'When ON, subscriptions are auto-confirmed without CamPay. '
                  'Use only during development.',
                  style: BackofficeTheme.inter(11, color: BackofficeTheme.muted, height: 1.4),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: _bypass,
              onChanged: _toggle,
              activeThumbColor: const Color(0xFFD4A853),
            ),
        ],
      ),
    );
  }
}
