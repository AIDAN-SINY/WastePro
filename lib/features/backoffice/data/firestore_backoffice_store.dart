import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    this.agenceId = '',
    this.societeId = '',
    @visibleForTesting bool Function()? isSignedOut,
  }) : _isSignedOutOverride = isSignedOut,
       _db = db ?? FirebaseFirestore.instance {
    _isScoped = agenceId.isNotEmpty;
    // Never flash the design's mock data in the real backoffice.
    clients.clear();
    collecteurs.clear();
    registrations.clear();
    load();
  }

  final FirebaseFirestore _db;

  /// When true, an empty collection is populated with [seedClients] /
  /// [seedCollecteurs] on first load.
  final bool seedIfEmpty;

  /// Id de l'agence du chef connecté (facultatif). Quand non vide, les
  /// données du backoffice sont filtrées à cette agence.
  final String agenceId;

  /// Id de l'entreprise (facultatif, porté par le login).
  final String societeId;

  /// Vrai quand le backoffice est limité à une agence (Phase 3).
  bool _isScoped = false;

  /// Ville (nom) de l'agence du chef — clé de secours pour retrouver les
  /// candidatures écrites avec le NOM de l'agence (`agenceName`) plutôt
  /// qu'avec son id (ex. doublons d'agences homonymes, candidatures dont
  /// l'`agenceId` pointe vers un autre doc que celui du chef).
  ///
  /// Compromis assumé : les chefs d'agences homonymes voient les mêmes
  /// candidatures (partage par nom) ; à l'approbation, le client est créé
  /// sous l'agence CHOISIE par le client (`reg.agenceId`), jamais sous
  /// celle du chef qui approuve — aucune donnée n'est corrompue.
  String _agencyVille = '';

  /// Candidatures vues par le query `agenceId == X` (clé = id du doc).
  final Map<String, RegistrationModel> _regsById = {};

  /// Candidatures vues par le query de secours `agenceName == ville`.
  final Map<String, RegistrationModel> _regsByName = {};

  /// Vrai après [dispose] : aucune notification ne doit plus être émise
  /// (garde pour les lectures one-shot comme [_loadAgenceVille], qui ne
  /// passent pas par un abonnement annulable).
  bool _disposed = false;

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
    _pending = 3;
    _seededClients = false;
    _seededCollecteurs = false;
    _regsById.clear();
    _regsByName.clear();
    _loadCompleter = Completer<void>();
    notifyListeners();

    // Phase 3 : quand le backoffice est scopé à une agence, les listeners
    // filtrent sur agenceId — le chef d'agence ne voit que SES données.
    final clientsQuery = _isScoped
        ? _db.collection('clients').where('agenceId', isEqualTo: agenceId)
        : _db.collection('clients');
    final collecteursQuery = _isScoped
        ? _db.collection('collecteurs').where('agenceId', isEqualTo: agenceId)
        : _db.collection('collecteurs');
    // Candidatures : celles adressées à cette agence (sélection dans le
    // formulaire client).
    final registrationsQuery = _isScoped
        ? _db
              .collection('registrations')
              .where('agenceId', isEqualTo: agenceId)
        : _db.collection('registrations');

    // Phase 3 : charge la ville de l'agence AVANT de monter les listeners
    // de candidatures — c'est la clé de secours par NOM (voir
    // [_agencyVille]). Silencieux : un échec ne doit pas bloquer le
    // backoffice (la recherche par id reste active).
    if (_isScoped && agenceId.isNotEmpty) {
      _agencyVille = await _loadAgenceVille();
    } else {
      _agencyVille = '';
    }

    _subs.add(
      clientsQuery.snapshots().listen(_onClients, onError: handleStreamError),
    );
    _subs.add(
      collecteursQuery
          .snapshots()
          .listen(_onCollecteurs, onError: handleStreamError),
    );
    // Fallback par NOM d'agence : un where supplémentaire sur un SEUL champ
    // (pas d'index composé requis). Fusionné en mémoire avec le listener par
    // id dans [registrations].
    if (_isScoped && _agencyVille.isNotEmpty) {
      _subs.add(
        _db
            .collection('registrations')
            .where('agenceName', isEqualTo: _agencyVille)
            .snapshots()
            .listen(
              _onRegistrationsByName,
              // Le fallback par nom est best-effort : un échec de CE query
              // ne doit pas afficher de bannière alors que le query par id
              // fonctionne (mêmes règles, mais défense en profondeur).
              onError: _ignoreFallbackError,
            ),
      );
    }
    _subs.add(
      registrationsQuery
          .snapshots()
          .listen(_onRegistrations, onError: handleStreamError),
    );

    await _loadCompleter!.future;
  }

  /// Lit `agences/{agenceId}`, expose son `ville` comme nom d'agence
  /// (sidebar) et le renvoie pour le fallback par nom des candidatures
  /// ('' si indisponible).
  Future<String> _loadAgenceVille() async {
    try {
      final doc = await _db.collection('agences').doc(agenceId).get();
      if (_disposed) return '';
      if (!doc.exists) return '';
      final ville = doc.data()?['ville'] as String? ?? '';
      if (ville.isNotEmpty) setAgenceName(ville);
      return ville;
    } catch (_) {
      // Silencieux (voir [load]).
      return '';
    }
  }

  // --- Snapshot handlers ---

  void _onClients(QuerySnapshot<Map<String, dynamic>> qs) {
    clients
      ..clear()
      ..addAll(qs.docs.map((d) => ClientModel.fromMap(d.data())));
    if (_seedEnabled && qs.docs.isEmpty && !_seededClients) {
      _seededClients = true;
      _seedCollection('clients', seedClients.map((c) => c.toMap()).toList());
    }
    _markLoaded();
  }

  void _onCollecteurs(QuerySnapshot<Map<String, dynamic>> qs) {
    collecteurs
      ..clear()
      ..addAll(qs.docs.map((d) => CollecteurModel.fromMap(d.data())));
    if (_seedEnabled && qs.docs.isEmpty && !_seededCollecteurs) {
      _seededCollecteurs = true;
      _seedCollection(
        'collecteurs',
        seedCollecteurs.map((c) => c.toMap()).toList(),
      );
      _seedCollectorWhitelist();
    }
    _markLoaded();
  }

  void _onRegistrations(QuerySnapshot<Map<String, dynamic>> qs) {
    _regsById
      ..clear()
      ..addEntries(
        qs.docs.map(
          (d) => MapEntry(d.id, RegistrationModel.fromMap(d.data())),
        ),
      );
    _rebuildRegistrations();
    _markLoaded();
  }

  /// Erreur du fallback par nom : ignorée (best-effort, voir [load]).
  void _ignoreFallbackError(Object error) {}

  /// Snapshots du fallback par `agenceName` (uniquement quand le backoffice
  /// est scopé). Ne marque pas le chargement initial (le listener par id
  /// s'en charge).
  void _onRegistrationsByName(QuerySnapshot<Map<String, dynamic>> qs) {
    _regsByName
      ..clear()
      ..addEntries(
        qs.docs.map(
          (d) => MapEntry(d.id, RegistrationModel.fromMap(d.data())),
        ),
      );
    _rebuildRegistrations();
  }

  /// Fusionne les candidatures vues par id et par nom (dédoublonnées par id)
  /// dans [registrations].
  void _rebuildRegistrations() {
    final merged = <String, RegistrationModel>{..._regsById, ..._regsByName};
    registrations
      ..clear()
      ..addAll(merged.values);
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

  /// Pré-approuve (liste blanche `collectors`) les collecteurs seedés actifs,
  /// pour que le flow d'auto-inscription leur attribue le rôle 'collector'.
  Future<void> _seedCollectorWhitelist() async {
    try {
      final batch = _db.batch();
      for (final c in seedCollecteurs.where((c) => _isActive(c.status))) {
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

  /// Le seed est désactivé quand le backoffice est scopé à une agence
  /// (les données viennent de l'entreprise, pas du seed).
  bool get _seedEnabled => seedIfEmpty && !_isScoped;

  // --- Candidatures (pré-inscriptions clients) ---

  @override
  Future<void> approveRegistration(
    RegistrationModel reg, {
    required String collecteurId,
  }) async {
    final clientId = nextId();
    final client = ClientModel(
      id: clientId,
      name: reg.fullName,
      phone: reg.phone,
      zone: reg.zone,
      plan: 'Standard',
      status: 'Active',
      agenceId: reg.agenceId,
      societeId: reg.societeId,
      collecteurId: collecteurId,
    );
    final canonical = _canonicalPhone(reg.phone);
    // Garde anti-doublon : une candidature déjà traitée (ou supprimée) ne
    // doit jamais créer un second client + compte de connexion. Vérifiée
    // AVANT l'écriture — l'approbation est atomique ou rien.
    final regDoc = await _db.collection('registrations').doc(reg.id).get();
    if (!regDoc.exists) {
      throw _SyncError('This application no longer exists.');
    }
    if (regDoc.data()?['status'] != 'pending') {
      throw _SyncError('This application has already been reviewed.');
    }
    try {
      final batch = _db.batch();
      // 1. Le client (le mot de passe choisi par le client est conservé
      //    dans le doc, comme pour les clients créés à la main).
      batch.set(_db.collection('clients').doc(clientId), {
        ...client.toMap(),
        'password': reg.password,
      });
      // 2. Son compte de connexion : il peut enfin se connecter.
      if (canonical.isNotEmpty && reg.password.isNotEmpty) {
        batch.set(_db.collection('users').doc(canonical), {
          'phoneNumber': canonical,
          'fullName': reg.fullName,
          'role': 'client',
          'password': reg.password,
          'subscription_plan': 'Standard',
          'isSubscribed': true,
          'agenceId': reg.agenceId,
          'societeId': reg.societeId,
          'collecteurId': collecteurId,
          // Marqueur : compte créé/géré par le backoffice admin.
          'consoleCreated': true,
        });
      }
      // 3. La candidature passe à 'approved' avec le collecteur assigné.
      batch.update(_db.collection('registrations').doc(reg.id), {
        'status': 'approved',
        'collecteurId': collecteurId,
      });
      // 4. Le client est notifié dans l'app (cloche du dashboard) : la
      //    décision est visible dès sa prochaine ouverture de l'app.
      if (canonical.isNotEmpty) {
        batch.set(
          _db.collection('notifications').doc('notif${reg.id}'),
          _notificationMap(
            regId: reg.id,
            phone: canonical,
            type: 'approved',
            title: 'Application approved',
            message: 'Your application was approved. You can now log in '
                'and start scheduling your pickups.',
          ),
        );
      }
      await batch.commit();
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
    // Mise à jour locale optimiste (le snapshot confirmera).
    final index = registrations.indexWhere((r) => r.id == reg.id);
    final updated = reg.copyWith(status: 'approved', collecteurId: collecteurId);
    if (index != -1) {
      registrations[index] = updated;
    } else {
      registrations.add(updated);
    }
    if (!clients.any((c) => c.id == clientId)) clients.add(client);
    notifyListeners();
  }

  @override
  Future<void> rejectRegistration(RegistrationModel reg) async {
    final canonical = _canonicalPhone(reg.phone);
    try {
      final batch = _db.batch();
      batch.update(_db.collection('registrations').doc(reg.id), {
        'status': 'rejected',
      });
      // Notifie le client dans l'app (cloche du dashboard).
      if (canonical.isNotEmpty) {
        batch.set(
          _db.collection('notifications').doc('notif${reg.id}'),
          _notificationMap(
            regId: reg.id,
            phone: canonical,
            type: 'rejected',
            title: 'Application rejected',
            message: 'Your application was rejected. You can submit a new '
                'application from the app.',
          ),
        );
      }
      await batch.commit();
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
    final index = registrations.indexWhere((r) => r.id == reg.id);
    final updated = reg.copyWith(status: 'rejected');
    if (index != -1) {
      registrations[index] = updated;
    } else {
      registrations.add(updated);
    }
    notifyListeners();
  }

  /// Doc de notification pour une décision de candidature. Id déterministe
  /// (`notif{regId}`) : une décision = une notification, jamais de doublon.
  Map<String, dynamic> _notificationMap({
    required String regId,
    required String phone,
    required String type,
    required String title,
    required String message,
  }) {
    final now = DateTime.now();
    final iso =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return {
      'id': 'notif$regId',
      'phone': phone,
      'type': type,
      'title': title,
      'message': message,
      'read': false,
      'createdAt': iso,
    };
  }

  /// Réassigne le collecteur d'un client — atomiquement :
  ///   1. `clients/{id}` porte le nouveau `collecteurId` ;
  ///   2. le compte de connexion `users/{téléphone}` est mis à jour (l'app
  ///      client connaît son nouveau collecteur) ;
  ///   3. les collectes à venir du client (Scheduled / Missed) portant
  ///      l'ancien collecteur basculent vers le nouveau — l'historique des
  ///      collectes effectuées ne change pas.
  @override
  Future<void> reassignCollecteur({
    required String clientId,
    required String collecteurId,
  }) async {
    ClientModel? client;
    for (final c in clients) {
      if (c.id == clientId) {
        client = c;
        break;
      }
    }
    if (client == null) return;
    if (client.collecteurId == collecteurId) return;

    final oldName = collecteurNameFor(collecteurs, client.collecteurId);
    final newName = collecteurNameFor(collecteurs, collecteurId);
    final canonical = _canonicalPhone(client.phone);

    try {
      final batch = _db.batch();
      // 1. Le client porte son nouveau collecteur (merge : on ne touche qu'à
      //    ce champ, même si le doc a été modifié hors console).
      batch.set(
        _db.collection('clients').doc(clientId),
        {'collecteurId': collecteurId},
        SetOptions(merge: true),
      );
      // 2. Le compte de connexion est mis à jour s'il existe.
      if (canonical.isNotEmpty) {
        final login = await _db.collection('users').doc(canonical).get();
        if (login.exists) {
          batch.update(login.reference, {'collecteurId': collecteurId});
        }
      }
      // 3. Les collectes à venir de ce client portant l'ancien collecteur.
      //    ⚠️ CollecteModel n'a pas encore d'agenceId : la correspondance se
      //    fait par NOM de client. Tant que deux agences ne partagent pas le
      //    même nom de client, c'est sans risque — à réviser quand `collectes`
      //    portera agenceId (multi-tenant).
      if (newName.isNotEmpty && oldName.isNotEmpty) {
        final upcoming = await _db
            .collection('collectes')
            .where('client', isEqualTo: client.name)
            .get();
        for (final doc in upcoming.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          final isDone = status == 'Completed' || status == 'Effectué';
          if (!isDone && data['collecteur'] == oldName) {
            batch.update(doc.reference, {'collecteur': newName});
          }
        }
      }
      await batch.commit();
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }

    // Mise à jour locale optimiste (le snapshot confirmera).
    final idx = clients.indexWhere((c) => c.id == clientId);
    if (idx != -1) clients[idx] = client.copyWith(collecteurId: collecteurId);
    if (newName.isNotEmpty && oldName.isNotEmpty) {
      for (var i = 0; i < collectes.length; i++) {
        final col = collectes[i];
        final isDone = col.status == 'Completed' || col.status == 'Effectué';
        if (!isDone &&
            col.client == client.name &&
            col.collecteur == oldName) {
          collectes[i] = col.copyWith(collecteur: newName);
        }
      }
    }
    notifyListeners();
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
    String agenceId = '',
    String societeId = '',
  }) async {
    final finalAgenceId = agenceId.isNotEmpty ? agenceId : this.agenceId;
    final finalSocieteId = societeId.isNotEmpty ? societeId : this.societeId;
    final model = ClientModel(
      id: nextId(),
      name: name,
      phone: phone,
      zone: zone,
      plan: plan,
      status: status,
      agenceId: finalAgenceId,
      societeId: finalSocieteId,
    );
    await _saveWithLogin(
      collection: 'clients',
      id: model.id,
      entityMap: {...model.toMap(), 'password': password},
      phone: phone,
      fullName: name,
      role: 'client',
      password: password,
      active: _isActive(status),
      subscriptionPlan: plan,
      isSubscribed: _isActive(status),
      collecteurId: model.collecteurId,
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
      active: _isActive(updated.status),
      subscriptionPlan: updated.plan,
      isSubscribed: _isActive(updated.status),
      collecteurId: updated.collecteurId,
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
    String agenceId = '',
    String societeId = '',
  }) async {
    final finalAgenceId = agenceId.isNotEmpty ? agenceId : this.agenceId;
    final finalSocieteId = societeId.isNotEmpty ? societeId : this.societeId;
    final model = CollecteurModel(
      id: nextId(),
      name: name,
      phone: phone,
      zone: zone,
      rating: rating,
      status: status,
      agenceId: finalAgenceId,
      societeId: finalSocieteId,
    );
    await _saveWithLogin(
      collection: 'collecteurs',
      id: model.id,
      entityMap: {...model.toMap(), 'password': password},
      phone: phone,
      fullName: name,
      role: 'collector',
      password: password,
      active: _isActive(status),
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
      active: _isActive(updated.status),
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
    String collecteurId = '',
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
            // Le collecteur du client est porté par son compte : l'app
            // client peut afficher / contacter le bon collecteur.
            'collecteurId': collecteurId,
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

  /// Vrai pour les statuts « actif » anglais ET hérités français (les
  /// enregistrements Firestore créés avant le passage à l'anglais gardent
  /// leurs valeurs : 'Actif'). Sans ça, éditer un client legacy le
  /// considérerait inactif et supprimerait son compte de connexion.
  bool _isActive(String status) => status == 'Active' || status == 'Actif';

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
          // Les règles LOCALES (firestore.rules) sont ouvertes : si Firebase
          // refuse quand même, c'est que les règles DÉPLOYÉES sur le projet
          // sont périmées (ex. collection `registrations` ajoutée après le
          // dernier déploiement). Le correctif est `firebase deploy
          // --only firestore:rules`.
          return 'Access denied: the Firestore rules deployed on Firebase '
              'are out of date. Deploy the latest rules with: firebase '
              'deploy --only firestore:rules';
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
    _disposed = true;
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
