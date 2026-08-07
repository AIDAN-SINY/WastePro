import 'package:flutter/material.dart';

import '../data/backoffice_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/chips.dart';
import '../widgets/item_card.dart';
import '../widgets/sheets.dart';
import '../widgets/toast.dart';

/// Generic list page for the backoffice (clients, collecteurs, contrats,
/// collectes, factures) with filter chips, search and item CRUD.
class BoListPage extends StatelessWidget {
  const BoListPage({
    super.key,
    required this.store,
    required this.type,
    required this.search,
  });

  final BackofficeStore store;
  final BoEntity type;
  final String search;

  String get _entityName => switch (type) {
        BoEntity.client => 'client',
        BoEntity.collecteur => 'collector',
        BoEntity.contrat => 'contract',
        BoEntity.collecte => 'collection',
        BoEntity.facture => 'invoice',
        BoEntity.frequence => 'frequency',
      };

  String get _emptyText => switch (type) {
        BoEntity.client => 'No clients found',
        BoEntity.collecteur => 'No collectors found',
        BoEntity.contrat => 'No contracts found',
        BoEntity.collecte => 'No collections found',
        BoEntity.facture => 'No invoices found',
        BoEntity.frequence => 'No frequencies',
      };

  /// (label shown, status value used for filtering) per the design.
  List<(String, String)> get _filters => switch (type) {
        BoEntity.client => [
            ('All', 'All'),
            ('Active', 'Active'),
            ('Suspended', 'Suspended'),
          ],
        BoEntity.collecteur => [
            ('All', 'All'),
            ('Active', 'Active'),
            ('Inactive', 'Inactive'),
          ],
        BoEntity.contrat => [
            ('All', 'All'),
            ('Active', 'Active'),
            ('Expired', 'Expired'),
          ],
        BoEntity.collecte => [
            ('All', 'All'),
            ('Completed', 'Completed'),
            ('Scheduled', 'Scheduled'),
            ('Missed', 'Missed'),
          ],
        BoEntity.facture => [
            ('All', 'All'),
            ('Paid', 'Paid'),
            ('Pending', 'Pending'),
            ('Overdue', 'Overdue'),
          ],
        BoEntity.frequence => [('All', 'All')],
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = _buildList();
        final selValue = store.filterFor(type);
        final selLabel = _filters
            .firstWhere((f) => f.$2 == selValue, orElse: () => _filters.first)
            .$1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            BoChipRow(
              options: _filters.map((f) => f.$1).toList(),
              selected: selLabel,
              onSelect: (label) {
                final value =
                    _filters.firstWhere((f) => f.$1 == label).$2;
                store.selectFilter(type, value);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(text: _emptyText)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
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

  /// Matches a status filter against both the English values and the legacy
  /// French ones (e.g. 'Active' also matches 'Actif') so records created
  /// before the switch to English stay visible when filtering.
  bool _statusMatches(String filter, String status) {
    if (filter == 'All') return true;
    const legacy = {
      'Active': {'Actif'},
      'Suspended': {'Suspendu'},
      'Inactive': {'Inactif'},
      'Completed': {'Effectué'},
      'Scheduled': {'Prévu'},
      'Missed': {'Manqué'},
      'Paid': {'Payée'},
      'Pending': {'En attente'},
      'Overdue': {'En retard'},
      'Expired': {'Expiré'},
    };
    return status == filter || (legacy[filter]?.contains(status) ?? false);
  }

  List<Object> _buildList() {
    final q = search.toLowerCase();
    bool match(String value) => q.isEmpty || value.toLowerCase().contains(q);
    final sel = store.filterFor(type);

    switch (type) {
      case BoEntity.client:
        return store.clients
            .where((c) => _statusMatches(sel, c.status) && (match(c.name) || match(c.zone)))
            .toList()
            .cast<Object>();
      case BoEntity.collecteur:
        return store.collecteurs
            .where((c) => _statusMatches(sel, c.status) && (match(c.name) || match(c.zone)))
            .toList()
            .cast<Object>();
      case BoEntity.contrat:
        return store.contrats
            .where((c) => _statusMatches(sel, c.status) && match(c.client))
            .toList()
            .cast<Object>();
      case BoEntity.collecte:
        final sorted = [...store.collectes]..sort((a, b) => b.date.compareTo(a.date));
        return sorted
            .where((c) => _statusMatches(sel, c.status) && match(c.client))
            .toList()
            .cast<Object>();
      case BoEntity.facture:
        return store.factures
            .where((f) => _statusMatches(sel, f.status) && match(f.client))
            .toList()
            .cast<Object>();
      case BoEntity.frequence:
        return store.frequences.toList().cast<Object>();
    }
  }

  Widget _card(BuildContext context, Object item) {
    switch (type) {
      case BoEntity.client:
        final c = item as ClientModel;
        return BoItemCard(
          avatarText: boInitials(c.name),
          title: c.name,
          subtitle: '${c.zone} · ${c.plan}',
          status: c.status,
          onKebab: () => _onKebab(context, c),
        );
      case BoEntity.collecteur:
        final c = item as CollecteurModel;
        return BoItemCard(
          avatarText: boInitials(c.name),
          title: c.name,
          subtitle: '${c.zone} · ★ ${c.rating.toStringAsFixed(1)}',
          status: c.status,
          onKebab: () => _onKebab(context, c),
        );
      case BoEntity.contrat:
        final c = item as ContratModel;
        return BoItemCard(
          avatarText: boInitials(c.client),
          title: c.client,
          subtitle: '${c.frequence} · ${boMoney(c.prix)} XAF',
          status: c.status,
          onKebab: () => _onKebab(context, c),
        );
      case BoEntity.collecte:
        final c = item as CollecteModel;
        return BoItemCard(
          avatarText: boInitials(c.client),
          title: c.client,
          subtitle:
              '${c.collecteur} · ${boFmtDate(c.date)}${c.poids > 0 ? ' · ${c.poids}kg' : ''}',
          status: c.status,
          onKebab: () => _onKebab(context, c),
        );
      case BoEntity.facture:
        final c = item as FactureModel;
        return BoItemCard(
          avatarText: boInitials(c.client),
          title: c.client,
          subtitle: '${boMoney(c.montant)} XAF · due ${boFmtDate(c.echeance)}',
          status: c.status,
          onKebab: () => _onKebab(context, c),
        );
      case BoEntity.frequence:
        return BoItemCard(
          avatarText: '🔄',
          title: (item as FrequenceModel).libelle,
          subtitle: 'Every ${item.jours} days',
          status: 'Active',
          onKebab: () => _onKebab(context, item),
        );
    }
  }

  void _onKebab(BuildContext context, Object item) {
    showBoActionSheet(
      context,
      onEdit: () => showBoFormSheet(context, store: store, type: type, existing: item),
      onDelete: () => _delete(context, item),
    );
  }

  void _delete(BuildContext context, Object item) {
    switch (type) {
      case BoEntity.client:
        store.deleteClient((item as ClientModel).id);
      case BoEntity.collecteur:
        store.deleteCollecteur((item as CollecteurModel).id);
      case BoEntity.contrat:
        store.deleteContrat((item as ContratModel).id);
      case BoEntity.collecte:
        store.deleteCollecte((item as CollecteModel).id);
      case BoEntity.facture:
        store.deleteFacture((item as FactureModel).id);
      case BoEntity.frequence:
        store.deleteFrequence((item as FrequenceModel).id);
    }
    BoToastService.show('$_entityName deleted');
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
            Icon(Icons.search_off_rounded, size: 34, color: BackofficeTheme.border),
            const SizedBox(height: 10),
            Text(
              text,
              style: BackofficeTheme.inter(12.5, color: BackofficeTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
