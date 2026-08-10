import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/backoffice/data/firestore_backoffice_store.dart';
import 'package:waste_pro/services/auth_service.dart';

/// Laisse les listeners de snapshots rattraper les écritures.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'parcours complet : client candidat → chef d agence voit → approbation '
    '→ client se connecte',
    () async {
      final db = FakeFirebaseFirestore();

      // --- Contexte : une agence existe (ag1, société so1) ---
      await db.collection('agences').doc('ag1').set({
        'id': 'ag1',
        'societe': 'WastePro Douala Ltd',
        'societeId': 'so1',
        'ville': 'Douala — Bonanjo',
        'responsable': 'Jean Dooh',
        'telephone': '+237 677 12 34 56',
        'status': 'Active',
      });
      // Un collecteur actif dans cette agence (pour l'assignation).
      await db.collection('collecteurs').doc('co1').set({
        'id': 'co1',
        'name': 'Paul Mbarga',
        'phone': '+237 678 90 11 22',
        'zone': 'Bonanjo / Akwa',
        'rating': 4.8,
        'status': 'Active',
        'agenceId': 'ag1',
        'societeId': 'so1',
      });
      // Le chef d'agence (compte de connexion créé par la console super
      // admin : rôle agency_manager, scopé à ag1).
      await db.collection('users').doc('+237677123456').set({
        'phoneNumber': '+237677123456',
        'fullName': 'Jean Dooh',
        'role': 'agency_manager',
        'password': 'manager123',
        'societeId': 'so1',
        'agenceId': 'ag1',
        'consoleCreated': true,
      });

      // --- 1. Le client remplit la pré-inscription (app) ---
      final auth = AuthService(db: db);
      await auth.submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: '698 22 44 66',
        zone: 'Bonanjo',
        agenceId: 'ag1',
        agenceName: 'Douala — Bonanjo',
        societeId: 'so1',
        password: 'secret123',
      );

      // La candidature est bien enregistrée (status pending, liée à ag1).
      final regs = await db.collection('registrations').get();
      expect(regs.docs.single.data()['status'], 'pending');
      expect(regs.docs.single.data()['agenceId'], 'ag1');
      // Pas encore de compte client ni de compte de connexion.
      expect((await db.collection('clients').get()).docs, isEmpty);
      expect(
        (await db.collection('users').doc('+237698224466').get()).exists,
        isFalse,
      );

      // --- 2. Le chef d'agence se connecte → backoffice scopé à ag1 ---
      final manager = await AuthService(db: db).login(
        '+237 677 12 34 56',
        'manager123',
      );
      expect(manager, isNotNull);
      expect(manager!.role, 'agency_manager');
      expect(manager.agenceId, 'ag1');

      final store = FirestoreBackofficeStore(
        db: db,
        seedIfEmpty: false,
        agenceId: manager.agenceId,
        societeId: manager.societeId,
      );
      await store.initialLoad;
      await _settle();

      // Le chef d'agence VOIT la candidature de Carine (scope ag1).
      expect(store.registrations.length, 1);
      expect(store.pendingRegistrations.single.fullName, 'Carine Mbappe');

      // Un autre chef d'agence (ag2) ne la verrait PAS.
      final otherStore = FirestoreBackofficeStore(
        db: db,
        seedIfEmpty: false,
        agenceId: 'ag2',
      );
      await otherStore.initialLoad;
      await _settle();
      expect(otherStore.registrations, isEmpty);
      otherStore.dispose();

      // --- 3. Le chef d'agence approuve et assigne le collecteur ---
      await store.approveRegistration(
        store.pendingRegistrations.single,
        collecteurId: 'co1',
      );
      await _settle();

      // Client créé + compte de connexion avec le mot de passe du client.
      final client = store.clients.singleWhere((c) => c.name == 'Carine Mbappe');
      expect(client.agenceId, 'ag1');
      expect(client.collecteurId, 'co1');
      expect(client.status, 'Active');

      final login = await db.collection('users').doc('+237698224466').get();
      expect(login.exists, isTrue);
      expect(login.data()?['role'], 'client');
      expect(login.data()?['password'], 'secret123');
      expect(login.data()?['collecteurId'], 'co1');

      // --- 4. Le client peut maintenant se connecter ---
      final clientUser = await AuthService(db: db).login('698 22 44 66', 'secret123');
      expect(clientUser, isNotNull);
      expect(clientUser!.role, 'client');
      expect(clientUser.agenceId, 'ag1');
      expect(clientUser.collecteurId, 'co1');

      store.dispose();
    },
  );

  test(
    'nom d agence partiel tapé par le client → résolu vers la bonne agence',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('agences').doc('ag1').set({
        'id': 'ag1',
        'societe': 'WastePro Douala Ltd',
        'societeId': 'so1',
        'ville': 'Douala — Bonanjo',
        'responsable': 'Jean Dooh',
        'telephone': '+237 677 12 34 56',
        'status': 'Active',
      });

      final auth = AuthService(db: db);
      // Le client tape « bonanjo » (pas le nom complet) sans sélectionner.
      await auth.submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: '698 22 44 66',
        zone: 'Bonanjo',
        agenceId: '',
        agenceName: 'bonanjo',
        societeId: '',
        password: 'secret123',
      );

      final regs = await db.collection('registrations').get();
      // La candidature est rattachée à l'agence unique trouvée par le nom
      // partiel — sinon le chef d'agence ne la verrait jamais.
      expect(regs.docs.single.data()['agenceId'], 'ag1');
      expect(regs.docs.single.data()['societeId'], 'so1');
    },
  );

  test(
    'deux candidatures du même numéro : la 2e est refusée sans crash '
    '(pas d index composé requis)',
    () async {
      final db = FakeFirebaseFirestore();
      final auth = AuthService(db: db);

      await auth.submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: '698 22 44 66',
        zone: 'Bonanjo',
        agenceId: 'ag1',
        agenceName: 'Douala — Bonanjo',
        societeId: 'so1',
        password: 'secret123',
      );
      // Pas de 2e candidature : un seul where sur phone, filtre en mémoire.
      expect(
        () => auth.submitPreRegistration(
          fullName: 'Carine Mbappe',
          phone: '698 22 44 66',
          zone: 'Bonanjo',
          agenceId: 'ag1',
          agenceName: 'Douala — Bonanjo',
          societeId: 'so1',
          password: 'otherpass',
        ),
        throwsA(contains('already have a pending application')),
      );
      expect((await db.collection('registrations').get()).docs, hasLength(1));
    },
  );
}
