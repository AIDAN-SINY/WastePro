import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/company/company_console.dart';
import 'package:waste_pro/features/company/data/company_store.dart';
import 'package:waste_pro/features/company/data/firestore_company_store.dart';
import 'package:waste_pro/models/agence_model.dart';

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

    expect(find.text('New manager'), findsOneWidget);
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

  testWidgets('créer un chef d agence SANS agence est bloqué', (tester) async {
    // Flow validé : chaque chef d'agence doit être assigné à une agence.
    // Sans agence, son backoffice n'aurait aucun périmètre. On passe par
    // un vrai store Firestore (le store mock bloque « New manager » en
    // mode aperçu démo).
    final db = FakeFirebaseFirestore();
    final store = FirestoreCompanyStore(db: db, societeId: 'so1');
    await store.initialLoad;

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: CompanyConsole(societeId: 'so1', store: store)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('cc_nav_managers')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New manager'));
    await tester.pumpAndSettle();

    // Nom + téléphone + mot de passe, mais agence laissée sur « — ».
    await tester.enterText(find.byType(TextFormField).at(0), 'Jean Dooh');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '+237 677 12 34 56',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Toast d'erreur + le drawer reste ouvert pour corriger.
    expect(
      find.text('Please assign this manager to an agency.'),
      findsOneWidget,
    );
    expect(find.text('Full name'), findsOneWidget);

    // Rien n'a été écrit : ni l'utilisateur, ni un compte de connexion.
    expect(store.utilisateurs, isEmpty);
    final utilisateurs = await db.collection('utilisateurs').get();
    expect(utilisateurs.docs, isEmpty);
    final users = await db.collection('users').get();
    expect(users.docs, isEmpty);

    // Flush le timer du toast (3 s) pour que le test se termine proprement.
    await tester.pump(const Duration(seconds: 4));
    store.dispose();
  });
}