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
  static const List<String> _filters = ['All', 'Active', 'Suspended'];

  int _filter = 0;
  final Map<String, dynamic> _form = {};

  /// Opens the "New company" drawer (used by the command palette).
  void openCreate() {
    _form
      ..clear()
      ..['status'] = 'Active';
    showCrudDrawer(
      context,
      title: 'New company',
      body: _buildForm(),
      onSave: () async {
        try {
          final raisonSociale =
              requireField(_form, 'raisonSociale', 'Company name');
          await context.read<PlatformStore>().addSociete(
                raisonSociale: raisonSociale,
                adresse: _form['adresse']?.toString().trim() ?? '',
                telephone: _form['telephone']?.toString().trim() ?? '',
                email: _form['email']?.toString().trim() ?? '',
                status: _form['status']?.toString() ?? 'Active',
              );
          ToastService.show('Company created successfully.');
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
      title: 'Edit company',
      body: _buildForm(),
      onSave: () async {
        try {
          final raisonSociale =
              requireField(_form, 'raisonSociale', 'Company name');
          await context.read<PlatformStore>().updateSociete(
                societe.copyWith(
                  raisonSociale: raisonSociale,
                  adresse: _form['adresse']?.toString().trim(),
                  telephone: _form['telephone']?.toString().trim(),
                  email: _form['email']?.toString().trim(),
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
        'Cannot delete: ${agences.length} agenc'
        '${agences.length > 1 ? 'ies' : 'y'} linked'
        '${agences.length > 1 ? '' : ''} to this company.',
        isError: true,
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this company?',
      message:
          '"${societe.raisonSociale}" will be permanently deleted. This action is irreversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<PlatformStore>().deleteSociete(societe.id);
        if (mounted) ToastService.show('Item deleted.');
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
          label: 'Company name',
          initial: _form['raisonSociale']?.toString(),
          hint: 'Ex. WastePro Douala Ltd',
          onChanged: (v) => _form['raisonSociale'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Address',
          initial: _form['adresse']?.toString(),
          hint: 'Ex. Bonanjo, Douala',
          onChanged: (v) => _form['adresse'] = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SaTextField(
                label: 'Phone',
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
                hint: 'contact@company.cm',
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => _form['email'] = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SaSelectField(
          label: 'Status',
          options: const ['Active', 'Suspended'],
          initial: _form['status']?.toString() ?? 'Active',
          onChanged: (v) => _form['status'] = v,
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
        ? store.societes
        : store.societes
              .where((s) => statusFilter == 'Active'
                  ? (s.status == 'Active' || s.status == 'Actif')
                  : (s.status == 'Suspended' || s.status == 'Suspendu'))
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
            label: 'New company',
            icon: Icons.add_rounded,
            onTap: openCreate,
          ),
        ),
        const SizedBox(height: 16),
        AppTable<SocieteModel>(
          rows: rows,
          emptyText: 'No companies found',
          footer: '${rows.length} compan${rows.length > 1 ? 'ies' : 'y'}',
          columns: [
            TableColumnSpec(
              label: 'Company',
              sortValue: (s) => s.raisonSociale,
              flex: 3,
              cell: (s) => saNameCell(s.raisonSociale),
            ),
            TableColumnSpec(
              label: 'Address',
              sortValue: (s) => s.adresse,
              flex: 2,
              cell: (s) => saTextCell(s.adresse),
            ),
            TableColumnSpec(
              label: 'Phone',
              sortValue: (s) => s.telephone,
              flex: 2,
              cell: (s) => saTextCell(s.telephone),
            ),
            TableColumnSpec(
              label: 'Status',
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
