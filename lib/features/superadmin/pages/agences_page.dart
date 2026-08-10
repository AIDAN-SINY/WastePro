import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/agence_model.dart';
import '../../../models/platform_user_model.dart';
import '../../../models/societe_model.dart';
import '../data/platform_store.dart';
import '../theme.dart';
import '../widgets/app_table.dart';
import '../widgets/app_toast.dart';
import '../widgets/cells.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/crud_drawer.dart';
import '../widgets/detail_drawer.dart';
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
  static const List<String> _filters = ['All', 'Active', 'Suspended'];

  int _filter = 0;
  final Map<String, dynamic> _form = {};

  List<String> get _societeOptions =>
      context.read<PlatformStore>().societes.map((s) => s.raisonSociale).toList();

  /// Id de la société correspondant à un nom (raisonSociale), ou '' si
  /// introuvable — pour lier l'agence à sa société (Phase 2).
  String _societeIdFor(String nom) {
    for (final s in context.read<PlatformStore>().societes) {
      if (s.raisonSociale == nom) return s.id;
    }
    return '';
  }

  /// Opens the "New agency" drawer (used by the command palette).
  void openCreate() {
    final options = _societeOptions;
    // An agency must belong to an existing company.
    if (options.isEmpty) {
      ToastService.show(
        'Create a company first before adding an agency.',
        isError: true,
      );
      return;
    }
    _form
      ..clear()
      ..['status'] = 'Active'
      ..['societe'] = options.first;
    showCrudDrawer(
      context,
      title: 'New agency',
      body: _buildForm(options),
      onSave: () async {
        try {
          final ville = requireField(_form, 'ville', 'City');
          final societe = _form['societe']?.toString() ?? '';
          await context.read<PlatformStore>().addAgence(
                societe: societe,
                societeId: _societeIdFor(societe),
                ville: ville,
                responsable: _form['responsable']?.toString().trim() ?? '',
                telephone: _form['telephone']?.toString().trim() ?? '',
                status: _form['status']?.toString() ?? 'Active',
              );
          ToastService.show('Agency created successfully.');
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
      title: 'Edit agency',
      body: _buildForm(_societeOptions),
      onSave: () async {
        try {
          final ville = requireField(_form, 'ville', 'City');
          final societe = _form['societe']?.toString();
          await context.read<PlatformStore>().updateAgence(
                agence.copyWith(
                  societe: societe,
                  societeId:
                      societe == null ? null : _societeIdFor(societe),
                  ville: ville,
                  responsable: _form['responsable']?.toString().trim(),
                  telephone: _form['telephone']?.toString().trim(),
                  status: _form['status']?.toString(),
                ),
              );
          ToastService.show('Changes saved.');
        } catch (e) {
          ToastService.show(e.toString(), isError: true);
          rethrow;
        }
      },
    );
  }

  /// Ouvre la vue détail d'une agence : toutes les informations (agence,
  /// société liée, managers affectés) + actions Éditer / Supprimer.
  /// C'est le super admin : il voit TOUT sur l'agence.
  void openDetail(AgenceModel agence) {
    showDetailDrawer(
      context,
      title: agence.ville,
      body: _buildDetailBody(agence),
      footer: _buildDetailFooter(agence),
    );
  }

  /// Corps de la vue détail : infos agence, société liée, managers.
  Widget _buildDetailBody(AgenceModel agence) {
    final store = context.read<PlatformStore>();
    // Société liée (par id si renseigné, sinon par nom).
    SocieteModel? societe;
    for (final s in store.societes) {
      if ((agence.societeId.isNotEmpty && s.id == agence.societeId) ||
          (agence.societeId.isEmpty && s.raisonSociale == agence.societe)) {
        societe = s;
        break;
      }
    }
    // Managers affectés à l'agence (par agenceId, sinon par nom).
    final managers = store.utilisateurs
        .where((u) =>
            u.agenceId == agence.id ||
            (u.agenceId.isEmpty && u.agence == agence.ville))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête visuel de l'agence.
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SuperAdminTheme.goldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 22,
                color: SuperAdminTheme.goldDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agence.ville,
                    style: SuperAdminTheme.sora(15, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    societe?.raisonSociale ?? agence.societe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SuperAdminTheme.inter(
                      11.5,
                      color: SuperAdminTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: agence.status),
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: SuperAdminTheme.border),
        const SizedBox(height: 18),
        // Infos de l'agence.
        Text(
          'AGENCY',
          style: SuperAdminTheme.inter(
            10.5,
            weight: FontWeight.w700,
            color: SuperAdminTheme.goldDim,
          ),
        ),
        const SizedBox(height: 12),
        DetailRow(label: 'City', value: agence.ville),
        DetailRow(label: 'Manager', value: agence.responsable),
        DetailRow(label: 'Phone', value: agence.telephone),
        const SizedBox(height: 6),
        // Société liée.
        Text(
          'COMPANY',
          style: SuperAdminTheme.inter(
            10.5,
            weight: FontWeight.w700,
            color: SuperAdminTheme.goldDim,
          ),
        ),
        const SizedBox(height: 12),
        if (societe != null) ...[
          DetailRow(label: 'Company', value: societe.raisonSociale),
          DetailRow(label: 'Address', value: societe.adresse),
          DetailRow(label: 'Email', value: societe.email),
          DetailRow(label: 'Phone', value: societe.telephone),
        ] else
          DetailRow(label: 'Company', value: agence.societe),
        const SizedBox(height: 6),
        // Managers affectés.
        Text(
          'MANAGERS — ${managers.length}',
          style: SuperAdminTheme.inter(
            10.5,
            weight: FontWeight.w700,
            color: SuperAdminTheme.goldDim,
          ),
        ),
        const SizedBox(height: 8),
        if (managers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No managers assigned to this agency yet.',
              style: SuperAdminTheme.inter(12, color: SuperAdminTheme.muted),
            ),
          )
        else
          for (final m in managers)
            _managerTile(m),
      ],
    );
  }

  /// Ligne manager dans la vue détail (avatar + nom + rôle + statut).
  Widget _managerTile(PlatformUserModel manager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SuperAdminTheme.rowHover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SuperAdminTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: SuperAdminTheme.goldSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                saInitials(manager.nom),
                style: SuperAdminTheme.inter(
                  10.5,
                  weight: FontWeight.w700,
                  color: SuperAdminTheme.goldDim,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SuperAdminTheme.inter(12.5, weight: FontWeight.w600),
                ),
                Text(
                  manager.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SuperAdminTheme.inter(10.5, color: SuperAdminTheme.muted),
                ),
              ],
            ),
          ),
          StatusBadge(status: manager.status),
        ],
      ),
    );
  }

  /// Pied de la vue détail : Éditer + Supprimer.
  Widget _buildDetailFooter(AgenceModel agence) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: SuperAdminTheme.border),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // ferme la vue détail
              openEdit(agence);
            },
            child: Text(
              'Edit',
              style: SuperAdminTheme.inter(
                12.5,
                weight: FontWeight.w600,
                color: SuperAdminTheme.muted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              backgroundColor: SuperAdminTheme.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // ferme la vue détail
              confirmDelete(agence);
            },
            child: Text(
              'Delete',
              style: SuperAdminTheme.inter(
                12.5,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> confirmDelete(AgenceModel agence) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this agency?',
      message:
          '"${agence.ville}" will be permanently deleted. This action is irreversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<PlatformStore>().deleteAgence(agence.id);
        if (mounted) ToastService.show('Item deleted.');
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
          label: 'Company',
          options: societeOptions,
          initial: _form['societe']?.toString(),
          onChanged: (v) => _form['societe'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'City',
          initial: _form['ville']?.toString(),
          hint: 'Ex. Douala — Bonanjo',
          onChanged: (v) => _form['ville'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Manager',
          initial: _form['responsable']?.toString(),
          hint: 'Manager name',
          onChanged: (v) => _form['responsable'] = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SaTextField(
                label: 'Phone',
                initial: _form['telephone']?.toString(),
                hint: '+237 6XX XX XX XX',
                keyboardType: TextInputType.phone,
                onChanged: (v) => _form['telephone'] = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SaSelectField(
                label: 'Status',
                options: const ['Active', 'Suspended'],
                initial: _form['status']?.toString() ?? 'Active',
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
        _filter == 1 ? 'Active' : (_filter == 2 ? 'Suspended' : null);
    // Match both the English values and the legacy French ones ('Actif' /
    // 'Suspendu') so records created before the switch stay visible.
    final rows = statusFilter == null
        ? store.agences
        : store.agences
              .where((a) => statusFilter == 'Active'
                  ? (a.status == 'Active' || a.status == 'Actif')
                  : (a.status == 'Suspended' || a.status == 'Suspendu'))
              .toList();

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
            label: 'New agency',
            icon: Icons.add_rounded,
            onTap: openCreate,
          ),
        ),
        const SizedBox(height: 16),
        AppTable<AgenceModel>(
          rows: rows,
          emptyText: 'No agencies found',
          footer: '${rows.length} agenc${rows.length > 1 ? 'ies' : 'y'}',
          columns: [
            TableColumnSpec(
              label: 'Agency',
              sortValue: (a) => a.ville,
              flex: 2,
              cell: (a) => saNameCell(a.ville),
            ),
            TableColumnSpec(
              label: 'Company',
              sortValue: (a) => a.societe,
              flex: 2,
              cell: (a) => saTextCell(a.societe),
            ),
            TableColumnSpec(
              label: 'Manager',
              sortValue: (a) => a.responsable,
              flex: 2,
              cell: (a) => saTextCell(a.responsable),
            ),
            TableColumnSpec(
              label: 'Status',
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
          // Clic sur une ligne → vue détail complète de l'agence.
          onRowTap: openDetail,
        ),
      ],
    );
  }
}
