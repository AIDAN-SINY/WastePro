import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../routing.dart';
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
  const SuperAdminConsole({
    super.key,
    this.store,
    this.page,
    this.autoCreate,
  });

  /// Optional store override — the real super admin login passes the
  /// Firestore-backed store here. When null, an in-memory mock store is
  /// used (dev preview / tests).
  final PlatformStore? store;

  /// Page initiale depuis l'URL (`/console/:page`) — 'overview' | 'societes'
  /// | 'agences' | 'utilisateurs' | 'rapports' | 'parametres'.
  final String? page;

  /// Création à ouvrir automatiquement au rendu (depuis la palette
  /// de commandes) : 'societe' | 'agence' | 'utilisateur'.
  final String? autoCreate;

  @override
  State<SuperAdminConsole> createState() => _SuperAdminConsoleState();
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
}

class _SuperAdminConsoleState extends State<SuperAdminConsole> {
  late PlatformStore _store;

  /// Vrai quand la console a elle-même créé le store (mode mock / preview) :
  /// dans ce cas seul, elle le dispose. Un store partagé/injecté appartient
  /// à son créateur (ConsoleStoreScope, AuthWrapper, tests) et ne doit
  /// jamais être disposé par la console — sinon le store Firestore partagé
  /// serait détruit au logout et « used after being disposed » au login
  /// suivant.
  late bool _ownsStore;

  late int _page = consolePageIndex(widget.page);
  bool _collapsed = false;
  bool _narrowResolved = false;
  bool _drawerOpen = false;

  final GlobalKey<SocietesPageState> _societesKey = GlobalKey();
  final GlobalKey<AgencesPageState> _agencesKey = GlobalKey();
  final GlobalKey<UtilisateursPageState> _utilisateursKey = GlobalKey();

  static const List<({String title, String sub})> _meta = [
    (title: 'Overview', sub: 'Across all companies'),
    (title: 'Companies', sub: 'Manage the platform client companies'),
    (title: 'Agencies', sub: 'All agencies, across all companies'),
    (title: 'Users', sub: 'Administrator and Agency Manager accounts'),
    (title: 'Reports', sub: 'Consolidated platform exports'),
    (title: 'Settings', sub: 'Platform configuration'),
  ];

  static const List<({IconData icon, String label})> _navItems = [
    (icon: Icons.speed_rounded, label: 'Overview'),
    (icon: Icons.business_rounded, label: 'Companies'),
    (icon: Icons.storefront_rounded, label: 'Agencies'),
    (icon: Icons.people_rounded, label: 'Users'),
    (icon: Icons.description_rounded, label: 'Reports'),
    (icon: Icons.settings_rounded, label: 'Settings'),
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
    _bindStore();
    _store.load();
    // Ouvre le drawer de création demandé via l'URL (?create=) après le
    // premier rendu (les pages doivent être présentes dans l'IndexedStack).
    final autoCreate = widget.autoCreate;
    if (autoCreate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyAutoCreate(autoCreate);
      });
    }
  }

  /// Lie le store fourni (partagé, ex. console connectée) ou en crée un
  /// (mock, preview debug / tests) et mémorise qui en est propriétaire.
  void _bindStore() {
    _ownsStore = widget.store == null;
    _store = widget.store ?? PlatformStore();
  }

  @override
  void didUpdateWidget(SuperAdminConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le store peut changer au fil de la vie de la console (session réelle →
    // preview debug après logout, ou l'inverse après login) : on libère le
    // store qu'on possédait (jamais un store partagé) et on s'aligne sur le
    // nouveau. Sans ça, la console continuerait d'utiliser un store mort.
    // Le `load()` re-arme les listeners : nécessaire quand on passe d'un
    // mock (rien à charger) à un store Firestore partagé en cours de
    // session ; inoffensif dans l'autre sens (load() annule et re-crée ses
    // abonnements).
    if (oldWidget.store != widget.store) {
      if (_ownsStore) _store.dispose();
      _bindStore();
      _store.load();
    }
    // Le routeur réutilise la même instance quand l'URL change
    // (/console/overview → /console/societes) : initState ne se
    // ré-exécute pas. On resynchronise donc la page affichée depuis le
    // nouveau paramètre d'URL — sinon l'IndexedStack reste sur l'ancienne
    // page jusqu'au rechargement manuel (F5).
    if (widget.page != oldWidget.page) {
      _page = consolePageIndex(widget.page);
    }
    // Si l'instance est réutilisée avec une nouvelle action (?create=),
    // initState ne se ré-exécute pas → on applique ici.
    final autoCreate = widget.autoCreate;
    if (autoCreate != null && autoCreate != oldWidget.autoCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyAutoCreate(autoCreate);
      });
    }
  }

  @override
  void dispose() {
    // Only dispose the store we created ourselves; a shared/injected store
    // is owned by its creator (ConsoleStoreScope / AuthWrapper / tests).
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  /// Navigue vers une page. Sur la route `/console/...` (app web), chaque
  /// page devient une URL (`/console/societes`…) : bouton retour du
  /// navigateur, rechargement et liens partageables fonctionnent. Hors
  /// route console (preview pushée / tests), la navigation reste interne.
  void _goToPage(int index, {bool closeDrawer = false, String? intent}) {
    final router = GoRouter.maybeOf(context);
    final isConsoleRoute = router != null &&
        router.routeInformationProvider.value.uri.path
            .startsWith(consoleBasePath);

    if (!isConsoleRoute) {
      setState(() {
        _page = index;
        if (closeDrawer) _drawerOpen = false;
      });
      if (intent != null) _applyAutoCreate(intent);
      return;
    }

    // Déjà sur la page cible avec une action (palette) : on l'applique
    // directement — une navigation query-only relancerait la route sans
    // ré-exécuter initState.
    if (index == _page && intent != null) {
      _applyAutoCreate(intent);
      return;
    }

    final page = consolePageNames[index];
    router.go(
      intent != null
          ? '$consoleBasePath/$page?create=$intent'
          : '$consoleBasePath/$page',
    );
  }

  /// Ouvre le drawer de création ciblé (utilisé par la palette et par le
  /// paramètre d'URL `?create=` après une navigation).
  void _applyAutoCreate(String intent) {
    switch (intent) {
      case 'societe':
        _societesKey.currentState?.openCreate();
        break;
      case 'agence':
        _agencesKey.currentState?.openCreate();
        break;
      case 'utilisateur':
        _utilisateursKey.currentState?.openCreate();
        break;
    }
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
          label: 'New company',
          hint: 'Create',
          run: () => _goToPage(1, intent: 'societe'),
        ),
        CmdItem(
          icon: Icons.add_rounded,
          label: 'New agency',
          hint: 'Create',
          run: () => _goToPage(2, intent: 'agence'),
        ),
        CmdItem(
          icon: Icons.add_rounded,
          label: 'New user',
          hint: 'Create',
          run: () => _goToPage(3, intent: 'utilisateur'),
        ),
      ],
    );
  }

  void _handleExit() {
    // Defensive read: standalone widget tests / previews may not provide a
    // UserProvider above the console.
    UserProvider? userProvider;
    try {
      userProvider = context.read<UserProvider>();
    } catch (_) {
      userProvider = null;
    }

    final hasSession = userProvider?.user != null;
    final router = GoRouter.maybeOf(context);

    if (hasSession) {
      // Real session: sign out AND explicitly leave the console route. In
      // debug builds the console preview (allowConsolePreview) keeps
      // /console/* reachable without a session, so the router redirect
      // alone would NOT fire after logout — the console would stay mounted
      // (swapping to the mock store) and the button would appear to do
      // nothing. Going to '/' explicitly is what actually takes the user
      // back to the welcome screen.
      userProvider!.logout();
      if (router != null) {
        router.go('/');
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else if (Navigator.of(context).canPop()) {
      // Preview mode (pushed from the welcome screen): pop back.
      Navigator.of(context).pop();
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
          child: Padding(
            // Marge horizontale constante du contenu : aligne toutes les
            // pages (cartes, tableaux, KPIs) avec le topbar et évite que le
            // contenu ne colle à la sidebar.
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 28,
              16,
              mobile ? 16 : 28,
              0,
            ),
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
                          text: 'Waste',
                          style: SuperAdminTheme.sora(
                            15,
                            weight: FontWeight.w700,
                            color: SuperAdminTheme.cream,
                          ),
                          children: [
                            TextSpan(
                              text: 'Pro',
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
                          child:                          Text(
                            'PLATFORM CONSOLE',
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
                          child:                          Text(
                            'System',
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
                            'Collapse',
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
                            'admin@wastepro.cm',
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
                        'Search or take action...',
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
                ToastService.show('No notifications at the moment.'),
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
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
