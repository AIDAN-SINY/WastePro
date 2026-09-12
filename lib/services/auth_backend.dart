import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Business error from the authentication backend.
///
/// [code] is stable and independent of SDK codes (which vary across
/// platforms and versions) — the login screen uses it to translate
/// into user-facing messages:
///   - `user-not-found`: no account for this email;
///   - `wrong-password`: the account exists but the password is wrong;
///   - `invalid-credentials`: the Auth API CANNOT distinguish
///     "no account" from "wrong password" (merged
///     `invalid-credential` + email enumeration protection
///     enabled on the project) — AuthService consults the `users`
///     collection to decide;
///   - `user-disabled`: the account has been disabled (rejected, suspended);
///   - `email-already-in-use`: creation impossible, existing account;
///   - `network`: connection problem (retry on AuthService side);
///   - `unknown`: any other error.
class AuthBackendException implements Exception {
  AuthBackendException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty ? code : message;
}

/// Authentication port over Firebase Auth.
///
/// The app never talks to `FirebaseAuth` directly: it goes through this
/// port, which allows
///   - tests to inject an in-memory backend (no plugin required);
///   - keeping a single error translation (see [AuthService]).
///
/// SESSION MANAGEMENT: operations "for another account"
/// ([createAccount], [updatePassword], [deleteAccount]) go through a
/// **temporary Firebase instance** — they NEVER touch the current session.
/// Without this, `createUserWithEmailAndPassword` would replace the
/// admin console session with the newly created account.
abstract class AuthBackend {
  /// Connecte un compte email + mot de passe sur l'app principale et
  /// renvoie son `uid` (la session est persistée par Firebase Auth).
  ///
  /// Lève [AuthBackendException] (`user-not-found`, `wrong-password`,
  /// `invalid-credentials`, `user-disabled`, `network`…).
  Future<String> signIn({
    required String email,
    required String password,
  });

  /// Crée un compte email + mot de passe et renvoie son `uid`, sans toucher
  /// à la session courante.
  ///
  /// Lève [AuthBackendException] (`email-already-in-use`, `network`…).
  Future<String> createAccount({
    required String email,
    required String password,
  });

  /// Change le mot de passe d'un compte existant (depuis la console, qui
  /// connaît le mot de passe actuel).
  Future<void> updatePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  });

  /// Supprime définitivement un compte existant (depuis la console).
  Future<void> deleteAccount({
    required String email,
    required String password,
  });

  /// Déconnecte la session courante (si elle existe).
  Future<void> signOut();

  /// Uid de la session active, ou null si personne n'est connecté.
  String? get currentUid;
}

/// Implémentation réelle par-dessus `firebase_auth`.
class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend({FirebaseAuth? auth}) : _auth = auth;

  /// Lazily resolved: construction never touches
  /// `FirebaseAuth.instance` (injected by tests or resolved on first
  /// use — a backend built before `Firebase.initializeApp` must not
  /// crash).
  FirebaseAuth? _auth;

  FirebaseAuth get _firebaseAuth => _auth ??= FirebaseAuth.instance;

  @override
  String? get currentUid => _firebaseAuth.currentUser?.uid;

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    //  PAS de `fetchSignInMethodsForEmail` ici. Cette API devait départager
    // « aucun compte » de « mauvais mot de passe », mais avec la protection
    // contre l'énumération d'emails activée sur le projet (réglage
    // Identity Platform), elle renvoie une liste VIDE même pour un compte
    // existant — le login échouait avec « User not found » pour des
    // identifiants corrects. L'erreur `invalid-credential` des SDK récents
    // fusionne elle aussi les deux cas : on remonte donc un code neutre
    // (`invalid-credentials`) et c'est AuthService qui tranche en
    // consultant la collection `users` (source de vérité de l'existence).
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-disabled':
          throw AuthBackendException('user-disabled');
        case 'network-request-failed':
        case 'too-many-requests':
          throw AuthBackendException('network');
        case 'invalid-credential':
        case 'wrong-password':
        case 'invalid-login-credentials':
          throw AuthBackendException('invalid-credentials');
        default:
          throw AuthBackendException('unknown', e.message ?? '');
      }
    }
  }

  @override
  Future<String> createAccount({
    required String email,
    required String password,
  }) {
    return _runInTempApp((auth) async {
      try {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return cred.user!.uid;
      } on FirebaseAuthException catch (e) {
        switch (e.code) {
          case 'email-already-in-use':
          case 'account-exists-with-different-credential':
            throw AuthBackendException('email-already-in-use');
          case 'network-request-failed':
          case 'too-many-requests':
            throw AuthBackendException('network');
          default:
            throw AuthBackendException('unknown', e.message ?? '');
        }
      }
    });
  }

  @override
  Future<void> updatePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) {
    return _runInTempApp((auth) async {
      final cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: currentPassword,
      );
      await cred.user!.updatePassword(newPassword);
    });
  }

  @override
  Future<void> deleteAccount({
    required String email,
    required String password,
  }) {
    return _runInTempApp((auth) async {
      final cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.delete();
    });
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

/// Runs [action] in a temporary Firebase instance (isolated auth),
  /// then destroys the instance — the main app session remains intact.
  Future<T> _runInTempApp<T>(Future<T> Function(FirebaseAuth auth) action) async {
    final app = await Firebase.initializeApp(
      name: 'auth-ops-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      return await action(auth);
    } finally {
      await app.delete();
    }
  }
}
