import 'package:flutter/foundation.dart';

import '../../backoffice/models.dart';

/// Store du dashboard collecteur (base, données mock pour les tests).
///
/// Les vraies données sont chargées par [FirestoreCollectorStore] (même
/// pattern que le backoffice) : profil du collecteur (`collecteurs`), ses
/// collectes (`collectes`, liées par NOM de collecteur) et ses clients
/// (`clients`, liés par `collecteurId`).
///
/// Le dashboard est opérationnel : marquer une collecte « Completed » (avec
/// poids + commentaire) ou « Missed » (avec motif) persiste dans Firestore.
class CollectorStore extends ChangeNotifier {
  int _uid = 1000;

  @protected
  String nextId() => 'c${_uid++}';

  // --- Lifecycle ---
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  @protected
  void setLoading(bool value) => _isLoading = value;

  @protected
  void setErrorValue(String? value) => _error = value;

  /// Profil du collecteur connecté (nom, zone, note, statut).
  CollecteurModel? _collecteur;

  CollecteurModel? get collecteur => _collecteur;

  @protected
  void setCollecteur(CollecteurModel? value) {
    _collecteur = value;
    notifyListeners();
  }

  /// Toutes les collectes du collecteur (passées + à venir).
  final List<CollecteModel> collectes = [];

  /// Clients assignés à ce collecteur.
  final List<ClientModel> clients = [];

  /// Charge les données initiales (la base mock n'a rien à charger).
  Future<void> load() async {}

  // ------------------------------------------------------------------
  // KPIs (le dashboard est alimenté par les données réelles)
  // ------------------------------------------------------------------

  /// Date du jour au format yyyy-MM-dd (même format que Firestore).
  static String todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Collectes programmées aujourd'hui.
  List<CollecteModel> get todayCollectes =>
      collectes.where((c) => c.date == todayIso()).toList();

  List<CollecteModel> get doneToday =>
      todayCollectes.where((c) => c.status == 'Completed').toList();

  List<CollecteModel> get missedToday =>
      todayCollectes.where((c) => c.status == 'Missed').toList();

  List<CollecteModel> get pendingToday => todayCollectes
      .where((c) => c.status == 'Scheduled')
      .toList();

  /// Poids collecté aujourd'hui (collectes terminées).
  double get kgToday => doneToday.fold(0, (s, c) => s + c.poids);

  /// Taux de réussite = terminées / (terminées + manquées), toutes dates.
  double get successRate {
    final done = collectes.where((c) => c.status == 'Completed').length;
    final missed = collectes.where((c) => c.status == 'Missed').length;
    final total = done + missed;
    if (total == 0) return 0;
    return done / total * 100;
  }

  /// Nombre total de collectes réalisées.
  int get totalDone =>
      collectes.where((c) => c.status == 'Completed').length;

  /// Poids total collecté (toutes dates).
  double get totalKg =>
      collectes.where((c) => c.status == 'Completed').fold(0, (s, c) => s + c.poids);

  /// Historique groupé par date (dates décroissantes).
  List<DateTime> get historyDates {
    final set = <String>{};
    for (final c in collectes) {
      if (c.date.isNotEmpty) set.add(c.date);
    }
    final dates = set.map(DateTime.parse).toList()
      ..sort((a, b) => b.compareTo(a));
    return dates;
  }

  List<CollecteModel> collectesOn(DateTime day) {
    final key = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return collectes.where((c) => c.date == key).toList();
  }

  /// Détail client d'une collecte ('' si inconnu).
  String clientZone(String clientName) {
    for (final c in clients) {
      if (c.name == clientName) return c.zone;
    }
    return '';
  }

  // ------------------------------------------------------------------
  // Actions opérationnelles (le store Firestore les persiste)
  // ------------------------------------------------------------------

  /// Marque une collecte comme terminée : poids + commentaire + statut.
  Future<void> completeCollecte(
    CollecteModel collecte, {
    required double poids,
    String commentaire = '',
  }) async {
    final updated = collecte.copyWith(
      status: 'Completed',
      poids: poids,
      commentaire: commentaire,
    );
    _replaceLocally(updated);
  }

  /// Marque une collecte comme manquée avec un motif.
  Future<void> markMissed(
    CollecteModel collecte, {
    required String motif,
  }) async {
    final updated = collecte.copyWith(status: 'Missed', motif: motif);
    _replaceLocally(updated);
  }

  void _replaceLocally(CollecteModel updated) {
    final index = collectes.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      collectes[index] = updated;
    } else {
      collectes.add(updated);
    }
    notifyListeners();
  }
}
