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

        // `permission-denied` = les règles Firestore DÉPLOYÉES sur Firebase
        // refusent l'opération. Le fichier local (firestore.rules) est
        // ouvert, mais si la collection `registrations` (ou autre) n'a pas
        // été déployée après son ajout, Firebase refuse — message brut
        // « Missing or insufficient permissions » incompréhensible pour le
        // client. On le traduit en action concrète.
        if (e.code == 'permission-denied') {
          throw 'Access denied: the Firestore rules deployed on Firebase are '
              'out of date. Deploy the latest rules with: firebase deploy '
              '--only firestore:rules';
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

  /// Statut de la candidature (pré-inscription) la plus récente pour
  /// [phone] : `'pending'` | `'approved'` | `'rejected'`, ou null si ce
  /// numéro n'a aucune candidature.
  ///
  /// Utilisé par l'écran de login : un client qui tente de se connecter
  /// AVANT l'approbation n'a pas encore de compte `users/{téléphone}` — au
  /// lieu du générique « User not found », on lui explique où en est sa
  /// candidature.
  Future<String?> registrationStatus(String phone) async {
    return _runWithRetry<String?>(() async {
      final canonical = canonicalPhone(phone);
      if (canonical.isEmpty) return null;
      final snap = await _db
          .collection('registrations')
          .where('phone', isEqualTo: canonical)
          .get();
      if (snap.docs.isEmpty) return null;
      // La plus récente d'abord : les ids sont `reg<microsecondes>` et se
      // trient donc chronologiquement.
      final docs = snap.docs.toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      return docs.first.data()['status'] as String?;
    });
  }

  /// Soumet une candidature client (pré-inscription).
  ///
  /// Le client remplit ses infos + choisit son agence ; la candidature est
  /// écrite dans `registrations` avec le statut `pending` et apparaît dans
  /// le dashboard du chef d'agence qui l'approuvera (en assignant un
  /// collecteur). Aucun compte `users/{téléphone}` n'est créé ici — le
  /// client n'existe qu'après approbation.
  ///
  /// - Un numéro déjà utilisé par un compte existant est refusé (le client
  ///   doit se connecter à la place).
  /// - Une candidature déjà en attente pour ce numéro est refusée.
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
      // Compte existant → connexion, pas de candidature.
      final existing = await _db.collection('users').doc(canonical).get();
      if (existing.exists) {
        throw 'This number already has an account. Please log in instead.';
      }

      // Candidature déjà en attente pour ce numéro.
      // ⚠️ Un seul where sur `phone` : un double where (phone + status)
      // exigerait un index composé Firestore non déployé (FAILED_PRECONDITION
      // en production) — le statut est filtré en mémoire ici.
      final existingRegs = await _db
          .collection('registrations')
          .where('phone', isEqualTo: canonical)
          .get();
      final hasPending = existingRegs.docs.any(
        (d) => (d.data()['status'] as String? ?? '') == 'pending',
      );
      if (hasPending) {
        throw 'You already have a pending application. The agency will '
            'contact you soon.';
      }

      // Le client peut taper le nom de l'agence au lieu de la choisir : on
      // résout ce nom contre les agences connues pour rattacher la
      // candidature à une agence — sinon elle n'apparaîtrait jamais dans le
      // backoffice (scopé par agenceId) du chef d'agence.
      var finalAgenceId = agenceId;
      var finalSocieteId = societeId;
      // Nom d'agence enregistré : la sélection, sinon le texte tapé — mis à
      // jour avec le nom RÉEL de l'agence quand le texte tapé est résolu
      // (ex. « bonanjo » → « Douala — Bonanjo »), pour que le backoffice
      // scopé retrouve la candidature par NOM et que la carte Applications
      // affiche la vraie agence.
      var finalAgenceName = agenceName.trim();
      if (finalAgenceId.isEmpty && finalAgenceName.isNotEmpty) {
        final name = agenceName.trim().toLowerCase();
        final agences = await _db.collection('agences').get();
        // D'abord le nom EXACT (ex. « douala — bonanjo »), puis un nom
        // PARTIEL unique (ex. « bonanjo ») — sinon la candidature serait
        // écrite sans agenceId et n'apparaîtrait jamais dans le backoffice
        // scopé du chef d'agence.
        final exact = agences.docs
            .where((d) =>
                (d.data()['ville'] as String? ?? '').toLowerCase() == name)
            .toList();
        final matches =
            exact.isNotEmpty ? exact
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
          // Aucune correspondance (nom inconnu) OU nom ambigu (ex. « douala »
          // → deux agences) : refuser plutôt que d'écrire une candidature
          // « orpheline » (agenceId vide) que le client croira envoyée mais
          // qu'aucun chef d'agence ne pourra jamais voir ni traiter.
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
      await _db.collection('registrations').doc(id).set({
        'id': id,
        'fullName': fullName.trim(),
        'phone': canonical,
        'zone': zone.trim(),
        'agenceId': finalAgenceId,
        'agenceName': finalAgenceName,
        'societeId': finalSocieteId,
        'status': 'pending',
        'collecteurId': '',
        'password': password,
        'createdAt': iso,
      });
    });
  }

  void signOut() {
    // En mode « numéro + mot de passe » Firestore, il n'y a pas de session
    // Firebase Auth à fermer : l'état local est nettoyé par le UserProvider.
  }
}
