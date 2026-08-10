import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/platform_user_model.dart';

/// Erreur métier de la synchro du compte de connexion (message affiché tel
/// quel par le toast du drawer, sans préfixe « Exception: »).
class LoginSyncError implements Exception {
  LoginSyncError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Helpers partagés entre la console super admin et la console entreprise
/// pour créer / mettre à jour / supprimer le compte de connexion
/// `users/{téléphone}` d'un utilisateur console.
class LoginAccountSync {
  LoginAccountSync._();

  // --- Normalisation du numéro ---

  /// Normalise un numéro de téléphone : sans espaces ni tirets, préfixe
  /// +237 (gère aussi le « 237... » saisi sans le +).
  static String canonicalPhone(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('237')) return '+$cleaned';
    return '+237$cleaned';
  }

  // --- Validation ---

  /// Un utilisateur avec un mot de passe DOIT avoir un numéro, sinon le
  /// compte de connexion users/{phone} ne peut pas exister.
  static void requirePhone(PlatformUserModel user) {
    if (user.password.isNotEmpty && canonicalPhone(user.telephone).isEmpty) {
      throw LoginSyncError(
        'A phone number is required to create the login account. Add a '
        'number to this user.',
      );
    }
  }

  /// Vérifie AVANT toute écriture que le numéro peut recevoir un compte de
  /// connexion console : ni compte client/collecteur réel, ni numéro déjà
  /// utilisé par un autre utilisateur console.
  static Future<void> preflight(
    FirebaseFirestore db,
    PlatformUserModel user,
  ) async {
    if (user.password.isEmpty) return;
    final phone = canonicalPhone(user.telephone);
    if (phone.isEmpty) return;
    if (user.status == 'Suspended' || user.status == 'Suspendu') return;
    await _assertPhoneAvailable(db, db.collection('users').doc(phone), user);
  }

  /// Ajoute au batch [batch] la synchronisation du compte de connexion
  /// `users/{téléphone}` pour [user] (création, mise à jour, suspension ou
  /// suppression). Appelé entre deux écritures du même batch pour garder
  /// l'ensemble atomique.
  static Future<void> stage(
    WriteBatch batch,
    FirebaseFirestore db,
    PlatformUserModel user, {
    String oldPhone = '',
  }) async {
    requirePhone(user);
    final phone = canonicalPhone(user.telephone);

    // Ancien numéro → supprime l'ancien compte (même si le nouveau n'a pas
    // de mot de passe : un seed qui perd son login ne doit pas garder
    // l'ancien compte actif).
    final oldCanonical = canonicalPhone(oldPhone);
    if (oldCanonical.isNotEmpty && oldCanonical != phone) {
      final oldDoc = await db.collection('users').doc(oldCanonical).get();
      if (oldDoc.exists && oldDoc.data()?['consoleCreated'] == true) {
        batch.delete(db.collection('users').doc(oldCanonical));
      }
    }

    if (user.password.isEmpty) return;
    final ref = db.collection('users').doc(phone);

    if (user.status == 'Suspended' || user.status == 'Suspendu') {
      final doc = await ref.get();
      if (doc.exists && doc.data()?['consoleCreated'] == true) {
        batch.delete(ref);
      }
    } else {
      await _assertPhoneAvailable(db, ref, user);
      batch.set(ref, {
        'phoneNumber': phone,
        'fullName': user.nom,
        'role': loginRoleFor(user.role),
        'password': user.password,
        'societeId': user.societeId,
        'agenceId': user.agenceId,
        'isSubscribed': false,
        'consoleCreated': true,
        'consoleUserId': user.id,
      });
    }
  }

  /// Ajoute au batch la suppression du compte de connexion s'il a été créé
  /// par la console. Utilisé lors de la suppression d'un utilisateur.
  static Future<void> stageDeleteLogin(
    WriteBatch batch,
    FirebaseFirestore db,
    String phone,
  ) async {
    final canonical = canonicalPhone(phone);
    if (canonical.isEmpty) return;
    final doc = await db.collection('users').doc(canonical).get();
    if (doc.exists && doc.data()?['consoleCreated'] == true) {
      batch.delete(db.collection('users').doc(canonical));
    }
  }

  // --- Helpers privés ---

  static Future<void> _assertPhoneAvailable(
    FirebaseFirestore db,
    DocumentReference<Map<String, dynamic>> ref,
    PlatformUserModel user,
  ) async {
    final existing = await ref.get();
    if (!existing.exists) return;
    final data = existing.data()!;
    if (data['consoleCreated'] != true) {
      throw LoginSyncError(
        'A client account already exists with this number. Choose a '
        'different number.',
      );
    }
    final owner = data['consoleUserId'];
    if (owner != null && owner != user.id) {
      throw LoginSyncError(
        'Another console user already uses this number for login. Choose a '
        'different number.',
      );
    }
  }

  /// Rôle de connexion (`users`) correspondant à un rôle console
  /// (`utilisateurs`).
  static String loginRoleFor(String consoleRole) {
    final role = consoleRole.trim().toLowerCase();
    if (role == 'general administrator' ||
        role == 'administrateur général') {
      return 'general_admin';
    }
    return 'agency_manager';
  }
}