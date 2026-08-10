import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../backoffice/theme.dart';

/// App mobile du collecteur — porté 1:1 du design `collecteur-mobile.html`
/// (Propre237 — Collecteur), en réutilisant la palette de [BackofficeTheme].
///
/// Sur écran large (web), l'app s'affiche dans le cadre « téléphone » du
/// design (centré sur le fond coquille #DEDBD1) ; sur mobile elle est
/// plein écran. L'écran propose trois onglets :
///  - **Tournée** : la tournée du jour, filtrable (À faire / Terminés /
///    Manqués), avec le détail client et le flow de collecte complet
///    (QR/OTP → photo → poids/commentaire → validation).
///  - **Historique** : les collectes passées par jour.
///  - **Profil** : stats du collecteur + coordonnées + déconnexion.
class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

// ====================================================================
// Mock data (same as collecteur-mobile.html)
// ====================================================================

/// Un point de la tournée du jour.
class _TourneeClient {
  _TourneeClient({
    required this.id,
    required this.num,
    required this.name,
    required this.address,
    required this.time,
    required this.phone,
    required this.formule,
    required this.status,
    this.missReason,
    this.heureArrivee = '',
    this.heureDepart = '',
    this.poids = 0,
  }) : commentaire = '';

  final String id;
  final int num;
  final String name;
  final String address;
  final String time;
  final String phone;
  final String formule;
  String status; // 'À faire' | 'En cours' | 'Terminé' | 'Manqué'
  String? missReason;
  String heureArrivee;
  String heureDepart;
  double poids;
  String commentaire;
}

/// Une entrée de l'historique.
class _HistoryEntry {
  _HistoryEntry({
    required this.name,
    required this.heure,
    required this.poids,
    required this.status,
  });

  final String name;
  final String heure; // '—' quand non visité
  final double poids;
  final String status; // 'Effectué' | 'Manqué'
}

/// Un jour d'historique.
class _HistoryDay {
  _HistoryDay({required this.date, required this.entries});

  final DateTime date;
  final List<_HistoryEntry> entries;
}

/// Un toast affiché en haut de l'écran.
class _ToastMsg {
  _ToastMsg(this.message, {this.error = false});
  final String message;
  final bool error;
}

// ====================================================================
// State
// ====================================================================

class _CollectorDashboardState extends State<CollectorDashboard>
    with SingleTickerProviderStateMixin {
  // --- Données mockées (portées du design) ---
  late List<_TourneeClient> _tournee;
  static final List<_HistoryDay> _historique = [
    _HistoryDay(
      date: DateTime(2026, 8, 5),
      entries: [
        _HistoryEntry(
            name: 'Jean Dooh', heure: '07:03', poids: 4.0, status: 'Effectué'),
        _HistoryEntry(
            name: 'Marie Ekwalla',
            heure: '07:41',
            poids: 5.2,
            status: 'Effectué'),
        _HistoryEntry(
            name: 'Sarah Mbida',
            heure: '08:10',
            poids: 3.3,
            status: 'Effectué'),
      ],
    ),
    _HistoryDay(
      date: DateTime(2026, 8, 4),
      entries: [
        _HistoryEntry(
            name: 'Robert Essomba',
            heure: '07:15',
            poids: 3.8,
            status: 'Effectué'),
        _HistoryEntry(
            name: 'Brice Talla', heure: '—', poids: 0, status: 'Manqué'),
        _HistoryEntry(
            name: 'Chantal Ngo', heure: '08:02', poids: 4.1, status: 'Effectué'),
      ],
    ),
  ];

  // --- Navigation ---
  int _tab = 0; // 0 Tournée · 1 Historique · 2 Profil
  String _filter = 'all'; // 'all' | 'À faire' | 'Terminé' | 'Manqué'

  // --- Sheet client ---
  String? _sheetId;
  bool _sheetOpen = false;
  String _flow = 'detail'; // 'detail' | 'miss' | 'step1' | 'step2' | 'step3'

  // --- Flow collecte ---
  String _method = 'qr'; // 'qr' | 'otp'
  bool _qrValidated = false;
  late final List<TextEditingController> _otp;
  late final List<FocusNode> _otpFocus;
  bool _photoTaken = false;
  final TextEditingController _poidsCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();
  String? _missSelected;

  // --- Scan line animation ---
  late final AnimationController _scanCtrl;

  // --- Toasts ---
  final List<_ToastMsg> _toasts = [];
  final List<Timer> _toastTimers = [];

  static const List<(String, IconData)> _missReasons = [
    ('Client absent', Icons.person_off_outlined),
    ('Bac cassé', Icons.delete_outline),
    ('Accès bloqué', Icons.lock_outline),
    ('Autre', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _tournee = _seedTournee();
    _otp = List.generate(4, (_) => TextEditingController());
    _otpFocus = List.generate(4, (_) => FocusNode());
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    for (final c in _otp) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _poidsCtrl.dispose();
    _commentCtrl.dispose();
    for (final t in _toastTimers) {
      t.cancel();
    }
    super.dispose();
  }

  List<_TourneeClient> _seedTournee() {
    return [
      _TourneeClient(
        id: 't1',
        num: 1,
        name: 'Jean Dooh',
        address: 'Rue 1.234, Bonanjo',
        time: '07:00–07:30',
        phone: '+237 677 12 34 56',
        formule: 'Standard · 2x/semaine',
        status: 'Terminé',
        heureArrivee: '07:04',
        heureDepart: '07:12',
        poids: 4.2,
      ),
      _TourneeClient(
        id: 't2',
        num: 2,
        name: 'Sarah Mbida',
        address: 'Rue 1.240, Bonanjo',
        time: '07:15–07:45',
        phone: '+237 691 77 04 22',
        formule: 'Essentiel · 1x/semaine',
        status: 'Terminé',
        heureArrivee: '07:20',
        heureDepart: '07:27',
        poids: 3.1,
      ),
      _TourneeClient(
        id: 't3',
        num: 3,
        name: 'Marie Ekwalla',
        address: 'Avenue de Gaulle, Akwa',
        time: '08:00–08:30',
        phone: '+237 690 45 12 78',
        formule: 'Premium · 2x/semaine',
        status: 'En cours',
      ),
      _TourneeClient(
        id: 't4',
        num: 4,
        name: 'Robert Essomba',
        address: 'Rue Joss, Akwa',
        time: '08:15–08:45',
        phone: '+237 655 22 11 09',
        formule: 'Standard · 2x/semaine',
        status: 'À faire',
      ),
      _TourneeClient(
        id: 't5',
        num: 5,
        name: 'Chantal Ngo',
        address: 'Rue Congo, Akwa',
        time: '08:45–09:15',
        phone: '+237 699 88 44 12',
        formule: 'Essentiel · 1x/semaine',
        status: 'À faire',
      ),
      _TourneeClient(
        id: 't6',
        num: 6,
        name: 'Emmanuel Owona',
        address: 'Rue Njo-Njo, Akwa',
        time: '09:15–09:45',
        phone: '+237 674 33 20 18',
        formule: 'Standard · 2x/semaine',
        status: 'À faire',
      ),
      _TourneeClient(
        id: 't7',
        num: 7,
        name: 'Brice Talla',
        address: 'Rue de la Gare, Bonanjo',
        time: '07:45–08:15',
        phone: '+237 656 40 88 15',
        formule: 'Standard · 2x/semaine',
        status: 'Manqué',
        missReason: 'Client absent',
      ),
      _TourneeClient(
        id: 't8',
        num: 8,
        name: 'Larissa Fouda',
        address: 'Rue Ivy, Akwa',
        time: '09:45–10:15',
        phone: '+237 693 15 60 24',
        formule: 'Premium · 2x/semaine',
        status: 'À faire',
      ),
    ];
  }

  _TourneeClient? get _currentClient {
    if (_sheetId == null) return null;
    for (final t in _tournee) {
      if (t.id == _sheetId) return t;
    }
    return null;
  }

  int get _doneCount => _tournee.where((t) => t.status == 'Terminé').length;

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    // Cadre « téléphone » sur écran large (web), plein écran sur mobile.
    return Scaffold(
      backgroundColor: BackofficeTheme.shell,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 520;
          if (!wide) return _buildPhoneScreen(context);
          // Hauteur adaptative : le cadre suit l'écran quand la fenêtre est
          // plus courte que le téléphone du design (844 px).
          final frameHeight = math.min(844.0, constraints.maxHeight);
          return Center(
            child: Container(
              width: 390,
              height: frameHeight,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(46),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 40,
                    offset: Offset(0, 24),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: _buildPhoneScreen(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoneScreen(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final userName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'Paul Mbarga';
    return LayoutBuilder(
      builder: (context, c) {
        final sheetHeight = c.maxHeight * 0.88;
        return Stack(
          children: [
            Column(
              children: [
                _buildTopbar(context, userName),
                Expanded(child: _buildContent(context)),
              ],
            ),
            // Tab bar (Positioned directement dans le Stack)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildTabBar(),
            ),
            // Scrim
            if (_sheetOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSheet,
                  child: AnimatedOpacity(
                    opacity: _sheetOpen ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const ColoredBox(color: Color(0x660A2A20)),
                  ),
                ),
              ),
            // Sheet client
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: _sheetOpen ? 0 : -sheetHeight,
              height: sheetHeight,
              child: _buildSheet(context),
            ),
            // Toasts
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  for (final t in _toasts) _ToastView(toast: t),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Topbar
  // ------------------------------------------------------------------

  Widget _buildTopbar(BuildContext context, String userName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
                _Avatar(initials: boInitials(userName), size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
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
                        'Zone Bonanjo / Akwa',
                        style: BackofficeTheme.inter(
                          10.5,
                          color: BackofficeTheme.cream.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BackofficeTheme.cream.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              BackofficeTheme.cream.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 7,
                            color: Color(0xFF8FD9AE),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Synchronisé',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8FD9AE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconBtn(
                      icon: Icons.notifications_none,
                      onTap: () => _showToast('Nouvelle notification'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProgressCard(done: _doneCount, total: _tournee.length),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Content (3 pages)
  // ------------------------------------------------------------------

  Widget _buildContent(BuildContext context) {
    if (_tab == 0) return _buildTourneePage();
    if (_tab == 1) return _buildHistoriquePage();
    return _buildProfilPage(context);
  }

  Widget _buildTourneePage() {
    final rows = _filter == 'all'
        ? _tournee
        : _tournee.where((t) => t.status == _filter).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterChips(),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const _EmptyState(text: 'Aucun client dans ce filtre')
          else
            for (final t in rows) ...[
              _ClientCard(client: t, onTap: () => _openClient(t.id)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const chips = [
      ('all', 'Tous'),
      ('À faire', 'À faire'),
      ('Terminé', 'Terminés'),
      ('Manqué', 'Manqués'),
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

  Widget _buildHistoriquePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in _historique) ...[
            Text(
              _frDayLabel(day.date),
              style: BackofficeTheme.inter(
                11,
                weight: FontWeight.w700,
                color: BackofficeTheme.muted,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in day.entries) ...[
              _HistoryCard(entry: e),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildProfilPage(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final userName =
        user?.fullName.isNotEmpty == true ? user!.fullName : 'Paul Mbarga';
    final phone = user?.phoneNumber.isNotEmpty == true
        ? user!.phoneNumber
        : '+237 678 90 11 22';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BackofficeTheme.card(),
            child: Column(
              children: [
                _Avatar(initials: boInitials(userName), size: 64),
                const SizedBox(height: 10),
                Text(
                  userName,
                  style: BackofficeTheme.sora(15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Collecteur · Zone Bonanjo / Akwa',
                  style: BackofficeTheme.inter(
                    11.5,
                    color: BackofficeTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _StatBox(value: '312', label: 'Collectes totales'),
              ),
              SizedBox(width: 10),
              Expanded(child: _StatBox(value: '4.8', label: 'Note moyenne')),
              SizedBox(width: 10),
              Expanded(child: _StatBox(value: '96%', label: 'Taux réussite')),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileRow(icon: Icons.phone_outlined, text: phone),
          const _ProfileRow(
            icon: Icons.local_shipping_outlined,
            text: 'Tricycle — MB-2024-CM',
          ),
          const _ProfileRow(
            icon: Icons.business_outlined,
            text: 'Propre237 Douala SARL — Agence Bonanjo',
          ),
          const _ProfileRow(
            icon: Icons.info_outline,
            text: 'Version app 1.0.0',
          ),
          const SizedBox(height: 6),
          Material(
            color: BackofficeTheme.redSoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => userProvider.logout(),
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
                      'Se déconnecter',
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

  // ------------------------------------------------------------------
  // Tab bar
  // ------------------------------------------------------------------

  Widget _buildTabBar() {
    const tabs = [
      (0, Icons.checklist, 'Tournée'),
      (1, Icons.history, 'Historique'),
      (2, Icons.person_outline, 'Profil'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF0FFFFFF),
        border: Border(top: BorderSide(color: BackofficeTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
        children: [
          for (final (index, icon, label) in tabs)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: _tab == index
                          ? BackofficeTheme.green
                          : BackofficeTheme.muted,
                    ),
                    const SizedBox(height: 4),
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
          ],
        ),
      ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Sheet client
  // ------------------------------------------------------------------

  void _openClient(String id) {
    setState(() {
      _sheetId = id;
      _sheetOpen = true;
      _flow = 'detail';
    });
    _syncScanAnimation();
  }

  void _closeSheet() {
    setState(() => _sheetOpen = false);
    _syncScanAnimation();
  }

  /// La ligne de scan n'anime que pendant l'étape QR (sinon le contrôleur
  /// tournerait pour rien toute la session, et casserait pumpAndSettle).
  void _syncScanAnimation() {
    final shouldRun = _sheetOpen && _flow == 'step1' && _method == 'qr';
    if (shouldRun && !_scanCtrl.isAnimating) {
      _scanCtrl.repeat(reverse: true);
    } else if (!shouldRun && _scanCtrl.isAnimating) {
      _scanCtrl.stop();
      _scanCtrl.value = 0;
    }
  }

  Widget _buildSheet(BuildContext context) {
    final client = _currentClient;
    return Material(
      color: BackofficeTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: BackofficeTheme.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: client == null
                  ? const SizedBox.shrink()
                  : switch (_flow) {
                      'detail' => _buildDetail(client),
                      'miss' => _buildMissFlow(),
                      'step1' => _buildStep1(),
                      'step2' => _buildStep2(),
                      _ => _buildStep3(),
                    },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Detail client ----

  Widget _buildDetail(_TourneeClient client) {
    if (client.status == 'Terminé') return _buildDone(client);
    if (client.status == 'Manqué') return _buildMissed(client);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClientHeader(client: client, showTime: true),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.phone_outlined,
                label: 'Appeler',
                onTap: () => _showToast('Ouverture de l\'appel…'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.directions_outlined,
                label: 'Itinéraire',
                onTap: () => _showToast('Ouverture de l\'itinéraire…'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.flag_outlined,
                label: 'Signaler',
                onTap: () => setState(() => _flow = 'miss'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: BackofficeTheme.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _InfoRow(label: 'Formule', value: client.formule),
              _InfoRow(label: 'Téléphone', value: client.phone),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryBtn(
          icon: Icons.play_arrow,
          label: client.status == 'En cours'
              ? 'Reprendre la collecte'
              : 'Démarrer la collecte',
          onTap: () => _startCollecte(client),
        ),
      ],
    );
  }

  Widget _buildDone(_TourneeClient client) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClientHeader(client: client),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BackofficeTheme.greenSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                size: 26,
                color: BackofficeTheme.success,
              ),
              const SizedBox(height: 8),
              Text(
                'Collecte validée',
                style: BackofficeTheme.sora(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Enregistrée avec succès',
                style: BackofficeTheme.inter(
                  11.5,
                  color: BackofficeTheme.muted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DoneCell(
                      label: 'Arrivée',
                      value: client.heureArrivee.isEmpty
                          ? '—'
                          : client.heureArrivee,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DoneCell(
                      label: 'Départ',
                      value: client.heureDepart.isEmpty
                          ? '—'
                          : client.heureDepart,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DoneCell(
                      label: 'Poids',
                      value: client.poids > 0 ? '${client.poids} kg' : '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DoneCell(
                      label: 'Commentaire',
                      value: client.commentaire.isEmpty
                          ? 'Aucun'
                          : client.commentaire,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMissed(_TourneeClient client) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClientHeader(client: client),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BackofficeTheme.redSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 26,
                color: BackofficeTheme.red,
              ),
              const SizedBox(height: 8),
              Text(
                'Ramassage manqué',
                style: BackofficeTheme.sora(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Motif : ${client.missReason ?? 'Non précisé'}',
                style: BackofficeTheme.inter(
                  11.5,
                  color: BackofficeTheme.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryBtn(
          icon: Icons.refresh,
          label: 'Réessayer maintenant',
          onTap: () => setState(() {
            client.status = 'À faire';
            client.missReason = null;
            _flow = 'detail';
          }),
        ),
      ],
    );
  }

  // ---- Flow « manqué » ----

  Widget _buildMissFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Signaler un problème',
          textAlign: TextAlign.center,
          style: BackofficeTheme.sora(14.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Pourquoi ce ramassage ne peut pas être effectué ?',
          textAlign: TextAlign.center,
          style: BackofficeTheme.inter(11.5, color: BackofficeTheme.muted),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            for (final (label, icon) in _missReasons)
              _ReasonChip(
                label: label,
                icon: icon,
                selected: _missSelected == label,
                onTap: () => setState(() => _missSelected = label),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _BackBtn(
              onTap: () {
                setState(() => _flow = 'detail');
                _syncScanAnimation();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NextBtn(
                label: 'Confirmer',
                enabled: _missSelected != null,
                onTap: _confirmMiss,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmMiss() {
    final client = _currentClient;
    if (client == null || _missSelected == null) return;
    setState(() {
      client.status = 'Manqué';
      client.missReason = _missSelected;
      _sheetOpen = false;
      _flow = 'detail';
      _missSelected = null;
    });
    _syncScanAnimation();
    _showToast('Ramassage marqué comme manqué.', error: true);
  }

  // ---- Flow collecte (3 étapes) ----

  void _startCollecte(_TourneeClient client) {
    setState(() {
      if (client.status == 'À faire') client.status = 'En cours';
      _flow = 'step1';
      _method = 'qr';
      _qrValidated = false;
      _photoTaken = false;
      _poidsCtrl.clear();
      _commentCtrl.clear();
      for (final c in _otp) {
        c.clear();
      }
    });
    _syncScanAnimation();
  }

  Widget _stepDots() {
    final activeStep = switch (_flow) {
      'step1' => 1,
      'step2' => 2,
      _ => 3,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 3; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == activeStep ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == activeStep
                  ? BackofficeTheme.green
                  : BackofficeTheme.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (i < 3) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _stepHeader(String title, String sub) {
    return Column(
      children: [
        _stepDots(),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: BackofficeTheme.sora(14.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: BackofficeTheme.inter(11.5, color: BackofficeTheme.muted),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep1() {
    final canNext = (_method == 'qr' && _qrValidated) ||
        (_method == 'otp' && _otp.every((c) => c.text.isNotEmpty));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          'Valider votre présence',
          'Scannez le QR code du client ou saisissez son code',
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: BackofficeTheme.bg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MethodTab(
                  label: 'Code QR',
                  active: _method == 'qr',
                  onTap: () {
                    setState(() {
                      _method = 'qr';
                      _qrValidated = false;
                    });
                    _syncScanAnimation();
                  },
                ),
              ),
              Expanded(
                child: _MethodTab(
                  label: 'Code OTP',
                  active: _method == 'otp',
                  onTap: () {
                    setState(() => _method = 'otp');
                    _syncScanAnimation();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_method == 'qr') _buildQrBody() else _buildOtpBody(),
        const SizedBox(height: 14),
        Row(
          children: [
            _BackBtn(
              onTap: () {
                setState(() => _flow = 'detail');
                _syncScanAnimation();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NextBtn(
                label: 'Suivant',
                enabled: canNext,
                onTap: () {
                  setState(() => _flow = 'step2');
                  _syncScanAnimation();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQrBody() {
    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              // Coins
              for (final align in [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Align(
                  alignment: align,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: BackofficeTheme.gold,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              // Ligne de scan animée
              AnimatedBuilder(
                animation: _scanCtrl,
                builder: (context, _) {
                  return Positioned(
                    left: 14,
                    right: 14,
                    top: 14 + _scanCtrl.value * 150,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: BackofficeTheme.gold,
                        boxShadow: const [
                          BoxShadow(
                            color: BackofficeTheme.gold,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Text(
                  'Cadrez le QR code du client',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xB3F5F1E8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryBtn(
          icon: Icons.qr_code_2,
          label: 'Simuler la lecture du QR',
          onTap: () {
            setState(() => _qrValidated = true);
            _showToast('QR code validé.');
          },
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildOtpBody() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++) ...[
              SizedBox(
                width: 48,
                height: 56,
                child: TextField(
                  controller: _otp[i],
                  focusNode: _otpFocus[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: BackofficeTheme.sora(22, weight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: BackofficeTheme.surface,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: BackofficeTheme.border,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: BackofficeTheme.green,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 3) {
                      _otpFocus[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _otpFocus[i - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
              ),
              if (i < 3) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          'Prendre une photo',
          'Photo du dépôt comme preuve de passage',
        ),
        GestureDetector(
          onTap: () => setState(() => _photoTaken = true),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: _photoTaken ? BackofficeTheme.greenSoft : BackofficeTheme.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _photoTaken ? BackofficeTheme.success : BackofficeTheme.border,
                width: 2,
              ),
            ),
            child: _photoTaken
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: BackofficeTheme.success,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Photo du dépôt prise',
                              style: BackofficeTheme.inter(
                                12,
                                weight: FontWeight.w600,
                                color: BackofficeTheme.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Material(
                          color: const Color(0x99151515),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => setState(() => _photoTaken = false),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      size: 12, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text(
                                    'Reprendre',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        size: 26,
                        color: BackofficeTheme.muted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Touchez pour prendre la photo',
                        style: BackofficeTheme.inter(
                          12,
                          weight: FontWeight.w600,
                          color: BackofficeTheme.muted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _BackBtn(
              onTap: () {
                setState(() => _flow = 'step1');
                _syncScanAnimation();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NextBtn(
                label: 'Suivant',
                enabled: _photoTaken,
                onTap: () {
                  setState(() => _flow = 'step3');
                  _syncScanAnimation();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          'Détails de la collecte',
          'Dernière étape avant validation',
        ),
        Text(
          'Poids estimé (kg)',
          style: BackofficeTheme.inter(
            11,
            weight: FontWeight.w600,
            color: BackofficeTheme.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _poidsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: BackofficeTheme.inter(14),
          decoration: _fieldDecoration('Ex. 4.5'),
        ),
        const SizedBox(height: 15),
        Text(
          'Commentaire (optionnel)',
          style: BackofficeTheme.inter(
            11,
            weight: FontWeight.w600,
            color: BackofficeTheme.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          style: BackofficeTheme.inter(14),
          decoration: _fieldDecoration('Ajoutez une note...'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _BackBtn(
              onTap: () {
                setState(() => _flow = 'step2');
                _syncScanAnimation();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NextBtn(
                label: 'Valider la collecte',
                icon: Icons.check,
                enabled: true,
                onTap: _validateCollecte,
              ),
            ),
          ],
        ),
      ],
    );
  }

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

  void _validateCollecte() {
    final client = _currentClient;
    if (client == null) return;
    final poids = double.tryParse(_poidsCtrl.text.trim()) ?? 0;
    setState(() {
      client.status = 'Terminé';
      client.heureArrivee =
          client.heureArrivee.isEmpty ? _now() : client.heureArrivee;
      client.heureDepart = _now();
      client.poids = poids;
      client.commentaire = _commentCtrl.text.trim();
      _sheetOpen = false;
      _flow = 'detail';
    });
    _syncScanAnimation();
    _showToast('Collecte enregistrée — ${client.name}');
  }

  // ------------------------------------------------------------------
  // Toasts
  // ------------------------------------------------------------------

  void _showToast(String message, {bool error = false}) {
    final toast = _ToastMsg(message, error: error);
    setState(() => _toasts.add(toast));
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 2800), () {
      _toastTimers.remove(timer);
      if (mounted) setState(() => _toasts.remove(toast));
    });
    _toastTimers.add(timer);
  }
}

// ====================================================================
// Helpers
// ====================================================================

String _now() {
  final d = DateTime.now();
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _frDayLabel(DateTime d) {
  const days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  return '${days[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')} '
      '${months[d.month - 1]}';
}

// ====================================================================
// Small widgets
// ====================================================================

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

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BackofficeTheme.cream.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(icon, size: 13, color: BackofficeTheme.cream),
        ),
      ),
    );
  }
}

/// Carte de progression avec anneau.
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
        border: Border.all(
          color: BackofficeTheme.cream.withValues(alpha: 0.14),
        ),
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
                  'Tournée du jour',
                  style: BackofficeTheme.sora(
                    13,
                    weight: FontWeight.w600,
                    color: BackofficeTheme.cream,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_frDayLabel(DateTime.now())} — '
                  '$remaining client${remaining > 1 ? 's' : ''} '
                  'restant${remaining > 1 ? 's' : ''}',
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
    // Fond
    canvas.drawCircle(
      center,
      radius,
      stroke..color = BackofficeTheme.cream.withValues(alpha: 0.15),
    );
    // Progression
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

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});

  final _TourneeClient client;
  final VoidCallback onTap;

  Color get _accent => switch (client.status) {
        'Terminé' => BackofficeTheme.success,
        'Manqué' => BackofficeTheme.red,
        'En cours' => BackofficeTheme.gold,
        _ => BackofficeTheme.border,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: BackofficeTheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: BackofficeTheme.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barre latérale colorée selon l'état
              Container(width: 4, color: _accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BackofficeTheme.greenSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${client.num}',
                          style: BackofficeTheme.sora(
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
                              client.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BackofficeTheme.inter(
                                13.5,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 9,
                                  color: BackofficeTheme.muted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    client.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: BackofficeTheme.inter(
                                      11,
                                      color: BackofficeTheme.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            client.time.split('–').first.trim(),
                            style: BackofficeTheme.inter(
                              11,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _StatusBadge(status: client.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
    final (bg, fg) = switch (status) {
      'Terminé' => (BackofficeTheme.greenSoft, BackofficeTheme.success),
      'Manqué' => (BackofficeTheme.redSoft, BackofficeTheme.red),
      'En cours' => (BackofficeTheme.goldSoft, BackofficeTheme.goldDim),
      _ => (BackofficeTheme.graySoft, BackofficeTheme.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: BackofficeTheme.inter(9.5, weight: FontWeight.w700, color: fg),
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
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: BackofficeTheme.inter(12.5, color: BackofficeTheme.muted),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final done = entry.status == 'Effectué';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: BackofficeTheme.surface,
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
                  entry.name,
                  style: BackofficeTheme.inter(13.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.heure == '—' ? 'Non visité' : 'Arrivée ${entry.heure}',
                  style: BackofficeTheme.inter(11, color: BackofficeTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (entry.poids > 0)
                Text(
                  '${entry.poids} kg',
                  style: BackofficeTheme.inter(
                    11,
                    weight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 5),
              _StatusBadge(status: done ? 'Terminé' : 'Manqué'),
            ],
          ),
        ],
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

/// En-tête du sheet détail client.
class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.client, this.showTime = false});

  final _TourneeClient client;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BackofficeTheme.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              boInitials(client.name),
              style: BackofficeTheme.sora(
                16,
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
                  client.name,
                  style: BackofficeTheme.sora(15.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  showTime ? '${client.time} · ${client.address}' : client.address,
                  style: BackofficeTheme.inter(
                    11.5,
                    color: BackofficeTheme.muted,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 15, color: BackofficeTheme.green),
              const SizedBox(height: 5),
              Text(
                label,
                style: BackofficeTheme.inter(
                  10.5,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: BackofficeTheme.inter(12, color: BackofficeTheme.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BackofficeTheme.inter(12, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneCell extends StatelessWidget {
  const _DoneCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: BackofficeTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: BackofficeTheme.inter(9.5, color: BackofficeTheme.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BackofficeTheme.inter(12.5, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BackofficeTheme.green,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(15),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: BackofficeTheme.cream),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(
                    14,
                    weight: FontWeight.w700,
                    color: BackofficeTheme.cream,
                  ),
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? BackofficeTheme.redSoft : BackofficeTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? BackofficeTheme.red : BackofficeTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? BackofficeTheme.red : BackofficeTheme.muted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: BackofficeTheme.inter(
                11.5,
                weight: FontWeight.w600,
                color: selected ? BackofficeTheme.red : BackofficeTheme.text,
              ),
            ),
          ],
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
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back,
            size: 16,
            color: BackofficeTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _NextBtn extends StatelessWidget {
  const _NextBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? BackofficeTheme.green
          : BackofficeTheme.green.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: BackofficeTheme.cream),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: BackofficeTheme.inter(
                  14,
                  weight: FontWeight.w700,
                  color: BackofficeTheme.cream,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active ? BackofficeTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: BackofficeTheme.inter(
            12,
            weight: FontWeight.w600,
            color: active ? BackofficeTheme.green : BackofficeTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({required this.toast});

  final _ToastMsg toast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: toast.error ? BackofficeTheme.red : BackofficeTheme.green,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            toast.error ? Icons.error_outline : Icons.check_circle_outline,
            size: 14,
            color: BackofficeTheme.gold,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              toast.message,
              style: BackofficeTheme.inter(
                12,
                weight: FontWeight.w500,
                color: BackofficeTheme.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
