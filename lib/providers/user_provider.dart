import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_backend.dart';
import '../services/auth_service.dart';

/// État de connexion global de l'app.
///
/// Depuis la migration sécurité, la session vit dans Firebase Auth (email
/// dérivé du numéro) : [tryAutoLogin] restaure la session persistée par Auth
/// et recharge le profil `users/{téléphone}` correspondant via
/// `auth_profiles/{uid}` (uid → téléphone).
class UserProvider with ChangeNotifier {
  UserProvider({AuthBackend? backend})
      : _backend = backend ?? FirebaseAuthBackend();

  final AuthBackend _backend;

  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  // 1. Set User and Persist Session
  Future<void> setUser(UserModel user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'saved_phone',
      user.phoneNumber,
    ); // Save phone locally
    notifyListeners();
  }

  // 2. Try Auto-Login on Startup (session Firebase Auth persistée)
  Future<void> tryAutoLogin() async {
    // Auth restaure sa propre session : si un uid est actif, on retrouve le
    // téléphone via auth_profiles/{uid} puis on charge le profil.
    final uid = _backend.currentUid;
    if (uid == null) return;
    try {
      final profile = await FirebaseFirestore.instance
          .collection('auth_profiles')
          .doc(uid)
          .get();
      if (!profile.exists) return;
      final phone = profile.data()?['phone'] as String?;
      if (phone == null || phone.isEmpty) return;
      await refreshUser(phone);
    } catch (e) {
      debugPrint("Error restoring session: $e");
    }
  }

  // 3. Fetch/Refresh user data from Firestore
  Future<void> refreshUser(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Essaie la clé telle que sauvegardée, puis sa forme canonique
      // (+237...) : un doc créé à la main dans la console peut avoir une
      // clé différente du champ phoneNumber (ex. clé '677123456', champ
      // '+237677123456').
      _user = null;
      for (final key in AuthService.canonicalKeys(phone)) {
        if (key.isEmpty) continue;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(key)
            .get();
        if (doc.exists) {
          _user = UserModel.fromMap(doc.data()!);
          break;
        }
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  // 4. Logout and Clear Session (Firebase Auth)
  Future<void> logout() async {
    // ⚠️ Ordre critique : la session APP est vidée SYNCHRONIQUEMENT, AVANT
    // le signOut backend. Si le signOut Firebase reste bloqué (réseau,
    // plugin web/desktop…), l'utilisateur doit quand même pouvoir quitter
    // le backoffice et se reconnecter avec un autre compte — le prochain
    // signInWithEmailAndPassword remplacera de toute façon la session Auth.
    _user = null;
    notifyListeners();

    // Nettoyage local best-effort (ne bloque jamais le logout).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_phone'); // Delete saved session
    } catch (e) {
      debugPrint("Error clearing saved session: $e");
    }

    // SignOut Firebase en arrière-plan (best-effort).
    try {
      await _backend.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }
}
