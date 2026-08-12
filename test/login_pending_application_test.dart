import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/auth/screens/login_screen.dart';

/// Le client qui remplit une pré-inscription n'a PAS encore de compte
/// `users/{téléphone}` : il ne peut se connecter qu'après approbation par
/// le chef d'agence. Le login doit le guider selon l'état de sa candidature
/// au lieu du générique « User not found ».
void main() {
  Future<void> pumpLogin(WidgetTester tester, FakeFirebaseFirestore db) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(db: db)));
    // pump fixe : le logo du login a une animation infinie (pas de
    // pumpAndSettle).
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tryLogin(WidgetTester tester, String phone) async {
    await tester.enterText(find.byType(TextField).at(0), phone);
    await tester.enterText(find.byType(TextField).at(1), 'whatever');
    await tester.tap(find.text('Log In'));
    await tester.pump(); // lance _handleAuth
    await tester.pump(const Duration(milliseconds: 500)); // requêtes async
    await tester.pump(const Duration(milliseconds: 500)); // snackbar slide-in
  }

  testWidgets(
    'login avec candidature EN ATTENTE → message clair (pas « User not found »)',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('registrations').doc('reg1').set({
        'id': 'reg1',
        'fullName': 'Carine Mbappe',
        'phone': '+237698224466',
        'status': 'pending',
        'agenceId': 'ag1',
        'agenceName': 'Douala — Bonanjo',
      });

      await pumpLogin(tester, db);
      await tryLogin(tester, '698 22 44 66');

      expect(find.textContaining('pending approval'), findsOneWidget);
      expect(find.textContaining('User not found'), findsNothing);
    },
  );

  testWidgets('login avec candidature REJETÉE → message dédié', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('registrations').doc('reg1').set({
      'id': 'reg1',
      'fullName': 'Carine Mbappe',
      'phone': '+237698224466',
      'status': 'rejected',
      'agenceId': 'ag1',
    });

    await pumpLogin(tester, db);
    await tryLogin(tester, '698 22 44 66');

    expect(find.textContaining('was rejected'), findsOneWidget);
  });

  testWidgets(
    'login sans compte ni candidature → « User not found » conservé',
    (tester) async {
      final db = FakeFirebaseFirestore();

      await pumpLogin(tester, db);
      await tryLogin(tester, '698 22 44 66');

      expect(
        find.text('User not found. Please sign up first.'),
        findsOneWidget,
      );
    },
  );
}
