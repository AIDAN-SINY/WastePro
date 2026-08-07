import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Authentication service — Phase 1 (sécurité / web).
///
/// Firebase Auth est maintenant la source de vérité des identifiants
/// (email dérivé du numéro : `2376XXXXXXX@wastepro.cm`), tandis que le doc
/// `users/{phone}` reste le profil (nom, rôle, mot de passe hérité…).
///
/// Compatibilité descendante : les comptes créés avant cette migration
/// (sans compte Firebase Auth) sont migrés à la volée à leur première
/// connexion — le mot de passe est vérifié sur le doc `users` hérité, puis
/// le compte Firebase Auth est créé et lié (email + uid écrits sur le doc).
///
/// La collection `roles/{uid}` mappe l'uid Firebase Auth → rôle, ce qui
/// permet aux règles Firestore de contrôler l'accès par rôle
/// (`isAdmin()`, `isSuperAdmin()`).
class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Domaine utilisé pour dériver l'email Firebase Auth d'un numéro :
  /// `+237 6XX XX XX XX` → `2376XXXXXXX@wastepro.cm`.
  static const String emailDomain = 'wastepro.cm';

  /// Normalise un numéro de téléphone : sans espaces ni tirets, préfixe +237.
  static String canonicalPhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('237')) return '+$cleaned';
    return '+237$cleaned';
  }

  /// Email Firebase Auth dérivé du numéro (unique et déterministe).
  static String authEmail(String raw) {
    final phone = canonicalPhone(raw).replaceAll('+', '');
    return '$phone@$emailDomain';
  }

  Future<T> _runWithRetry<T>(
    Future<T> Function() action, {
    int retries = 2,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await action();
      } on FirebaseException catch (e) {
        final isTransient =
            e.code == 'unavailable' || e.code == 'deadline-exceeded';
        if (isTransient && attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }

        if (e.code == 'unavailable') {
          throw 'The database service is temporarily unavailable. Please check your internet connection and try again.';
        }

        throw e.message ?? 'Firestore request failed.';
      } on Exception {
        // Firestore/Auth exceptions non transitoires : réessaie quand même
        // une fois (le premier échec est parfois un souci de connexion),
        // puis propage.
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }

    throw 'Unable to complete the request right now.';
  }

  /// Assigns a role at registration.
  ///
  /// Admins pre-approve collector numbers in the `collectors` collection
  /// (whitelist). If the number is whitelisted the account becomes a
  /// 'collector', otherwise it is a regular 'client'.
  Future<String> determineRole(String phone) async {
    final normalizedPhone = canonicalPhone(phone);

    if (normalizedPhone.isEmpty) {
      return 'client';
    }

    return _runWithRetry(() async {
      final doc = await _db.collection('collectors').doc(normalizedPhone).get();
      return doc.exists ? 'collector' : 'client';
    });
  }

  /// Returns true when an account already exists for this phone number.
  ///
  /// Les comptes protégés (doc `users` avec champ `email`, c'est-à-dire déjà
  /// liés à Firebase Auth) ne sont pas lisibles sans authentification : on
  /// les considère alors comme « déjà enregistrés » (le numéro est pris).
  Future<bool> isPhoneRegistered(String phone) async {
    final normalizedPhone = canonicalPhone(phone);

    if (normalizedPhone.isEmpty) {
      return false;
    }

    return _runWithRetry(() async {
      try {
        final doc = await _db.collection('users').doc(normalizedPhone).get();
        return doc.exists;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') return true;
        rethrow;
      }
    });
  }

  /// Crée le compte Firebase Auth (email dérivé du numéro) puis le profil
  /// `users/{phone}` (avec `email` + `uid`) et le doc de rôle
  /// `roles/{uid}` — l'utilisateur est connecté à l'issue de l'appel.
  Future<void> register(UserModel user) async {
    final phone = canonicalPhone(user.phoneNumber);
    if (phone.isEmpty) {
      throw 'Invalid phone number.';
    }
    final email = authEmail(phone);
    final role = user.role.trim().toLowerCase();

    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: user.password,
    );
    final uid = _auth.currentUser!.uid;

    try {
      await _db.collection('users').doc(phone).set({
        ...user.toMap(),
        'phoneNumber': phone,
        'email': email,
        'uid': uid,
      });
      await _db.collection('roles').doc(uid).set({
        'role': role,
        'phoneNumber': phone,
        'email': email,
      });
    } catch (e) {
      // Nettoyage best effort du compte auth si l'écriture Firestore échoue.
      try {
        await _auth.currentUser?.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<UserModel?> login(String phone, String password) async {
    final canonical = canonicalPhone(phone);
    if (canonical.isEmpty) return null;
    final email = authEmail(canonical);

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // Compte Firebase Auth inexistant → peut être un compte « legacy »
      // (créé avant la migration) : on tente la migration à la volée.
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return _migrateLegacyAccount(canonical, email, password);
      }
      if (e.code == 'wrong-password') {
        throw 'Incorrect password.';
      }
      if (e.code == 'invalid-email') {
        return null;
      }
      throw _friendlyAuthError(e);
    }

    final profile = await _loadProfile(canonical, email);
    // Auto-réparation : si le doc de rôle manque (ex. échec transitoire à la
    // migration précédente), on le recrée à chaque connexion.
    if (profile != null) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _ensureRoleDoc(
          canonical,
          uid,
          profile.role.trim().toLowerCase(),
          email,
        );
      }
    }
    return profile;
  }

  /// Migration à la volée d'un compte « legacy » (créé avant Firebase Auth) :
  /// vérifie le mot de passe sur le doc `users` hérité, crée le compte
  /// Firebase Auth, puis lie le doc (email + uid) et crée le doc de rôle.
  Future<UserModel?> _migrateLegacyAccount(
    String phone,
    String email,
    String password,
  ) async {
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _db.collection('users').doc(phone).get();
    } on FirebaseException catch (e) {
      // Lecture refusée → doc déjà protégé (lié à Firebase Auth) : le compte
      // existe, le sign-in a donc échoué sur le mot de passe.
      if (e.code == 'permission-denied') {
        throw 'Incorrect password.';
      }
      return null;
    } catch (_) {
      return null;
    }
    if (!doc.exists) return null;

    final data = doc.data()!;
    if (data['password'] != password) {
      throw 'Incorrect password.';
    }

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'Incorrect password.';
      }
      throw _friendlyAuthError(e);
    }

    final uid = _auth.currentUser!.uid;
    final role = (data['role'] as String?)?.trim().toLowerCase() ?? 'client';

    // Lie le compte auth au doc users (ferme la lecture « legacy » pré-auth
    // et permet le lien du rôle dans les règles Firestore).
    await _db.collection('users').doc(phone).update({
      'email': email,
      'uid': uid,
    });
    await _ensureRoleDoc(phone, uid, role, email);

    return _loadProfile(phone, email);
  }

  Future<void> _ensureRoleDoc(
    String phone,
    String uid,
    String role,
    String email,
  ) async {
    try {
      await _db.collection('roles').doc(uid).set({
        'role': role,
        'phoneNumber': phone,
        'email': email,
      });
    } catch (_) {
      // Doc de rôle déjà présent (re-connexion) ou refusé → non bloquant.
    }
  }

  Future<UserModel?> _loadProfile(String phone, String email) async {
    try {
      final doc = await _db.collection('users').doc(phone).get();
      if (!doc.exists) {
        // Compte auth sans profil (ex. utilisateur suspendu par la console) :
        // on déconnecte pour ne pas laisser traîner un token orphelin.
        await _auth.signOut();
        return null;
      }
      return UserModel.fromMap(doc.data()!);
    } catch (_) {
      await _auth.signOut();
      return null;
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'An internet connection is required. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled '
            '(Firebase Console → Authentication → Sign-in method).';
      default:
        return e.message ?? 'Erreur de connexion.';
    }
  }
}
