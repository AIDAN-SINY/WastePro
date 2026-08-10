import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../models/agence_model.dart';
import '../../models/platform_user_model.dart';
import '../superadmin/theme.dart';
import '../superadmin/widgets/app_table.dart';
import '../superadmin/widgets/app_toast.dart';
import '../superadmin/widgets/cells.dart';
import '../superadmin/widgets/confirm_dialog.dart';
import '../superadmin/widgets/crud_drawer.dart';
import '../superadmin/widgets/form_fields.dart';
import '../superadmin/widgets/form_validation.dart';
import '../superadmin/widgets/primary_button.dart';
import '../superadmin/widgets/status_badge.dart';
import 'data/company_store.dart';
import 'data/firestore_company_store.dart';

/// Console entreprise — General Administrator.
///
/// Phase 2 : gestion des agences et des chefs d'agence de l'entreprise.
/// Les données sont scopées par [societeId] (l'id de l'entreprise
/// de l'administrateur, stocké dans `users/{phone}/societeId`).
class CompanyConsole extends StatefulWidget {
  const CompanyConsole({super.key, this.societeId, this.store});

  /// Id de l'entreprise de l'administrateur connecté. '' en preview démo.
  final String? societeId;

  /// Store injecté (tests) ; sinon créé paresseusement.
  final CompanyStore? store;

  @override
  State<CompanyConsole> createState() => _CompanyConsoleState();
}

class _CompanyConsoleState extends State<CompanyConsole> {
  late CompanyStore _store;
  late bool _ownsStore;
  int _page = 0;
  bool _narrow = false;

  static const _navItems = [
    (icon: Icons.speed_rounded, label: 'Overview'),
    (icon: Icons.storefront_rounded, label: 'Agencies'),
    (icon: Icons.people_rounded, label: 'Managers'),
  ];
  static const _meta = [
    (title: 'Overview', sub: 'Your company at a glance'),
    (title: 'Agencies', sub: 'Manage your agencies'),
    (title: 'Managers', sub: 'Agency managers'),
  ];

  @override
  void initState() {
    super.initState();
    _bindStore();
    _store.load();
  }

  void _bindStore() {
    _ownsStore = widget.store == null;
    final sid = widget.societeId ?? '';
    _store = widget.store ??
        (sid.isNotEmpty
            ? FirestoreCompanyStore(societeId: sid)
            : CompanyStore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_narrow) {
      if (MediaQuery.sizeOf(context).width < 900) _narrow = true;
    }
  }

  @override
  void dispose() {
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  void _handleExit() {
    UserProvider? userProvider;
    try {
      userProvider = context.read<UserProvider>();
    } catch (_) {
      userProvider = null;
    }
    if (userProvider?.user != null) {
      userProvider!.logout();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // --- Demo detection ---
  bool get _isDemo => _store is! FirestoreCompanyStore;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _store,
      child: Material(
        color: SuperAdminTheme.bg,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(),
                Expanded(child: _buildMain()),
              ],
            ),
            // Toasts (succès/erreur des actions) — obligatoire pour que
            // ToastService.show() soit visible.
            ToastService.host(),
          ],
        ),
      ),
    );
  }

  // --- Sidebar ---

  Widget _buildSidebar() {
    return Material(
      color: SuperAdminTheme.ink,
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      size: 16,
                      color: SuperAdminTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Company',
                        style: SuperAdminTheme.sora(
                          15,
                          weight: FontWeight.w700,
                          color: SuperAdminTheme.cream,
                        ),
                        children: [
                          TextSpan(
                            text: ' Console',
                            style: SuperAdminTheme.sora(
                              15,
                              weight: FontWeight.w700,
                              color: SuperAdminTheme.gold,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Navigation
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _navItems.length; i++)
                      _navItem(i, _navItems[i].icon, _navItems[i].label),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 18),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: SuperAdminTheme.inkLine),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.gold.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Consumer<CompanyStore>(
                        builder: (context, store, _) => Text(
                          saInitials(store.societeNom.isNotEmpty
                              ? store.societeNom
                              : 'Company'),
                          style: const TextStyle(
                            color: SuperAdminTheme.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Consumer<CompanyStore>(
                      builder: (context, store, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.societeNom.isNotEmpty
                                ? store.societeNom
                                : 'My Company',
                            overflow: TextOverflow.ellipsis,
                            style: SuperAdminTheme.inter(
                              12,
                              weight: FontWeight.w600,
                              color: SuperAdminTheme.cream,
                            ),
                          ),
                          Text(
                            'General Administrator',
                            overflow: TextOverflow.ellipsis,
                            style: SuperAdminTheme.inter(
                              10,
                              color: SuperAdminTheme.cream.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _handleExit,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: SuperAdminTheme.cream.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _page == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => setState(() => _page = index),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? SuperAdminTheme.gold.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active
                ? Border.all(
                    color: SuperAdminTheme.gold.withValues(alpha: 0.32),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? SuperAdminTheme.gold
                    : SuperAdminTheme.cream.withValues(alpha: 0.62),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: SuperAdminTheme.inter(
                    13,
                    weight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active
                        ? SuperAdminTheme.gold
                        : SuperAdminTheme.cream.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Main ---

  Widget _buildMain() {
    return Column(
      children: [
        _buildTopbar(),
        if (_isDemo) const _DemoBanner(),
        Consumer<CompanyStore>(
          builder: (context, store, _) {
            if (store.isLoading) {
              return const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: SuperAdminTheme.gold,
              );
            }
            if (store.error != null) {
              return _ErrorBanner(
                message: store.error!,
                onRetry: store.load,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
            child: IndexedStack(
              index: _page,
              children: const [
                _OverviewPage(),
                _AgenciesPage(),
                _ManagersPage(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      decoration: const BoxDecoration(
        color: SuperAdminTheme.bg,
        border: Border(bottom: BorderSide(color: SuperAdminTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _meta[_page].title,
                  style: SuperAdminTheme.sora(19, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _meta[_page].sub,
                  style: SuperAdminTheme.inter(
                    12,
                    color: SuperAdminTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Bandeau démo ---

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: SuperAdminTheme.gold.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 15,
            color: SuperAdminTheme.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demo preview — changes are not saved. Log in as a '
              'General Administrator to manage your company.',
              style: SuperAdminTheme.inter(12, color: SuperAdminTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Bannière d'erreur ---

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: SuperAdminTheme.redSoft,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 15,
            color: SuperAdminTheme.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: SuperAdminTheme.inter(12, color: SuperAdminTheme.red),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: SuperAdminTheme.red,
              textStyle: SuperAdminTheme.inter(12, weight: FontWeight.w600),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Pages
// ====================================================================

// --- Overview ---

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CompanyStore>();
    final nom = store.societeNom.isNotEmpty ? store.societeNom : 'Your Company';
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // KPI row
        Row(
          children: [
            Expanded(child: _KpiCard('Agencies', '${store.agences.length}')),
            const SizedBox(width: 16),
            Expanded(
              child: _KpiCard(
                'Managers',
                '${store.utilisateurs.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Company info card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: SuperAdminTheme.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nom,
                style: SuperAdminTheme.sora(18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'General Administrator',
                style: SuperAdminTheme.inter(
                  12,
                  color: SuperAdminTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SuperAdminTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SuperAdminTheme.inter(
              12,
              color: SuperAdminTheme.muted,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: SuperAdminTheme.sora(
              32,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Agences ---

class _AgenciesPage extends StatefulWidget {
  const _AgenciesPage();

  @override
  State<_AgenciesPage> createState() => _AgenciesPageState();
}

class _AgenciesPageState extends State<_AgenciesPage> {
  final Map<String, dynamic> _form = {};

  void openCreate() {
    _form
      ..clear()
      ..['status'] = 'Active';
    showCrudDrawer(
      context,
      title: 'New agency',
      body: _buildForm(),
      onSave: () async {
        try {
          final ville = requireField(_form, 'ville', 'City');
          await context.read<CompanyStore>().addAgence(
                ville: ville,
                responsable:
                    _form['responsable']?.toString().trim() ?? '',
                telephone:
                    _form['telephone']?.toString().trim() ?? '',
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
      body: _buildForm(),
      onSave: () async {
        try {
          final ville = requireField(_form, 'ville', 'City');
          await context.read<CompanyStore>().updateAgence(
                agence.copyWith(
                  ville: ville,
                  responsable:
                      _form['responsable']?.toString().trim(),
                  telephone:
                      _form['telephone']?.toString().trim(),
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

  Future<void> confirmDelete(AgenceModel agence) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this agency?',
      message:
          '"${agence.ville}" will be permanently deleted. This action is irreversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<CompanyStore>().deleteAgence(agence.id);
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
    final store = context.watch<CompanyStore>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Row(
          children: [
            const Spacer(),
            PrimaryButton(
              label: 'New agency',
              icon: Icons.add_rounded,
              onTap: store is! FirestoreCompanyStore
                  ? () => ToastService.show(
                        'Demo preview — log in as a General Administrator '
                        'to create agencies.',
                        isError: true,
                      )
                  : openCreate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTable<AgenceModel>(
          rows: store.agences,
          emptyText: 'No agencies yet',
          footer: '${store.agences.length} agenc${store.agences.length > 1 ? 'ies' : 'y'}',
          columns: [
            TableColumnSpec(
              label: 'Agency',
              sortValue: (a) => a.ville,
              flex: 3,
              cell: (a) => saNameCell(a.ville),
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
          onRowTap: openEdit,
        ),
      ],
    );
  }
}

// --- Managers ---

class _ManagersPage extends StatefulWidget {
  const _ManagersPage();

  @override
  State<_ManagersPage> createState() => _ManagersPageState();
}

class _ManagersPageState extends State<_ManagersPage> {
  final Map<String, dynamic> _form = {};

  List<String> get _agenceOptions {
    final agences = context.read<CompanyStore>().agences.map((a) => a.ville).toList();
    return ['—', ...agences];
  }

  String _agenceIdFor(String ville) {
    for (final a in context.read<CompanyStore>().agences) {
      if (a.ville == ville) return a.id;
    }
    return '';
  }

  void openCreate() {
    _form
      ..clear()
      ..['status'] = 'Active'
      ..['role'] = 'Agency Manager'
      ..['agence'] = '—';
    showCrudDrawer(
      context,
      title: 'New manager',
      body: _buildForm(),
      onSave: () async {
        try {
          final nom = requireField(_form, 'nom', 'Full name');
          final telephone = requireField(_form, 'telephone', 'Phone');
          final password = requireField(_form, 'password', 'Password');
          // Flow validé : chaque chef d'agence est assigné à une agence.
          // Sans agence, son compte serait créé mais le backoffice serait
          // vide (aucune donnée ne lui appartiendrait).
          final agenceVille = _form['agence']?.toString() ?? '—';
          if (agenceVille == '—') {
            throw 'Please assign this manager to an agency.';
          }
          await context.read<CompanyStore>().addUtilisateur(
                nom: nom,
                telephone: telephone,
                role: 'Agency Manager',
                agence: agenceVille,
                agenceId: _agenceIdFor(agenceVille),
                status: _form['status']?.toString() ?? 'Active',
                password: password,
              );
          ToastService.show(
            'Manager created. They can log in with their number and '
            'this password.',
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
      ..remove('password');
    showCrudDrawer(
      context,
      title: 'Edit manager',
      body: _buildForm(),
      onSave: () async {
        try {
          final nom = requireField(_form, 'nom', 'Full name');
          final telephone = requireField(_form, 'telephone', 'Phone');
          final password = _form['password']?.toString().trim() ?? '';
          final agenceVille = _form['agence']?.toString() ?? '—';
          if (agenceVille == '—') {
            throw 'Please assign this manager to an agency.';
          }
          await context.read<CompanyStore>().updateUtilisateur(
                user.copyWith(
                  nom: nom,
                  telephone: telephone,
                  agence: agenceVille,
                  agenceId: _agenceIdFor(agenceVille),
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
      title: 'Delete this manager?',
      message:
          '"${user.nom}" will be permanently deleted. This action is irreversible.',
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<CompanyStore>().deleteUtilisateur(user.id);
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
          label: 'Full name',
          initial: _form['nom']?.toString(),
          hint: 'Ex. Jean Dooh',
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
        SaSelectField(
          label: 'Agency',
          options: _agenceOptions,
          initial: _form['agence']?.toString(),
          onChanged: (v) => _form['agence'] = v,
        ),
        const SizedBox(height: 16),
        SaTextField(
          label: 'Password',
          initial: _form['password']?.toString(),
          hint: 'Login password',
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
    final store = context.watch<CompanyStore>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Row(
          children: [
            const Spacer(),
            PrimaryButton(
              label: 'New manager',
              icon: Icons.add_rounded,
              onTap: store is! FirestoreCompanyStore
                  ? () => ToastService.show(
                        'Demo preview — log in as a General Administrator '
                        'to create managers.',
                        isError: true,
                      )
                  : openCreate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTable<PlatformUserModel>(
          rows: store.utilisateurs,
          emptyText: 'No managers yet',
          footer: '${store.utilisateurs.length} manager${store.utilisateurs.length > 1 ? 's' : ''}',
          columns: [
            TableColumnSpec(
              label: 'Name',
              sortValue: (u) => u.nom,
              flex: 3,
              cell: (u) => saNameCell(u.nom),
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