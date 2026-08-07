import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/firestore_platform_store.dart';
import 'package:waste_pro/services/auth_service.dart';

/// Tests d'intégration du login « numéro + mot de passe » (Firestore simple,
/// restauré après le commit 8ecd422 qui avait migré vers Firebase Auth).
///
/// Ces tests reproduisent le parcours réel avec un Firestore simulé :
///   1. Le superadmin se connecte avec son doc `users/{téléphone}`
///      (créé dans la console Firebase, rôle `super_admin`).
///   2. Le superadmin crée un utilisateur via la console → la console écrit
///      son compte de connexion `users/{téléphone}`.
///   3. Cet utilisateur peut se connecter avec le numéro + mot de passe.
void main() {
  group('login superadmin (compte créé dans la console Firebase)', () {
    test('se connecte avec numéro + mot de passe en clair', () async {
      final db = FakeFirebaseFirestore();
      // Doc créé à la main dans la console : users/{téléphone} avec rôle
      // super_admin et mot de passe en clair.
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Super Admin',
        'role': 'super_admin',
        'password': 'admin123',
      });

      final auth = AuthService(db: db);
      final user = await auth.login('677 12 34 56', 'admin123');

      expect(user, isNotNull);
      expect(user!.role, 'super_admin');
      expect(user.fullName, 'Super Admin');
    });

    test('rejette un mauvais mot de passe', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Super Admin',
        'role': 'super_admin',
        'password': 'admin123',
      });

      final auth = AuthService(db: db);
      expect(
        () => auth.login('+237677123456', 'wrong'),
        throwsA('Incorrect Password'),
      );
    });

    test('retourne null pour un numéro inconnu', () async {
      final db = FakeFirebaseFirestore();
      final auth = AuthService(db: db);
      expect(await auth.login('+237600000000', 'x'), isNull);
    });
  });

  group('login quelle que soit la saisie (console Firebase)', () {
    test('retrouve le profil via une saisie brute ou espacée', () async {
      final db = FakeFirebaseFirestore();
      // Doc créé dans la console avec une clé canonique +237... : le login
      // et l'auto-login (refreshUser) partagent la logique canonicalKeys et
      // doivent retrouver le profil quelle que soit la façon de saisir le
      // numéro (brut, avec espaces/tirets, avec ou sans +237).
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Super Admin',
        'role': 'super_admin',
        'password': 'admin123',
      });

      final auth = AuthService(db: db);

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

  group('utilisateurs créés par la console superadmin', () {
    test('peuvent se connecter après création via la console', () async {
      final db = FakeFirebaseFirestore();
      // La console superadmin (FirestorePlatformStore) écrit le compte de
      // connexion `users/{téléphone}` quand un utilisateur est créé avec un
      // mot de passe (rôle 'admin', mot de passe en clair).
      final store = FirestorePlatformStore(
        db: db,
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

      // Le compte de connexion a bien été écrit.
      final loginDoc = await db.collection('users').doc('+237699999999').get();
      expect(loginDoc.exists, isTrue);
      expect(loginDoc.data()?['role'], 'admin');
      expect(loginDoc.data()?['password'], 'secret123');

      // L'utilisateur se connecte avec le numéro + le mot de passe fixé par
      // le superadmin.
      final auth = AuthService(db: db);
      final user = await auth.login('+237 699 99 99 99', 'secret123');

      expect(user, isNotNull);
      expect(user!.role, 'admin');
      expect(user.fullName, 'Marie Ekwalla');

      store.dispose();
    });

    test('rejette un mot de passe différent de celui fixé', () async {
      final db = FakeFirebaseFirestore();
      final store = FirestorePlatformStore(
        db: db,
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

      final auth = AuthService(db: db);
      expect(
        () => auth.login('+237677123456', 'autre-mdp'),
        throwsA('Incorrect Password'),
      );

      store.dispose();
    });
  });
}
