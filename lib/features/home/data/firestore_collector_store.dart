import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../services/auth_service.dart';
import '../../backoffice/models.dart';
import 'collector_store.dart';

/// Store Firestore du dashboard collecteur — données RÉELLES.
///
/// - Profil : `collecteurs` (un collecteur se connecte avec son numéro ;
///   on retrouve sa fiche par téléphone canonique).
/// - Collectes : `collectes` filtrées sur le NOM du collecteur (c'est la
///   clé utilisée par le backoffice, cf. `collecteurNameFor`).
/// - Clients : `clients` filtrés sur `collecteurId`.
///
/// Les actions du dashboard sont persistées : `completeCollecte` met à jour
/// `collectes/{id}` (statut Completed + poids + commentaire), `markMissed`
/// le passe en Missed avec le motif choisi.
class FirestoreCollectorStore extends CollectorStore {
  FirestoreCollectorStore({
    required String phone,
    FirebaseFirestore? db,
    this.seedIfEmpty = true,
  }) : _phone = AuthService.canonicalPhone(phone),
       _db = db ?? FirebaseFirestore.instance {
    load();
  }

  final String _phone;
  final FirebaseFirestore _db;

  /// Quand aucune collecte n'existe pour ce collecteur sur un projet neuf,
  /// le seed des collectes est inséré (données de démonstration scopées sur
  /// ce collecteur).
  final bool seedIfEmpty;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];

  Completer<void>? _loadCompleter;
  int _pending = 0;
  bool _disposed = false;
  bool _seeded = false;

  /// Nom du collecteur résolu depuis sa fiche (clé des collectes).
  String _collectorName = '';

  /// Complete once the first snapshot has been applied (used by tests).
  Future<void> get initialLoad => _loadCompleter?.future ?? Future<void>.value();

  @override
  Future<void> load() async {
    _cancelSubscriptions();
    setLoading(true);
    setErrorValue(null);
    _pending = 0;
    _loadCompleter = Completer<void>();
    notifyListeners();

    // 1. Profil : `collecteurs` où phone == numéro du collecteur connecté.
    try {
      final qs = await _db
          .collection('collecteurs')
          .where('phone', isEqualTo: _phone)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        final model = CollecteurModel.fromMap(qs.docs.first.data());
        setCollecteur(model);
        _collectorName = model.name;
      }
    } catch (error) {
      _fail(error);
      return;
    }

    // 2. Collectes du collecteur (par nom) + clients assignés (par id).
    _pending = 2;
    _listenCollectes();
    _listenClients();

    await _loadCompleter!.future;
  }

  void _listenCollectes() {
    final name = _collectorName;
    if (name.isEmpty) {
      // Collecteur introuvable : écoute quand même (le nom reste vide →
      // aucune collecte) pour terminer le chargement proprement.
      _markLoaded();
      return;
    }
    final query = _db
        .collection('collectes')
        .where('collecteur', isEqualTo: name);
    _subs.add(query.snapshots().listen(
      (qs) {
        collectes
          ..clear()
          ..addAll(qs.docs.map((d) => CollecteModel.fromMap(d.data())));
        if (seedIfEmpty && qs.docs.isEmpty && !_seeded) {
          _seeded = true;
          _seedCollectes(name);
        }
        _markLoaded();
        notifyListeners();
      },
      onError: handleStreamError,
    ));
  }

  void _listenClients() {
    final collecteur = this.collecteur;
    final id = collecteur?.id ?? '';
    final query = id.isEmpty
        ? _db.collection('clients').where('collecteurId', isEqualTo: '')
        : _db
              .collection('clients')
              .where('collecteurId', isEqualTo: id);
    _subs.add(query.snapshots().listen(
      (qs) {
        clients
          ..clear()
          ..addAll(qs.docs.map((d) => ClientModel.fromMap(d.data())));
        _markLoaded();
        notifyListeners();
      },
      onError: handleStreamError,
    ));
  }

  void _markLoaded() {
    if (_pending > 0) _pending--;
    if (_pending <= 0) {
      setLoading(false);
      final completer = _loadCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  void _fail(Object error) {
    setLoading(false);
    setErrorValue(_friendlyError(error));
    final completer = _loadCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    notifyListeners();
  }

  /// Point d'entrée des erreurs de flux (exposé pour les tests).
  @visibleForTesting
  void handleStreamError(Object error) {
    setLoading(false);
    if (!_disposed) {
      setErrorValue(_friendlyError(error));
    }
    final completer = _loadCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    notifyListeners();
  }

  /// Insère des collectes de démonstration pour ce collecteur sur un projet
  /// neuf (aucune collecte n'existe encore) — sinon le dashboard serait vide
  /// sans rien à montrer. Les dates sont autour d'aujourd'hui pour que la
  /// tournée du jour soit visible.
  Future<void> _seedCollectes(String name) async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final yKey =
          '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';

      // Clients de démo assignés à ce collecteur (les vraies fiches sont
      // créées par le chef d'agence dans le backoffice).
      final demoClients = [
        ClientModel(
          id: 'dcc1',
          name: 'Jean Dooh',
          phone: '+237 677 12 34 56',
          zone: 'Bonanjo',
          plan: 'Standard',
          status: 'Active',
          collecteurId: collecteur?.id ?? '',
        ),
        ClientModel(
          id: 'dcc2',
          name: 'Sarah Mbida',
          phone: '+237 691 77 04 22',
          zone: 'Bonanjo',
          plan: 'Essential',
          status: 'Active',
          collecteurId: collecteur?.id ?? '',
        ),
        ClientModel(
          id: 'dcc3',
          name: 'Marie Ekwalla',
          phone: '+237 690 45 12 78',
          zone: 'Akwa',
          plan: 'Premium',
          status: 'Active',
          collecteurId: collecteur?.id ?? '',
        ),
      ];

      final seed = [
        CollecteModel(
          id: nextId(),
          client: 'Jean Dooh',
          collecteur: name,
          date: today,
          poids: 4.2,
          status: 'Completed',
          commentaire: 'Bac plein, collecte ok',
        ),
        CollecteModel(
          id: nextId(),
          client: 'Sarah Mbida',
          collecteur: name,
          date: today,
          poids: 0,
          status: 'Scheduled',
        ),
        CollecteModel(
          id: nextId(),
          client: 'Marie Ekwalla',
          collecteur: name,
          date: today,
          poids: 0,
          status: 'Scheduled',
        ),
        CollecteModel(
          id: nextId(),
          client: 'Jean Dooh',
          collecteur: name,
          date: yKey,
          poids: 3.9,
          status: 'Completed',
        ),
      ];

      final batch = _db.batch();
      for (final client in demoClients) {
        batch.set(_db.collection('clients').doc(client.id), client.toMap());
      }
      for (final c in seed) {
        batch.set(_db.collection('collectes').doc(c.id), c.toMap());
      }
      await batch.commit();
    } catch (error) {
      setErrorValue(_friendlyError(error));
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // Actions opérationnelles (persistées)
  // ------------------------------------------------------------------

  @override
  Future<void> completeCollecte(
    CollecteModel collecte, {
    required double poids,
    String commentaire = '',
  }) async {
    try {
      await _db.collection('collectes').doc(collecte.id).update({
        'status': 'Completed',
        'poids': poids,
        'commentaire': commentaire,
      });
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
    super.completeCollecte(
      collecte,
      poids: poids,
      commentaire: commentaire,
    );
  }

  @override
  Future<void> markMissed(
    CollecteModel collecte, {
    required String motif,
  }) async {
    try {
      await _db.collection('collectes').doc(collecte.id).update({
        'status': 'Missed',
        'motif': motif,
      });
    } catch (error) {
      throw _SyncError(_friendlyError(error));
    }
    super.markMissed(collecte, motif: motif);
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return 'Service unavailable. Check your internet connection.';
        case 'permission-denied':
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

/// Erreur métier (message affiché tel quel par le toast).
class _SyncError implements Exception {
  _SyncError(this.message);

  final String message;

  @override
  String toString() => message;
}
