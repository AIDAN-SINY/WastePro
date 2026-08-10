import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../backoffice/models.dart';
import '../backoffice/theme.dart';
import '../backoffice/widgets/toast.dart';
import 'data/collector_store.dart';
import 'data/firestore_collector_store.dart';

/// Dashboard du collecteur — **mobile-first et responsive web**.
///
/// Sur mobile : topbar verte + contenu + barre d'onglets en bas (Today /
/// History / Profile). Sur desktop (≥ 900 px) : sidebar fixe + topbar, comme
/// les autres consoles web.
///
/// L'app est **opérationnelle** : la tournée du jour vient des vraies
/// collectes Firestore du collecteur, et chaque collecte peut être marquée
/// « Completed » (poids + commentaire) ou « Missed » (motif) — persisté.
class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key, this.store});

  /// Store injecté par les tests (mock) — sinon un [FirestoreCollectorStore]
  /// est créé avec le téléphone de l'utilisateur connecté.
  final CollectorStore? store;

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  late CollectorStore _store;
  late bool _ownsStore;
  int _tab = 0; // 0 Today · 1 History · 2 Profile
  String _filter = 'all'; // 'all' | 'pending' | 'done' | 'missed'
  bool _toastInit = false;

  static const List<(int, IconData, String)> _tabs = [
    (0, Icons.checklist_rounded, 'Today'),
    (1, Icons.history_rounded, 'History'),
    (2, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? _createFirestoreStore();
    _store.load();
  }

  FirestoreCollectorStore _createFirestoreStore() {
    final user = context.read<UserProvider>().user;
    return FirestoreCollectorStore(phone: user?.phoneNumber ?? '');
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
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BackofficeTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          return ListenableBuilder(
            listenable: _store,
            builder: (context, _) =>
                desktop ? _buildDesktop() : _buildMobile(),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Mobile (bottom tabs)
  // ------------------------------------------------------------------

  Widget _buildMobile() {
    return Column(
      children: [
        _buildTopbar(),
        if (_store.isLoading) const LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: Colors.transparent,
          color: BackofficeTheme.gold,
        ),
        _buildErrorBanner(),
        Expanded(child: _buildTabContent(desktop: false)),
        _buildBottomTabs(),
      ],
    );
  }

  Widget _buildBottomTabs() {
    return Container(
      decoration: BoxDecoration(
        color: BackofficeTheme.surface,
        border: Border(top: BorderSide(color: BackofficeTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              for (final (index, icon, label) in _tabs)
                Expanded(
                  child: InkWell(
                    key: Key('cd_tab_$index'),
                    onTap: () => setState(() => _tab = index),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 19,
                            color: _tab == index
                                ? BackofficeTheme.green
                                : BackofficeTheme.muted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: BackofficeTheme.inter(
                              9.5,
                              weight: FontWeight.w600,
                              color: _tab == index
                                  ? BackofficeTheme.green
                                  : BackofficeTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Desktop (sidebar + topbar)
  // ------------------------------------------------------------------

  Widget _buildDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSidebar(),
        Expanded(
          child: Column(
            children: [
              _buildDesktopTopbar(),
              if (_store.isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: BackofficeTheme.gold,
                ),
              _buildErrorBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  child: _buildTabContent(desktop: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Material(
      color: BackofficeTheme.green,
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: BackofficeTheme.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.recycling_rounded,
                      size: 16,
                      color: BackofficeTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Waste',
                        style: BackofficeTheme.sora(
                          15,
                          weight: FontWeight.w700,
                          color: BackofficeTheme.cream,
                        ),
                        children: [
                          TextSpan(
                            text: 'Pro',
                            style: BackofficeTheme.sora(
                              15,
                              weight: FontWeight.w700,
                              color: BackofficeTheme.gold,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: BackofficeTheme.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pedal_bike_outlined,
                        size: 10,
                        color: BackofficeTheme.gold,
                      ),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'COLLECTOR APP',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: BackofficeTheme.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, icon, label) in _tabs)
                      _sidebarItem(index, icon, label),
                  ],
                ),
              ),
            ),
            _buildSidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final active = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? BackofficeTheme.gold.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active
                ? Border.all(
                    color: BackofficeTheme.gold.withValues(alpha: 0.32),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: active
                    ? BackofficeTheme.gold
                    : const Color(0xBFE9F2ED),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(
                    13,
                    weight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active
                        ? BackofficeTheme.gold
                        : const Color(0xBFE9F2ED),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final user = context.read<UserProvider>().user;
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (_store.collecteur?.name ?? 'Collector');
    final zone = _store.collecteur?.zone.isNotEmpty == true
        ? _store.collecteur!.zone
        : 'Collector';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 18),
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
                  name,
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
                  zone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(
                    10.5,
                    color: const Color(0x80E9F2ED),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('cd_logout'),
            tooltip: 'Log out',
            onPressed: () => _logout(),
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

  Widget _buildDesktopTopbar() {
    final titles = ['Today', 'History', 'Profile'];
    final subtitles = [
      '${_store.pendingToday.length} to do · ${_store.kgToday.toStringAsFixed(1)} kg collected',
      '${_store.historyDates.length} day${_store.historyDates.length > 1 ? 's' : ''}',
      _store.collecteur?.zone.isNotEmpty == true
          ? _store.collecteur!.zone
          : 'Collector',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      decoration: const BoxDecoration(
        color: BackofficeTheme.surface,
        border: Border(bottom: BorderSide(color: BackofficeTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_tab],
                  style: BackofficeTheme.sora(19, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitles[_tab],
                  style: BackofficeTheme.inter(
                    12,
                    color: BackofficeTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(),
        ],
      ),
    );
  }

  Widget _buildTopbar() {
    final user = context.read<UserProvider>().user;
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (_store.collecteur?.name ?? 'Collector');
    final zone = _store.collecteur?.zone.isNotEmpty == true
        ? _store.collecteur!.zone
        : 'Collector';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: const BoxDecoration(
        color: BackofficeTheme.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(initials: boInitials(name), size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BackofficeTheme.sora(
                          15,
                          weight: FontWeight.w700,
                          color: BackofficeTheme.cream,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        zone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BackofficeTheme.inter(
                          10.5,
                          color: BackofficeTheme.cream.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _ProgressCard(
              done: _store.doneToday.length,
              total: _store.todayCollectes.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final error = _store.error;
    if (error == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: BackofficeTheme.redSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 15, color: BackofficeTheme.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: BackofficeTheme.inter(11.5, color: BackofficeTheme.red),
            ),
          ),
          TextButton(
            onPressed: _store.load,
            style: TextButton.styleFrom(
              foregroundColor: BackofficeTheme.red,
              textStyle: BackofficeTheme.inter(11.5, weight: FontWeight.w600),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Content (3 tabs)
  // ------------------------------------------------------------------

  Widget _buildTabContent({required bool desktop}) {
    if (_tab == 1) return _buildHistory(desktop: desktop);
    if (_tab == 2) return _buildProfile(desktop: desktop);
    return _buildToday(desktop: desktop);
  }

  Widget _buildToday({required bool desktop}) {
    final rows = switch (_filter) {
      'pending' => _store.pendingToday,
      'done' => _store.doneToday,
      'missed' => _store.missedToday,
      _ => _store.todayCollectes,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 0 : 16,
        desktop ? 0 : 16,
        desktop ? 0 : 16,
        desktop ? 0 : 96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop) ...[
            _buildKpis(),
            const SizedBox(height: 18),
          ],
          _buildFilterChips(),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            _EmptyState(text: 'No collections ${_filter == 'all' ? 'today' : 'in this filter'}.')
          else
            for (final c in rows) ...[
              _CollecteCard(
                collecte: c,
                zone: _store.clientZone(c.client),
                onTap: () => _openCollecte(c),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildKpis() {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.event_note_rounded,
            value: '${_store.todayCollectes.length}',
            label: 'Collections today',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.assignment_turned_in_outlined,
            value: '${_store.doneToday.length}',
            label: 'Completed',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.scale_outlined,
            value: '${_store.kgToday.toStringAsFixed(1)} kg',
            label: 'Collected today',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.trending_up_rounded,
            value: '${_store.successRate.toStringAsFixed(0)}%',
            label: 'Success rate',
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    const chips = [
      ('all', 'All'),
      ('pending', 'To do'),
      ('done', 'Done'),
      ('missed', 'Missed'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in chips) ...[
            _FilterChip(
              label: label,
              active: _filter == value,
              onTap: () => setState(() => _filter = value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory({required bool desktop}) {
    final dates = _store.historyDates;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 0 : 16,
        desktop ? 0 : 16,
        desktop ? 0 : 16,
        desktop ? 0 : 96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dates.isEmpty)
            const _EmptyState(text: 'No collections yet.')
          else
            for (final day in dates) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  boFmtDate(
                    '${day.year.toString().padLeft(4, '0')}-'
                    '${day.month.toString().padLeft(2, '0')}-'
                    '${day.day.toString().padLeft(2, '0')}',
                  ),
                  style: BackofficeTheme.inter(
                    11,
                    weight: FontWeight.w700,
                    color: BackofficeTheme.muted,
                  ),
                ),
              ),
              for (final c in _store.collectesOn(day)) ...[
                _HistoryCard(
                  collecte: c,
                  zone: _store.clientZone(c.client),
                  onTap: () => _openCollecte(c),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Widget _buildProfile({required bool desktop}) {
    final user = context.read<UserProvider>().user;
    final collecteur = _store.collecteur;
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (collecteur?.name ?? 'Collector');
    final phone = user?.phoneNumber.isNotEmpty == true
        ? user!.phoneNumber
        : (collecteur?.phone ?? '—');
    final zone = collecteur?.zone.isNotEmpty == true
        ? collecteur!.zone
        : '—';
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 0 : 16,
        desktop ? 0 : 16,
        desktop ? 0 : 16,
        desktop ? 0 : 96,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BackofficeTheme.card(),
            child: Column(
              children: [
                _Avatar(initials: boInitials(name), size: 64),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: BackofficeTheme.sora(15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Collector · $zone',
                  textAlign: TextAlign.center,
                  style: BackofficeTheme.inter(
                    11.5,
                    color: BackofficeTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '${_store.totalDone}',
                  label: 'Collections done',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: '${_store.totalKg.toStringAsFixed(1)} kg',
                  label: 'Total collected',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: collecteur?.rating.toStringAsFixed(1) ?? '—',
                  label: 'Rating',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileRow(icon: Icons.phone_outlined, text: phone),
          _ProfileRow(
            icon: Icons.location_on_outlined,
            text: zone == '—' ? 'No zone assigned' : 'Zone $zone',
          ),
          _ProfileRow(
            icon: Icons.business_outlined,
            text: 'WastePro agency',
          ),
          _ProfileRow(
            icon: Icons.info_outline,
            text: 'App version 1.0.0',
          ),
          const SizedBox(height: 6),
          Material(
            color: BackofficeTheme.redSoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('cd_logout_mobile'),
              onTap: _logout,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout,
                      size: 15,
                      color: BackofficeTheme.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Log out',
                      style: BackofficeTheme.inter(
                        12.5,
                        weight: FontWeight.w700,
                        color: BackofficeTheme.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    context.read<UserProvider>().logout();
  }

  // ------------------------------------------------------------------
  // Collecte detail (sheet/dialog)
  // ------------------------------------------------------------------

  void _openCollecte(CollecteModel collecte) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final content = _CollecteSheet(
      collecte: collecte,
      zone: _store.clientZone(collecte.client),
      store: _store,
    );
    if (desktop) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black45,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 40,
          ),
          child: content,
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black45,
        builder: (_) => content,
      );
    }
  }
}

// ====================================================================
// Detail sheet (collecte)
// ====================================================================

class _CollecteSheet extends StatefulWidget {
  const _CollecteSheet({
    required this.collecte,
    required this.zone,
    required this.store,
  });

  final CollecteModel collecte;
  final String zone;
  final CollectorStore store;

  @override
  State<_CollecteSheet> createState() => _CollecteSheetState();
}

class _CollecteSheetState extends State<_CollecteSheet> {
  late CollecteModel _collecte;
  String _flow = 'detail'; // 'detail' | 'complete' | 'miss'
  final _poidsCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String? _motif;
  bool _busy = false;

  static const _motifs = [
    ('Client absent', Icons.person_off_outlined),
    ('Access blocked', Icons.lock_outline),
    ('Bin not accessible', Icons.delete_outline),
    ('Other', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _collecte = widget.collecte;
  }

  @override
  void dispose() {
    _poidsCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmComplete() async {
    final poids = double.tryParse(_poidsCtrl.text.trim());
    if (poids == null || poids <= 0) {
      BoToastService.show('Enter a valid weight (kg)', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.completeCollecte(
        _collecte,
        poids: poids,
        commentaire: _commentCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _collecte = _collecte.copyWith(
            status: 'Completed',
            poids: poids,
            commentaire: _commentCtrl.text.trim(),
          );
          _flow = 'detail';
        });
      }
      BoToastService.show('Collection completed — ${_collecte.client}');
    } catch (e) {
      if (mounted) BoToastService.show(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmMiss() async {
    if (_motif == null) {
      BoToastService.show('Choose a reason', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.markMissed(_collecte, motif: _motif!);
      if (mounted) {
        setState(() {
          _collecte = _collecte.copyWith(status: 'Missed', motif: _motif);
          _flow = 'detail';
        });
      }
      BoToastService.show('Collection marked as missed', isError: true);
    } catch (e) {
      if (mounted) BoToastService.show(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Material(
      color: BackofficeTheme.surface,
      borderRadius: BorderRadius.circular(desktop ? 22 : 0),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktop ? 520 : double.infinity,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, desktop ? 20 : 12, 20, 24),
          child: _flow == 'detail'
              ? _buildDetail(desktop)
              : _flow == 'complete'
              ? _buildComplete(desktop)
              : _buildMiss(desktop),
        ),
      ),
    );
  }

  Widget _buildDetail(bool desktop) {
    final c = _collecte;
    final done = c.status == 'Completed';
    final missed = c.status == 'Missed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BackofficeTheme.greenSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                boInitials(c.client),
                style: BackofficeTheme.sora(
                  15,
                  weight: FontWeight.w700,
                  color: BackofficeTheme.green,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.client,
                    style: BackofficeTheme.sora(15.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.zone.isEmpty ? c.collecteur : '${widget.zone} · ${c.date}',
                    style: BackofficeTheme.inter(
                      11.5,
                      color: BackofficeTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: c.status),
          ],
        ),
        const SizedBox(height: 14),
        if (done)
          _resultCard(
            icon: Icons.check_circle,
            color: BackofficeTheme.success,
            title: 'Collection completed',
            lines: [
              'Weight: ${c.poids.toStringAsFixed(1)} kg',
              if (c.commentaire.isNotEmpty) 'Note: ${c.commentaire}',
            ],
          )
        else if (missed)
          _resultCard(
            icon: Icons.warning_amber_rounded,
            color: BackofficeTheme.red,
            title: 'Collection missed',
            lines: [c.motif.isEmpty ? 'Reason not specified' : 'Reason: ${c.motif}'],
          )
        else ...[
          Text(
            'Collection scheduled for today. Start it now:',
            style: BackofficeTheme.inter(12.5, color: BackofficeTheme.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SheetBtn(
                  label: 'Mark as missed',
                  outlined: true,
                  onTap: () => setState(() => _flow = 'miss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetBtn(
                  label: 'Complete',
                  onTap: () => setState(() => _flow = 'complete'),
                ),
              ),
            ],
          ),
        ],
        if (done || missed) ...[
          const SizedBox(height: 14),
          _SheetBtn(
            label: 'Close',
            outlined: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }

  Widget _resultCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color == BackofficeTheme.success
            ? BackofficeTheme.greenSoft
            : BackofficeTheme.redSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(title, style: BackofficeTheme.sora(14, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final line in lines)
            Text(
              line,
              textAlign: TextAlign.center,
              style: BackofficeTheme.inter(11.5, color: BackofficeTheme.muted),
            ),
        ],
      ),
    );
  }

  Widget _buildComplete(bool desktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetHeader('Complete collection', 'Weight and optional note'),
        _label('Weight (kg)'),
        const SizedBox(height: 6),
        TextField(
          key: const Key('cd_poids'),
          controller: _poidsCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: BackofficeTheme.inter(14),
          decoration: _fieldDecoration('Ex. 4.5'),
        ),
        const SizedBox(height: 15),
        _label('Note (optional)'),
        const SizedBox(height: 6),
        TextField(
          key: const Key('cd_comment'),
          controller: _commentCtrl,
          maxLines: 2,
          style: BackofficeTheme.inter(14),
          decoration: _fieldDecoration('Add a note...'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _BackBtn(onTap: () => setState(() => _flow = 'detail')),
            const SizedBox(width: 10),
            Expanded(
              child: _SheetBtn(
                label: _busy ? 'Saving...' : 'Confirm collection',
                onTap: _busy ? null : _confirmComplete,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiss(bool desktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetHeader('Mark as missed', 'Why was this collection not done?'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            for (final (label, icon) in _motifs)
              _ReasonChip(
                label: label,
                icon: icon,
                selected: _motif == label,
                onTap: () => setState(() => _motif = label),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _BackBtn(onTap: () => setState(() => _flow = 'detail')),
            const SizedBox(width: 10),
            Expanded(
              child: _SheetBtn(
                label: _busy ? 'Saving...' : 'Confirm',
                onTap: _busy ? null : _confirmMiss,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sheetHeader(String title, String sub) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: BackofficeTheme.sora(15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: BackofficeTheme.inter(11.5, color: BackofficeTheme.muted),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: BackofficeTheme.inter(
      11,
      weight: FontWeight.w600,
      color: BackofficeTheme.muted,
    ),
  );

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: BackofficeTheme.inter(14, color: BackofficeTheme.muted),
      filled: true,
      fillColor: BackofficeTheme.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BackofficeTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BackofficeTheme.green),
      ),
    );
  }
}

// ====================================================================
// Small widgets
// ====================================================================

class _StatusPill extends StatelessWidget {
  const _StatusPill({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: BackofficeTheme.cream.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: BackofficeTheme.cream.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.circle,
            size: 7,
            color: Color(0xFF8FD9AE),
          ),
          const SizedBox(width: 5),
          Text(
            'Online',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8FD9AE),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BackofficeTheme.gold.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: BackofficeTheme.sora(
          size * 0.34,
          weight: FontWeight.w700,
          color: BackofficeTheme.gold,
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final remaining = total - done;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BackofficeTheme.cream.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BackofficeTheme.cream.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _RingPainter(progress: progress),
              child: Center(
                child: Text(
                  '$done/$total',
                  style: BackofficeTheme.sora(
                    13,
                    weight: FontWeight.w700,
                    color: BackofficeTheme.cream,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's route",
                  style: BackofficeTheme.sora(
                    13,
                    weight: FontWeight.w600,
                    color: BackofficeTheme.cream,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining == 0
                      ? 'All done — great job!'
                      : '$remaining collection${remaining > 1 ? 's' : ''} remaining',
                  style: BackofficeTheme.inter(
                    10.5,
                    color: BackofficeTheme.cream.withValues(alpha: 0.55),
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

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(
      center,
      radius,
      stroke..color = BackofficeTheme.cream.withValues(alpha: 0.15),
    );
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      stroke
        ..color = BackofficeTheme.gold
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BackofficeTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: BackofficeTheme.green),
          const SizedBox(height: 10),
          Text(
            value,
            style: BackofficeTheme.sora(
              19,
              weight: FontWeight.w700,
              color: BackofficeTheme.green,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BackofficeTheme.inter(10.5, color: BackofficeTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? BackofficeTheme.green : BackofficeTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? BackofficeTheme.green : BackofficeTheme.border,
          ),
        ),
        child: Text(
          label,
          style: BackofficeTheme.inter(
            11.5,
            weight: FontWeight.w600,
            color: active ? BackofficeTheme.cream : BackofficeTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _CollecteCard extends StatelessWidget {
  const _CollecteCard({
    required this.collecte,
    required this.zone,
    required this.onTap,
  });

  final CollecteModel collecte;
  final String zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BackofficeTheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: BackofficeTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BackofficeTheme.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              boInitials(collecte.client),
              style: BackofficeTheme.inter(
                12,
                weight: FontWeight.w700,
                color: BackofficeTheme.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collecte.client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(13.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  zone.isEmpty ? collecte.date : '$zone · ${collecte.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(11, color: BackofficeTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (collecte.poids > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${collecte.poids.toStringAsFixed(1)} kg',
                style: BackofficeTheme.inter(11, weight: FontWeight.w700),
              ),
            ),
          _StatusBadge(status: collecte.status),
        ],
      ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'Completed' => (
          BackofficeTheme.greenSoft,
          BackofficeTheme.success,
          'Done',
        ),
      'Missed' => (BackofficeTheme.redSoft, BackofficeTheme.red, 'Missed'),
      _ => (BackofficeTheme.goldSoft, BackofficeTheme.goldDim, 'To do'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: BackofficeTheme.inter(9.5, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.collecte,
    required this.zone,
    required this.onTap,
  });

  final CollecteModel collecte;
  final String zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = collecte.status == 'Completed';
    return Material(
      color: BackofficeTheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: BackofficeTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? BackofficeTheme.greenSoft : BackofficeTheme.redSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  done ? Icons.check : Icons.close,
                  size: 14,
                  color: done ? BackofficeTheme.success : BackofficeTheme.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collecte.client,
                      style: BackofficeTheme.inter(13.5, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zone.isEmpty
                          ? (done ? 'Completed' : 'Missed')
                          : '$zone · ${done ? 'Completed' : 'Missed'}',
                      style: BackofficeTheme.inter(
                        11,
                        color: BackofficeTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (collecte.poids > 0)
                    Text(
                      '${collecte.poids.toStringAsFixed(1)} kg',
                      style: BackofficeTheme.inter(11, weight: FontWeight.w700),
                    ),
                  const SizedBox(height: 5),
                  _StatusBadge(status: collecte.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BackofficeTheme.card(),
      child: Column(
        children: [
          Text(
            value,
            style: BackofficeTheme.sora(
              18,
              weight: FontWeight.w700,
              color: BackofficeTheme.green,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: BackofficeTheme.inter(9.5, color: BackofficeTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BackofficeTheme.card(),
      child: Row(
        children: [
          Icon(icon, size: 16, color: BackofficeTheme.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BackofficeTheme.inter(12.5, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 34,
            color: BackofficeTheme.border,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: BackofficeTheme.inter(12.5, color: BackofficeTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  const _SheetBtn({
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: outlined ? Colors.transparent : BackofficeTheme.green,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          alignment: Alignment.center,
          decoration: outlined
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BackofficeTheme.border),
                )
              : null,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BackofficeTheme.inter(
              13,
              weight: FontWeight.w700,
              color: outlined
                  ? (enabled ? BackofficeTheme.text : BackofficeTheme.muted)
                  : BackofficeTheme.cream,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BackofficeTheme.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 17,
            color: BackofficeTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? BackofficeTheme.greenSoft : BackofficeTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? BackofficeTheme.green : BackofficeTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? BackofficeTheme.green : BackofficeTheme.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BackofficeTheme.inter(
                  11.5,
                  weight: FontWeight.w600,
                  color: selected ? BackofficeTheme.green : BackofficeTheme.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
