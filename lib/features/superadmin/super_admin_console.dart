import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import 'command_palette.dart';
import 'data/platform_store.dart';
import 'pages/agences_page.dart';
import 'pages/overview_page.dart';
import 'pages/parametres_page.dart';
import 'pages/rapports_page.dart';
import 'pages/societes_page.dart';
import 'pages/utilisateurs_page.dart';
import 'theme.dart';
import 'widgets/app_toast.dart';

/// The Super Admin back-office console, ported from `super-admin-desktop.html`.
///
/// Responsive: on desktop the sidebar is fixed and can be collapsed; on
/// narrow screens (< 900px) it becomes a hamburger drawer so the console
/// stays usable on phones and small web windows.
class SuperAdminConsole extends StatefulWidget {
  const SuperAdminConsole({super.key, this.store});

  /// Optional store override — the real super admin login passes the
  /// Firestore-backed store here. When null, an in-memory mock store is
  /// used (dev preview / tests).
  final PlatformStore? store;

  @override
  State<SuperAdminConsole> createState() => _SuperAdminConsoleState();
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
}

class _SuperAdminConsoleState extends State<SuperAdminConsole> {
  late final PlatformStore _store = widget.store ?? PlatformStore();

  int _page = 0;
  bool _collapsed = false;
  bool _narrowResolved = false;
  bool _drawerOpen = false;

  final GlobalKey<SocietesPageState> _societesKey = GlobalKey();
  final GlobalKey<AgencesPageState> _agencesKey = GlobalKey();
  final GlobalKey<UtilisateursPageState> _utilisateursKey = GlobalKey();

  static const List<({String title, String sub})> _meta = [
    (title: "Vue d'ensemble", sub: 'Toutes sociétés confondues'),
    (title: 'Sociétés', sub: 'Gérer les sociétés clientes de la plateforme'),
    (title: 'Agences', sub: 'Toutes les agences, toutes sociétés confondues'),
    (
      title: 'Utilisateurs',
      sub: "Comptes Administrateurs et Responsables d'Agence",
    ),
    (title: 'Rapports', sub: 'Exports consolidés de la plateforme'),
    (title: 'Paramètres', sub: 'Configuration de la plateforme'),
  ];

  static const List<({IconData icon, String label})> _navItems = [
    (icon: Icons.speed_rounded, label: "Vue d'ensemble"),
    (icon: Icons.business_rounded, label: 'Sociétés'),
    (icon: Icons.storefront_rounded, label: 'Agences'),
    (icon: Icons.people_rounded, label: 'Utilisateurs'),
    (icon: Icons.description_rounded, label: 'Rapports'),
    (icon: Icons.settings_rounded, label: 'Paramètres'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time initialisation: auto-collapse the sidebar on narrow desktops.
    if (!_narrowResolved) {
      _narrowResolved = true;
      if (MediaQuery.sizeOf(context).width < 1050) _collapsed = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    // Only dispose the store we created ourselves; an injected store is
    // owned by its creator (e.g. AuthWrapper).
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  void _goToPage(int index, {bool closeDrawer = false}) {
    setState(() {
      _page = index;
      if (closeDrawer) _drawerOpen = false;
    });
  }

  void _openPalette() {
    showCommandPalette(
      context,
      navItems: [
        for (var i = 0; i < _navItems.length; i++)
          CmdItem(
            icon: _navItems[i].icon,
            label: _navItems[i].label,
            hint: 'Page',
            run: () => _goToPage(i),
          ),
      ],
      actionItems: [
        CmdItem(
          icon: Icons.add_rounded,
          label: 'Nouvelle société',
          hint: 'Créer',
          run: () {
            _goToPage(1);
            _societesKey.currentState?.openCreate();
          },
        ),
        CmdItem(
          icon: Icons.add_rounded,
          label: 'Nouvelle agence',
          hint: 'Créer',
          run: () {
            _goToPage(2);
            _agencesKey.currentState?.openCreate();
          },
        ),
        CmdItem(
          icon: Icons.add_rounded,
          label: 'Nouvel utilisateur',
          hint: 'Créer',
          run: () {
            _goToPage(3);
            _utilisateursKey.currentState?.openCreate();
          },
        ),
      ],
    );
  }

  void _handleExit() {
    if (Navigator.of(context).canPop()) {
      // Preview mode (pushed from the welcome screen).
      Navigator.of(context).pop();
    } else {
      context.read<UserProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Android system back: first close the mobile drawer if open, only
      // then allow the pop to happen.
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _drawerOpen) {
          setState(() => _drawerOpen = false);
        }
      },
      child: ChangeNotifierProvider.value(
      value: _store,
      child: Actions(
        actions: {
          _OpenPaletteIntent: CallbackAction<_OpenPaletteIntent>(
            onInvoke: (_) {
              _openPalette();
              return null;
            },
          ),
        },
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _OpenPaletteIntent(),
            SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _OpenPaletteIntent(),
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 900;
              // Leaving the mobile breakpoint with the drawer open would keep
              // stale state for the next mobile visit — reset it on the spot.
              if (!mobile && _drawerOpen) _drawerOpen = false;
              return Material(
                color: SuperAdminTheme.bg,
                child: Stack(
                  children: [
                    if (mobile)
                      _buildMobileLayout()
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSidebar(drawer: false),
                          Expanded(child: _buildMain(mobile: false)),
                        ],
                      ),
                    ToastService.host(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  // --- Layout helpers ---

  Widget _buildMain({required bool mobile}) {
    return Column(
      children: [
        _buildTopbar(mobile: mobile),
        // Consumer (not context.watch): this context sits above the
        // ChangeNotifierProvider the console creates for its pages.
        Consumer<PlatformStore>(
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
          child: IndexedStack(
            index: _page,
            children: [
              const OverviewPage(),
              SocietesPage(key: _societesKey),
              AgencesPage(key: _agencesKey),
              UtilisateursPage(key: _utilisateursKey),
              const RapportsPage(),
              const ParametresPage(),
            ],
          ),
        ),
      ],
    );
  }

  /// Mobile: the sidebar becomes a slide-in drawer over the content.
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        _buildMain(mobile: true),
        // Barrier
        AnimatedOpacity(
          opacity: _drawerOpen ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !_drawerOpen,
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: GestureDetector(
                onTap: () => setState(() => _drawerOpen = false),
              ),
            ),
          ),
        ),
        // Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: _drawerOpen ? 0 : -SuperAdminTheme.sidebarWidth,
          top: 0,
          bottom: 0,
          // A closed drawer must not stay reachable by keyboard / screen
          // readers — exclude it from focus while it is offscreen.
          child: ExcludeFocus(
            excluding: !_drawerOpen,
            child: _buildSidebar(drawer: true),
          ),
        ),
      ],
    );
  }

  // --- Sidebar ---

  Widget _buildSidebar({required bool drawer}) {
    final expanded = !_collapsed || drawer;
    return Material(
      color: SuperAdminTheme.ink,
      elevation: drawer ? 16 : 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: drawer
            ? SuperAdminTheme.sidebarWidth
            : (_collapsed
                ? SuperAdminTheme.sidebarWidthCollapsed
                : SuperAdminTheme.sidebarWidth),
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
                      Icons.recycling_rounded,
                      size: 16,
                      color: SuperAdminTheme.gold,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Propre',
                          style: SuperAdminTheme.sora(
                            15,
                            weight: FontWeight.w700,
                            color: SuperAdminTheme.cream,
                          ),
                          children: [
                            TextSpan(
                              text: '237',
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
                ],
              ),
            ),
            // Platform tag
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.gold.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 10,
                          color: SuperAdminTheme.gold,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'CONSOLE PLATEFORME',
                            overflow: TextOverflow.ellipsis,
                            style: SuperAdminTheme.inter(
                              9.5,
                              weight: FontWeight.w700,
                              color: SuperAdminTheme.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
            // Navigation
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _navItems.length; i++) ...[
                      if (i == 5 && expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                          child: Text(
                            'Système',
                            style: SuperAdminTheme.inter(
                              9.5,
                              weight: FontWeight.w600,
                              color: SuperAdminTheme.cream.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      _navItem(
                        i,
                        _navItems[i].icon,
                        _navItems[i].label,
                        drawer: drawer,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Collapse button (desktop only)
            if (!drawer)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: InkWell(
                  onTap: () => setState(() => _collapsed = !_collapsed),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: SuperAdminTheme.cream.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _collapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          size: 14,
                          color: SuperAdminTheme.cream.withValues(alpha: 0.5),
                        ),
                        if (expanded) ...[
                          const SizedBox(width: 4),
                          Text(
                            'Réduire',
                            style: SuperAdminTheme.inter(
                              12,
                              color: SuperAdminTheme.cream.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: SuperAdminTheme.inkLine)),
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
                    child: const Center(
                      child: Text(
                        'SA',
                        style: TextStyle(
                          color: SuperAdminTheme.gold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Super Admin',
                            overflow: TextOverflow.ellipsis,
                            style: SuperAdminTheme.inter(
                              12,
                              weight: FontWeight.w600,
                              color: SuperAdminTheme.cream,
                            ),
                          ),
                          Text(
                            'admin@propre237.cm',
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
                  ],
                  if (!expanded) const Spacer(),
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

  Widget _navItem(int index, IconData icon, String label,
      {required bool drawer}) {
    final active = _page == index;
    final expanded = !_collapsed || drawer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _goToPage(index, closeDrawer: drawer),
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
              if (expanded) ...[
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
            ],
          ),
        ),
      ),
    );
  }

  // --- Topbar ---

  Widget _buildTopbar({required bool mobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 28,
        vertical: 15,
      ),
      decoration: const BoxDecoration(
        color: SuperAdminTheme.bg,
        border: Border(bottom: BorderSide(color: SuperAdminTheme.border)),
      ),
      child: Row(
        children: [
          if (mobile) ...[
            _topIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Menu',
              onTap: () => setState(() => _drawerOpen = true),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _meta[_page].title,
                  overflow: TextOverflow.ellipsis,
                  style: SuperAdminTheme.sora(19, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _meta[_page].sub,
                  overflow: TextOverflow.ellipsis,
                  style: SuperAdminTheme.inter(
                    12,
                    color: SuperAdminTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Command palette trigger
          InkWell(
            onTap: _openPalette,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: mobile ? 38 : 240,
              height: 38,
              padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : 13),
              decoration: BoxDecoration(
                color: SuperAdminTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SuperAdminTheme.border),
              ),
              child: Row(
                mainAxisAlignment: mobile
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 13,
                    color: SuperAdminTheme.muted,
                  ),
                  if (!mobile) ...[
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Rechercher ou agir...',
                        overflow: TextOverflow.ellipsis,
                        style: SuperAdminTheme.inter(
                          12.5,
                          color: SuperAdminTheme.muted,
                        ),
                      ),
                    ),
                    _kbdChip('⌘K'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Notifications bell
          _topIconButton(
            icon: Icons.notifications_none_rounded,
            dot: true,
            tooltip: 'Notifications',
            onTap: () =>
                ToastService.show('Aucune notification pour le moment.'),
          ),
        ],
      ),
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool dot = false,
    String? tooltip,
  }) {
    Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: SuperAdminTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SuperAdminTheme.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 16, color: SuperAdminTheme.ink),
            if (dot)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SuperAdminTheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _kbdChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SuperAdminTheme.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: SuperAdminTheme.border),
      ),
      child: Text(
        text,
        style: SuperAdminTheme.inter(10.5, color: SuperAdminTheme.muted),
      ),
    );
  }
}

/// Thin banner shown under the topbar when the initial data load failed.
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
              textStyle: SuperAdminTheme.inter(
                12,
                weight: FontWeight.w600,
              ),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
