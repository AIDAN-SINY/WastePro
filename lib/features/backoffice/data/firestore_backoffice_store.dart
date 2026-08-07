import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models.dart';
import 'backoffice_store.dart';
import 'seed_data.dart';

/// Firestore-backed implementation of [BackofficeStore] for the real mobile
/// backoffice (entreprise manager).
///
/// - Collections: `clients`, `collecteurs` (document id = entity id).
/// - Data stays in sync in real time through snapshot listeners.
/// - When a collection is empty on first load, it is seeded with the
///   design's default entities (see [seedIfEmpty]) so the backoffice is
///   never blank on a fresh project.
/// - Creating / editing a client or collector with a password also creates
///   its **login account** in `users` (role 'client' / 'collector', marker
///   `consoleCreated`) so the person can log in to their dedicated
///   interface. Active collectors are also pre-approved in the `collectors`
///   whitelist.
/// - On failure (network / rules), [error] is set so the screen can show a
///   banner with a retry action; the mock data is never shown.
class FirestoreBackofficeStore extends BackofficeStore {
  FirestoreBackofficeStore({
    FirebaseFirestore? db,
    this.seedIfEmpty = true,
    @visibleForTesting bool Function()? isSignedOut,
  }) : _isSignedOutOverride = isSignedOut,
       _db = db ?? FirebaseFirestore.instance {
    // Never flash the design's mock data in the real backoffice.
    clients.clear();
    collecteurs.clear();
    load();
  }

  final FirebaseFirestore _db;

  /// When true, an empty collection is populated with [seedClients] /
  /// [seedCollecteurs] on first load.
  final bool seedIfEmpty;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];

  Completer<void>? _loadCompleter;
  int _pending = 0;
  bool _seededClients = false;
  bool _seededCollecteurs = false;

  /// Completes once the first snapshot of every collection has been applied
  /// (or an error occurred). Used by tests to await the initial load.
  Future<void> get initialLoad =>
      _loadCompleter?.future ?? Future<void>.value();

  @override
  String nextId() => 'b${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<void> load() async {
    _cancelSubscriptions();
    setLoading(true);
    setErrorValue(null);
    _pending = 2;
    _seededClients = false;
    _seededCollecteurs = false;
    _loadCompleter = Completer<void>();
    notifyListeners();

    _subs.add(
      _db
          .collection('clients')
          .snapshots()
          .listen(_onClients, onError: handleStreamError),
    );
    _subs.add(
      _db
          .collection('collecteurs')
          .snapshots()
          .listen(_onCollecteurs, onError: handleStreamError),
    );

    await _loadCompleter!.future;
  }

  // --- Snapshot handlers ---

  void _onClients(QuerySnapshot<Map<String, dynamic>> qs) {
    clients
      ..clear()
      ..addAll(qs.docs.map((d) => ClientModel.fromMap(d.data())));
    if (seedIfEmpty && qs.docs.isEmpty && !_seededClients) {
      _seededClients = true;
      _seedCollection('clients', seedClients.map((c) => c.toMap()).toList());
    }
    _markLoaded();
  }

  void _onCollecteurs(QuerySnapshot<Map<String, dynamic>> qs) {
    collecteurs
      ..clear()
      ..addAll(qs.docs.map((d) => CollecteurModel.fromMap(d.data())));
    if (seedIfEmpty && qs.docs.isEmpty && !_seededCollecteurs) {
      _seededCollecteurs = true;
      _seedCollection(
        'collecteurs',
        seedCollecteurs.map((c) => c.toMap()).toList(),
      );
      _seedCollectorWhitelist();
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

  /// Vrai quand aucune session Firebase Auth n'est active (déconnecté ou
  /// token expiré). Protégé pour les tests (app Firebase non initialisée) :
  /// on considère alors qu'une session existe, pour ne jamais masquer une
  /// vraie erreur de règles.
  bool _isSignedOut() {
    final override = _isSignedOutOverride;
    if (override != null) return override();
    try {
      return FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return false;
    }
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

  /// Pré-approuve (liste blanche `collectors`) les collecteurs seedés actifs,
  /// pour que le flow d'auto-inscription leur attribue le rôle 'collector'.
  Future<void> _seedCollectorWhitelist() async {
    try {
      final batch = _db.batch();
      for (final c in seedCollecteurs.where((c) => c.status == 'Active')) {
        final phone = _canonicalPhone(c.phone);
        if (phone.isNotEmpty) {
          batch.set(_db.collection('collectors').doc(phone), {
            'phone': phone,
            'name': c.name,
          });
        }
      }
      await batch.commit();
    } catch (error) {
      setErrorValue(_friendlyError(error));
      notifyListeners();
    }
  }

  // --- Clients CRUD ---

  @override
  Future<void> addClient({
    required String name,
    required String phone,
    required String zone,
    required String plan,
    required String status,
    String password = '',
  }) async {
    final model = ClientModel(
      id: nextId(),
      name: name,
      phone: phone,
      zone: zone,
      plan: plan,
      status: status,
    );
    await _saveWithLogin(
      collection: 'clients',
      id: model.id,
      entityMap: {...model.toMap(), 'password': password},
      phone: phone,
      fullName: name,
      role: 'client',
      password: password,
      active: status == 'Active',
      subscriptionPlan: plan,
      isSubscribed: status == 'Active',
    );
    // Upsert : le snapshot peut déjà avoir appliqué ce document.
    final index = clients.indexWhere((c) => c.id == model.id);
    if (index == -1) {
      clients.add(model);
    } else {
      clients[index] = model;
    }
    notifyListeners();
  }

  @override
  Future<void> updateClient(ClientModel updated, {String password = ''}) async {
    ClientModel? old;
    for (final c in clients) {
      if (c.id == updated.id) {
        old = c;
        break;
      }
    }
    // Conserve le mot de passe déjà enregistré si aucun nouveau n'est saisi.
    final stored =
        (await _db.collection('clients').doc(updated.id).get())
                .data()?['password']
            as String? ??
        '';
    final effective = password.isNotEmpty ? password : stored;
    await _saveWithLogin(
      collection: 'clients',
      id: updated.id,
      entityMap: {...updated.toMap(), 'password': effective},
      phone: updated.phone,
      fullName: updated.name,
      role: 'client',
      password: effective,
      active: updated.status == 'Active',
      subscriptionPlan: updated.plan,
      isSubscribed: updated.status == 'Active',
      oldPhone: old != null && old.phone != updated.phone ? old.phone : null,
    );
    final index = clients.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      clients[index] = updated;
    } else {
      clients.add(updated);
    }
    notifyListeners();
  }

  @override
  Future<void> deleteClient(String id) async {
    ClientModel? existing;
    for (final c in clients) {
      if (c.id == id) {
        existing = c;
        break;
      }
    }
    try {
      final batch = _db.batch();
      batch.delete(_db.collection('clients').doc(id));
      await _stageLoginDeletion(batch, existing?.phone);
      await batch.commit();
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
    clients.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // --- Collecteurs CRUD ---

  @override
  Future<void> addCollecteur({
    required String name,
    required String phone,
    required String zone,
    required double rating,
    required String status,
    String password = '',
  }) async {
    final model = CollecteurModel(
      id: nextId(),
      name: name,
      phone: phone,
      zone: zone,
      rating: rating,
      status: status,
    );
    await _saveWithLogin(
      collection: 'collecteurs',
      id: model.id,
      entityMap: {...model.toMap(), 'password': password},
      phone: phone,
      fullName: name,
      role: 'collector',
      password: password,
      active: status == 'Active',
      whitelist: true,
    );
    // Upsert : le snapshot peut déjà avoir appliqué ce document.
    final index = collecteurs.indexWhere((c) => c.id == model.id);
    if (index == -1) {
      collecteurs.add(model);
    } else {
      collecteurs[index] = model;
    }
    notifyListeners();
  }

  @override
  Future<void> updateCollecteur(
    CollecteurModel updated, {
    String password = '',
  }) async {
    CollecteurModel? old;
    for (final c in collecteurs) {
      if (c.id == updated.id) {
        old = c;
        break;
      }
    }
    final stored =
        (await _db.collection('collecteurs').doc(updated.id).get())
                .data()?['password']
            as String? ??
        '';
    final effective = password.isNotEmpty ? password : stored;
    await _saveWithLogin(
      collection: 'collecteurs',
      id: updated.id,
      entityMap: {...updated.toMap(), 'password': effective},
      phone: updated.phone,
      fullName: updated.name,
      role: 'collector',
      password: effective,
      active: updated.status == 'Active',
      whitelist: true,
      oldPhone: old != null && old.phone != updated.phone ? old.phone : null,
    );
    final index = collecteurs.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      collecteurs[index] = updated;
    } else {
      collecteurs.add(updated);
    }
    notifyListeners();
  }

  @override
  Future<void> deleteCollecteur(String id) async {
    CollecteurModel? existing;
    for (final c in collecteurs) {
      if (c.id == id) {
        existing = c;
        break;
      }
    }
    try {
      final batch = _db.batch();
      batch.delete(_db.collection('collecteurs').doc(id));
      await _stageLoginDeletion(batch, existing?.phone);
      final phone = _canonicalPhone(existing?.phone ?? '');
      if (phone.isNotEmpty) {
        // Retire aussi l'approbation de la liste blanche des collecteurs.
        batch.delete(_db.collection('collectors').doc(phone));
      }
      await batch.commit();
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
    collecteurs.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // --- Comptes de connexion ---

  /// Écrit l'entité + synchronise son compte de connexion dans `users`
  /// (et la liste blanche `collectors` pour les collecteurs) dans un seul
  /// batch, donc de façon atomique.
  ///
  /// - Statut inactif/suspendu → le compte de connexion est supprimé (plus
  ///   de login possible) tant que la personne n'est pas réactivée.
  /// - Un numéro déjà utilisé par un compte réel (non créé par la console)
  ///   n'est jamais écrasé : une erreur est levée à la place.
  Future<void> _saveWithLogin({
    required String collection,
    required String id,
    required Map<String, dynamic> entityMap,
    required String phone,
    required String fullName,
    required String role,
    required String password,
    required bool active,
    String? subscriptionPlan,
    bool? isSubscribed,
    bool whitelist = false,
    String? oldPhone,
  }) async {
    final canonical = _canonicalPhone(phone);
    final oldCanonical = oldPhone == null ? '' : _canonicalPhone(oldPhone);
    final loginRef = canonical.isEmpty
        ? null
        : _db.collection('users').doc(canonical);

    DocumentSnapshot<Map<String, dynamic>>? existing;
    if (loginRef != null) existing = await loginRef.get();

    if (active && loginRef != null && existing!.exists) {
      final isConsole = existing.data()?['consoleCreated'] == true;
      if (!isConsole) {
        throw _SyncError(
          'An account already exists with this number. Choose a different '
          'number.',
        );
      }
    }

    final batch = _db.batch();
    batch.set(_db.collection(collection).doc(id), entityMap);

    if (loginRef != null) {
      if (active) {
        // Mot de passe final : le nouveau saisi, sinon l'existant.
        final finalPassword = password.isNotEmpty
            ? password
            : (existing!.data()?['password'] as String? ?? '');
        if (finalPassword.isNotEmpty) {
          batch.set(loginRef, {
            'phoneNumber': canonical,
            'fullName': fullName,
            'role': role,
            'password': finalPassword,
            'subscription_plan': ?subscriptionPlan,
            'isSubscribed': ?isSubscribed,
            // Marqueur : compte créé/géré par le backoffice admin — seul ce
            // type de compte peut être écrasé ou supprimé proprement.
            'consoleCreated': true,
          });
        }
      } else if (existing!.exists &&
          existing.data()?['consoleCreated'] == true) {
        batch.delete(loginRef);
      }
    }

    // Pré-approbation des collecteurs actifs (auto-inscription → 'collector').
    if (whitelist) {
      if (active && canonical.isNotEmpty) {
        batch.set(_db.collection('collectors').doc(canonical), {
          'phone': canonical,
          'name': fullName,
        });
      } else if (canonical.isNotEmpty) {
        batch.delete(_db.collection('collectors').doc(canonical));
      }
      if (oldCanonical.isNotEmpty && oldCanonical != canonical) {
        batch.delete(_db.collection('collectors').doc(oldCanonical));
      }
    }

    // Téléphone changé → supprime l'ancien compte de connexion (s'il a été
    // créé par la console) pour ne pas laisser de doublon orphelin.
    if (oldCanonical.isNotEmpty && oldCanonical != canonical) {
      final oldDoc = await _db.collection('users').doc(oldCanonical).get();
      if (oldDoc.exists && oldDoc.data()?['consoleCreated'] == true) {
        batch.delete(_db.collection('users').doc(oldCanonical));
      }
    }

    try {
      await batch.commit();
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
  }

  /// Supprime le compte de connexion d'un téléphone, uniquement s'il a été
  /// créé par le backoffice (jamais un compte client/collecteur réel).
  Future<void> _stageLoginDeletion(WriteBatch batch, String? phone) async {
    final canonical = _canonicalPhone(phone ?? '');
    if (canonical.isEmpty) return;
    final doc = await _db.collection('users').doc(canonical).get();
    if (doc.exists && doc.data()?['consoleCreated'] == true) {
      batch.delete(doc.reference);
    }
  }

  // --- Helpers ---

  /// Normalise un numéro de téléphone : sans espaces ni tirets, préfixe +237
  /// (gère aussi le « 237... » saisi sans le +).
  String _canonicalPhone(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('237')) return '+$cleaned';
    return '+237$cleaned';
  }

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
/// quel par le toast du formulaire, sans préfixe « Exception: »).
class _SyncError implements Exception {
  _SyncError(this.message);

  final String message;

  @override
  String toString() => message;
}
