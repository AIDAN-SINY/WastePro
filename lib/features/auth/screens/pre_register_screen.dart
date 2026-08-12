import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/agence_model.dart';
import '../../../services/auth_service.dart';
import 'application_status_screen.dart';
import 'login_screen.dart';

/// Pré-inscription client — réservée aux clients (le login reste pour tous).
///
/// Ce n'est pas une inscription immédiate : le client remplit ses infos et
/// choisit l'agence où il veut s'abonner (suggestions selon sa zone, ou il
/// tape directement le nom). La candidature part dans le dashboard du chef
/// d'agence qui l'approuve et lui assigne un collecteur — le compte n'est
/// créé qu'à ce moment.
class PreRegisterScreen extends StatefulWidget {
  const PreRegisterScreen({
    super.key,
    FirebaseFirestore? db,
    this.initialName = '',
    this.initialPhone = '',
    this.initialZone = '',
  }) : _db = db;

  /// Base injectée par les tests ; sinon l'instance par défaut.
  final FirebaseFirestore? _db;

  /// Pré-remplissage du formulaire — utilisé par « Re-apply » depuis
  /// l'écran de statut d'une candidature rejetée (infos conservées).
  final String initialName;
  final String initialPhone;
  final String initialZone;

  @override
  State<PreRegisterScreen> createState() => _PreRegisterScreenState();
}

class _PreRegisterScreenState extends State<PreRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  FirebaseFirestore get _db => widget._db ?? FirebaseFirestore.instance;

  /// Agences chargées pour les suggestions.
  List<AgenceModel> _agences = [];
  bool _loadingAgencies = true;

  /// Agence sélectionnée (null = l'utilisateur tape son propre nom).
  AgenceModel? _selected;
  bool _submitting = false;
  bool _submitted = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  // Palette cohérente avec LoginScreen.
  static const Color bgDarker = Color(0xFF0A2A20);
  static const Color accentGold = Color(0xFFE8A33D);
  static const Color cream = Color(0xFFF5F1E8);
  static const Color muted = Color(0xFFAEC0B7);
  static const Color glass = Color(0x12F5F1E8);
  static const Color glassBorder = Color(0x29F5F1E8);

  @override
  void initState() {
    super.initState();
    // Re-apply : le formulaire repart avec les infos de la candidature
    // rejetée (le client n'a qu'à ajuster ce qui a changé).
    _nameCtrl.text = widget.initialName;
    _phoneCtrl.text = widget.initialPhone;
    _zoneCtrl.text = widget.initialZone;
    _loadAgencies();
  }

  Future<void> _loadAgencies() async {
    try {
      final snap = await _db.collection('agences').get();
      final list =
          snap.docs.map((d) => AgenceModel.fromMap(d.data())).toList()
            ..sort((a, b) => a.ville.compareTo(b.ville));
      if (mounted) {
        setState(() {
          _agences = list;
          _loadingAgencies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAgencies = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _zoneCtrl.dispose();
    _agencyCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // --- Suggestions d'agences ---

  /// Ville (ex. « Douala ») déduite de la zone saisie (« Douala: Akwa »).
  String get _zoneCity {
    final z = _zoneCtrl.text.trim();
    if (z.isEmpty) return '';
    final idx = z.indexOf(':');
    return (idx > 0 ? z.substring(0, idx) : z).trim().toLowerCase();
  }

  /// Agences suggérées pour la zone saisie.
  List<AgenceModel> get _suggested {
    final city = _zoneCity;
    if (city.isEmpty) return [];
    return _agences
        .where((a) => a.ville.toLowerCase().contains(city))
        .toList();
  }

  /// Résultat de la recherche libre par nom d'agence.
  List<AgenceModel> get _searchResults {
    final q = _agencyCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _agences.where((a) => a.ville.toLowerCase().contains(q)).toList();
  }

  void _choose(AgenceModel a) {
    setState(() {
      _selected = a;
      _agencyCtrl.text = a.ville;
    });
  }

  /// Nom d'agence final : la sélection, sinon le nom tapé dans le champ.
  String get _effectiveAgencyName =>
      _selected?.ville ?? _agencyCtrl.text.trim();

  String get _effectiveAgencyId => _selected?.id ?? '';

  String get _effectiveSocieteId => _selected?.societeId ?? '';

  // --- Soumission ---

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      _toast('Passwords do not match');
      return;
    }
    if (_effectiveAgencyName.isEmpty) {
      _toast('Please choose an agency or type its name');
      return;
    }

    setState(() => _submitting = true);
    try {
      final phone = AuthService.canonicalPhone(_phoneCtrl.text.trim());
      await AuthService(db: _db).submitPreRegistration(
        fullName: _nameCtrl.text.trim(),
        phone: phone,
        zone: _zoneCtrl.text.trim(),
        agenceId: _effectiveAgencyId,
        agenceName: _effectiveAgencyName,
        societeId: _effectiveSocieteId,
        password: _passCtrl.text,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Retour au login via le routeur quand il est présent (/login) : une push
  /// impérative resterait empilée AU-DESSUS du routeur et l'URL resterait sur
  /// /register (obligation de recharger la page après le login).
  void _goToLogin() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/login');
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDarker,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _submitted
                      ? _buildSuccessCard()
                      : _buildFormCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF1C5A41),
              borderRadius: BorderRadius.circular(140),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: accentGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(110),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: glass,
        border: Border.all(color: glassBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: cream,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Apply as a client',
                    style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cream,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tell us about yourself and choose your agency. The agency '
              'manager will review your application and assign you a '
              'collector.',
              style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 22),

            _label('Full name'),
            _field(
              _nameCtrl,
              hint: 'Ex. Marie Ekwalla',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 14),

            _label('Phone number'),
            _phoneField(),
            const SizedBox(height: 14),

            _label('Neighborhood / zone'),
            _field(
              _zoneCtrl,
              hint: 'Ex. Douala: Akwa',
              icon: Icons.map_outlined,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your zone' : null,
            ),

            // Suggestions d'agences selon la zone.
            if (_suggested.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Agencies near $_zoneCity',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _suggested.take(4))
                    _agencyChip(
                      label: a.ville,
                      selected: _selected?.id == a.id,
                      onTap: () => _choose(a),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            _label('Agency'),
            _searchAgencyField(),
            const SizedBox(height: 6),

            // Aucune agence enregistrée sur la plateforme : le client doit
            // le savoir (sinon il croirait que la recherche est cassée).
            if (!_loadingAgencies && _agences.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No agency available yet',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

            // Sélection actuelle (agence choisie ou nom tapé).
            if (_selected != null)
              _selectedChip(
                label: _selected!.ville,
                sub: 'Selected agency',
                onClear: () => setState(() {
                  _selected = null;
                  _agencyCtrl.clear();
                }),
              )
            else if (_agencyCtrl.text.trim().isNotEmpty)
              _selectedChip(
                label: _agencyCtrl.text.trim(),
                sub: 'Using typed name',
                onClear: () => setState(() {
                  _agencyCtrl.clear();
                }),
              ),

            // Résultats de la recherche libre.
            if (_searchResults.isNotEmpty && _selected == null) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: bgDarker.withValues(alpha: 0.5),
                  border: Border.all(color: glassBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in _searchResults.take(5))
                      InkWell(
                        onTap: () => _choose(a),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 15,
                                color: accentGold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  a.ville,
                                  style: const TextStyle(
                                    color: cream,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            _label('Password'),
            _field(
              _passCtrl,
              hint: 'Min. 4 characters',
              icon: Icons.lock_outline_rounded,
              obscure: true,
              obscureCtrl: () => setState(() => _obscure1 = !_obscure1),
              isObscure: _obscure1,
              validator: (v) =>
                  (v == null || v.length < 4)
                  ? 'Password must be at least 4 characters'
                  : null,
            ),
            const SizedBox(height: 14),
            _label('Confirm password'),
            _field(
              _confirmCtrl,
              hint: 'Repeat your password',
              icon: Icons.lock_outline_rounded,
              obscure: true,
              obscureCtrl: () => setState(() => _obscure2 = !_obscure2),
              isObscure: _obscure2,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Confirm your password' : null,
            ),

            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: const Color(0xFF2A1B05),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2A1B05),
                        ),
                      )
                    : Text(
                        'Submit application',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _goToLogin,
                child: const Text(
                  'Already have an account? Log in',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: glass,
        border: Border.all(color: glassBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1E9E5A).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 32,
              color: Color(0xFF33D17E),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Application sent!',
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cream,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your request has been sent to ${_effectiveAgencyName.isEmpty ? 'your agency' : _effectiveAgencyName}. '
            'The agency manager will review it and assign you a collector. '
            'You will be able to log in once your account is approved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _goToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: const Color(0xFF2A1B05),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Go to login'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Suivi en direct : l'écran de statut se met à jour quand le
              // chef d'agence approuve/rejette la candidature.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ApplicationStatusScreen(
                    db: widget._db,
                    initialPhone: _phoneCtrl.text.trim(),
                  ),
                ),
              );
            },
            child: const Text(
              'Track application status',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
        ),
      ),
    );
  }

  /// Champ texte générique (fond sombre vitré, icône, option mot de passe).
  Widget _field(
    TextEditingController ctrl, {
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscure = false,
    bool isObscure = true,
    VoidCallback? obscureCtrl,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgDarker.withValues(alpha: 0.35),
        border: Border.all(color: glassBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, size: 17, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: ctrl,
              obscureText: obscure ? isObscure : false,
              onChanged: onChanged,
              validator: validator,
              style: const TextStyle(color: cream, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: muted.withValues(alpha: 0.55)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 13,
                ),
                errorStyle: const TextStyle(fontSize: 10.5),
              ),
            ),
          ),
          if (obscure) ...[
            IconButton(
              onPressed: obscureCtrl,
              icon: Icon(
                isObscure ? Icons.visibility_off : Icons.visibility,
                color: muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  /// Champ téléphone avec préfixe +237 (comme le login).
  Widget _phoneField() {
    return Container(
      decoration: BoxDecoration(
        color: bgDarker.withValues(alpha: 0.35),
        border: Border.all(color: glassBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: const Text(
              '+237',
              style: TextStyle(color: muted, fontSize: 14),
            ),
          ),
          Container(width: 1, height: 20, color: glassBorder),
          Expanded(
            child: TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\s-]')),
              ],
              style: const TextStyle(color: cream, fontSize: 14),
              decoration: InputDecoration(
                hintText: '6 XX XX XX XX',
                hintStyle: TextStyle(
                  color: muted.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                errorStyle: const TextStyle(fontSize: 10.5),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your phone' : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Champ de recherche d'agence (saisie libre + suggestions).
  Widget _searchAgencyField() {
    return Container(
      decoration: BoxDecoration(
        color: bgDarker.withValues(alpha: 0.35),
        border: Border.all(
          color: _selected != null ? accentGold : glassBorder,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.storefront_outlined, size: 17, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _agencyCtrl,
              onChanged: (v) => setState(() {
                // La saisie annule la sélection ; si elle correspond
                // EXACTEMENT à une agence connue, elle est re-sélectionnée.
                _selected = null;
                final q = v.trim().toLowerCase();
                if (q.isNotEmpty) {
                  final exact = _agences
                      .where((a) => a.ville.toLowerCase() == q)
                      .toList();
                  if (exact.length == 1) _selected = exact.first;
                }
              }),
              style: const TextStyle(color: cream, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    _loadingAgencies
                        ? 'Loading agencies...'
                        : 'Search or type your agency name',
                hintStyle: TextStyle(color: muted.withValues(alpha: 0.55)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 13,
                ),
              ),
            ),
          ),
          if (_agencyCtrl.text.isNotEmpty)
            IconButton(
              onPressed: () => setState(() {
                _agencyCtrl.clear();
                _selected = null;
              }),
              icon: const Icon(Icons.close_rounded, color: muted, size: 17),
            ),
        ],
      ),
    );
  }

  Widget _agencyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accentGold.withValues(alpha: 0.18)
              : bgDarker.withValues(alpha: 0.4),
          border: Border.all(
            color: selected ? accentGold : glassBorder,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 13, color: accentGold),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(color: cream, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedChip({
    required String label,
    required String sub,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1E9E5A).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFF1E9E5A).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: Color(0xFF33D17E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(color: muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: muted, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}
