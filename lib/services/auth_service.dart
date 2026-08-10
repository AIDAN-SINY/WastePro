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

  /// Clés de doc `users` à essayer pour un numéro :
  ///   1. la forme canonique (+237…) ;
  ///   2. le numéro tel que saisi ;
  ///   3. le numéro sans le préfixe +237 (un compte créé à la main dans la
  ///      console Firebase peut utiliser la clé brute, ex. `'653645807'` au
  ///      lieu de `'+237653645807'`).
  /// Le premier doc trouvé fait foi.
  static Set<String> canonicalKeys(String raw) {
    final canonical = canonicalPhone(raw);
    final trimmed = raw.trim();
    final bare = canonical.startsWith('+237')
        ? canonical.substring(4)
        : trimmed;
    return {canonical, trimmed, bare};
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

  /// Rôles réservés aux comptes console (protégés contre l'écrasement par
  /// l'inscription publique).
  static const _consoleRoles = {
    'admin',
    'super_admin',
    'general_admin',
    'agency_manager',
  };

  /// Crée le profil `users/{téléphone}` (le mot de passe est stocké en clair,
  /// comme avant la migration Firebase Auth).
  ///
  /// Protège les comptes console : si le numéro est déjà utilisé par un
  /// General Administrator, Agency Manager, Super Admin, ou un compte créé
  /// par la console, l'inscription est refusée.
  Future<void> register(UserModel user) async {
    final phone = canonicalPhone(user.phoneNumber);
    if (phone.isEmpty) {
      throw 'Invalid phone number.';
    }

    await _runWithRetry(() async {
      // Vérifie que le numéro n'appartient pas à un compte console.
      final existing = await _db.collection('users').doc(phone).get();
      if (existing.exists) {
        final data = existing.data()!;
        final role = (data['role'] as String?)?.trim().toLowerCase() ?? '';
        if (_consoleRoles.contains(role) ||
            data['consoleCreated'] == true) {
          throw 'This number is already registered as a platform account. '
              'Please use a different number.';
        }
      }

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
      // Essaie toutes les clés candidates (canonique +237…, saisie brute,
      // et numéro sans +237 pour les docs créés à la main). Un doc trouvé
      // avec un mauvais mot de passe n'interrompt pas la recherche : une
      // autre clé peut porter le bon compte (ex. clé brute legacy).
      var found = false;
      for (final key in canonicalKeys(phone)) {
        if (key.isEmpty) continue;
        final doc = await _db.collection('users').doc(key).get();
        if (!doc.exists) continue;
        found = true;
        final user = UserModel.fromMap(doc.data()!);
        if (user.password == password) {
          return user;
        }
      }

      // Un compte existe pour ce numéro mais le mot de passe ne correspond
      // à aucune de ses clés.
      if (found) throw 'Incorrect Password';
      return null;
    });
  }

  void signOut() {
    // En mode « numéro + mot de passe » Firestore, il n'y a pas de session
    // Firebase Auth à fermer : l'état local est nettoyé par le UserProvider.
  }
}
