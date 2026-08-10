import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/auth/screens/pre_register_screen.dart';

void main() {
  Future<FakeFirebaseFirestore> seededDb() async {
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
    await db.collection('agences').doc('ag2').set({
      'id': 'ag2',
      'societe': 'WastePro Douala Ltd',
      'societeId': 'so1',
      'ville': 'Douala — Bassa',
      'responsable': 'Aïcha Bello',
      'telephone': '+237 699 33 67 41',
      'status': 'Active',
    });
    return db;
  }

  Future<void> pumpPreRegister(
    WidgetTester tester,
    FakeFirebaseFirestore db,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PreRegisterScreen(db: db)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'suggestions d agences selon la zone saisie, sélection + soumission',
    (tester) async {
      final db = await seededDb();
      await pumpPreRegister(tester, db);

      // Champs du formulaire.
      expect(find.text('Apply as a client'), findsOneWidget);

      // Remplir les infos (ordre : nom, téléphone, zone, pass, confirm).
      await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
      await tester.enterText(
        find.byType(TextFormField).at(1), // téléphone (sans +237)
        '698 22 44 66',
      );
      // Zone « Douala: Akwa » → suggère les agences de Douala.
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Douala: Akwa',
      );
      await tester.pumpAndSettle();

      // Les 2 agences de Douala sont proposées comme chips.
      expect(find.text('Agencies near douala'), findsOneWidget);
      expect(find.text('Douala — Bonanjo'), findsWidgets);
      expect(find.text('Douala — Bassa'), findsWidgets);

      // Choisir l'agence via la recherche libre.
      await tester.tap(find.text('Douala — Bonanjo').last);
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

  testWidgets('mot de passe trop court → erreur, pas de candidature', (
    tester,
  ) async {
    final db = await seededDb();
    await pumpPreRegister(tester, db);

    await tester.enterText(find.byType(TextFormField).at(0), 'Carine Mbappe');
    await tester.enterText(find.byType(TextFormField).at(1), '698 22 44 66');
    await tester.enterText(find.byType(TextFormField).at(2), 'Bonanjo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Douala — Bonanjo').last);
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
    await tester.enterText(find.byType(TextFormField).at(2), 'Bonanjo');
    await tester.pumpAndSettle();
    expect(find.text('No agency available yet'), findsOneWidget);
  });
}
