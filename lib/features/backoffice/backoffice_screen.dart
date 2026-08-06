import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import 'data/backoffice_store.dart';
import 'data/firestore_backoffice_store.dart';
import 'models.dart';
import 'pages/dashboard_page.dart';
import 'pages/list_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';
import 'widgets/sheets.dart';
import 'widgets/toast.dart';

const List<String> _tabPages = [
  'dashboard',
  'clients',
  'collectes',
  'contrats',
];
const Set<String> _searchablePages = {
  'clients',
  'collecteurs',
  'contrats',
  'collectes',
  'facturation',
};

/// Mobile backoffice for the enterprise manager — faithful port of
/// `backoffice-mobile.html`. Uses the [BackofficeStore]; by default the
/// Firestore-backed store (real data + login accounts for clients and
/// collecteurs), the mock store is used by tests.
class BackofficeScreen extends StatefulWidget {
  const BackofficeScreen({super.key, this.store});

  /// Injectable store (used by tests); a Firestore-backed store is created
  /// otherwise.
  final BackofficeStore? store;

  @override
  State<BackofficeScreen> createState() => _BackofficeScreenState();
}

class _BackofficeScreenState extends State<BackofficeScreen> {
  late final BackofficeStore _store;
  final _searchCtrl = TextEditingController();
  String _page = 'dashboard';
  bool _menuOpen = false;
  bool _searchOpen = false;
  String _search = '';
  bool _toastInit = false;

  static const _titles = <String, String>{
    'dashboard': "Vue d'ensemble",
    'clients': 'Clients',
    'collecteurs': 'Collecteurs',
    'contrats': 'Contrats',
    'collectes': 'Collectes',
    'facturation': 'Facturation',
    'parametres': 'Paramètres',
  };

  @override
  void initState() {
    super.initState();
    // The Firestore store starts loading in its constructor; load() also
    // re-arms the listeners here (same pattern as the super admin console).
    _store = widget.store ?? FirestoreBackofficeStore();
    _store.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_toastInit) {
      _toastInit = true;
      BoToastService.init(context);
    }
  }

  @override
  void dispose() {
    // Only dispose the store we created ourselves; an injected store is
    // owned by its creator (e.g. tests).
    if (widget.store == null) _store.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- navigation ---

  void _goTo(String page) {
    setState(() {
      _page = page;
      _menuOpen = false;
      _searchOpen = false;
      _search = '';
      _searchCtrl.clear();
    });
  }

  String get _subtitle {
    switch (_page) {
      case 'clients':
        return '${_store.clients.length} enregistrés';
      case 'collecteurs':
        return '${_store.collecteurs.length} agents';
      case 'contrats':
        return '${_store.contrats.length} au total';
      case 'facturation':
        return '${_store.factures.length} factures';
      case 'parametres':
        return 'Configuration';
      default:
        return "Aujourd'hui";
    }
  }

  BoEntity? get _fabEntity => switch (_page) {
    'clients' => BoEntity.client,
    'collecteurs' => BoEntity.collecteur,
    'contrats' => BoEntity.contrat,
    'collectes' => BoEntity.collecte,
    'facturation' => BoEntity.facture,
    _ => null,
  };

  void _openCreate() {
    final type = _fabEntity;
    if (type == null) return;
    showBoFormSheet(context, store: _store, type: type);
  }

  // --- build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BackofficeTheme.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _topbar(),
              _searchRow(),
              _statusBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_page),
                    child: _pageContent(),
                  ),
                ),
              ),
            ],
          ),
          // FAB
          if (_fabEntity != null)
            Positioned(right: 18, bottom: 100, child: _fab()),
          // Tab bar
          Positioned(left: 0, right: 0, bottom: 0, child: _tabbar()),
          // Side menu overlay + panel
          _menuOverlay(),
          _sideMenu(),
        ],
      ),
    );
  }

  Widget _pageContent() {
    switch (_page) {
      case 'clients':
        return BoListPage(
          store: _store,
          type: BoEntity.client,
          search: _search,
        );
      case 'collecteurs':
        return BoListPage(
          store: _store,
          type: BoEntity.collecteur,
          search: _search,
        );
      case 'contrats':
        return BoListPage(
          store: _store,
          type: BoEntity.contrat,
          search: _search,
        );
      case 'collectes':
        return BoListPage(
          store: _store,
          type: BoEntity.collecte,
          search: _search,
        );
      case 'facturation':
        return BoListPage(
          store: _store,
          type: BoEntity.facture,
          search: _search,
        );
      case 'parametres':
        return BoSettingsPage(store: _store);
      default:
        return BoDashboardPage(store: _store);
    }
  }

  // --- topbar ---

  Widget _topbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          _iconButton(
            key: const Key('bo_menu'),
            icon: Icons.menu_rounded,
            onTap: () => setState(() => _menuOpen = true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titles[_page]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BackofficeTheme.sora(17, weight: FontWeight.w700),
                  ),
                  Text(
                    _subtitle,
                    style: BackofficeTheme.inter(
                      11,
                      color: BackofficeTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_searchablePages.contains(_page)) ...[
            _iconButton(
              key: const Key('bo_search_toggle'),
              icon: Icons.search_rounded,
              onTap: () => setState(() => _searchOpen = !_searchOpen),
            ),
            const SizedBox(width: 8),
          ],
          _iconButton(
            key: const Key('bo_bell'),
            icon: Icons.notifications_none_rounded,
            dot: true,
            onTap: () => BoToastService.show('Aucune nouvelle notification'),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
    bool dot = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: BackofficeTheme.surface,
          border: Border.all(color: BackofficeTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 17, color: BackofficeTheme.green),
            if (dot)
              Positioned(
                top: 7,
                right: 8,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: BackofficeTheme.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- load status / error banner ---

  Widget _statusBar() {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        if (_store.isLoading) {
          return const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: BackofficeTheme.gold,
          );
        }
        if (_store.error != null) {
          return Container(
            width: double.infinity,
            color: BackofficeTheme.redSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 15,
                  color: BackofficeTheme.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _store.error!,
                    style: BackofficeTheme.inter(
                      11.5,
                      color: BackofficeTheme.red,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _store.load,
                  style: TextButton.styleFrom(
                    foregroundColor: BackofficeTheme.red,
                    textStyle: BackofficeTheme.inter(
                      11.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // --- search row ---

  Widget _searchRow() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: _searchOpen
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: BackofficeTheme.surface,
                  border: Border.all(color: BackofficeTheme.border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 15,
                      color: BackofficeTheme.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('bo_search'),
                        controller: _searchCtrl,
                        autofocus: true,
                        style: BackofficeTheme.inter(13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Rechercher...',
                          hintStyle: TextStyle(
                            color: BackofficeTheme.muted,
                            fontSize: 13,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _search = v.trim().toLowerCase()),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  // --- FAB ---

  Widget _fab() {
    return FloatingActionButton(
      key: const Key('bo_fab'),
      onPressed: _openCreate,
      elevation: 6,
      backgroundColor: BackofficeTheme.gold,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 24, color: Color(0xFF2A1B05)),
    );
  }

  // --- tab bar ---

  Widget _tabbar() {
    final moreActive = !_tabPages.contains(_page);
    return Container(
      decoration: BoxDecoration(
        color: BackofficeTheme.surface.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: BackofficeTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Row(
            children: [
              _tabItem('dashboard', Icons.home_rounded, 'Accueil'),
              _tabItem('clients', Icons.people_outline_rounded, 'Clients'),
              _tabItem('collectes', Icons.event_note_rounded, 'Collectes'),
              _tabItem('contrats', Icons.description_outlined, 'Contrats'),
              _tabItem(
                'more',
                Icons.more_horiz_rounded,
                'Plus',
                forceActive: moreActive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabItem(
    String page,
    IconData icon,
    String label, {
    bool forceActive = false,
  }) {
    final active = forceActive || _page == page;
    return Expanded(
      child: InkWell(
        key: Key('bo_tab_$page'),
        onTap: () {
          if (page == 'more') {
            setState(() => _menuOpen = true);
          } else {
            _goTo(page);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? BackofficeTheme.green : BackofficeTheme.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: BackofficeTheme.inter(
                  9,
                  weight: FontWeight.w600,
                  color: active ? BackofficeTheme.green : BackofficeTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- side menu ---

  Widget _menuOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_menuOpen,
        child: AnimatedOpacity(
          opacity: _menuOpen ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onTap: () => setState(() => _menuOpen = false),
            child: const ColoredBox(color: Color(0x660A2A20)),
          ),
        ),
      ),
    );
  }

  Widget _sideMenu() {
    final width = math.min(MediaQuery.of(context).size.width * 0.78, 300.0);
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: AnimatedSlide(
        offset: _menuOpen ? Offset.zero : const Offset(-1, 0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: Container(
          color: BackofficeTheme.green,
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 22),
                  child: Row(
                    children: [
                      Icon(
                        Icons.recycling_rounded,
                        size: 26,
                        color: BackofficeTheme.gold,
                      ),
                      SizedBox(width: 9),
                      Text.rich(
                        TextSpan(
                          text: 'Propre',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: BackofficeTheme.cream,
                          ),
                          children: [
                            TextSpan(
                              text: '237',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontWeight: FontWeight.w700,
                                color: BackofficeTheme.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _menuItem('dashboard', Icons.home_rounded, "Vue d'ensemble"),
                _menuItem('clients', Icons.people_outline_rounded, 'Clients'),
                _menuItem(
                  'collecteurs',
                  Icons.person_search_rounded,
                  'Collecteurs',
                ),
                _menuItem('contrats', Icons.description_outlined, 'Contrats'),
                _menuItem('collectes', Icons.event_note_rounded, 'Collectes'),
                _menuItem(
                  'facturation',
                  Icons.payments_outlined,
                  'Facturation',
                ),
                _menuItem('parametres', Icons.settings_outlined, 'Paramètres'),
                const Spacer(),
                _menuFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(String page, IconData icon, String label) {
    final active = _page == page;
    return InkWell(
      key: Key('bo_menu_$page'),
      onTap: () => _goTo(page),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: active
            ? BackofficeTheme.gold.withValues(alpha: 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? BackofficeTheme.gold : const Color(0xBFE9F2ED),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: BackofficeTheme.inter(
                13.5,
                weight: FontWeight.w500,
                color: active ? BackofficeTheme.gold : const Color(0xBFE9F2ED),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuFooter() {
    // UserProvider lives above the backoffice in main.dart; in standalone
    // widget tests it may be absent, so we read it defensively.
    UserProvider? userProvider;
    try {
      userProvider = Provider.of<UserProvider>(context, listen: false);
    } catch (_) {
      userProvider = null;
    }
    final user = userProvider?.user;
    final label = user != null ? user.fullName : 'Admin';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1FE9F2ED))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(
                    12,
                    weight: FontWeight.w600,
                    color: BackofficeTheme.cream,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin',
                  style: BackofficeTheme.inter(
                    10.5,
                    color: const Color(0x80E9F2ED),
                  ),
                ),
              ],
            ),
          ),
          if (user != null)
            IconButton(
              key: const Key('bo_logout'),
              tooltip: 'Déconnexion',
              onPressed: () =>
                  Provider.of<UserProvider>(context, listen: false).logout(),
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0x80E9F2ED),
              ),
            ),
        ],
      ),
    );
  }
}
