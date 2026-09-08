import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/auth/screens/pre_register_screen.dart';

import 'fakes/fake_auth_backend.dart';

void main() {
  Future<FakeFirebaseFirestore> seededDb() async {
    final db = FakeFirebaseFirestore();
    await db.collection('agences').doc('ag1').set({
      'id': 'ag1',
      'societe': 'WastePro Yaoundé SARL',
      'societeId': 'so1',
      'ville': 'Yaoundé — Bastos',
      'responsable': 'Jean Dooh',
      'telephone': '+237 677 12 34 56',
      'status': 'Active',
    });
    await db.collection('agences').doc('ag2').set({
      'id': 'ag2',
      'societe': 'WastePro Yaoundé SARL',
      'societeId': 'so1',
      'ville': 'Yaoundé — Nlongkak',
      'responsable': 'Aïcha Bello',
      'telephone': '+237 699 33 67 41',
      'status': 'Active',
    });
    // Agency managers (console accounts): only agencies covered by
    // an active manager are offered to clients.
    await db.collection('utilisateurs').doc('u1').set({
      'id': 'u1',
      'nom': 'Jean Dooh',
      'telephone': '+237 677 12 34 56',
      'role': 'Agency Manager',
      'agence': 'Yaoundé — Bastos',
      'societeId': 'so1',
      'agenceId': 'ag1',
      'status': 'Active',
      'password': 'x',
    });
    await db.collection('utilisateurs').doc('u2').set({
      'id': 'u2',
      'nom': 'Aïcha Bello',
      'telephone': '+237 699 33 67 41',
      'role': 'Agency Manager',
      'agence': 'Yaoundé — Nlongkak',
      'societeId': 'so1',
      'agenceId': 'ag2',
      'status': 'Active',
      'password': 'x',
    });
    return db;
  }

  Future<void> pumpPreRegister(
    WidgetTester tester,
    FakeFirebaseFirestore db,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PreRegisterScreen(db: db, backend: FakeAuthBackend())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'agency suggestions based on entered zone, selection + submission',
    (tester) async {
      final db = await seededDb();
      await pumpPreRegister(tester, db);

      // Form fields.
      expect(find.text('Apply as a client'), findsOneWidget);

      // Fill in the info (order: name, phone, zone, password, confirm).
      await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
      await tester.enterText(
        find.byType(TextFormField).at(1), // phone (without +237)
        '698 22 44 66',
      );
      // Zone "Yaoundé: Bastos" → suggests agencies in Yaoundé.
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Yaoundé: Bastos',
      );
      await tester.pumpAndSettle();

      // The 2 Yaoundé agencies are offered as chips.
      expect(find.text('Agencies near yaoundé'), findsOneWidget);
      expect(find.text('Yaoundé — Bastos'), findsWidgets);
      expect(find.text('Yaoundé — Nlongkak'), findsWidgets);

      // Choisir l'agence via la recherche libre.
      await tester.tap(find.text('Yaoundé — Bastos').last);
      await tester.pumpAndSettle();
      expect(find.text('Selected agency'), findsOneWidget);

      // Mot de passe + confirmation.
      final passFields = find.byType(TextFormField);
      await tester.enterText(passFields.at(3), 'secret123');
      await tester.enterText(passFields.at(4), 'secret123');
      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();

      // Candidature envoyée : la carte de succès s'affiche…
      expect(find.text('Application sent!'), findsOneWidget);
      // …et la candidature est bien écrite dans Firestore (agence ag1).
      final regs = await db.collection('registrations').get();
      expect(regs.docs.single.data()['fullName'], 'Carine Mbappe');
      expect(regs.docs.single.data()['agenceId'], 'ag1');
      expect(regs.docs.single.data()['status'], 'pending');
    },
  );

  testWidgets(
    'zone « etoudi » → agence d etoudi auto-sélectionnée (pas de recherche '
    'manuelle)',
    (tester) async {
      final db = FakeFirebaseFirestore();
      // Agence d etoudi + son chef d agence actif.
      await db.collection('agences').doc('c1').set({
        'id': 'c1',
        'societe': 'emana',
        'societeId': 'so1',
        'ville': "Yaounde — agence d'etoudi",
        'location': 'carrefour du palais',
        'responsable': 'Eric Ekwa',
        'telephone': '699887667',
        'status': 'Active',
      });
      await db.collection('utilisateurs').doc('u1').set({
        'id': 'u1',
        'nom': 'Eric Ekwa',
        'telephone': '+237677980000',
        'role': 'Agency Manager',
        'agence': "Yaounde — agence d'etoudi",
        'societeId': 'so1',
        'agenceId': 'c1',
        'status': 'Active',
        'password': 'x',
      });
      await pumpPreRegister(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
      await tester.enterText(find.byType(TextFormField).at(1), '698 22 44 66');
      // Quartier seul « etoudi » → l agence d etoudi est choisie seule.
      await tester.enterText(find.byType(TextFormField).at(2), 'etoudi');
      await tester.pumpAndSettle();

      // Auto-sélection : la puce « Selected agency » apparaît sans tap.
      expect(find.text('Selected agency'), findsOneWidget);
      expect(find.text("Yaounde — agence d'etoudi"), findsWidgets);

      final passFields = find.byType(TextFormField);
      await tester.enterText(passFields.at(3), 'secret123');
      await tester.enterText(passFields.at(4), 'secret123');
      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();

      // Candidature bien écrite sur l agence d etoudi.
      final regs = await db.collection('registrations').get();
      expect(regs.docs.single.data()['agenceId'], 'c1');
      expect(regs.docs.single.data()['status'], 'pending');
    },
  );

  testWidgets('mot de passe trop court → erreur, pas de candidature', (
    tester,
  ) async {
    final db = await seededDb();
    await pumpPreRegister(tester, db);

    await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
    await tester.enterText(find.byType(TextFormField).at(1), '698 22 44 66');
    await tester.enterText(find.byType(TextFormField).at(2), 'Bastos');
    await tester.pumpAndSettle();
    // La zone « Bonanjo » correspond à UNE seule agence : elle est déjà
    // auto-sélectionnée — la puce peut être hors écran, le tap est optionnel.
    await tester.ensureVisible(find.text('Yaoundé — Bastos').last);
    await tester.tap(find.text('Yaoundé — Bastos').last);
    await tester.pumpAndSettle();

    final passFields = find.byType(TextFormField);
    await tester.enterText(passFields.at(3), 'abc');
    await tester.enterText(passFields.at(4), 'abc');
    await tester.ensureVisible(find.text('Submit application'));
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();

    expect(find.text('Application sent!'), findsNothing);
    expect((await db.collection('registrations').get()).docs, isEmpty);
  });

  testWidgets('sans agence dans Firestore, message d aide au lieu de rien',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpPreRegister(tester, db);

    // La recherche d'agence explique qu'il n'y a pas encore d'agence.
    await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
    await tester.enterText(find.byType(TextFormField).at(2), 'Bastos');
    await tester.pumpAndSettle();
    expect(find.text('No agency available yet'), findsOneWidget);
  });

  testWidgets(
    'agence sans chef d agence actif → non proposée + message dédié + '
    'soumission bloquée',
    (tester) async {
      final db = FakeFirebaseFirestore();
      // Une agence existe (ag1) mais AUCUN chef d'agence ne la gère.
      await db.collection('agences').doc('ag1').set({
        'id': 'ag1',
        'societe': 'WastePro Yaoundé SARL',
        'societeId': 'so1',
        'ville': 'Yaoundé — Bastos',
        'responsable': 'Jean Dooh',
        'telephone': '+237 677 12 34 56',
        'status': 'Active',
      });
      await pumpPreRegister(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
      await tester.enterText(find.byType(TextFormField).at(1), '698 22 44 66');
      await tester.enterText(find.byType(TextFormField).at(2), 'Bastos');
      await tester.pumpAndSettle();

      // L'agence existe mais n'est PAS proposée (aucun chef pour la
      // traiter) — message dédié au lieu de la liste.
      expect(find.text('Yaoundé — Bastos'), findsNothing);
      expect(find.textContaining('No agency has a manager yet'), findsOneWidget);

      // Taper le nom de l'agence ne la sélectionne pas (pas de chef)…
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.hintText ?? '').contains('type your agency'),
        ),
        'Yaoundé — Bastos',
      );
      await tester.pumpAndSettle();
      final passFields = find.byType(TextFormField);
      await tester.enterText(passFields.at(3), 'secret123');
      await tester.enterText(passFields.at(4), 'secret123');
      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();

      // …donc la soumission est bloquée : pas de candidature dans le vide.
      expect(
        find.textContaining('has no agency manager yet'),
        findsOneWidget,
      );
      expect((await db.collection('registrations').get()).docs, isEmpty);
    },
  );

  testWidgets('le champ zone offre un bouton « choisir sur la carte »',
      (tester) async {
    final db = await seededDb();
    await pumpPreRegister(tester, db);

    // Le bouton carte (MapPickerScreen) est présent à côté du champ zone.
    final mapButton = find.byKey(const Key('zone_pick_map'));
    expect(mapButton, findsOneWidget);

    // Il ouvre bien MapPickerScreen.
    await tester.tap(mapButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Set Collection Point'), findsOneWidget);
  });
}
