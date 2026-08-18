import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/company/company_console.dart';
import 'package:waste_pro/features/company/data/company_store.dart';
import 'package:waste_pro/features/company/data/firestore_company_store.dart';
import 'package:waste_pro/models/agence_model.dart';

import 'fakes/fake_auth_backend.dart';

void main() {
  Future<void> pumpConsole(WidgetTester tester, {CompanyStore? store}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Sans store fourni, la console crée son propre store mock et le seed
    // (chemin « preview démo ») — c'est ce que les tests de preview testent.
    await tester.pumpWidget(
      MaterialApp(home: CompanyConsole(store: store)),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('renders the company console shell and overview', (
    tester,
  ) async {
    final store = CompanyStore(societeId: 'so1');
    store.agences.add(
      const AgenceModel(
        id: 'ag1',
        societe: 'WastePro Douala Ltd',
        societeId: 'so1',
        ville: 'Douala — Bonanjo',
        responsable: 'Jean Dooh',
        telephone: '+237 677 12 34 56',
        status: 'Active',
      ),
    );
    store.notifyListeners();

    await pumpConsole(tester, store: store);

    // Sidebar brand
    expect(find.text('Company Console'), findsOneWidget);
    // Nav items
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Agencies'), findsWidgets);
    expect(find.text('Managers'), findsWidgets);
    // Agency dropdown present
    expect(find.byKey(const Key('cc_agency_dropdown')), findsOneWidget);
    // Bandeau aperçu démo (store mock) présent.
    expect(find.textContaining('Demo preview'), findsOneWidget);
  });

  testWidgets('navigates to the agencies page (preview seeded data)', (
    tester,
  ) async {
    await pumpConsole(tester);

    // Preview store → agences sont seedées.
    await tester.tap(find.byKey(const Key('cc_nav_agencies')));
    await tester.pumpAndSettle();

    expect(find.text('New agency'), findsOneWidget);
    // Les 3 agences seedées sont visibles.
    expect(find.text('Douala — Bonanjo'), findsOneWidget);
    expect(find.text('Douala — Bassa'), findsOneWidget);
    expect(find.text('Yaoundé'), findsOneWidget);
    // Footer
    expect(find.textContaining('3 agenc'), findsOneWidget);
  });

  testWidgets('navigates to the managers page (preview seeded data)', (
    tester,
  ) async {
    await pumpConsole(tester);

    await tester.tap(find.byKey(const Key('cc_nav_managers')));
    await tester.pumpAndSettle();

    // Le bouton « New manager » a disparu : les managers sont créés avec
    // leur agence via le modal agence.
    expect(find.text('New manager'), findsNothing);
    expect(
      find.text('Managers are created with their agency.'),
      findsOneWidget,
    );
    // 3 managers seedés.
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Aïcha Bello'), findsOneWidget);
    expect(find.text('Marie Ekwalla'), findsOneWidget);
    expect(find.textContaining('3 manager'), findsOneWidget);
  });

  testWidgets('agency dropdown changes the overview scope', (tester) async {
    await pumpConsole(tester);

    // Le dropdown est dans la topbar.
    await tester.tap(find.byKey(const Key('cc_agency_dropdown')));
    await tester.pumpAndSettle();

    // Choisir la première agence : Douala — Bonanjo.
    await tester.tap(find.byKey(const Key('cc_dd_preview-ag1')));
    await tester.pumpAndSettle();

    // Le titre du dropdown a changé pour l'agence sélectionnée.
    expect(find.text('Douala — Bonanjo'), findsWidgets);
    // L'Overview affiche le scope : 'Viewing Douala — Bonanjo'
    expect(find.textContaining('Viewing Douala'), findsOneWidget);

    // Revenir à « All agencies ».
    await tester.tap(find.byKey(const Key('cc_agency_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cc_dd_all')));
    await tester.pumpAndSettle();

    expect(find.text('All agencies'), findsWidgets);
    expect(find.textContaining('Viewing all'), findsOneWidget);
  });

  testWidgets('créer une agence via le modal (badge entreprise + champs)', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('societes').doc('so1').set({
      'id': 'so1',
      'raisonSociale': 'WastePro Douala Ltd',
      'adresse': '127 Rue du Commerce, Akwa, Douala',
      'telephone': '+237 233 42 10 55',
      'email': 'contact@wastepro.cm',
      'status': 'Active',
    });
    final store = FirestoreCompanyStore(
      db: db,
      backend: FakeAuthBackend(),
      societeId: 'so1',
    );
    await store.initialLoad;

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: CompanyConsole(societeId: 'so1', store: store)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('cc_nav_agencies')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New agency'));
    await tester.pumpAndSettle();

    // Badge non-éditable avec l'entreprise du connecté en haut du modal.
    expect(find.textContaining('Creating agency for:'), findsOneWidget);
    expect(find.textContaining('WastePro Douala Ltd'), findsWidgets);

    // Les 6 champs demandés sont présents.
    expect(find.text('Agency name'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Manager phone'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);

    // Remplir le formulaire (nom, localisation, manager, tél. manager,
    // ville, téléphone de l'agence).
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bonanjo');
    await tester.enterText(fields.at(1), 'Rue de la Paix');
    await tester.enterText(fields.at(2), 'Jean Dooh');
    await tester.enterText(fields.at(3), '+237 699 88 77 66');
    await tester.enterText(fields.at(4), 'Douala');
    await tester.enterText(fields.at(5), '+237 677 12 34 56');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // L'agence est créée : ville fusionnée « Douala — Bonanjo » + location.
    expect(store.agences, hasLength(1));
    final agence = store.agences.first;
    expect(agence.ville, 'Douala — Bonanjo');
    expect(agence.location, 'Rue de la Paix');
    expect(agence.responsable, 'Jean Dooh');
    expect(agence.telephone, '+237 677 12 34 56');
    expect(agence.societe, 'WastePro Douala Ltd');
    expect(agence.status, 'Active');

    // Le manager saisi est synchronisé avec l'agence : il apparaît dans la
    // liste des managers sans être recréé via la page Managers, avec un
    // mot de passe numérique généré.
    expect(store.utilisateurs, hasLength(1));
    final manager = store.utilisateurs.first;
    expect(manager.nom, 'Jean Dooh');
    expect(manager.telephone, '+237 699 88 77 66');
    expect(manager.role, 'Agency Manager');
    expect(manager.agence, 'Douala — Bonanjo');
    expect(manager.agenceId, agence.id);
    expect(manager.password, matches(RegExp(r'^\d{6}$')));

    // Le compte de connexion users/{phone} a bien été créé (uid Auth,
    // pas de mot de passe en clair dans Firestore).
    final userDoc =
        await db.collection('users').doc('+237699887766').get();
    expect(userDoc.exists, isTrue);
    expect(userDoc.data()!['role'], 'agency_manager');
    expect(userDoc.data()!['fullName'], 'Jean Dooh');
    expect(userDoc.data()!['uid'], isNotEmpty);
    expect(userDoc.data()!['password'], isNull);
    expect(userDoc.data()!['consoleCreated'], isTrue);

    // Le dialogue affiche les identifiants générés une seule fois.
    expect(find.text('Manager account created'), findsOneWidget);
    expect(find.text('+237 699 88 77 66'), findsOneWidget);
    expect(find.text(manager.password), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Flush le timer du toast (3 s) pour que le test se termine proprement.
    await tester.pump(const Duration(seconds: 4));
    store.dispose();
  });

  testWidgets(
    'créer une agence avec un manager SANS téléphone est bloqué',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('societes').doc('so1').set({
        'id': 'so1',
        'raisonSociale': 'WastePro Douala Ltd',
        'adresse': '127 Rue du Commerce, Akwa, Douala',
        'telephone': '+237 233 42 10 55',
        'email': 'contact@wastepro.cm',
        'status': 'Active',
      });
      final store = FirestoreCompanyStore(
        db: db,
        backend: FakeAuthBackend(),
        societeId: 'so1',
      );
      await store.initialLoad;

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: CompanyConsole(societeId: 'so1', store: store)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('cc_nav_agencies')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New agency'));
      await tester.pumpAndSettle();

      // Nom d'agence + nom du manager, mais pas de téléphone manager.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Bonanjo');
      await tester.enterText(fields.at(2), 'Jean Dooh');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Toast d'erreur + le modal reste ouvert pour corriger.
      expect(
        find.text('Please enter the manager phone number.'),
        findsOneWidget,
      );
      expect(find.text('Agency name'), findsOneWidget);

      // Rien n'a été créé : ni agence, ni manager.
      expect(store.agences, isEmpty);
      expect(store.utilisateurs, isEmpty);

      // Flush le timer du toast (3 s) pour que le test se termine
      // proprement.
      await tester.pump(const Duration(seconds: 4));
      store.dispose();
    },
  );

  testWidgets('créer une agence SANS nom ni ville est bloqué par le modal', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('societes').doc('so1').set({
      'id': 'so1',
      'raisonSociale': 'WastePro Douala Ltd',
      'adresse': '127 Rue du Commerce, Akwa, Douala',
      'telephone': '+237 233 42 10 55',
      'email': 'contact@wastepro.cm',
      'status': 'Active',
    });
    final store = FirestoreCompanyStore(
      db: db,
      backend: FakeAuthBackend(),
      societeId: 'so1',
    );
    await store.initialLoad;

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: CompanyConsole(societeId: 'so1', store: store)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('cc_nav_agencies')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New agency'));
    await tester.pumpAndSettle();

    // Ne remplir que le manager : nom d'agence et ville restent vides.
    await tester.enterText(find.byType(TextFormField).at(2), 'Jean Dooh');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Toast d'erreur + le modal reste ouvert pour corriger.
    expect(
      find.text('Please enter an agency name or a city.'),
      findsOneWidget,
    );
    expect(find.text('Agency name'), findsOneWidget);

    // Rien n'a été créé.
    expect(store.agences, isEmpty);

    // Flush le timer du toast (3 s) pour que le test se termine proprement.
    await tester.pump(const Duration(seconds: 4));
    store.dispose();
  });

  testWidgets('créer une agence SANS manager (aucun compte créé)', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('societes').doc('so1').set({
      'id': 'so1',
      'raisonSociale': 'WastePro Douala Ltd',
      'adresse': '127 Rue du Commerce, Akwa, Douala',
      'telephone': '+237 233 42 10 55',
      'email': 'contact@wastepro.cm',
      'status': 'Active',
    });
    final store = FirestoreCompanyStore(
      db: db,
      backend: FakeAuthBackend(),
      societeId: 'so1',
    );
    await store.initialLoad;

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: CompanyConsole(societeId: 'so1', store: store)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('cc_nav_agencies')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New agency'));
    await tester.pumpAndSettle();

    // Remplir l'agence mais laisser le manager (et son téléphone) vides.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bonanjo');
    await tester.enterText(fields.at(4), 'Douala');
    await tester.enterText(fields.at(5), '+237 677 12 34 56');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Agence créée sans manager : aucun dialogue d'identifiants, aucun
    // compte manager.
    expect(store.agences, hasLength(1));
    expect(store.utilisateurs, isEmpty);
    expect(find.text('Manager account created'), findsNothing);
    final users = await db.collection('users').get();
    expect(users.docs, isEmpty);

    // Flush le timer du toast (3 s) pour que le test se termine proprement.
    await tester.pump(const Duration(seconds: 4));
    store.dispose();
  });
}