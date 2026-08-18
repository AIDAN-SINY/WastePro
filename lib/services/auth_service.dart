import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'auth_backend.dart';

/// Service d'authentification — mode « numéro + mot de passe » sur
/// **Firebase Auth** (email dérivé du numéro), profil dans `users/{téléphone}`.
///
/// ⚠️ MIGRATION SÉCURITÉ : avant ce commit, le login lisait `users/{téléphone}`
/// et comparait le mot de passe EN CLAIR stocké dans Firestore. Depuis :
///   1. le mot de passe n'est plus JAMAIS écrit dans Firestore — il vit dans
///      Firebase Auth (haché côté Google) ;
///   2. le login passe par `signInWithEmailAndPassword` (email dérivé :
///      `2376XXXXXXX@wastepro.cm`) ;
///   3. chaque compte de connexion possède un `auth_profiles/{uid}` (rôle +
///      scope) que les règles Firestore consultent pour verrouiller l'accès.
///
/// Un script de migration (`tool/migrate_auth.mjs`) crée les comptes Auth
/// des utilisateurs existants à partir de leur mot de passe actuel — aucune
/// donnée de connexion n'est perdue.
class AuthService {
  AuthService({FirebaseFirestore? db, AuthBackend? backend})
      : _db = db ?? FirebaseFirestore.instance,
        _backend = backend ?? FirebaseAuthBackend();

  final FirebaseFirestore _db;
  final AuthBackend _backend;

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
    final bare = canonical.startsWith('+237') ? canonical.substring(4) : trimmed;
    return {canonical, trimmed, bare};
  }

  /// Email Firebase Auth dérivé d'un numéro (identifiant de connexion).
  ///
  /// Même règle que la migration `tool/migrate_auth.mjs` : le numéro
  /// canonique sans le `+`, suivi du domaine de la plateforme.
  static String emailFor(String phone) {
    final canonical = canonicalPhone(phone);
    if (canonical.isEmpty) return '';
    return '${canonical.replaceAll('+', '')}@wastepro.cm';
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

        // `permission-denied` = les règles Firestore DÉPLOYÉES sur Firebase
        // refusent l'opération. On traduit en action concrète.
        if (e.code == 'permission-denied') {
          throw 'Access denied: the Firestore rules deployed on Firebase are '
              'out of date. Deploy the latest rules with: firebase deploy '
              '--only firestore:rules';
        }

        throw e.message ?? 'Firestore request failed.';
      } on Exception {
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }

    throw 'Unable to complete the request right now.';
  }

  /// Connecte un numéro + mot de passe via Firebase Auth, puis charge le
  /// profil `users/{téléphone}`.
  ///
  /// - `null` : aucun compte pour ce numéro.
  /// - `UserModel` : connexion réussie (le rôle peut être `pending_client`
  ///   pour une candidature pas encore approuvée).
  /// - Sinon, une erreur est levée (mot de passe incorrect, compte
  ///   désactivé…).
  ///
  /// ⚠️ Avec la protection anti-énumération activée sur le projet, le
  /// backend Auth renvoie `invalid-credentials` (indécidable) : on consulte
  /// alors `users/{téléphone}` pour savoir si le compte existe réellement
  /// et produire « Incorrect Password » au lieu de « User not found ».
  Future<UserModel?> login(String phone, String password) async {
    final canonical = canonicalPhone(phone);
    if (canonical.isEmpty) return null;
    final email = emailFor(canonical);

    final String uid;
    try {
      uid = await _backend.signIn(email: email, password: password);
    } on AuthBackendException catch (e) {
      if (e.code == 'user-not-found') return null;
      if (e.code == 'wrong-password') throw 'Incorrect Password';
      if (e.code == 'invalid-credentials') {
        // L'API Auth ne départage pas « aucun compte » de « mauvais mot de
        // passe » (protection anti-énumération) : la collection `users`
        // fait foi. Un doc `users/{téléphone}` présent → le compte existe,
        // c'est le mot de passe qui est faux. Sinon → aucun compte.
        final exists = await _runWithRetry<bool>(() async {
          for (final key in canonicalKeys(canonical)) {
            if (key.isEmpty) continue;
            if ((await _db.collection('users').doc(key).get()).exists) {
              return true;
            }
          }
          return false;
        });
        if (exists) throw 'Incorrect Password';
        return null;
      }
      if (e.code == 'user-disabled') {
        throw 'This account has been disabled. Please contact your agency '
            'administrator.';
      }
      if (e.code == 'network') {
        throw 'Unable to reach the authentication service. Check your '
            'internet connection and try again.';
      }
      throw e.message.isEmpty ? 'Authentication failed.' : e.message;
    }

    // Profil : essaie la clé canonique puis les variantes legacy (compte créé
    // à la main dans la console, clé brute sans +237).
    return _runWithRetry<UserModel?>(() async {
      for (final key in canonicalKeys(canonical)) {
        if (key.isEmpty) continue;
        final doc = await _db.collection('users').doc(key).get();
        if (!doc.exists) continue;
        final user = UserModel.fromMap(doc.data()!);
        // Un doc legacy (créé à la main dans la console, avant la migration)
        // peut ne pas porter de `uid` — on le laisse passer. S'il en porte
        // un, il doit correspondre au compte Auth qui vient de se connecter
        // (sinon c'est une clé de secours d'un autre compte).
        final userUid = user.uid;
        if (userUid != null && userUid.isNotEmpty && userUid != uid) {
          continue;
        }
        return user;
      }
      return null;
    });
  }

  /// Statut de la candidature (pré-inscription) la plus récente pour
  /// [phone] : `'pending'` | `'approved'` | `'rejected'`, ou null si ce
  /// numéro n'a aucune candidature.
  Future<String?> registrationStatus(String phone) async {
    return _runWithRetry<String?>(() async {
      final canonical = canonicalPhone(phone);
      if (canonical.isEmpty) return null;
      final snap = await _db
          .collection('registrations')
          .where('phone', isEqualTo: canonical)
          .get();
      if (snap.docs.isEmpty) return null;
      final docs = snap.docs.toList()..sort((a, b) => b.id.compareTo(a.id));
      return docs.first.data()['status'] as String?;
    });
  }

  /// Soumet une candidature client (pré-inscription) — et **crée le compte**
  /// de connexion sur Firebase Auth dès maintenant.
  ///
  /// Nouveau modèle « compte dès l'inscription » :
  ///   - un compte Auth est créé (email dérivé + mot de passe choisi) ;
  ///   - `users/{téléphone}` porte le profil avec le rôle `pending_client`
  ///     et le `uid` Auth (PAS de mot de passe en clair) ;
  ///   - `auth_profiles/{uid}` porte rôle + scope pour les règles Firestore ;
  ///   - `registrations/{id}` est la candidature vue par le backoffice.
  ///
  /// Le client peut donc se connecter immédiatement : l'app le dirige vers
  /// l'écran de suivi jusqu'à ce que le chef d'agence approuve (le rôle
  /// passe alors à `client`).
  ///
  /// - Un numéro déjà lié à un compte réel (client/collecteur/console) est
  ///   refusé (il faut se connecter à la place).
  /// - Une candidature déjà en attente pour ce numéro est refusée.
  /// - Une candidature REJETÉE autorise une nouvelle demande (re-apply) :
  ///   le compte existant est conservé (même uid), les champs du profil sont
  ///   mis à jour et une nouvelle candidature `pending` est écrite.
  Future<void> submitPreRegistration({
    required String fullName,
    required String phone,
    required String zone,
    required String agenceId,
    required String agenceName,
    required String societeId,
    required String password,
  }) async {
    final canonical = canonicalPhone(phone);
    if (canonical.isEmpty) throw 'Invalid phone number.';
    if (fullName.trim().isEmpty) throw 'Please enter your full name.';
    if (password.length < 4) {
      throw 'Password must be at least 4 characters.';
    }
    if (agenceId.isEmpty && agenceName.trim().isEmpty) {
      throw 'Please choose an agency.';
    }

    await _runWithRetry(() async {
      // --- Compte existant ? ---
      final existing = await _db.collection('users').doc(canonical).get();
      var uid = '';
      var isReapply = false;

      if (existing.exists) {
        final role = (existing.data()?['role'] as String? ?? '').toLowerCase();
        final existingUid = existing.data()?['uid'] as String? ?? '';
        if (role != 'pending_client') {
          throw 'This number already has an account. Please log in instead.';
        }
        // pending_client : seule une candidature REJETÉE autorise un re-apply.
        final status = await registrationStatus(canonical);
        if (status != 'rejected') {
          throw 'You already have a pending application. The agency will '
              'contact you soon.';
        }
        uid = existingUid;
        isReapply = true;
      }

      // --- Création du compte Auth (une seule fois par numéro) ---
      if (uid.isEmpty) {
        try {
          uid = await _backend.createAccount(
            email: emailFor(canonical),
            password: password,
          );
        } on AuthBackendException catch (e) {
          if (e.code == 'email-already-in-use') {
            throw 'An account already exists with this number. Please log in '
                'instead.';
          }
          if (e.code == 'network') {
            throw 'Unable to reach the authentication service. Check your '
                'internet connection and try again.';
          }
          throw e.message.isEmpty ? 'Unable to create the account.' : e.message;
        }
      }

      // --- Résolution du nom d'agence (taper librement vs sélection) ---
      var finalAgenceId = agenceId;
      var finalSocieteId = societeId;
      var finalAgenceName = agenceName.trim();
      if (finalAgenceId.isEmpty && finalAgenceName.isNotEmpty) {
        final name = agenceName.trim().toLowerCase();
        final agences = await _db.collection('agences').get();
        final exact = agences.docs
            .where((d) =>
                (d.data()['ville'] as String? ?? '').toLowerCase() == name)
            .toList();
        final matches =
            exact.isNotEmpty
                ? exact
                : agences.docs
                      .where((d) =>
                          (d.data()['ville'] as String? ?? '')
                              .toLowerCase()
                              .contains(name))
                      .toList();
        if (matches.length == 1) {
          finalAgenceId = matches.single.id;
          finalSocieteId =
              matches.single.data()['societeId'] as String? ?? '';
          final resolvedVille =
              matches.single.data()['ville'] as String? ?? '';
          if (resolvedVille.isNotEmpty) finalAgenceName = resolvedVille;
        } else {
          throw matches.isEmpty
              ? 'Agency not found. Choose one of the suggested agencies.'
              : 'Several agencies match this name. Choose one from the '
                    'suggestions.';
        }
      }

      final now = DateTime.now();
      final iso =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final id = 'reg${now.microsecondsSinceEpoch}';

      try {
        final batch = _db.batch();
        // Profil de connexion (sans mot de passe — il vit dans Firebase Auth).
        batch.set(_db.collection('users').doc(canonical), {
          'phoneNumber': canonical,
          'fullName': fullName.trim(),
          'role': 'pending_client',
          'uid': uid,
          'societeId': finalSocieteId,
          'agenceId': finalAgenceId,
          'agenceName': finalAgenceName,
          'collecteurId': '',
          'isSubscribed': false,
        }, SetOptions(merge: isReapply));
        // Profil de règles (rôle + scope), consulté par firestore.rules.
        batch.set(_db.collection('auth_profiles').doc(uid), {
          'uid': uid,
          'phone': canonical,
          'role': 'pending_client',
          'status': 'pending',
          'societeId': finalSocieteId,
          'agenceId': finalAgenceId,
        }, SetOptions(merge: isReapply));
        // Candidature vue par le backoffice.
        batch.set(_db.collection('registrations').doc(id), {
          'id': id,
          'fullName': fullName.trim(),
          'phone': canonical,
          'zone': zone.trim(),
          'agenceId': finalAgenceId,
          'agenceName': finalAgenceName,
          'societeId': finalSocieteId,
          'status': 'pending',
          'collecteurId': '',
          'createdAt': iso,
        });
        await batch.commit();
      } catch (_) {
        // Rollback : on ne laisse jamais un compte Auth orphelin si la
        // candidature n'a pas pu être écrite.
        if (!isReapply && uid.isNotEmpty) {
          try {
            await _backend.deleteAccount(
              email: emailFor(canonical),
              password: password,
            );
          } catch (_) {}
        }
        rethrow;
      }

      // Vérification serveur (HORS du try/catch de rollback : une
      // candidature mise en file locale doit pouvoir se synchroniser plus
      // tard, sans détruire le compte Auth déjà créé). Avec la persistance
      // hors-ligne, un `batch.commit()` qui ne peut pas joindre Firestore se
      // résout quand même (écriture dans le cache local) — l'écran de succès
      // affiché alors est un MENSONGE : la candidature n'arrivera jamais au
      // backoffice du chef d'agence. On relit le doc depuis le serveur pour
      // confirmer que la soumission est réellement partie.
      bool confirmed = false;
      try {
        confirmed = await _db
            .collection('registrations')
            .doc(id)
            .get(const GetOptions(source: Source.server))
            .then((snap) => snap.exists);
      } on Exception {
        confirmed = false;
      }
      if (!confirmed) {
        throw 'Your device appears to be offline — the application was not '
            'sent. Check your internet connection, then submit again.';
      }
    });
  }

  /// Uid de la session active (null si déconnecté).
  String? get currentUid => _backend.currentUid;

  /// Déconnecte la session Firebase Auth.
  Future<void> signOut() => _backend.signOut();
}
