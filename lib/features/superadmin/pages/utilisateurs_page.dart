import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/platform_user_model.dart';
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

class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key});

  @override
  State<UtilisateursPage> createState() => UtilisateursPageState();
}

class UtilisateursPageState extends State<UtilisateursPage> {
  static const List<String> _filters = [
    'All',
    'Admins',
    'Agency managers',
  ];
  static const List<String> _roleOptions = [
    'General Administrator',
    'Agency Manager',
  ];

  int _filter = 0;
  final Map<String, dynamic> _form = {};

  List<String> get _agenceOptions {
    final agences =
        context.read<PlatformStore>().agences.map((a) => a.ville).toList();
    return ['—', ...agences];
  }

  /// Opens the "New user" drawer (used by the command palette).
  void openCreate() {
    _form
      ..clear()
      ..['status'] = 'Active'
      ..['role'] = 'Agency Manager'
      ..['agence'] = '—';
    showCrudDrawer(
      context,
      title: 'New user',
      body: _buildForm(_agenceOptions),
      onSave: () async {
        try {
          final nom = requireField(_form, 'nom', 'Full name');
          // The super admin sets the initial password (no email yet): the
          // user will use it to log in.
          final password = requireField(_form, 'password', 'Password');
          await context.read<PlatformStore>().addUtilisateur(
                nom: nom,
                telephone: _form['telephone']?.toString().trim() ?? '',
                role: _form['role']?.toString() ?? _roleOptions[0],
                agence: _form['agence']?.toString() ?? '—',
                status: _form['status']?.toString() ?? 'Active',
                password: password,
              );
          ToastService.show(
            'User created successfully. They can log in with their '
            'number and this password.',
          );
        } catch (e) {
          ToastService.show(e.toString(), isError: true);
          rethrow;
        }
      },
    );
  }

  void openEdit(PlatformUserModel user) {
    _form
      ..clear()
      ..addAll(user.toMap())
      // Le mot de passe n'est pas pré-rempli : champ vide = conserver
      // le mot de passe actuel.
      ..remove('password');
    showCrudDrawer(
      context,
      title: 'Edit user',
      body: _buildForm(_agenceOptions),
      onSave: () async {
        try {
          final nom = requireField(_form, 'nom', 'Full name');
          // Empty field when editing = keep the current password.
          final password = _form['password']?.toString().trim() ?? '';
          await context.read<PlatformStore>().updateUtilisateur(
                user.copyWith(
                  nom: nom,
                  telephone: _form['telephone']?.toString().trim(),
                  role: _form['role']?.toString(),
                  agence: _form['agence']?.toString(),
                  status: _form['status']?.toString(),
                  password: password.isEmpty ? user.password : password,
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

  Future<void> confirmDelete(PlatformUserModel user) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this user?',
      message:
          '"${user.nom}" will be permanently deleted. This action is irreversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<PlatformStore>().deleteUtilisateur(user.id);
        if (mounted) ToastService.show('Item deleted.');
      } catch (e) {
        if (mounted) ToastService.show(e.toString(), isError: true);
      }
    }
  }

  Widget _buildForm(List<String> agenceOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SaTextField(
          label: 'Full name',
          initial: _form['nom']?.toString(),
          hint: 'Ex. Marie Ekwalla',
          onChanged: (v) => _form['nom'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Phone',
          initial: _form['telephone']?.toString(),
          hint: '+237 6XX XX XX XX',
          keyboardType: TextInputType.phone,
          onChanged: (v) => _form['telephone'] = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SaSelectField(
                label: 'Role',
                options: _roleOptions,
                initial: _form['role']?.toString(),
                onChanged: (v) => _form['role'] = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SaSelectField(
                label: 'Linked agency',
                options: agenceOptions,
                initial: _form['agence']?.toString(),
                onChanged: (v) => _form['agence'] = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Password',
          initial: _form['password']?.toString(),
          hint: 'This user login password',
          obscureText: true,
          onChanged: (v) => _form['password'] = v,
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
    final roleFilter = _filter == 1
        ? _roleOptions[0]
        : (_filter == 2 ? _roleOptions[1] : null);
    // Match both the English roles and the legacy French ones
    // ('Administrateur Général' / "Responsable d'Agence").
    bool roleMatches(String role) => roleFilter == null || switch (roleFilter) {
      'General Administrator' =>
        role == 'General Administrator' || role == 'Administrateur Général',
      _ => role == 'Agency Manager' || role == "Responsable d'Agence",
    };
    final rows = roleFilter == null
        ? store.utilisateurs
        : store.utilisateurs.where((u) => roleMatches(u.role)).toList();

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
            label: 'New user',
            icon: Icons.add_rounded,
            onTap: openCreate,
          ),
        ),
        const SizedBox(height: 16),
        AppTable<PlatformUserModel>(
          rows: rows,
          emptyText: 'No users found',
          footer: '${rows.length} user${rows.length > 1 ? 's' : ''}',
          columns: [
            TableColumnSpec(
              label: 'User',
              sortValue: (u) => u.nom,
              flex: 3,
              cell: (u) => saNameCell(u.nom),
            ),
            TableColumnSpec(
              label: 'Role',
              sortValue: (u) => u.role,
              flex: 2,
              cell: (u) => saTextCell(u.role),
            ),
            TableColumnSpec(
              label: 'Agency',
              sortValue: (u) => u.agence,
              flex: 2,
              cell: (u) => saTextCell(u.agence),
            ),
            TableColumnSpec(
              label: 'Status',
              sortValue: (u) => u.status,
              flex: 1,
              cell: (u) => StatusBadge(status: u.status),
            ),
          ],
          actions: (u) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RowActionButton(
                icon: Icons.edit_rounded,
                onTap: () => openEdit(u),
              ),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                onTap: () => confirmDelete(u),
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
