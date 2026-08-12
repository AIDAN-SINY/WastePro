import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/backoffice/data/firestore_backoffice_store.dart';
import 'package:waste_pro/features/company/data/firestore_company_store.dart';
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
    'console → candidature → backoffice : une agence créée par la console '
    'entreprise, son chef d agence, la candidature du client, et la visibilité '
    'dans le backoffice scopé',
    () async {
      final db = FakeFirebaseFirestore();

      // --- L entreprise existe ---
      await db.collection('societes').doc('so9').set({
        'id': 'so9',
        'raisonSociale': 'WastePro Akwa Ltd',
        'adresse': 'Akwa, Douala',
        'telephone': '+237 233 42 10 55',
        'email': 'contact@wastepro-akwa.cm',
        'status': 'Active',
      });

      // --- 1. Le General Administrator crée une agence (console entreprise) ---
      final company = FirestoreCompanyStore(
        db: db,
        societeId: 'so9',
        seedIfEmpty: false,
      );
      await company.initialLoad;
      await _settle();

      final agence = await company.addAgence(
        ville: 'Douala — Akwa',
        location: 'Avenue Kennedy',
        responsable: 'Jean Dooh',
        telephone: '+237 677 12 34 56',
        status: 'Active',
      );
      // L'agence est écrite AVEC son id dans le doc (lu par le formulaire
      // client via AgenceModel.fromMap(map['id'])).
      final agenceDoc =
          await db.collection('agences').doc(agence.id).get();
      expect(agenceDoc.exists, isTrue);
      expect(agenceDoc.data()?['id'], agence.id);

      // --- 2. Le GA crée le chef d'agence affecté à cette agence ---
      await company.addUtilisateur(
        nom: 'Jean Dooh',
        telephone: '+237 677 12 34 56',
        role: 'Agency Manager',
        agence: agence.ville,
        agenceId: agence.id,
        status: 'Active',
        password: 'manager123',
      );
      await _settle();

      // Le compte de connexion du chef porte le MÊME agenceId que l'agence.
      final managerLogin =
          await db.collection('users').doc('+237677123456').get();
      expect(managerLogin.exists, isTrue);
      expect(managerLogin.data()?['role'], 'agency_manager');
      expect(managerLogin.data()?['agenceId'], agence.id);

      // --- 3. Le client remplit la pré-inscription (choix de l'agence) ---
      final auth = AuthService(db: db);
      await auth.submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: '698 22 44 66',
        zone: 'Akwa',
        agenceId: agence.id,
        agenceName: agence.ville,
        societeId: 'so9',
        password: 'secret123',
      );

      final regs = await db.collection('registrations').get();
      expect(regs.docs.single.data()['agenceId'], agence.id);

      // --- 4. Le chef d'agence se connecte → backoffice scopé ---
      final manager = await AuthService(db: db).login(
        '+237 677 12 34 56',
        'manager123',
      );
      expect(manager, isNotNull);
      expect(manager!.agenceId, agence.id);

      final store = FirestoreBackofficeStore(
        db: db,
        seedIfEmpty: false,
        agenceId: manager.agenceId,
        societeId: manager.societeId,
      );
      await store.initialLoad;
      await _settle();

      // La candidature EST visible dans le backoffice du chef d'agence.
      expect(store.registrations.length, 1);
      expect(store.pendingRegistrations.single.fullName, 'Carine Mbappe');
      expect(store.pendingRegistrations.single.agenceId, agence.id);

      company.dispose();
      store.dispose();
    },
  );

  test(
    'backoffice scopé : une candidature écrite avec le NOM de l agence (mais '
    'un id différent, ex. agence homonyme) reste visible via le fallback',
    () async {
      final db = FakeFirebaseFirestore();

      // Deux agences HOMONYMES (ex. l agence seed « Douala — Bonanjo » et
      // une vraie agence créée plus tard avec le même nom).
      const ville = 'Douala — Bonanjo';
      await db.collection('agences').doc('agSeed').set({
        'id': 'agSeed',
        'societe': 'WastePro Douala Ltd',
        'societeId': 'so1',
        'ville': ville,
        'responsable': 'Jean Dooh',
        'telephone': '+237 677 12 34 56',
        'status': 'Active',
      });
      await db.collection('agences').doc('agReal').set({
        'id': 'agReal',
        'societe': 'WastePro Akwa Ltd',
        'societeId': 'so9',
        'ville': ville,
        'responsable': 'Marie Ekwalla',
        'telephone': '+237 690 45 12 78',
        'status': 'Active',
      });
      // Le chef est affecté à la VRAIE agence (agReal).
      await db.collection('users').doc('+237690451278').set({
        'phoneNumber': '+237690451278',
        'fullName': 'Marie Ekwalla',
        'role': 'agency_manager',
        'password': 'manager123',
        'societeId': 'so9',
        'agenceId': 'agReal',
        'consoleCreated': true,
      });

      // Le client a sélectionné l'agence homonyme agSeed (même nom) : sa
      // candidature porte l'id de agSeed mais le nom « Douala — Bonanjo ».
      await AuthService(db: db).submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: '698 22 44 66',
        zone: 'Bonanjo',
        agenceId: 'agSeed',
        agenceName: ville,
        societeId: 'so1',
        password: 'secret123',
      );

      final store = FirestoreBackofficeStore(
        db: db,
        seedIfEmpty: false,
        agenceId: 'agReal',
        societeId: 'so9',
      );
      await store.initialLoad;
      await _settle();

      // L'id ne correspond pas, mais le NOM oui : le chef d'agence VOIT la
      // candidature et peut l'approuver (l'approbation crée le client sous
      // l'agence choisie par le client).
      expect(store.pendingRegistrations.length, 1);
      expect(store.pendingRegistrations.single.fullName, 'Carine Mbappe');
      expect(store.pendingRegistrations.single.agenceId, 'agSeed');

      // Approbation : le client est créé sous l'agence CHOISIE par le
      // client (agSeed), jamais sous celle du chef qui approuve (agReal).
      await store.approveRegistration(
        store.pendingRegistrations.single,
        collecteurId: 'coX',
      );
      await _settle();
      final client = store.clients.singleWhere(
        (c) => c.name == 'Carine Mbappe',
      );
      expect(client.agenceId, 'agSeed');
      final login =
          await db.collection('users').doc('+237698224466').get();
      expect(login.exists, isTrue);
      expect(login.data()?['agenceId'], 'agSeed');

      store.dispose();
    },
  );
}
