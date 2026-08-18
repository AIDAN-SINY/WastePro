import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Erreur métier du backend d'authentification.
///
/// [code] est stable et indépendant des codes SDK (qui varient selon les
/// plateformes et les versions) — l'écran de login s'appuie dessus pour
/// traduire en message utilisateur :
///   - `user-not-found` : aucun compte pour cet email ;
///   - `wrong-password` : le compte existe mais le mot de passe est faux ;
///   - `invalid-credentials` : l'API Auth ne permet PAS de départager
///     « aucun compte » de « mauvais mot de passe » (erreur fusionnée
///     `invalid-credential` + protection contre l'énumération d'emails
///     activée sur le projet) — AuthService consulte la collection
///     `users` pour trancher ;
///   - `user-disabled` : le compte a été désactivé (rejet, suspension) ;
///   - `email-already-in-use` : création impossible, compte existant ;
///   - `network` : problème de connexion (retry côté AuthService) ;
///   - `unknown` : toute autre erreur.
class AuthBackendException implements Exception {
  AuthBackendException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty ? code : message;
}

/// Port d'authentification par-dessus Firebase Auth.
///
/// L'app ne parle jamais à `FirebaseAuth` directement : elle passe par ce
/// port, ce qui permet
///   - aux tests d'injecter un backend en mémoire (pas de plugin requis) ;
///   - de garder une seule traduction des erreurs (voir [AuthService]).
///
/// ⚠️ Gestion de session : les opérations « pour un autre compte »
/// ([createAccount], [updatePassword], [deleteAccount]) passent par une
/// **instance Firebase temporaire** — elles ne touchent JAMAIS la session
/// courante. Sans ça, `createUserWithEmailAndPassword` remplacerait la
/// session de l'admin console par le nouveau compte créé.
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

  /// Résolu paresseusement : la construction ne touche jamais à
  /// `FirebaseAuth.instance` (injecté par les tests ou résolu au premier
  /// usage — un backend construit avant `Firebase.initializeApp` ne doit
  /// pas crasher).
  FirebaseAuth? _auth;

  FirebaseAuth get _firebaseAuth => _auth ??= FirebaseAuth.instance;

  @override
  String? get currentUid => _firebaseAuth.currentUser?.uid;

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    // ⚠️ PAS de `fetchSignInMethodsForEmail` ici. Cette API devait départager
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

  /// Exécute [action] dans une instance Firebase temporaire (auth isolée),
  /// puis détruit l'instance — la session de l'app principale reste intacte.
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
