import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Authentication service — mode « numéro + mot de passe » (Firestore).
///
/// ⚠️ RESTAURÉ : le commit 8ecd422 avait migré le login vers Firebase Auth
/// (email dérivé du numéro : `2376XXXXXXX@wastepro.cm`). Cette migration a
/// cassé la connexion des comptes créés directement dans la console
/// Firebase (doc `users/{téléphone}` avec un mot de passe en clair, sans
/// compte Firebase Auth associé). On revient donc au fonctionnement
/// d'origine : le login lit `users/{téléphone}` dans Firestore et compare
/// le mot de passe en clair.
class AuthService {
  AuthService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Normalise un numéro de téléphone : sans espaces ni tirets, préfixe +237
  /// (gère aussi le « 237... » saisi sans le +).
  static String canonicalPhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('237')) return '+$cleaned';
    return '+237$cleaned';
  }

  /// Clés de doc `users` à essayer pour un numéro : la forme canonique
  /// (+237…) puis le numéro tel que saisi. Un doc créé à la main dans la
  /// console peut utiliser un autre format de clé — le premier doc trouvé
  /// fait foi.
  static Set<String> canonicalKeys(String raw) =>
      {canonicalPhone(raw), raw.trim()};

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
        // Autres exceptions : réessaie une fois (le premier échec est
        // parfois un souci de connexion), puis propage.
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
  /// Même logique de clés que [login] : la clé canonique (+237…) puis le
  /// numéro tel que saisi (un doc créé à la main dans la console peut
  /// utiliser un autre format) — pour éviter les doublons d'inscription.
  Future<bool> isPhoneRegistered(String phone) async {
    return _runWithRetry(() async {
      for (final key in canonicalKeys(phone)) {
        if (key.isEmpty) continue;
        final doc = await _db.collection('users').doc(key).get();
        if (doc.exists) return true;
      }
      return false;
    });
  }

  /// Crée le profil `users/{téléphone}` (le mot de passe est stocké en clair,
  /// comme avant la migration Firebase Auth).
  Future<void> register(UserModel user) async {
    final phone = canonicalPhone(user.phoneNumber);
    if (phone.isEmpty) {
      throw 'Invalid phone number.';
    }

    await _runWithRetry(() async {
      await _db.collection('users').doc(phone).set({
        ...user.toMap(),
        'phoneNumber': phone,
      });
    });
  }

  /// Se connecte avec un numéro + un mot de passe : lit le doc
  /// `users/{téléphone}` et compare le mot de passe en clair.
  ///
  /// - `null` : aucun compte pour ce numéro.
  /// - `UserModel` : connexion réussie.
  /// - Sinon, une erreur est levée (mot de passe incorrect).
  Future<UserModel?> login(String phone, String password) async {
    return _runWithRetry<UserModel?>(() async {
      // Essaie la forme canonique (+237...), puis le numéro tel que saisi
      // (un doc créé à la main dans la console peut utiliser un autre
      // format). Le premier doc trouvé fait foi.
      for (final key in canonicalKeys(phone)) {
        if (key.isEmpty) continue;
        final doc = await _db.collection('users').doc(key).get();
        if (!doc.exists) continue;

        final user = UserModel.fromMap(doc.data()!);
        if (user.password == password) {
          return user;
        }
        throw 'Incorrect Password';
      }

      return null;
    });
  }

  void signOut() {
    // En mode « numéro + mot de passe » Firestore, il n'y a pas de session
    // Firebase Auth à fermer : l'état local est nettoyé par le UserProvider.
  }
}
