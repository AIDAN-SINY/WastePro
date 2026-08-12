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
///
/// [selectedAgenceId] permet au General Administrator de « zoomer » sur une
/// agence : le dropdown du header change les stats de l'Overview pour cette
/// agence ('' = toute l'entreprise).
class CompanyStore extends ChangeNotifier {
  CompanyStore({this.societeId = ''});

  /// Entreprise de l'administrateur connecté ('' en preview démo / tests).
  final String societeId;

  /// Id de l'agence sélectionnée par le dropdown du header ('' = toutes).
  String _selectedAgenceId = '';
  String get selectedAgenceId => _selectedAgenceId;

  /// Re-sélectionne l'agence sur laquelle l'Overview se concentre.
  void selectAgence(String id) {
    _selectedAgenceId = id;
    notifyListeners();
  }

  /// L'agence sélectionnée, ou null quand le scope couvre toute l'entreprise.
  AgenceModel? get selectedAgence {
    if (_selectedAgenceId.isEmpty) return null;
    for (final a in agences) {
      if (a.id == _selectedAgenceId) return a;
    }
    return null;
  }

  /// Agences dans le scope courant (toutes, ou uniquement la sélectionnée).
  List<AgenceModel> get scopedAgences {
    final sel = selectedAgence;
    return sel == null ? agences : [sel];
  }

  /// Utilisateurs (chefs d'agence) dans le scope courant.
  List<PlatformUserModel> get scopedUtilisateurs {
    final sel = selectedAgence;
    if (sel == null) return utilisateurs;
    return utilisateurs
        .where((u) =>
            u.agenceId == sel.id || u.agence == sel.ville)
        .toList();
  }

  /// Nombre de chefs d'agence affectés à [agenceId].
  int managersForAgence(String agenceId) {
    return utilisateurs.where((u) => u.agenceId == agenceId).length;
  }

  /// Agences actives du scope courant.
  int get activeAgencies =>
      scopedAgences.where((a) => a.status == 'Active' || a.status == 'Actif').length;

  /// Répartition des rôles utilisateurs (pour le donut « managers »).
  int get scopedManagersCount => scopedUtilisateurs.length;

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
  /// Creates and returns the new agency (callers use its id to attach
  /// resources like the agency manager).
  Future<AgenceModel> addAgence({
    required String ville,
    String location = '',
    required String responsable,
    required String telephone,
    required String status,
  }) async {
    final agence = AgenceModel(
      id: nextId(),
      societe: societeNom,
      societeId: societeId,
      ville: ville,
      location: location,
      responsable: responsable,
      telephone: telephone,
      status: status,
    );
    agences.add(agence);
    notifyListeners();
    return agence;
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

  // --- Preview demo data ---

  /// Seeds preview data so the demo experience looks rich directly.
  /// Called by [CompanyConsole] when the store is mock (preview mode).
  void seedPreviewData() {
    // Ne seeder qu'une seule fois.
    if (agences.isNotEmpty) return;
    societes.clear();
    agences.clear();
    utilisateurs.clear();

    societes.add(const SocieteModel(
      id: 'preview-so1',
      raisonSociale: 'WastePro Douala Ltd',
      adresse: '127 Rue du Commerce, Akwa, Douala',
      telephone: '+237 233 42 10 55',
      email: 'contact@wastepro.cm',
      status: 'Active',
    ));

    agences.addAll([
      const AgenceModel(
        id: 'preview-ag1',
        societe: 'WastePro Douala Ltd',
        societeId: 'preview-so1',
        ville: 'Douala — Bonanjo',
        responsable: 'Jean Dooh',
        telephone: '+237 677 12 34 56',
        status: 'Active',
      ),
      const AgenceModel(
        id: 'preview-ag2',
        societe: 'WastePro Douala Ltd',
        societeId: 'preview-so1',
        ville: 'Douala — Bassa',
        responsable: 'Aïcha Bello',
        telephone: '+237 699 33 67 41',
        status: 'Active',
      ),
      const AgenceModel(
        id: 'preview-ag3',
        societe: 'WastePro Douala Ltd',
        societeId: 'preview-so1',
        ville: 'Yaoundé',
        responsable: 'Marie Ekwalla',
        telephone: '+237 690 45 12 78',
        status: 'Active',
      ),
    ]);

    utilisateurs.addAll([
      PlatformUserModel(
        id: 'preview-u1',
        nom: 'Jean Dooh',
        telephone: '+237 677 12 34 56',
        role: 'Agency Manager',
        agence: 'Douala — Bonanjo',
        societeId: 'preview-so1',
        agenceId: 'preview-ag1',
        status: 'Active',
        password: '',
      ),
      PlatformUserModel(
        id: 'preview-u2',
        nom: 'Aïcha Bello',
        telephone: '+237 699 33 67 41',
        role: 'Agency Manager',
        agence: 'Douala — Bassa',
        societeId: 'preview-so1',
        agenceId: 'preview-ag2',
        status: 'Active',
        password: '',
      ),
      PlatformUserModel(
        id: 'preview-u3',
        nom: 'Marie Ekwalla',
        telephone: '+237 690 45 12 78',
        role: 'Agency Manager',
        agence: 'Yaoundé',
        societeId: 'preview-so1',
        agenceId: 'preview-ag3',
        status: 'Active',
        password: '',
      ),
    ]);
  }
}
