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
    'Tous',
    'Admins',
    "Resp. d'agence",
  ];
  static const List<String> _roleOptions = [
    'Administrateur Général',
    "Responsable d'Agence",
  ];

  int _filter = 0;
  final Map<String, dynamic> _form = {};

  List<String> get _agenceOptions {
    final agences =
        context.read<PlatformStore>().agences.map((a) => a.ville).toList();
    return ['—', ...agences];
  }

  /// Opens the "Nouvel utilisateur" drawer (used by the command palette).
  void openCreate() {
    _form
      ..clear()
      ..['status'] = 'Actif'
      ..['role'] = "Responsable d'Agence"
      ..['agence'] = '—';
    showCrudDrawer(
      context,
      title: 'Nouvel utilisateur',
      body: _buildForm(_agenceOptions),
      onSave: () async {
        try {
          final nom = requireField(_form, 'nom', 'Nom complet');
          // Le super admin fixe le mot de passe initial (pas d'envoi par
          // mail pour l'instant) : l'utilisateur s'en servira pour se loguer.
          final password = requireField(_form, 'password', 'Mot de passe');
          await context.read<PlatformStore>().addUtilisateur(
                nom: nom,
                telephone: _form['telephone']?.toString().trim() ?? '',
                role: _form['role']?.toString() ?? _roleOptions[0],
                agence: _form['agence']?.toString() ?? '—',
                status: _form['status']?.toString() ?? 'Actif',
                password: password,
              );
          ToastService.show(
            'Utilisateur créé avec succès. Il peut se connecter avec son '
            'numéro et ce mot de passe.',
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
      title: "Modifier l'utilisateur",
      body: _buildForm(_agenceOptions),
      onSave: () async {
        try {
          final nom = requireField(_form, 'nom', 'Nom complet');
          // Champ vide à l'édition = garder le mot de passe actuel.
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
          ToastService.show('Modifications enregistrées.');
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
      title: "Supprimer cet utilisateur ?",
      message:
          '"${user.nom}" sera définitivement supprimé. Cette action est irréversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<PlatformStore>().deleteUtilisateur(user.id);
        if (mounted) ToastService.show('Élément supprimé.');
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
          label: 'Nom complet',
          initial: _form['nom']?.toString(),
          hint: 'Ex. Marie Ekwalla',
          onChanged: (v) => _form['nom'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Téléphone',
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
                label: 'Rôle',
                options: _roleOptions,
                initial: _form['role']?.toString(),
                onChanged: (v) => _form['role'] = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SaSelectField(
                label: 'Agence rattachée',
                options: agenceOptions,
                initial: _form['agence']?.toString(),
                onChanged: (v) => _form['agence'] = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Mot de passe',
          initial: _form['password']?.toString(),
          hint: 'Le mot de passe de connexion de cet utilisateur',
          obscureText: true,
          onChanged: (v) => _form['password'] = v,
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
    final roleFilter = _filter == 1
        ? _roleOptions[0]
        : (_filter == 2 ? _roleOptions[1] : null);
    final rows = roleFilter == null
        ? store.utilisateurs
        : store.utilisateurs.where((u) => u.role == roleFilter).toList();

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
            label: 'Nouvel utilisateur',
            icon: Icons.add_rounded,
            onTap: openCreate,
          ),
        ),
        const SizedBox(height: 16),
        AppTable<PlatformUserModel>(
          rows: rows,
          emptyText: 'Aucun utilisateur trouvé',
          footer: '${rows.length} utilisateur${rows.length > 1 ? 's' : ''}',
          columns: [
            TableColumnSpec(
              label: 'Utilisateur',
              sortValue: (u) => u.nom,
              flex: 3,
              cell: (u) => saNameCell(u.nom),
            ),
            TableColumnSpec(
              label: 'Rôle',
              sortValue: (u) => u.role,
              flex: 2,
              cell: (u) => saTextCell(u.role),
            ),
            TableColumnSpec(
              label: 'Agence',
              sortValue: (u) => u.agence,
              flex: 2,
              cell: (u) => saTextCell(u.agence),
            ),
            TableColumnSpec(
              label: 'Statut',
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
