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

    await tester.pumpWidget(
      MaterialApp(home: CompanyConsole(store: store ?? CompanyStore())),
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

    expect(find.text('Company Console'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Agencies'), findsWidgets);
    expect(find.text('Managers'), findsWidgets);
    // Bandeau aperçu démo (store mock) présent.
    expect(find.textContaining('Demo preview'), findsOneWidget);
  });

  testWidgets('navigates to the agencies page', (tester) async {
    await pumpConsole(tester);

    await tester.tap(find.text('Agencies').first);
    await tester.pumpAndSettle();

    expect(find.text('New agency'), findsOneWidget);
    expect(find.text('No agencies yet'), findsOneWidget);
  });

  testWidgets('navigates to the managers page', (tester) async {
    await pumpConsole(tester);

    await tester.tap(find.text('Managers').first);
    await tester.pumpAndSettle();

    expect(find.text('New manager'), findsOneWidget);
    expect(find.text('No managers yet'), findsOneWidget);
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

    await tester.tap(find.text('Managers').first);
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
