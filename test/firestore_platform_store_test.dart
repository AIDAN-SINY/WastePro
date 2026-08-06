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
      'status': 'Actif',
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
      status: 'Actif',
    );
    expect(store.societes.single.raisonSociale, 'Test SARL');
    final id = store.societes.first.id;
    var doc = await db.collection('societes').doc(id).get();
    expect(doc.data()?['raisonSociale'], 'Test SARL');

    // Update
    await store.updateSociete(store.societes.first.copyWith(status: 'Suspendu'));
    expect(store.societes.first.status, 'Suspendu');
    doc = await db.collection('societes').doc(id).get();
    expect(doc.data()?['status'], 'Suspendu');

    // Delete
    await store.deleteSociete(id);
    expect(store.societes, isEmpty);
    final remaining = await db.collection('societes').get();
    expect(remaining.docs, isEmpty);

    store.dispose();
  });

  test('renaming a société cascades to its agences', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db);
    await store.initialLoad;
    await _settle();

    // so1 'Propre237 Douala SARL' owns ag1 + ag2 (seed data).
    final so1 = store.societes.firstWhere((s) => s.id == 'so1');
    expect(
      store.agences.where((a) => a.societe == so1.raisonSociale).length,
      2,
    );

    await store.updateSociete(
      so1.copyWith(raisonSociale: 'Propre237 Douala SAS'),
    );

    // In-memory lists are in sync…
    expect(
      store.agences
          .where((a) => a.id == 'ag1' || a.id == 'ag2')
          .every((a) => a.societe == 'Propre237 Douala SAS'),
      isTrue,
    );
    // …and the rename really landed in Firestore.
    final ag1 = await db.collection('agences').doc('ag1').get();
    expect(ag1.data()?['societe'], 'Propre237 Douala SAS');

    store.dispose();
  });

  test('agences and utilisateurs CRUD round-trip too', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addAgence(
      societe: 'Propre237 Douala SARL',
      ville: 'Douala — Akwa',
      responsable: 'Paul Biya Jr',
      telephone: '+237 688 00 00 00',
      status: 'Actif',
    );
    expect(store.agences.single.ville, 'Douala — Akwa');
    final agenceId = store.agences.first.id;
    expect(
      (await db.collection('agences').doc(agenceId).get()).data()?['ville'],
      'Douala — Akwa',
    );

    await store.addUtilisateur(
      nom: 'Nouvel Admin',
      telephone: '+237 699 99 99 99',
      role: 'Administrateur Général',
      agence: '—',
      status: 'Actif',
      password: 'mdp123',
    );
    expect(store.utilisateurs.single.nom, 'Nouvel Admin');
    final userId = store.utilisateurs.first.id;
    expect(
      (await db.collection('utilisateurs').doc(userId).get()).data()?['role'],
      'Administrateur Général',
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
      nom: 'Sans MDP',
      telephone: '+237 611 11 11 11',
      role: "Responsable d'Agence",
      agence: 'Douala — Bonanjo',
      status: 'Actif',
      password: '',
    );
    expect(
      (await db.collection('users').doc('+237611111111').get()).exists,
      isFalse,
    );

    // Avec mot de passe → compte de connexion créé (téléphone canonique,
    // rôle admin, mot de passe identique).
    await store.addUtilisateur(
      nom: 'Marie Ekwalla',
      telephone: '+237 699 99 99 99',
      role: "Responsable d'Agence",
      agence: 'Yaoundé',
      status: 'Actif',
      password: 'secret123',
    );
    final login = await db.collection('users').doc('+237699999999').get();
    expect(login.exists, isTrue);
    expect(login.data()?['role'], 'admin');
    expect(login.data()?['password'], 'secret123');
    expect(login.data()?['fullName'], 'Marie Ekwalla');

    // Éditer le mot de passe met à jour le compte de connexion.
    final user = store.utilisateurs.firstWhere((u) => u.nom == 'Marie Ekwalla');
    await store.updateUtilisateur(user.copyWith(password: 'newpass456'));
    final updated = await db.collection('users').doc('+237699999999').get();
    expect(updated.data()?['password'], 'newpass456');

    // Suspendre l'utilisateur supprime son compte de connexion (plus de login).
    await store.updateUtilisateur(user.copyWith(status: 'Suspendu'));
    expect(
      (await db.collection('users').doc('+237699999999').get()).exists,
      isFalse,
    );

    // Le réactiver recrée le compte de connexion.
    await store.updateUtilisateur(user.copyWith(status: 'Actif'));
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
        nom: 'Faux Admin',
        telephone: '+237 688 88 88 88',
        role: 'Administrateur Général',
        agence: '—',
        status: 'Actif',
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
}
