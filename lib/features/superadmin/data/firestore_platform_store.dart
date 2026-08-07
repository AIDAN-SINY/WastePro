import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../models/agence_model.dart';
import '../../../models/platform_user_model.dart';
import '../../../models/societe_model.dart';
import 'platform_store.dart';
import 'seed_data.dart';

/// Firestore-backed implementation of [PlatformStore] for the real
/// super admin console.
///
/// - Collections: `societes`, `agences`, `utilisateurs` (document id = entity id).
/// - Data stays in sync in real time through snapshot listeners.
/// - When a collection is empty on first load, it is seeded with the
///   design's default entities (see [seedIfEmpty]) so the console is
///   never blank on a fresh project.
/// - On failure (network / rules), [error] is set so the console can show a
///   banner with a retry action; the mock data is never shown.
class FirestorePlatformStore extends PlatformStore {
  FirestorePlatformStore({
    FirebaseFirestore? db,
    this.seedIfEmpty = true,
    @visibleForTesting bool Function()? isSignedOut,
  }) : _isSignedOutOverride = isSignedOut,
       _db = db ?? FirebaseFirestore.instance {
    // Never flash the design's mock data in the real console.
    societes.clear();
    agences.clear();
    utilisateurs.clear();
    load();
  }

  final FirebaseFirestore _db;

  /// When true, an empty collection is populated with [seedSocietes] /
  /// [seedAgences] / [seedUtilisateurs] on first load.
  final bool seedIfEmpty;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];

  Completer<void>? _loadCompleter;
  int _pending = 0;
  bool _seededSocietes = false;
  bool _seededAgences = false;
  bool _seededUtilisateurs = false;

  /// Completes once the first snapshot of every collection has been applied
  /// (or an error occurred). Used by tests to await the initial load.
  Future<void> get initialLoad =>
      _loadCompleter?.future ?? Future<void>.value();

  @override
  String nextId() => 'f${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<void> load() async {
    _cancelSubscriptions();
    setLoading(true);
    setErrorValue(null);
    _pending = 3;
    _seededSocietes = false;
    _seededAgences = false;
    _seededUtilisateurs = false;
    _loadCompleter = Completer<void>();
    notifyListeners();

    _subs.add(
      _db.collection('societes').snapshots().listen(
            _onSocietes,
            onError: handleStreamError,
          ),
    );
    _subs.add(
      _db.collection('agences').snapshots().listen(
            _onAgences,
            onError: handleStreamError,
          ),
    );
    _subs.add(
      _db.collection('utilisateurs').snapshots().listen(
            _onUtilisateurs,
            onError: handleStreamError,
          ),
    );

    await _loadCompleter!.future;
  }

  // --- Snapshot handlers ---

  void _onSocietes(QuerySnapshot<Map<String, dynamic>> qs) {
    societes
      ..clear()
      ..addAll(qs.docs.map((d) => SocieteModel.fromMap(d.data())));
    if (seedIfEmpty && qs.docs.isEmpty && !_seededSocietes) {
      _seededSocietes = true;
      _seedCollection(
        'societes',
        seedSocietes.map((s) => s.toMap()).toList(),
      );
    }
    _markLoaded();
  }

  void _onAgences(QuerySnapshot<Map<String, dynamic>> qs) {
    agences
      ..clear()
      ..addAll(qs.docs.map((d) => AgenceModel.fromMap(d.data())));
    if (seedIfEmpty && qs.docs.isEmpty && !_seededAgences) {
      _seededAgences = true;
      _seedCollection('agences', seedAgences.map((a) => a.toMap()).toList());
    }
    _markLoaded();
  }

  void _onUtilisateurs(QuerySnapshot<Map<String, dynamic>> qs) {
    utilisateurs
      ..clear()
      ..addAll(qs.docs.map((d) => PlatformUserModel.fromMap(d.data())));
    if (seedIfEmpty && qs.docs.isEmpty && !_seededUtilisateurs) {
      _seededUtilisateurs = true;
      _seedCollection(
        'utilisateurs',
        seedUtilisateurs.map((u) => u.toMap()).toList(),
      );
    }
    _markLoaded();
  }

  void _markLoaded() {
    if (_pending > 0) _pending--;
    if (_pending <= 0) {
      setLoading(false);
      final completer = _loadCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
    notifyListeners();
  }

  final bool Function()? _isSignedOutOverride;

  /// Point d'entrée des erreurs de flux (exposé pour les tests).
  ///
  /// Après une déconnexion, le token est révoqué et les règles rejettent
  /// les listeners encore actifs (permission-denied…) : c'est attendu — la
  /// console est en train de se démonter, on n'affiche pas de bannière.
  @visibleForTesting
  void handleStreamError(Object error) {
    setLoading(false);
    if (!_isSignedOut()) {
      setErrorValue(_friendlyError(error));
    }
    final completer = _loadCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    notifyListeners();
  }

  /// Vrai quand aucune session active n'existe (déconnecté).
  ///
  /// La connexion n'utilise plus Firebase Auth (restaurée en mode
  /// « numéro + mot de passe » Firestore) : il n'y a donc jamais de token
  /// à révoquer au logout et les erreurs de flux ne doivent pas être
  /// masquées. Le cas « logout → permission-denied attendu » reste testable
  /// via [_isSignedOutOverride].
  bool _isSignedOut() {
    final override = _isSignedOutOverride;
    if (override != null) return override();
    return false;
  }

  Future<void> _seedCollection(
    String collection,
    List<Map<String, dynamic>> docs,
  ) async {
    try {
      final batch = _db.batch();
      for (final doc in docs) {
        batch.set(_db.collection(collection).doc(doc['id'] as String), doc);
      }
      await batch.commit();
    } catch (error) {
      setErrorValue(_friendlyError(error));
      notifyListeners();
    }
  }

  // --- Sociétés CRUD ---

  @override
  Future<void> addSociete({
    required String raisonSociale,
    required String adresse,
    required String telephone,
    required String email,
    required String status,
  }) async {
    final model = SocieteModel(
      id: nextId(),
      raisonSociale: raisonSociale,
      adresse: adresse,
      telephone: telephone,
      email: email,
      status: status,
    );
    try {
      await _db.collection('societes').doc(model.id).set(model.toMap());
    } catch (error) {
      throw _friendlyError(error);
    }
    // Upsert: the snapshot listener may already have applied this document.
    final index = societes.indexWhere((s) => s.id == model.id);
    if (index == -1) {
      societes.add(model);
    } else {
      societes[index] = model;
    }
    notifyListeners();
  }

  @override
  Future<void> updateSociete(SocieteModel updated) async {
    String? oldName;
    for (final s in societes) {
      if (s.id == updated.id) {
        oldName = s.raisonSociale;
        break;
      }
    }
    try {
      await _db.collection('societes').doc(updated.id).set(updated.toMap());
      // Cascade the rename to agences referencing the old name (agences
      // store the société by name, not by id).
      if (oldName != null && oldName != updated.raisonSociale) {
        final agenceDocs = await _db
            .collection('agences')
            .where('societe', isEqualTo: oldName)
            .get();
        if (agenceDocs.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in agenceDocs.docs) {
            batch.update(doc.reference, {'societe': updated.raisonSociale});
          }
          await batch.commit();
        }
      }
    } catch (error) {
      throw _friendlyError(error);
    }
    final index = societes.indexWhere((s) => s.id == updated.id);
    if (index != -1) societes[index] = updated;
    // Keep the local list in sync with the rename (snapshots will confirm).
    if (oldName != null && oldName != updated.raisonSociale) {
      for (var i = 0; i < agences.length; i++) {
        if (agences[i].societe == oldName) {
          agences[i] = agences[i].copyWith(societe: updated.raisonSociale);
        }
      }
    }
    notifyListeners();
  }

  @override
  Future<void> deleteSociete(String id) async {
    try {
      await _db.collection('societes').doc(id).delete();
    } catch (error) {
      throw _friendlyError(error);
    }
    societes.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // --- Agences CRUD ---

  @override
  Future<void> addAgence({
    required String societe,
    required String ville,
    required String responsable,
    required String telephone,
    required String status,
  }) async {
    final model = AgenceModel(
      id: nextId(),
      societe: societe,
      ville: ville,
      responsable: responsable,
      telephone: telephone,
      status: status,
    );
    try {
      await _db.collection('agences').doc(model.id).set(model.toMap());
    } catch (error) {
      throw _friendlyError(error);
    }
    // Upsert: the snapshot listener may already have applied this document.
    final index = agences.indexWhere((a) => a.id == model.id);
    if (index == -1) {
      agences.add(model);
    } else {
      agences[index] = model;
    }
    notifyListeners();
  }

  @override
  Future<void> updateAgence(AgenceModel updated) async {
    try {
      await _db.collection('agences').doc(updated.id).set(updated.toMap());
    } catch (error) {
      throw _friendlyError(error);
    }
    final index = agences.indexWhere((a) => a.id == updated.id);
    if (index != -1) agences[index] = updated;
    notifyListeners();
  }

  @override
  Future<void> deleteAgence(String id) async {
    try {
      await _db.collection('agences').doc(id).delete();
    } catch (error) {
      throw _friendlyError(error);
    }
    agences.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // --- Utilisateurs CRUD ---

  @override
  Future<void> addUtilisateur({
    required String nom,
    required String telephone,
    required String role,
    required String agence,
    required String status,
    required String password,
  }) async {
    final model = PlatformUserModel(
      id: nextId(),
      nom: nom,
      telephone: telephone,
      role: role,
      agence: agence,
      status: status,
      password: password,
    );
    try {
      await _db.collection('utilisateurs').doc(model.id).set(model.toMap());
      // Compte de connexion réel : l'utilisateur se connecte avec son
      // numéro + le mot de passe fixé par le super admin.
      await _syncLogin(model);
    } catch (error) {
      if (error is! FirebaseException) rethrow;
      throw _friendlyError(error);
    }
    // Upsert: the snapshot listener may already have applied this document.
    final index = utilisateurs.indexWhere((u) => u.id == model.id);
    if (index == -1) {
      utilisateurs.add(model);
    } else {
      utilisateurs[index] = model;
    }
    notifyListeners();
  }

  @override
  Future<void> updateUtilisateur(PlatformUserModel updated) async {
    try {
      await _db.collection('utilisateurs').doc(updated.id).set(updated.toMap());
      await _syncLogin(updated);
    } catch (error) {
      if (error is! FirebaseException) rethrow;
      throw _friendlyError(error);
    }
    final index = utilisateurs.indexWhere((u) => u.id == updated.id);
    if (index != -1) utilisateurs[index] = updated;
    notifyListeners();
  }

  @override
  Future<void> deleteUtilisateur(String id) async {
    // Supprime aussi le compte de connexion correspondant dans `users`.
    var existing = const PlatformUserModel(
      id: '',
      nom: '',
      telephone: '',
      role: '',
      agence: '',
      status: '',
    );
    for (final u in utilisateurs) {
      if (u.id == id) {
        existing = u;
        break;
      }
    }
    try {
      await _db.collection('utilisateurs').doc(id).delete();
      // Ne supprime le compte de connexion que s'il a été créé par la
      // console (marqueur consoleCreated) — jamais un compte client réel.
      final phone = _canonicalPhone(existing.telephone);
      if (phone.isNotEmpty) {
        final loginDoc = await _db.collection('users').doc(phone).get();
        if (loginDoc.exists && loginDoc.data()?['consoleCreated'] == true) {
          await loginDoc.reference.delete();
        }
      }
    } catch (error) {
      if (error is! FirebaseException) rethrow;
      throw _friendlyError(error);
    }
    utilisateurs.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  /// Crée (ou met à jour) le compte de connexion dans la collection `users`
  /// pour un utilisateur console qui a un mot de passe. Sans mot de passe,
  /// aucun compte de connexion n'est créé (ex. les utilisateurs seedés).
  ///
  /// - Statut « Suspendu » → le compte de connexion est supprimé (plus de
  ///   login possible) tant que l'utilisateur n'est pas réactivé.
  /// - Un numéro déjà utilisé par un compte client/collecteur réel n'est
  ///   jamais écrasé : une erreur est levée à la place.
  Future<void> _syncLogin(PlatformUserModel user) async {
    final phone = _canonicalPhone(user.telephone);
    if (phone.isEmpty || user.password.isEmpty) return;
    final ref = _db.collection('users').doc(phone);

    // Accepte aussi le statut hérité français ('Suspendu') : les docs
    // créés avant le passage à l'anglais gardent leur valeur d'origine.
    if (user.status == 'Suspended' || user.status == 'Suspendu') {
      final doc = await ref.get();
      if (doc.exists && doc.data()?['consoleCreated'] == true) {
        await ref.delete();
      }
      return;
    }

    final existing = await ref.get();
    if (existing.exists && existing.data()?['consoleCreated'] != true) {
      throw _SyncError(
        'A client account already exists with this number. Choose a '
        'different number.',
      );
    }
    await ref.set({
      'phoneNumber': phone,
      'fullName': user.nom,
      // Les deux rôles console pointent vers le dashboard admin existant ;
      // un dashboard dédié « Responsable d'Agence » pourra être ajouté.
      'role': 'admin',
      'password': user.password,
      'isSubscribed': false,
      // Marqueur : ce compte a été créé/géré par la console super admin.
      'consoleCreated': true,
    });
  }

  /// Normalise un numéro de téléphone : sans espaces ni tirets, préfixe +237
  /// (gère aussi le « 237... » saisi sans le +).
  String _canonicalPhone(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('237')) return '+$cleaned';
    return '+237$cleaned';
  }

  // --- Helpers ---

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return 'Service unavailable. Check your internet connection.';
        case 'permission-denied':
          return 'Access denied. Check the project Firestore rules.';
        default:
          return error.message ?? 'Firestore error.';
      }
    }
    return 'An error occurred. Please try again.';
  }

  void _cancelSubscriptions() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}

/// Erreur métier de la synchro du compte de connexion (message affiché tel
/// quel par le toast du drawer, sans préfixe « Exception: »).
class _SyncError implements Exception {
  _SyncError(this.message);

  final String message;

  @override
  String toString() => message;
}
