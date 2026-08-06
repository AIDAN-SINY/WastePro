import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/backoffice/data/firestore_backoffice_store.dart';
import 'package:waste_pro/features/backoffice/data/seed_data.dart';

/// Lets the snapshot listeners catch up with seed writes / CRUD writes.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'seeds empty collections with the design data + collector whitelist',
    () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreBackofficeStore(db: db);
      await store.initialLoad;
      await _settle();

      expect(store.error, isNull);
      expect(store.isLoading, isFalse);
      expect(store.clients.length, seedClients.length);
      expect(store.collecteurs.length, seedCollecteurs.length);

      // Le seed est bien écrit dans Firestore (ids déterministes 'cl1'...).
      final clients = await db.collection('clients').get();
      expect(clients.docs.length, seedClients.length);
      final collecteurs = await db.collection('collecteurs').get();
      expect(collecteurs.docs.length, seedCollecteurs.length);

      // Les collecteurs seedés actifs sont pré-approuvés (liste blanche).
      final whitelist = await db.collection('collectors').get();
      final active = seedCollecteurs.where((c) => c.status == 'Actif').length;
      expect(whitelist.docs.length, active);

      store.dispose();
    },
  );

  test('keeps existing data and only seeds the empty collections', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('clients').doc('custom').set({
      'id': 'custom',
      'name': 'Client Existant',
      'phone': '+237 600 00 00 00',
      'zone': 'Yaoundé',
      'plan': 'Standard',
      'status': 'Actif',
    });

    final store = FirestoreBackofficeStore(db: db);
    await store.initialLoad;
    await _settle();

    // Le document existant est conservé, pas écrasé par le seed.
    expect(store.clients.single.name, 'Client Existant');
    // La collection collecteurs, vide, est seedée.
    expect(store.collecteurs.length, seedCollecteurs.length);

    store.dispose();
  });

  test(
    'creating a client with a password creates a real login account',
    () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
      await store.initialLoad;
      await _settle();

      await store.addClient(
        name: 'Claude Nguema',
        phone: '+237 612 34 56 78',
        zone: 'Bonanjo',
        plan: 'Premium',
        status: 'Actif',
        password: 'secret123',
      );
      expect(store.clients.single.name, 'Claude Nguema');

      final clientDoc = await db.collection('clients').get();
      expect(clientDoc.docs.single.data()['name'], 'Claude Nguema');

      // Le compte de connexion existe : rôle client + mot de passe identique,
      // pour que la personne puisse se connecter à son interface client.
      final login = await db.collection('users').doc('+237612345678').get();
      expect(login.exists, isTrue);
      expect(login.data()?['role'], 'client');
      expect(login.data()?['password'], 'secret123');
      expect(login.data()?['fullName'], 'Claude Nguema');
      expect(login.data()?['consoleCreated'], isTrue);
      expect(login.data()?['subscription_plan'], 'Premium');
      expect(login.data()?['isSubscribed'], isTrue);

      store.dispose();
    },
  );

  test(
    'creating a client without a password creates no login account',
    () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
      await store.initialLoad;
      await _settle();

      await store.addClient(
        name: 'Client Demo',
        phone: '+237 622 22 22 22',
        zone: 'Akwa',
        plan: 'Standard',
        status: 'Actif',
      );
      expect(
        (await db.collection('users').doc('+237622222222').get()).exists,
        isFalse,
      );

      store.dispose();
    },
  );

  test('creating a collector with a password creates a collector login + '
      'whitelist entry', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addCollecteur(
      name: 'Boris Ndongo',
      phone: '+237 655 00 00 00',
      zone: 'Bonanjo / Akwa',
      rating: 4.7,
      status: 'Actif',
      password: 'collector123',
    );
    expect(store.collecteurs.single.name, 'Boris Ndongo');

    final login = await db.collection('users').doc('+237655000000').get();
    expect(login.exists, isTrue);
    expect(login.data()?['role'], 'collector');
    expect(login.data()?['password'], 'collector123');
    expect(login.data()?['fullName'], 'Boris Ndongo');

    // Le numéro est pré-approuvé pour l'auto-inscription.
    final whitelist = await db
        .collection('collectors')
        .doc('+237655000000')
        .get();
    expect(whitelist.exists, isTrue);

    store.dispose();
  });

  test('updating name and password keeps the login account in sync', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addClient(
      name: 'Claude Nguema',
      phone: '+237 612 34 56 78',
      zone: 'Bonanjo',
      plan: 'Premium',
      status: 'Actif',
      password: 'secret123',
    );
    final client = store.clients.first;

    await store.updateClient(
      client.copyWith(name: 'Claude Nguema Jr'),
      password: 'newpass456',
    );

    final login = await db.collection('users').doc('+237612345678').get();
    expect(login.data()?['fullName'], 'Claude Nguema Jr');
    expect(login.data()?['password'], 'newpass456');

    store.dispose();
  });

  test(
    'suspending a client removes its login; reactivating recreates it',
    () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
      await store.initialLoad;
      await _settle();

      await store.addClient(
        name: 'Claude Nguema',
        phone: '+237 612 34 56 78',
        zone: 'Bonanjo',
        plan: 'Premium',
        status: 'Actif',
        password: 'secret123',
      );
      final client = store.clients.first;

      // Suspendu → plus de compte de connexion (plus de login possible).
      await store.updateClient(client.copyWith(status: 'Suspendu'));
      expect(
        (await db.collection('users').doc('+237612345678').get()).exists,
        isFalse,
      );

      // Réactivé → le compte de connexion est recréé avec le mot de passe
      // conservé (le champ reste vide côté admin).
      await store.updateClient(client.copyWith(status: 'Actif'));
      final login = await db.collection('users').doc('+237612345678').get();
      expect(login.exists, isTrue);
      expect(login.data()?['password'], 'secret123');

      store.dispose();
    },
  );

  test(
    'an inactive collector gets no login account nor whitelist entry',
    () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
      await store.initialLoad;
      await _settle();

      await store.addCollecteur(
        name: 'Boris Ndongo',
        phone: '+237 655 00 00 00',
        zone: 'Deido',
        rating: 4.0,
        status: 'Inactif',
        password: 'collector123',
      );
      expect(
        (await db.collection('users').doc('+237655000000').get()).exists,
        isFalse,
      );
      expect(
        (await db.collection('collectors').doc('+237655000000').get()).exists,
        isFalse,
      );

      // Réactivé → le compte de connexion et l'approbation sont créés.
      final collecteur = store.collecteurs.first;
      await store.updateCollecteur(collecteur.copyWith(status: 'Actif'));
      expect(
        (await db.collection('users').doc('+237655000000').get()).exists,
        isTrue,
      );
      expect(
        (await db.collection('collectors').doc('+237655000000').get()).exists,
        isTrue,
      );

      store.dispose();
    },
  );

  test('deleting a client removes its console-created login account', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addClient(
      name: 'Claude Nguema',
      phone: '+237 612 34 56 78',
      zone: 'Bonanjo',
      plan: 'Premium',
      status: 'Actif',
      password: 'secret123',
    );
    await store.deleteClient(store.clients.first.id);

    expect(store.clients, isEmpty);
    expect(
      (await db.collection('users').doc('+237612345678').get()).exists,
      isFalse,
    );

    store.dispose();
  });

  test('deleting a collecteur removes its whitelist entry too', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addCollecteur(
      name: 'Boris Ndongo',
      phone: '+237 655 00 00 00',
      zone: 'Bonanjo',
      rating: 4.7,
      status: 'Actif',
      password: 'collector123',
    );
    await store.deleteCollecteur(store.collecteurs.first.id);

    expect(store.collecteurs, isEmpty);
    expect(
      (await db.collection('users').doc('+237655000000').get()).exists,
      isFalse,
    );
    expect(
      (await db.collection('collectors').doc('+237655000000').get()).exists,
      isFalse,
    );

    store.dispose();
  });

  test(
    'never deletes a real account when removing an entity sharing its phone',
    () async {
      final db = FakeFirebaseFirestore();
      // Un compte client réel existe déjà avec ce numéro (pas de marqueur
      // console) — et un collecteur du backoffice référence le même numéro.
      await db.collection('users').doc('+237655000000').set({
        'phoneNumber': '+237655000000',
        'fullName': 'Client Réel',
        'role': 'client',
        'password': 'clientpass',
      });
      await db.collection('collecteurs').doc('x1').set({
        'id': 'x1',
        'name': 'Ancien collecteur',
        'phone': '+237 655 00 00 00',
        'zone': 'Akwa',
        'rating': 4.0,
        'status': 'Inactif',
      });

      final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
      await store.initialLoad;
      await _settle();

      await store.deleteCollecteur('x1');

      // Le compte client réel n'a pas été supprimé.
      final real = await db.collection('users').doc('+237655000000').get();
      expect(real.exists, isTrue);
      expect(real.data()?['role'], 'client');
      expect(real.data()?['password'], 'clientpass');

      store.dispose();
    },
  );

  test('never clobbers an existing real account with the same phone', () async {
    final db = FakeFirebaseFirestore();
    // Un client réel existe déjà avec ce numéro (pas de marqueur console).
    await db.collection('users').doc('+237688888888').set({
      'phoneNumber': '+237688888888',
      'fullName': 'Client Existant',
      'role': 'client',
      'password': 'clientpass',
    });

    final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await expectLater(
      store.addClient(
        name: 'Faux Client',
        phone: '+237 688 88 88 88',
        zone: 'Akwa',
        plan: 'Standard',
        status: 'Actif',
        password: 'hack',
      ),
      throwsA(isA<Exception>()),
    );

    // Le compte client réel n'a pas été écrasé.
    final client = await db.collection('users').doc('+237688888888').get();
    expect(client.data()?['role'], 'client');
    expect(client.data()?['password'], 'clientpass');
    // Et aucun client n'a été créé dans la collection du backoffice.
    expect(store.clients, isEmpty);

    store.dispose();
  });

  test('changing the phone number migrates the login account', () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreBackofficeStore(db: db, seedIfEmpty: false);
    await store.initialLoad;
    await _settle();

    await store.addClient(
      name: 'Claude Nguema',
      phone: '+237 612 34 56 78',
      zone: 'Bonanjo',
      plan: 'Premium',
      status: 'Actif',
      password: 'secret123',
    );
    final client = store.clients.first;

    await store.updateClient(client.copyWith(phone: '+237 699 99 99 99'));

    // L'ancien compte de connexion est migré vers le nouveau numéro.
    expect(
      (await db.collection('users').doc('+237612345678').get()).exists,
      isFalse,
    );
    final moved = await db.collection('users').doc('+237699999999').get();
    expect(moved.exists, isTrue);
    expect(moved.data()?['password'], 'secret123');

    store.dispose();
  });
}
