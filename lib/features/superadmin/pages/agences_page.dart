import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/agence_model.dart';
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

class AgencesPage extends StatefulWidget {
  const AgencesPage({super.key});

  @override
  State<AgencesPage> createState() => AgencesPageState();
}

class AgencesPageState extends State<AgencesPage> {
  static const List<String> _filters = ['Toutes', 'Actives', 'Suspendues'];

  int _filter = 0;
  final Map<String, dynamic> _form = {};

  List<String> get _societeOptions =>
      context.read<PlatformStore>().societes.map((s) => s.raisonSociale).toList();

  /// Opens the "Nouvelle agence" drawer (used by the command palette).
  void openCreate() {
    final options = _societeOptions;
    // An agence must belong to an existing société.
    if (options.isEmpty) {
      ToastService.show(
        'Créez d\'abord une société avant d\'ajouter une agence.',
        isError: true,
      );
      return;
    }
    _form
      ..clear()
      ..['status'] = 'Actif'
      ..['societe'] = options.first;
    showCrudDrawer(
      context,
      title: 'Nouvelle agence',
      body: _buildForm(options),
      onSave: () async {
        try {
          final ville = requireField(_form, 'ville', 'Ville');
          await context.read<PlatformStore>().addAgence(
                societe: _form['societe']?.toString() ?? '',
                ville: ville,
                responsable: _form['responsable']?.toString().trim() ?? '',
                telephone: _form['telephone']?.toString().trim() ?? '',
                status: _form['status']?.toString() ?? 'Actif',
              );
          ToastService.show('Agence créée avec succès.');
        } catch (e) {
          ToastService.show(e.toString(), isError: true);
          rethrow;
        }
      },
    );
  }

  void openEdit(AgenceModel agence) {
    _form
      ..clear()
      ..addAll(agence.toMap());
    showCrudDrawer(
      context,
      title: "Modifier l'agence",
      body: _buildForm(_societeOptions),
      onSave: () async {
        try {
          final ville = requireField(_form, 'ville', 'Ville');
          await context.read<PlatformStore>().updateAgence(
                agence.copyWith(
                  societe: _form['societe']?.toString(),
                  ville: ville,
                  responsable: _form['responsable']?.toString().trim(),
                  telephone: _form['telephone']?.toString().trim(),
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

  Future<void> confirmDelete(AgenceModel agence) async {
    final confirmed = await showConfirmDialog(
      context,
      title: "Supprimer cette agence ?",
      message:
          '"${agence.ville}" sera définitivement supprimée. Cette action est irréversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<PlatformStore>().deleteAgence(agence.id);
        if (mounted) ToastService.show('Élément supprimé.');
      } catch (e) {
        if (mounted) ToastService.show(e.toString(), isError: true);
      }
    }
  }

  Widget _buildForm(List<String> societeOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SaSelectField(
          label: 'Société',
          options: societeOptions,
          initial: _form['societe']?.toString(),
          onChanged: (v) => _form['societe'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Ville',
          initial: _form['ville']?.toString(),
          hint: 'Ex. Douala — Bonanjo',
          onChanged: (v) => _form['ville'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Responsable',
          initial: _form['responsable']?.toString(),
          hint: 'Nom du responsable',
          onChanged: (v) => _form['responsable'] = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SaTextField(
                label: 'Téléphone',
                initial: _form['telephone']?.toString(),
                hint: '+237 6XX XX XX XX',
                keyboardType: TextInputType.phone,
                onChanged: (v) => _form['telephone'] = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SaSelectField(
                label: 'Statut',
                options: const ['Actif', 'Suspendu'],
                initial: _form['status']?.toString() ?? 'Actif',
                onChanged: (v) => _form['status'] = v,
              ),
            ),
          ],
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
        ? store.agences
        : store.agences.where((a) => a.status == statusFilter).toList();

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
            label: 'Nouvelle agence',
            icon: Icons.add_rounded,
            onTap: openCreate,
          ),
        ),
        const SizedBox(height: 16),
        AppTable<AgenceModel>(
          rows: rows,
          emptyText: 'Aucune agence trouvée',
          footer: '${rows.length} agence${rows.length > 1 ? 's' : ''}',
          columns: [
            TableColumnSpec(
              label: 'Agence',
              sortValue: (a) => a.ville,
              flex: 2,
              cell: (a) => saNameCell(a.ville),
            ),
            TableColumnSpec(
              label: 'Société',
              sortValue: (a) => a.societe,
              flex: 2,
              cell: (a) => saTextCell(a.societe),
            ),
            TableColumnSpec(
              label: 'Responsable',
              sortValue: (a) => a.responsable,
              flex: 2,
              cell: (a) => saTextCell(a.responsable),
            ),
            TableColumnSpec(
              label: 'Statut',
              sortValue: (a) => a.status,
              flex: 1,
              cell: (a) => StatusBadge(status: a.status),
            ),
          ],
          actions: (a) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RowActionButton(
                icon: Icons.edit_rounded,
                onTap: () => openEdit(a),
              ),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                onTap: () => confirmDelete(a),
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
