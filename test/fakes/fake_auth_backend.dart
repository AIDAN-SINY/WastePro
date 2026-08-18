import 'package:waste_pro/services/auth_backend.dart';

/// Backend d'authentification en mémoire pour les tests.
///
/// Remplace `FirebaseAuthBackend` (qui exigerait un vrai Firebase) partout
/// où un test construit un `AuthService`, un store Firestore ou un
/// `UserProvider`. Miroir du comportement réel :
///   - `signIn` : vérifie email + mot de passe, `user-not-found` /
///     `wrong-password` ;
///   - `createAccount` : refuse un email déjà pris (`email-already-in-use`) ;
///   - les `uid` sont déterministes par email — le uid renvoyé par
///     `createAccount` est exactement celui rendu par `signIn`, donc le
///     contrôle `user.uid == uid` de `AuthService.login` fonctionne.
class FakeAuthBackend implements AuthBackend {
  final Map<String, String> _passwords = {}; // email -> password
  final Map<String, String> _uids = {}; // email -> uid
  int _uidCounter = 0;
  String? _currentUid;

  /// Prépare un compte existant (comme un compte créé à la main dans la
  /// console Firebase, dont la migration Auth a déjà créé l'entrée).
  void seedAccount(String email, String password) {
    _passwords[email] = password;
    _uidFor(email);
  }

  /// Uid déterministe qu'un compte [email] recevra (le même que celui
  /// rendu par [createAccount] / [signIn]). Utile pour écrire à l'avance le
  /// champ `uid` d'un doc `users` à la main (comme le fait la migration).
  String uidFor(String email) => _uidFor(email);

  String _uidFor(String email) {
    return _uids.putIfAbsent(email, () => 'uid-${++_uidCounter}');
  }

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final stored = _passwords[email];
    if (stored == null) throw AuthBackendException('user-not-found');
    if (stored != password) throw AuthBackendException('wrong-password');
    _currentUid = _uidFor(email);
    return _currentUid!;
  }

  @override
  Future<String> createAccount({
    required String email,
    required String password,
  }) async {
    if (_passwords.containsKey(email)) {
      throw AuthBackendException('email-already-in-use');
    }
    _passwords[email] = password;
    return _uidFor(email);
  }

  @override
  Future<void> updatePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final stored = _passwords[email];
    if (stored == null) throw AuthBackendException('user-not-found');
    if (stored != currentPassword) {
      throw AuthBackendException('wrong-password');
    }
    _passwords[email] = newPassword;
  }

  @override
  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    if (_passwords[email] == password) {
      _passwords.remove(email);
      _uids.remove(email);
    }
  }

  @override
  Future<void> signOut() async {
    _currentUid = null;
  }

  @override
  String? get currentUid => _currentUid;
}
