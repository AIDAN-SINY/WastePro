import 'package:flutter/foundation.dart';

import '../../../models/agence_model.dart';
import '../../../models/platform_user_model.dart';
import '../../../models/societe_model.dart';
import 'seed_data.dart';

/// In-memory store for the Super Admin console.
///
/// Provides the mock dataset from the design plus the loading/error lifecycle
/// shared with [FirestorePlatformStore] (see `firestore_platform_store.dart`),
/// which overrides the CRUD methods to persist to Firestore while keeping the
/// same interface (ChangeNotifier + entity lists).
class PlatformStore extends ChangeNotifier {
  int _uid = 100;

  /// Generates a unique entity id. Overridden by the Firestore store to
  /// produce ids that never collide across sessions.
  @protected
  String nextId() => 'id${_uid++}';

  // --- Lifecycle state ---
  bool _isLoading = false;
  String? _error;

  /// True while the initial data is being fetched from the backend.
  bool get isLoading => _isLoading;

  /// Non-null when the initial load failed (e.g. network / rules).
  String? get error => _error;

  @protected
  void setLoading(bool value) => _isLoading = value;

  @protected
  void setErrorValue(String? value) => _error = value;

  /// Loads the initial data. The base (mock) store has nothing to load.
  Future<void> load() async {}

  // --- Mock data (same as the HTML design) ---
  final List<SocieteModel> societes = [...seedSocietes];
  final List<AgenceModel> agences = [...seedAgences];
  final List<PlatformUserModel> utilisateurs = [...seedUtilisateurs];

  // --- Dashboard helpers ---
  // Counts both the English ('Active') and the legacy French ('Actif')
  // values so companies created before the switch stay on the dashboard.
  int get societesActives => societes
      .where((s) => s.status == 'Active' || s.status == 'Actif')
      .length;
  int get agencesCount => agences.length;
  int get utilisateursCount => utilisateurs.length;

  // --- Sociétés CRUD ---
  Future<void> addSociete({
    required String raisonSociale,
    required String adresse,
    required String telephone,
    required String email,
    required String status,
  }) async {
    societes.add(
      SocieteModel(
        id: nextId(),
        raisonSociale: raisonSociale,
        adresse: adresse,
        telephone: telephone,
        email: email,
        status: status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateSociete(SocieteModel updated) async {
    final index = societes.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    final oldName = societes[index].raisonSociale;
    societes[index] = updated;
    // Agences reference the société by name: a rename must cascade, or they
    // would keep a stale name (breaking the delete guard and the overview
    // "Agences par société" chart).
    if (oldName != updated.raisonSociale) {
      for (var i = 0; i < agences.length; i++) {
        if (agences[i].societe == oldName) {
          agences[i] = agences[i].copyWith(societe: updated.raisonSociale);
        }
      }
    }
    notifyListeners();
  }

  Future<void> deleteSociete(String id) async {
    societes.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // --- Agences CRUD ---
  Future<void> addAgence({
    required String societe,
    required String ville,
    required String responsable,
    required String telephone,
    required String status,
  }) async {
    agences.add(
      AgenceModel(
        id: nextId(),
        societe: societe,
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

  // --- Utilisateurs CRUD ---
  Future<void> addUtilisateur({
    required String nom,
    required String telephone,
    required String role,
    required String agence,
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
