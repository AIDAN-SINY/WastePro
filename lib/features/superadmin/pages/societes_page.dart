import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/societe_model.dart';
import '../data/platform_store.dart';
import '../widgets/app_table.dart';
import '../widgets/app_toast.dart';
import '../widgets/cells.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/crud_drawer.dart';
import '../widgets/filter_pills.dart';
import '../widgets/form_fields.dart';
import '../widgets/form_validation.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';

class SocietesPage extends StatefulWidget {
  const SocietesPage({super.key});

  @override
  State<SocietesPage> createState() => SocietesPageState();
}

class SocietesPageState extends State<SocietesPage> {
  static const List<String> _filters = ['Toutes', 'Actives', 'Suspendues'];

  int _filter = 0;
  final Map<String, dynamic> _form = {};

  /// Opens the "Nouvelle société" drawer (used by the command palette).
  void openCreate() {
    _form
      ..clear()
      ..['status'] = 'Actif';
    showCrudDrawer(
      context,
      title: 'Nouvelle société',
      body: _buildForm(),
      onSave: () async {
        try {
          final raisonSociale =
              requireField(_form, 'raisonSociale', 'Raison sociale');
          await context.read<PlatformStore>().addSociete(
                raisonSociale: raisonSociale,
                adresse: _form['adresse']?.toString().trim() ?? '',
                telephone: _form['telephone']?.toString().trim() ?? '',
                email: _form['email']?.toString().trim() ?? '',
                status: _form['status']?.toString() ?? 'Actif',
              );
          ToastService.show('Société créée avec succès.');
        } catch (e) {
          ToastService.show(e.toString(), isError: true);
          rethrow;
        }
      },
    );
  }

  void openEdit(SocieteModel societe) {
    _form
      ..clear()
      ..addAll(societe.toMap());
    showCrudDrawer(
      context,
      title: 'Modifier la société',
      body: _buildForm(),
      onSave: () async {
        try {
          final raisonSociale =
              requireField(_form, 'raisonSociale', 'Raison sociale');
          await context.read<PlatformStore>().updateSociete(
                societe.copyWith(
                  raisonSociale: raisonSociale,
                  adresse: _form['adresse']?.toString().trim(),
                  telephone: _form['telephone']?.toString().trim(),
                  email: _form['email']?.toString().trim(),
                  status: _form['status']?.toString(),
                ),
              );
          ToastService.show('Modifications enregistrées.');
        } catch (e) {
          ToastService.show(e.toString(), isError: true);
          rethrow;
        }
      },
    );
  }

  Future<void> confirmDelete(SocieteModel societe) async {
    // A société with attached agences cannot be deleted: this would leave
    // orphan agences referencing a company that no longer exists.
    final agences = context
        .read<PlatformStore>()
        .agences
        .where((a) => a.societe == societe.raisonSociale)
        .toList();
    if (agences.isNotEmpty) {
      ToastService.show(
        'Impossible de supprimer : ${agences.length} agence'
        '${agences.length > 1 ? 's' : ''} rattachée'
        '${agences.length > 1 ? 's' : ''} à cette société.',
        isError: true,
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer cette société ?',
      message:
          '"${societe.raisonSociale}" sera définitivement supprimée. Cette action est irréversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<PlatformStore>().deleteSociete(societe.id);
        if (mounted) ToastService.show('Élément supprimé.');
      } catch (e) {
        if (mounted) ToastService.show(e.toString(), isError: true);
      }
    }
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SaTextField(
          label: 'Raison sociale',
          initial: _form['raisonSociale']?.toString(),
          hint: 'Ex. Propre237 Douala SARL',
          onChanged: (v) => _form['raisonSociale'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Adresse',
          initial: _form['adresse']?.toString(),
          hint: 'Ex. Bonanjo, Douala',
          onChanged: (v) => _form['adresse'] = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SaTextField(
                label: 'Téléphone',
                initial: _form['telephone']?.toString(),
                hint: '+237 2XX XX XX XX',
                keyboardType: TextInputType.phone,
                onChanged: (v) => _form['telephone'] = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SaTextField(
                label: 'Email',
                initial: _form['email']?.toString(),
                hint: 'contact@societe.cm',
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => _form['email'] = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SaSelectField(
          label: 'Statut',
          options: const ['Actif', 'Suspendu'],
          initial: _form['status']?.toString() ?? 'Actif',
          onChanged: (v) => _form['status'] = v,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlatformStore>();
    final statusFilter =
        _filter == 1 ? 'Actif' : (_filter == 2 ? 'Suspendu' : null);
    final rows = statusFilter == null
        ? store.societes
        : store.societes.where((s) => s.status == statusFilter).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        PageToolbar(
          filters: FilterPills(
            labels: _filters,
            activeIndex: _filter,
            onChanged: (i) => setState(() => _filter = i),
          ),
          action: PrimaryButton(
            label: 'Nouvelle société',
            icon: Icons.add_rounded,
            onTap: openCreate,
          ),
        ),
        const SizedBox(height: 16),
        AppTable<SocieteModel>(
          rows: rows,
          emptyText: 'Aucune société trouvée',
          footer: '${rows.length} société${rows.length > 1 ? 's' : ''}',
          columns: [
            TableColumnSpec(
              label: 'Société',
              sortValue: (s) => s.raisonSociale,
              flex: 3,
              cell: (s) => saNameCell(s.raisonSociale),
            ),
            TableColumnSpec(
              label: 'Adresse',
              sortValue: (s) => s.adresse,
              flex: 2,
              cell: (s) => saTextCell(s.adresse),
            ),
            TableColumnSpec(
              label: 'Téléphone',
              sortValue: (s) => s.telephone,
              flex: 2,
              cell: (s) => saTextCell(s.telephone),
            ),
            TableColumnSpec(
              label: 'Statut',
              sortValue: (s) => s.status,
              flex: 1,
              cell: (s) => StatusBadge(status: s.status),
            ),
          ],
          actions: (s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RowActionButton(
                icon: Icons.edit_rounded,
                onTap: () => openEdit(s),
              ),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                onTap: () => confirmDelete(s),
                danger: true,
              ),
            ],
          ),
          onRowTap: openEdit,
        ),
      ],
    );
  }
}
