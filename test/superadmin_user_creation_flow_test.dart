import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/firestore_platform_store.dart';
import 'package:waste_pro/features/superadmin/super_admin_console.dart';
import 'package:waste_pro/services/auth_service.dart';

/// Parcours de bout en bout : le superadmin crée un utilisateur dans la
/// console (store Firestore réel), le compte de connexion `users/{téléphone}`
/// est écrit avec le mot de passe fixé, et cet utilisateur parvient à se
/// connecter avec son numéro + mot de passe (AuthService, login Firestore
/// simple).
void main() {
  testWidgets(
      'superadmin crée un utilisateur via le drawer → il peut se connecter',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(
      db: db,
      seedIfEmpty: false,
      isSignedOut: () => false,
    );
    await store.initialLoad;

    // Console desktop avec le vrai store Firestore (comme après un login
    // super admin).
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SuperAdminConsole(store: store)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    // Aller sur la page Utilisateurs et ouvrir le drawer « New user ».
    // ("Users" apparaît aussi ailleurs : on cible le premier, la sidebar.)
    await tester.tap(find.text('Users').first);
    await tester.pumpAndSettle();
    expect(find.text('New user'), findsOneWidget);
    await tester.tap(find.text('New user'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);

    // Remplir le formulaire : nom, téléphone, mot de passe.
    await tester.enterText(find.byType(TextFormField).at(0), 'Marie Ekwalla');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '+237 699 99 99 99',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Aucune erreur pendant la création. Flush le timer du toast de succès.
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));

    // Le compte de connexion a bien été écrit dans `users` (rôle admin,
    // mot de passe en clair = celui fixé par le superadmin).
    final loginDoc = await db.collection('users').doc('+237699999999').get();
    expect(loginDoc.exists, isTrue,
        reason: 'la console doit créer le compte de connexion users/{phone}');
    expect(loginDoc.data()?['role'], 'admin');
    expect(loginDoc.data()?['password'], 'secret123');
    expect(loginDoc.data()?['fullName'], 'Marie Ekwalla');
    expect(loginDoc.data()?['consoleCreated'], isTrue);

    // L'utilisateur créé se connecte avec son numéro + le mot de passe fixé
    // par le superadmin.
    final auth = AuthService(db: db);
    final user = await auth.login('+237 699 99 99 99', 'secret123');
    expect(user, isNotNull,
        reason: 'l utilisateur créé par le superadmin doit pouvoir se '
            'connecter avec numéro + mot de passe');
    expect(user!.fullName, 'Marie Ekwalla');
    expect(user.role, 'admin');

    store.dispose();
  });

  testWidgets('un mauvais mot de passe est rejeté pour un user créé en console',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(
      db: db,
      seedIfEmpty: false,
      isSignedOut: () => false,
    );
    await store.initialLoad;

    // Création via la console (comme dans le parcours réel du superadmin).
    await store.addUtilisateur(
      nom: 'Jean Dooh',
      telephone: '+237 677 12 34 56',
      role: 'Agency Manager',
      agence: 'Douala — Bonanjo',
      status: 'Active',
      password: 'mdp-cons',
    );

    final auth = AuthService(db: db);
    expect(
      () => auth.login('+237677123456', 'mauvais'),
      throwsA('Incorrect Password'),
    );
    // Et le bon mot de passe fonctionne.
    final user = await auth.login('+237677123456', 'mdp-cons');
    expect(user, isNotNull);
    expect(user!.role, 'admin');

    store.dispose();
  });
}
