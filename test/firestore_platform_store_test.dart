import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/firestore_platform_store.dart';
import 'package:waste_pro/features/superadmin/data/seed_data.dart';

/// Lets the snapshot listeners catch up with seed writes / CRUD writes.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeds empty collections with the design data', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db);
    await store.initialLoad;
    await _settle();

    expect(store.error, isNull);
    expect(store.isLoading, isFalse);
    expect(store.societes.length, seedSocietes.length);
    expect(store.agences.length, seedAgences.length);
    expect(store.utilisateurs.length, seedUtilisateurs.length);

    // The seed really landed in Firestore (deterministic ids 'so1'...).
    final docs = await db.collection('societes').get();
    expect(docs.docs.length, seedSocietes.length);

    store.dispose();
  });

  test('keeps existing data and only seeds the empty collections', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('societes').doc('custom').set({
      'id': 'custom',
      'raisonSociale': 'Ma Société',
      'adresse': 'Yaoundé',
      'telephone': '+237 600 00 00 00',
      'email': 'contact@ma-societe.cm',
      'status': 'Active',
    });

    final store = FirestorePlatformStore(db: db);
    await store.initialLoad;
    await _settle();

    // The existing document is kept, not overwritten by the seed.
    expect(store.societes.single.raisonSociale, 'Ma Société');
    // The two empty collections are still seeded.
    expect(store.agences.length, seedAgences.length);
    expect(store.utilisateurs.length, seedUtilisateurs.length);

    store.dispose();
  });

  test('CRUD writes through to Firestore', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    expect(store.societes, isEmpty);

    // Create
    await store.addSociete(
      raisonSociale: 'Test SARL',
      adresse: 'Douala',
      telephone: '+237 6 00 00 00 00',
      email: 'test@sarl.cm',
      status: 'Active',
    );
    expect(store.societes.single.raisonSociale, 'Test SARL');
    final id = store.societes.first.id;
    var doc = await db.collection('societes').doc(id).get();
    expect(doc.data()?['raisonSociale'], 'Test SARL');

    // Update
    await store.updateSociete(store.societes.first.copyWith(status: 'Suspended'));
    expect(store.societes.first.status, 'Suspended');
    doc = await db.collection('societes').doc(id).get();
    expect(doc.data()?['status'], 'Suspended');

    // Delete
    await store.deleteSociete(id);
    expect(store.societes, isEmpty);
    final remaining = await db.collection('societes').get();
    expect(remaining.docs, isEmpty);

    store.dispose();
  });

  test('permission-denied après déconnexion ne déclenche pas de bannière',
      () async {
    final db = FakeFirebaseFirestore();
    // Simule une session Firebase Auth révoquée (logout) : les listeners
    // encore actifs sont rejetés par les règles → pas d'erreur affichée.
    final store = FirestorePlatformStore(
      db: db,
      seedIfEmpty: false,
      isSignedOut: () => true,
    );
    await store.initialLoad;
    await _settle();

    store.handleStreamError(
      FirebaseException(plugin: 'firestore', code: 'permission-denied'),
    );

    expect(store.error, isNull,
        reason: 'Après logout, permission-denied est attendu — pas une erreur.');
    expect(store.isLoading, isFalse);

    store.dispose();
  });

  test('permission-denied pendant une session active affiche l erreur',
      () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(
      db: db,
      seedIfEmpty: false,
      isSignedOut: () => false,
    );
    await store.initialLoad;
    await _settle();

    store.handleStreamError(
      FirebaseException(plugin: 'firestore', code: 'permission-denied'),
    );

    expect(store.error, contains('Access denied'));

    store.dispose();
  });

  test('renaming a société cascades to its agences', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db);
    await store.initialLoad;
    await _settle();

    // so1 'WastePro Douala Ltd' owns ag1 + ag2 (seed data).
    final so1 = store.societes.firstWhere((s) => s.id == 'so1');
    expect(
      store.agences.where((a) => a.societe == so1.raisonSociale).length,
      2,
    );

    await store.updateSociete(
      so1.copyWith(raisonSociale: 'WastePro Douala SAS'),
    );

    // In-memory lists are in sync…
    expect(
      store.agences
          .where((a) => a.id == 'ag1' || a.id == 'ag2')
          .every((a) => a.societe == 'WastePro Douala SAS'),
      isTrue,
    );
    // …and the rename really landed in Firestore.
    final ag1 = await db.collection('agences').doc('ag1').get();
    expect(ag1.data()?['societe'], 'WastePro Douala SAS');

    store.dispose();
  });

  test('agences and utilisateurs CRUD round-trip too', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addAgence(
      societe: 'WastePro Douala Ltd',
      ville: 'Douala — Akwa',
      responsable: 'Paul Biya Jr',
      telephone: '+237 688 00 00 00',
      status: 'Active',
    );
    expect(store.agences.single.ville, 'Douala — Akwa');
    final agenceId = store.agences.first.id;
    expect(
      (await db.collection('agences').doc(agenceId).get()).data()?['ville'],
      'Douala — Akwa',
    );

    await store.addUtilisateur(
      nom: 'New Admin',
      telephone: '+237 699 99 99 99',
      role: 'General Administrator',
      agence: '—',
      status: 'Active',
      password: 'mdp123',
    );
    expect(store.utilisateurs.single.nom, 'New Admin');
    final userId = store.utilisateurs.first.id;
    expect(
      (await db.collection('utilisateurs').doc(userId).get()).data()?['role'],
      'General Administrator',
    );

    await store.deleteAgence(agenceId);
    await store.deleteUtilisateur(userId);
    expect(store.agences, isEmpty);
    expect(store.utilisateurs, isEmpty);

    store.dispose();
  });

  test('console user with a password gets a real login account', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    // Sans mot de passe → aucun compte de connexion (utilisateurs seedés).
    await store.addUtilisateur(
      nom: 'No Password',
      telephone: '+237 611 11 11 11',
      role: 'Agency Manager',
      agence: 'Douala — Bonanjo',
      status: 'Active',
      password: '',
    );
    expect(
      (await db.collection('users').doc('+237611111111').get()).exists,
      isFalse,
    );

    // Avec mot de passe → compte de connexion créé (téléphone canonique,
    // vrai rôle console = agency_manager pour un Agency Manager, mot de
    // passe identique).
    await store.addUtilisateur(
      nom: 'Marie Ekwalla',
      telephone: '+237 699 99 99 99',
      role: 'Agency Manager',
      agence: 'Yaoundé',
      status: 'Active',
      password: 'secret123',
    );
    final login = await db.collection('users').doc('+237699999999').get();
    expect(login.exists, isTrue);
    expect(login.data()?['role'], 'agency_manager');
    expect(login.data()?['password'], 'secret123');
    expect(login.data()?['fullName'], 'Marie Ekwalla');

    // Éditer le mot de passe met à jour le compte de connexion.
    final user = store.utilisateurs.firstWhere((u) => u.nom == 'Marie Ekwalla');
    await store.updateUtilisateur(user.copyWith(password: 'newpass456'));
    final updated = await db.collection('users').doc('+237699999999').get();
    expect(updated.data()?['password'], 'newpass456');

    // Suspending the user removes their login account (no more login).
    await store.updateUtilisateur(user.copyWith(status: 'Suspended'));
    expect(
      (await db.collection('users').doc('+237699999999').get()).exists,
      isFalse,
    );

    // Reactivating recreates the login account.
    await store.updateUtilisateur(user.copyWith(status: 'Active'));
    expect(
      (await db.collection('users').doc('+237699999999').get()).exists,
      isTrue,
    );

    // Supprimer l'utilisateur supprime aussi son compte de connexion.
    await store.deleteUtilisateur(user.id);
    expect(store.utilisateurs.any((u) => u.nom == 'Marie Ekwalla'), isFalse);
    expect(
      (await db.collection('users').doc('+237699999999').get()).exists,
      isFalse,
    );

    store.dispose();
  });

  test('never clobbers an existing client account with the same phone',
      () async {
    final db = FakeFirebaseFirestore();
    // Un client réel existe déjà avec ce numéro (pas de marqueur console).
    await db.collection('users').doc('+237688888888').set({
      'phoneNumber': '+237688888888',
      'fullName': 'Client Existant',
      'role': 'client',
      'password': 'clientpass',
    });

    final store = FirestorePlatformStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await expectLater(
      store.addUtilisateur(
        nom: 'Fake Admin',
        telephone: '+237 688 88 88 88',
        role: 'General Administrator',
        agence: '—',
        status: 'Active',
        password: 'hack',
      ),
      throwsA(isA<Exception>()),
    );

    // Le compte client n'a pas été écrasé.
    final client = await db.collection('users').doc('+237688888888').get();
    expect(client.data()?['role'], 'client');
    expect(client.data()?['password'], 'clientpass');

    store.dispose();
  });

  test('editing a legacy console user migrates its login role (Phase 1)',
      () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    // Compte de connexion legacy créé AVANT la Phase 1 : rôle générique
    // 'admin' dans `users`, propriétaire = l'utilisateur console.
    await db.collection('users').doc('+237677111111').set({
      'phoneNumber': '+237677111111',
      'fullName': 'Legacy',
      'role': 'admin',
      'password': 'oldpass',
      'consoleCreated': true,
      'consoleUserId': 'legacy-user',
    });
    await db.collection('utilisateurs').doc('legacy-user').set({
      'id': 'legacy-user',
      'nom': 'Legacy',
      'telephone': '+237 677 11 11 11',
      'role': 'Agency Manager',
      'agence': 'Douala',
      'status': 'Active',
      'password': 'oldpass',
    });
    await _settle();
    final user = store.utilisateurs.firstWhere((u) => u.id == 'legacy-user');

    // Une édition (nouveau mot de passe) réécrit le vrai rôle console dans
    // `users` : le legacy 'admin' devient 'agency_manager'.
    await store.updateUtilisateur(user.copyWith(password: 'newpass'));
    final migrated = await db.collection('users').doc('+237677111111').get();
    expect(migrated.data()?['role'], 'agency_manager');
    expect(migrated.data()?['password'], 'newpass');

    store.dispose();
  });
}
