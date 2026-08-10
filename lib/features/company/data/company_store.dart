import 'package:flutter/foundation.dart';

import '../../../models/agence_model.dart';
import '../../../models/platform_user_model.dart';
import '../../../models/societe_model.dart';

/// Store de la console entreprise (General Administrator).
///
/// Données scopées à l'entreprise du connecté ([societeId]) : sa société,
/// ses agences, et ses utilisateurs (chefs d'agence). La base (mock) tient
/// les listes en mémoire ; [FirestoreCompanyStore] (firestore_company_store)
/// persiste dans Firestore avec la même interface (ChangeNotifier + CRUD).
class CompanyStore extends ChangeNotifier {
  CompanyStore({this.societeId = ''});

  /// Entreprise de l'administrateur connecté ('' en preview démo / tests).
  final String societeId;

  int _uid = 1000;

  /// Génère un id unique. Surchargé par le store Firestore pour produire
  /// des ids qui ne se heurtent jamais entre sessions.
  @protected
  String nextId() => 'id${_uid++}';

  // --- Cycle de vie (prêt pour le store Firestore) ---
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  @protected
  void setLoading(bool value) => _isLoading = value;

  @protected
  void setErrorValue(String? value) => _error = value;

  /// Charge les données initiales. La base (mock) n'a rien à charger.
  Future<void> load() async {}

  // --- Données scopées ---
  final List<SocieteModel> societes = [];
  final List<AgenceModel> agences = [];
  final List<PlatformUserModel> utilisateurs = [];

  /// Nom de l'entreprise (raison sociale) une fois chargée.
  String get societeNom =>
      societes.isNotEmpty ? societes.first.raisonSociale : '';

  // --- Agences CRUD (mock) ---
  Future<void> addAgence({
    required String ville,
    required String responsable,
    required String telephone,
    required String status,
  }) async {
    agences.add(
      AgenceModel(
        id: nextId(),
        societe: societeNom,
        societeId: societeId,
        ville: ville,
        responsable: responsable,
        telephone: telephone,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateAgence(AgenceModel updated) async {
    final index = agences.indexWhere((a) => a.id == updated.id);
    if (index != -1) agences[index] = updated;
    notifyListeners();
  }

  Future<void> deleteAgence(String id) async {
    agences.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // --- Utilisateurs (chefs d'agence) CRUD (mock) ---
  Future<void> addUtilisateur({
    required String nom,
    required String telephone,
    required String role,
    required String agence,
    String agenceId = '',
    required String status,
    required String password,
  }) async {
    utilisateurs.add(
      PlatformUserModel(
        id: nextId(),
        nom: nom,
        telephone: telephone,
        role: role,
        agence: agence,
        societeId: societeId,
        agenceId: agenceId,
        status: status,
        password: password,
      ),
    );
    notifyListeners();
  }

  Future<void> updateUtilisateur(PlatformUserModel updated) async {
    final index = utilisateurs.indexWhere((u) => u.id == updated.id);
    if (index != -1) utilisateurs[index] = updated;
    notifyListeners();
  }

  Future<void> deleteUtilisateur(String id) async {
    utilisateurs.removeWhere((u) => u.id == id);
    notifyListeners();
  }
}
