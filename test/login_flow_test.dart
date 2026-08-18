import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/firestore_platform_store.dart';
import 'package:waste_pro/services/auth_service.dart';

import 'fakes/fake_auth_backend.dart';

/// AuthService branché sur un backend Auth en mémoire (pas de Firebase).
AuthService makeAuth(FakeFirebaseFirestore db, FakeAuthBackend backend) =>
    AuthService(db: db, backend: backend);

/// Tests d'intégration du login « numéro + mot de passe » (Firebase Auth,
/// après la migration sécurité).
///
/// Ces tests reproduisent le parcours réel avec un Firestore simulé + un
/// backend Auth en mémoire :
///   1. Le superadmin se connecte avec son doc `users/{téléphone}`
///      (créé dans la console Firebase, rôle `super_admin`, compte Auth
///      créé par la migration — d'où le `seedAccount`).
///   2. Le superadmin crée un utilisateur via la console → la console écrit
///      son compte de connexion `users/{téléphone}` (uid + auth_profiles,
///      PLUS aucun mot de passe en clair).
///   3. Cet utilisateur peut se connecter avec le numéro + mot de passe.
void main() {
  group('login superadmin (compte créé dans la console Firebase)', () {
    test('se connecte avec numéro + mot de passe', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend()
        ..seedAccount('237677123456@wastepro.cm', 'admin123');
      // Doc créé à la main dans la console : users/{téléphone} avec rôle
      // super_admin ; le mot de passe vit dans Firebase Auth (migration), il
      // n'est plus dans Firestore.
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Super Admin',
        'role': 'super_admin',
      });

      final auth = makeAuth(db, backend);
      final user = await auth.login('677 12 34 56', 'admin123');

      expect(user, isNotNull);
      expect(user!.role, 'super_admin');
      expect(user.fullName, 'Super Admin');
    });

    test('rejette un mauvais mot de passe', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend()
        ..seedAccount('237677123456@wastepro.cm', 'admin123');
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Super Admin',
        'role': 'super_admin',
      });

      final auth = makeAuth(db, backend);
      expect(
        () => auth.login('+237677123456', 'wrong'),
        throwsA('Incorrect Password'),
      );
    });

    test('retourne null pour un numéro inconnu', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend();
      final auth = makeAuth(db, backend);
      expect(await auth.login('+237600000000', 'x'), isNull);
    });
  });

  group('login quelle que soit la saisie (console Firebase)', () {
    test('retrouve le profil via une saisie brute ou espacée', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend()
        ..seedAccount('237677123456@wastepro.cm', 'admin123');
      // Doc créé dans la console avec une clé canonique +237... : le login
      // et l'auto-login (refreshUser) partagent la logique canonicalKeys et
      // doivent retrouver le profil quelle que soit la façon de saisir le
      // numéro (brut, avec espaces/tirets, avec ou sans +237).
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Super Admin',
        'role': 'super_admin',
      });

      final auth = makeAuth(db, backend);

      // Saisie brute sans +237 : canonicalKeys essaie +237677123456 puis
      // 677123456 → le doc canonique est trouvé.
      final byRaw = await auth.login('677123456', 'admin123');
      expect(byRaw, isNotNull);
      expect(byRaw!.role, 'super_admin');

      // Saisie avec espaces : même résultat.
      final bySpaced = await auth.login('+237 677 12 34 56', 'admin123');
      expect(bySpaced, isNotNull);
      expect(bySpaced!.fullName, 'Super Admin');

      // Saisie canonique exacte : même résultat.
      final byCanonical = await auth.login('+237677123456', 'admin123');
      expect(byCanonical, isNotNull);
      expect(byCanonical!.fullName, 'Super Admin');
    });
  });

  group('comptes legacy créés à la main avec une clé brute', () {
    test('se connecte via un doc users/{numéro sans +237}', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend()
        ..seedAccount('237653645807@wastepro.cm', 'motdepasse');
      // Compte super admin créé à la main dans la console Firebase avec
      // une clé NON canonique ('653645807' au lieu de '+237653645807').
      // Le login doit quand même le retrouver (clé brute ajoutée aux clés
      // candidates par canonicalKeys).
      await db.collection('users').doc('653645807').set({
        'phoneNumber': '653645807',
        'fullName': 'Adams',
        'role': 'super_admin',
      });

      final auth = makeAuth(db, backend);
      final user = await auth.login('653645807', 'motdepasse');

      expect(user, isNotNull);
      expect(user!.role, 'super_admin');
      expect(user.fullName, 'Adams');
    });

    test('privilégie le doc canonique quand il existe aussi', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend()
        ..seedAccount('237696713899@wastepro.cm', 'secret123');
      // Doublon legacy (clé brute, sans compte Auth) + compte canonique
      // correct : le login doit aboutir via la clé canonique et non échouer
      // sur le doublon.
      await db.collection('users').doc('696713899').set({
        'phoneNumber': '696713899',
        'fullName': 'Nadia (legacy)',
        'role': 'admin',
      });
      await db.collection('users').doc('+237696713899').set({
        'phoneNumber': '+237696713899',
        'fullName': 'Nadia',
        'role': 'admin',
      });

      final auth = makeAuth(db, backend);
      final user = await auth.login('696713899', 'secret123');
      expect(user, isNotNull);
      expect(user!.fullName, 'Nadia');

      // Et un mauvais mot de passe reste rejeté malgré le doublon.
      expect(
        () => auth.login('696713899', 'mauvais'),
        throwsA('Incorrect Password'),
      );
    });
  });

  group('utilisateurs créés par la console superadmin', () {
    test('peuvent se connecter après création via la console', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend();
      // La console superadmin (FirestorePlatformStore) crée le compte Auth
      // (via le backend injecté) + le doc `users/{téléphone}` (uid, PLUS
      // aucun mot de passe en clair).
      final store = FirestorePlatformStore(
        db: db,
        backend: backend,
        seedIfEmpty: false,
        isSignedOut: () => false,
      );
      await store.initialLoad;

      await store.addUtilisateur(
        nom: 'Marie Ekwalla',
        telephone: '+237 699 99 99 99',
        role: 'General Administrator',
        agence: 'Yaoundé',
        status: 'Active',
        password: 'secret123',
      );

      // Le compte de connexion a bien été écrit avec le VRAI rôle console
      // (General Administrator → general_admin, Phase 1) et le uid Auth.
      final loginDoc = await db.collection('users').doc('+237699999999').get();
      expect(loginDoc.exists, isTrue);
      expect(loginDoc.data()?['role'], 'general_admin');
      expect(loginDoc.data()?['uid'], isNotEmpty);
      expect(loginDoc.data()?['password'], isNull,
          reason: 'le mot de passe ne doit plus être écrit dans Firestore');

      // L'utilisateur se connecte avec le numéro + le mot de passe fixé par
      // le superadmin.
      final auth = makeAuth(db, backend);
      final user = await auth.login('+237 699 99 99 99', 'secret123');

      expect(user, isNotNull);
      expect(user!.role, 'general_admin');
      expect(user.fullName, 'Marie Ekwalla');

      store.dispose();
    });

    test('rejette un mot de passe différent de celui fixé', () async {
      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend();
      final store = FirestorePlatformStore(
        db: db,
        backend: backend,
        seedIfEmpty: false,
        isSignedOut: () => false,
      );
      await store.initialLoad;

      await store.addUtilisateur(
        nom: 'Jean Dooh',
        telephone: '+237 677 12 34 56',
        role: 'Agency Manager',
        agence: 'Douala — Bonanjo',
        status: 'Active',
        password: 'mdp-cons',
      );

      final auth = makeAuth(db, backend);
      expect(
        () => auth.login('+237677123456', 'autre-mdp'),
        throwsA('Incorrect Password'),
      );

      store.dispose();
    });
  });
}
