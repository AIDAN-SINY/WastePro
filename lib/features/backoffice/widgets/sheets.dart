import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backoffice_store.dart';
import '../models.dart';
import '../theme.dart';
import 'toast.dart';

/// Opens the create/edit bottom sheet for an entity. [existing] is the model
/// being edited, or null when creating.
Future<void> showBoFormSheet(
  BuildContext context, {
  required BackofficeStore store,
  required BoEntity type,
  Object? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black45,
    builder: (_) => _BoFormSheet(store: store, type: type, existing: existing),
  );
}

/// Opens the action sheet (Modifier / Supprimer) for an item.
Future<void> showBoActionSheet(
  BuildContext context, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black45,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: BackofficeTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Modifier',
                    onTap: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                  ),
                  Divider(height: 1, color: BackofficeTheme.border),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Supprimer',
                    danger: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: BackofficeTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Annuler',
                    textAlign: TextAlign.center,
                    style: BackofficeTheme.inter(
                      14,
                      weight: FontWeight.w700,
                      color: BackofficeTheme.green,
                    ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BackofficeTheme.red : BackofficeTheme.text;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: BackofficeTheme.inter(
                14,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit form sheet
// ---------------------------------------------------------------------------

class _BoFormSheet extends StatefulWidget {
  const _BoFormSheet({required this.store, required this.type, this.existing});

  final BackofficeStore store;
  final BoEntity type;
  final Object? existing;

  @override
  State<_BoFormSheet> createState() => _BoFormSheetState();
}

class _BoFormSheetState extends State<_BoFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Shared by most entities.
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _zone;
  late final TextEditingController _number;
  late final TextEditingController _password;
  bool _obscurePassword = true;
  String _selectA = ''; // plan / status / client / libelle
  String _selectB = ''; // status / frequence / client...
  late DateTime _date;

  bool get _isEdit => widget.existing != null;

  /// Les comptes client/collecteur ont un mot de passe de connexion.
  bool get _needsPassword =>
      widget.type == BoEntity.client || widget.type == BoEntity.collecteur;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _zone = TextEditingController();
    _number = TextEditingController();
    _password = TextEditingController();
    _date = DateTime.now();
    _seed();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _zone.dispose();
    _number.dispose();
    _password.dispose();
    super.dispose();
  }

  void _seed() {
    final d = widget.existing;
    switch (widget.type) {
      case BoEntity.client:
        final c = d as ClientModel?;
        _name.text = c?.name ?? '';
        _phone.text = c?.phone ?? '';
        _zone.text = c?.zone ?? '';
        _selectA = c?.plan ?? 'Standard';
        _selectB = c?.status ?? 'Actif';
      case BoEntity.collecteur:
        final c = d as CollecteurModel?;
        _name.text = c?.name ?? '';
        _phone.text = c?.phone ?? '';
        _zone.text = c?.zone ?? '';
        _number.text = c?.rating.toString() ?? '4.5';
        _status = c?.status ?? 'Actif';
      case BoEntity.contrat:
        final c = d as ContratModel?;
        _selectA =
            c?.client ??
            (widget.store.clients.isNotEmpty
                ? widget.store.clients.first.name
                : '');
        _selectB =
            c?.frequence ??
            (widget.store.frequences.isNotEmpty
                ? widget.store.frequences.first.libelle
                : '');
        _number.text = c?.prix.toString() ?? '';
        _seedStatus(c?.status ?? 'Actif');
      case BoEntity.collecte:
        final c = d as CollecteModel?;
        _selectA =
            c?.client ??
            (widget.store.clients.isNotEmpty
                ? widget.store.clients.first.name
                : '');
        _selectB =
            c?.collecteur ??
            (widget.store.collecteurs.isNotEmpty
                ? widget.store.collecteurs.first.name
                : '');
        _number.text = c != null && c.poids > 0 ? c.poids.toString() : '';
        _date = c != null
            ? (DateTime.tryParse(c.date) ?? DateTime.now())
            : DateTime.now();
        _seedStatus(c?.status ?? 'Prévu');
      case BoEntity.facture:
        final c = d as FactureModel?;
        _selectA =
            c?.client ??
            (widget.store.clients.isNotEmpty
                ? widget.store.clients.first.name
                : '');
        _number.text = c?.montant.toString() ?? '';
        _date = c != null
            ? (DateTime.tryParse(c.echeance) ?? DateTime.now())
            : DateTime.now();
        _seedStatus(c?.status ?? 'En attente');
      case BoEntity.frequence:
        final c = d as FrequenceModel?;
        _name.text = c?.libelle ?? '';
        _number.text = c?.jours.toString() ?? '7';
    }
  }

  void _seedStatus(String status) {
    // status select is the last dropdown of every form except frequence;
    // keep it on a dedicated member when the form has two selects.
    _status = status;
  }

  String _status = '';

  String get _title {
    final base = switch (widget.type) {
      BoEntity.client => 'client',
      BoEntity.collecteur => 'collecteur',
      BoEntity.contrat => 'contrat',
      BoEntity.collecte => 'collecte',
      BoEntity.facture => 'facture',
      BoEntity.frequence => 'fréquence',
    };
    return '${_isEdit ? 'Modifier' : 'Nouveau'} $base';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _fmtDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final store = widget.store;
    final s = _name.text.trim();
    final phone = _phone.text.trim();
    final zone = _zone.text.trim();
    final numText = _number.text.trim();
    final n = int.tryParse(numText) ?? 0;
    final r = double.tryParse(numText) ?? 0;
    final password = _password.text.trim();

    // Mot de passe : requis à la création (il permet à la personne de se
    // connecter à son interface) ; en édition, vide = on le conserve.
    if (_needsPassword) {
      if (!_isEdit && password.isEmpty) {
        return _warn('Le mot de passe est requis (min. 4 caractères)');
      }
      if (password.isNotEmpty && password.length < 4) {
        return _warn('Le mot de passe doit contenir au moins 4 caractères');
      }
    }

    try {
      switch (widget.type) {
        case BoEntity.client:
          if (s.isEmpty) return _warn('Le nom du client est requis');
          if (_isEdit) {
            await store.updateClient(
              (widget.existing as ClientModel).copyWith(
                name: s,
                phone: phone,
                zone: zone,
                plan: _selectA,
                status: _selectB,
              ),
              password: password,
            );
          } else {
            await store.addClient(
              name: s,
              phone: phone,
              zone: zone,
              plan: _selectA,
              status: _selectB,
              password: password,
            );
          }
        case BoEntity.collecteur:
          if (s.isEmpty) return _warn('Le nom du collecteur est requis');
          if (_isEdit) {
            await store.updateCollecteur(
              (widget.existing as CollecteurModel).copyWith(
                name: s,
                phone: phone,
                zone: zone,
                rating: r,
                status: _status,
              ),
              password: password,
            );
          } else {
            await store.addCollecteur(
              name: s,
              phone: phone,
              zone: zone,
              rating: r,
              status: _status,
              password: password,
            );
          }
        case BoEntity.contrat:
          if (_selectA.isEmpty || _selectB.isEmpty) {
            return _warn('Aucun client ou fréquence disponible');
          }
          if (n <= 0) return _warn('Le prix est requis');
          if (_isEdit) {
            await store.updateContrat(
              (widget.existing as ContratModel).copyWith(
                client: _selectA,
                frequence: _selectB,
                prix: n,
                status: _status,
              ),
            );
          } else {
            await store.addContrat(
              client: _selectA,
              frequence: _selectB,
              prix: n,
              status: _status,
            );
          }
        case BoEntity.collecte:
          if (_selectA.isEmpty || _selectB.isEmpty) {
            return _warn('Aucun client ou collecteur disponible');
          }
          if (_isEdit) {
            await store.updateCollecte(
              (widget.existing as CollecteModel).copyWith(
                client: _selectA,
                collecteur: _selectB,
                date: _fmtDate(_date),
                poids: r,
                status: _status,
              ),
            );
          } else {
            await store.addCollecte(
              client: _selectA,
              collecteur: _selectB,
              date: _fmtDate(_date),
              poids: r,
              status: _status,
            );
          }
        case BoEntity.facture:
          if (_selectA.isEmpty) return _warn('Aucun client disponible');
          if (n <= 0) return _warn('Le montant est requis');
          if (_isEdit) {
            await store.updateFacture(
              (widget.existing as FactureModel).copyWith(
                client: _selectA,
                montant: n,
                echeance: _fmtDate(_date),
                status: _status,
              ),
            );
          } else {
            await store.addFacture(
              client: _selectA,
              montant: n,
              echeance: _fmtDate(_date),
              status: _status,
            );
          }
        case BoEntity.frequence:
          if (s.isEmpty) return _warn('Le libellé est requis');
          if (_isEdit) {
            await store.updateFrequence(
              (widget.existing as FrequenceModel).copyWith(
                libelle: s,
                jours: n,
              ),
            );
          } else {
            await store.addFrequence(libelle: s, jours: n);
          }
      }
    } catch (e) {
      // Échec (ex. numéro déjà utilisé par un autre compte) : on garde la
      // feuille ouverte pour que l'admin puisse corriger.
      _warn(e.toString());
      return;
    }
    if (mounted) Navigator.of(context).pop();
    BoToastService.show('${_isEdit ? 'Modifié' : 'Ajouté'} avec succès');
  }

  void _warn(String message) {
    BoToastService.show(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: BackofficeTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: BackofficeTheme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 12, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Annuler',
                      style: BackofficeTheme.inter(
                        13,
                        weight: FontWeight.w600,
                        color: BackofficeTheme.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: BackofficeTheme.sora(
                        14.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('bo_sheet_save'),
                    onPressed: _save,
                    child: Text(
                      'OK',
                      style: BackofficeTheme.inter(
                        13,
                        weight: FontWeight.w700,
                        color: BackofficeTheme.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: BackofficeTheme.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _fields(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    final store = widget.store;
    switch (widget.type) {
      case BoEntity.client:
        return [
          _text(
            'Nom complet',
            _name,
            key: const Key('bo_f_name'),
            hint: 'Ex. Jean Dooh',
          ),
          _text('Téléphone', _phone, hint: '+237 6XX XX XX XX', phone: true),
          _text('Zone / Quartier', _zone, hint: 'Ex. Bonanjo'),
          Row(
            children: [
              Expanded(
                child: _select(
                  'Formule',
                  ['Essentiel', 'Standard', 'Premium'],
                  _selectA,
                  (v) => setState(() => _selectA = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _select(
                  'Statut',
                  ['Actif', 'Suspendu'],
                  _selectB,
                  (v) => setState(() => _selectB = v),
                ),
              ),
            ],
          ),
          _passwordField(),
        ];
      case BoEntity.collecteur:
        return [
          _text('Nom complet', _name, hint: 'Ex. Paul Mbarga'),
          _text('Téléphone', _phone, hint: '+237 6XX XX XX XX', phone: true),
          _text('Zone assignée', _zone, hint: 'Ex. Bonanjo / Akwa'),
          Row(
            children: [
              Expanded(
                child: _text(
                  'Note',
                  _number,
                  hint: '4.5',
                  number: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _select(
                  'Statut',
                  ['Actif', 'Inactif'],
                  _status.isEmpty ? 'Actif' : _status,
                  (v) => setState(() => _status = v),
                ),
              ),
            ],
          ),
          _passwordField(),
        ];
      case BoEntity.contrat:
        return [
          _select(
            'Client',
            store.clients.map((c) => c.name).toList(),
            _selectA,
            (v) => setState(() => _selectA = v),
          ),
          _select(
            'Fréquence',
            store.frequences.map((f) => f.libelle).toList(),
            _selectB,
            (v) => setState(() => _selectB = v),
          ),
          Row(
            children: [
              Expanded(
                child: _text(
                  'Prix / mois (XAF)',
                  _number,
                  hint: '8000',
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _select(
                  'Statut',
                  ['Actif', 'Suspendu', 'Expiré'],
                  _status.isEmpty ? 'Actif' : _status,
                  (v) => setState(() => _status = v),
                ),
              ),
            ],
          ),
        ];
      case BoEntity.collecte:
        return [
          _select(
            'Client',
            store.clients.map((c) => c.name).toList(),
            _selectA,
            (v) => setState(() => _selectA = v),
          ),
          _select(
            'Collecteur',
            store.collecteurs.map((c) => c.name).toList(),
            _selectB,
            (v) => setState(() => _selectB = v),
          ),
          Row(
            children: [
              Expanded(child: _dateField('Date', _fmtDate(_date), _pickDate)),
              const SizedBox(width: 12),
              Expanded(
                child: _text(
                  'Poids (kg)',
                  _number,
                  hint: '0',
                  number: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
            ],
          ),
          _select(
            'Statut',
            ['Prévu', 'Effectué', 'Manqué'],
            _status.isEmpty ? 'Prévu' : _status,
            (v) => setState(() => _status = v),
          ),
        ];
      case BoEntity.facture:
        return [
          _select(
            'Client',
            store.clients.map((c) => c.name).toList(),
            _selectA,
            (v) => setState(() => _selectA = v),
          ),
          Row(
            children: [
              Expanded(
                child: _text(
                  'Montant (XAF)',
                  _number,
                  hint: '8000',
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField('Échéance', _fmtDate(_date), _pickDate),
              ),
            ],
          ),
          _select(
            'Statut',
            ['Payée', 'En attente', 'En retard'],
            _status.isEmpty ? 'En attente' : _status,
            (v) => setState(() => _status = v),
          ),
        ];
      case BoEntity.frequence:
        return [
          _text('Libellé', _name, hint: 'Ex. Bi-hebdomadaire'),
          _text('Intervalle (jours)', _number, hint: '7', number: true),
        ];
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: BackofficeTheme.inter(
        11,
        weight: FontWeight.w600,
        color: BackofficeTheme.muted,
      ),
    ),
  );

  Widget _text(
    String label,
    TextEditingController controller, {
    String? hint,
    bool phone = false,
    bool number = false,
    Key? key,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          TextField(
            key: key,
            controller: controller,
            obscureText: obscure,
            keyboardType: number
                ? TextInputType.number
                : phone
                ? TextInputType.phone
                : TextInputType.text,
            inputFormatters: inputFormatters,
            style: BackofficeTheme.inter(14),
            decoration: _dec(hint, suffixIcon: suffixIcon),
          ),
        ],
      ),
    );
  }

  /// Champ mot de passe (client / collecteur) : c'est lui qui permet à la
  /// personne de se connecter à son interface dédiée.
  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          'Mot de passe',
          _password,
          key: const Key('bo_f_password'),
          hint: _isEdit ? 'Laisser vide pour conserver' : 'Min. 4 caractères',
          obscure: true,
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 17,
              color: BackofficeTheme.muted,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Text(
            widget.type == BoEntity.client
                ? 'Ce mot de passe permet à ce client de se connecter à son application client.'
                : 'Ce mot de passe permet à ce collecteur de se connecter à son application collecteur.',
            style: BackofficeTheme.inter(10.5, color: BackofficeTheme.muted),
          ),
        ),
      ],
    );
  }

  Widget _select(
    String label,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();
    final current = options.contains(value) ? value : options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          DropdownButtonFormField<String>(
            initialValue: current,
            isExpanded: true,
            style: BackofficeTheme.inter(14),
            dropdownColor: BackofficeTheme.surface,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: BackofficeTheme.muted,
            ),
            decoration: _dec(null),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: _dec(null),
              child: Text(value, style: BackofficeTheme.inter(14)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String? hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: BackofficeTheme.inter(14, color: BackofficeTheme.muted),
      filled: true,
      fillColor: BackofficeTheme.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BackofficeTheme.border),
      ),
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
