import 'package:flutter/foundation.dart';

import '../models.dart';
import 'seed_data.dart';

/// In-memory store for the mobile backoffice (entreprise manager).
///
/// Provides the design's mock dataset plus the loading/error lifecycle shared
/// with a future `FirestoreBackofficeStore` (same pattern as the super admin
/// console) — the CRUD methods are the only place that will change.
class BackofficeStore extends ChangeNotifier {
  int _uid = 100;

  /// Generates a unique entity id. Overridden by a Firestore store to
  /// produce ids that never collide across sessions.
  @protected
  String nextId() => 'id${_uid++}';

  // --- Lifecycle state (ready for a Firestore-backed store) ---
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  @protected
  void setLoading(bool value) => _isLoading = value;

  @protected
  void setErrorValue(String? value) => _error = value;

  /// Loads the initial data. The base (mock) store has nothing to load.
  Future<void> load() async {}

  /// Mock dataset, with two collectes pinned to today so the
  /// « Collectes aujourd'hui » KPI stays alive whatever the date.
  BackofficeStore() {
    final now = DateTime.now();
    final iso =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (collectes.length >= 4) {
      collectes[2] = collectes[2].copyWith(date: iso);
      collectes[3] = collectes[3].copyWith(date: iso);
    }
  }

  // --- Mock data (same entities as backoffice-mobile.html) ---
  final List<ClientModel> clients = [...seedClients];
  final List<CollecteurModel> collecteurs = [...seedCollecteurs];
  final List<ContratModel> contrats = [...seedContrats];
  final List<CollecteModel> collectes = [...seedCollectes];
  final List<FactureModel> factures = [...seedFactures];
  final List<FrequenceModel> frequences = [...seedFrequences];

  // --- List filters (per entity) ---
  final Map<BoEntity, String> _filters = {};

  static String _defaultFilter(BoEntity type) => switch (type) {
    BoEntity.client || BoEntity.collecteur || BoEntity.contrat => 'Tous',
    BoEntity.collecte || BoEntity.facture || BoEntity.frequence => 'Toutes',
  };

  String filterFor(BoEntity type) => _filters[type] ?? _defaultFilter(type);

  void selectFilter(BoEntity type, String value) {
    if (_filters[type] == value) return;
    _filters[type] = value;
    notifyListeners();
  }

  // --- Dashboard helpers ---
  int get clientsActifs => clients.where((c) => c.status == 'Actif').length;

  int get collectesAujourdhui {
    final now = DateTime.now();
    final key =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return collectes.where((c) => c.date == key).length;
  }

  /// Revenus (milliers de XAF) = factures payées.
  double get revenusMilliers {
    final total = factures
        .where((f) => f.status == 'Payée')
        .fold<int>(0, (s, f) => s + f.montant);
    return total / 1000;
  }

  /// Taux de réussite = part des collectes effectuées.
  double get tauxReussite {
    if (collectes.isEmpty) return 0;
    final ok = collectes.where((c) => c.status == 'Effectué').length;
    return ok / collectes.length * 100;
  }

  // --- Clients CRUD ---
  //
  // [password] crée (ou met à jour) le compte de connexion du client dans
  // `users`. La base (mock) l'ignore ; le store Firestore l'utilise pour
  // que le client puisse se connecter à son interface dédiée.
  Future<void> addClient({
    required String name,
    required String phone,
    required String zone,
    required String plan,
    required String status,
    String password = '',
  }) async {
    clients.add(
      ClientModel(
        id: nextId(),
        name: name,
        phone: phone,
        zone: zone,
        plan: plan,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateClient(ClientModel updated, {String password = ''}) async {
    final index = clients.indexWhere((c) => c.id == updated.id);
    if (index != -1) clients[index] = updated;
    notifyListeners();
  }

  Future<void> deleteClient(String id) async {
    clients.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // --- Collecteurs CRUD ---
  //
  // [password] crée (ou met à jour) le compte de connexion du collecteur
  // dans `users` (rôle 'collector'). La base (mock) l'ignore.
  Future<void> addCollecteur({
    required String name,
    required String phone,
    required String zone,
    required double rating,
    required String status,
    String password = '',
  }) async {
    collecteurs.add(
      CollecteurModel(
        id: nextId(),
        name: name,
        phone: phone,
        zone: zone,
        rating: rating,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateCollecteur(
    CollecteurModel updated, {
    String password = '',
  }) async {
    final index = collecteurs.indexWhere((c) => c.id == updated.id);
    if (index != -1) collecteurs[index] = updated;
    notifyListeners();
  }

  Future<void> deleteCollecteur(String id) async {
    collecteurs.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // --- Contrats CRUD ---
  Future<void> addContrat({
    required String client,
    required String frequence,
    required int prix,
    required String status,
  }) async {
    contrats.add(
      ContratModel(
        id: nextId(),
        client: client,
        frequence: frequence,
        prix: prix,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateContrat(ContratModel updated) async {
    final index = contrats.indexWhere((c) => c.id == updated.id);
    if (index != -1) contrats[index] = updated;
    notifyListeners();
  }

  Future<void> deleteContrat(String id) async {
    contrats.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // --- Collectes CRUD ---
  Future<void> addCollecte({
    required String client,
    required String collecteur,
    required String date,
    required double poids,
    required String status,
  }) async {
    collectes.add(
      CollecteModel(
        id: nextId(),
        client: client,
        collecteur: collecteur,
        date: date,
        poids: poids,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateCollecte(CollecteModel updated) async {
    final index = collectes.indexWhere((c) => c.id == updated.id);
    if (index != -1) collectes[index] = updated;
    notifyListeners();
  }

  Future<void> deleteCollecte(String id) async {
    collectes.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // --- Factures CRUD ---
  Future<void> addFacture({
    required String client,
    required int montant,
    required String echeance,
    required String status,
  }) async {
    factures.add(
      FactureModel(
        id: nextId(),
        client: client,
        montant: montant,
        echeance: echeance,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateFacture(FactureModel updated) async {
    final index = factures.indexWhere((f) => f.id == updated.id);
    if (index != -1) factures[index] = updated;
    notifyListeners();
  }

  Future<void> deleteFacture(String id) async {
    factures.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  // --- Frequences CRUD ---
  Future<void> addFrequence({
    required String libelle,
    required int jours,
  }) async {
    frequences.add(
      FrequenceModel(id: nextId(), libelle: libelle, jours: jours),
    );
    notifyListeners();
  }

  Future<void> updateFrequence(FrequenceModel updated) async {
    final index = frequences.indexWhere((f) => f.id == updated.id);
    if (index != -1) frequences[index] = updated;
    notifyListeners();
  }

  Future<void> deleteFrequence(String id) async {
    frequences.removeWhere((f) => f.id == id);
    notifyListeners();
  }
}
