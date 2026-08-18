import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/firestore_platform_store.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';
import 'package:waste_pro/features/superadmin/super_admin_console.dart';

import 'fakes/fake_auth_backend.dart';

/// Régression : « A FirestorePlatformStore was used after being disposed ».
///
/// Scénario réel qui déclenchait l'erreur :
///   1. Session super admin → la console est montée avec le store Firestore
///      PARTAGÉ (ConsoleStoreScope).
///   2. Logout en debug → le routeur reconstruit la console SANS store
///      (preview mock) avant de la démonter.
///   3. Au démontage, dispose() voyait widget.store == null et disposait le
///      store partagé qu'il n'avait PAS créé.
///   4. Au login suivant, le store disposé était réutilisé → l'erreur.
void main() {
  testWidgets(
      'le store Firestore partagé survit au démontage de la console et '
      'peut être réutilisé', (tester) async {
    final db = FakeFirebaseFirestore();
    final store = FirestorePlatformStore(
      db: db,
      backend: FakeAuthBackend(),
      seedIfEmpty: false,
      isSignedOut: () => false,
    );
    await store.initialLoad;

    // 1. Session réelle : console montée avec le store partagé.
    await tester.pumpWidget(
      MaterialApp(home: SuperAdminConsole(store: store)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 2. Logout en debug : le routeur reconstruit la console SANS store.
    await tester.pumpWidget(
      const MaterialApp(home: SuperAdminConsole()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3. Démontage complet (retour à l'écran d'accueil).
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 4. Le store partagé doit rester utilisable (pas « used after
    //    disposed ») et être réutilisable par le login suivant.
    expect(() => store.load(), returnsNormally);
    await store.initialLoad;
    expect(store.error, isNull);

    // Réutilisation effective par une nouvelle console.
    await tester.pumpWidget(
      MaterialApp(home: SuperAdminConsole(store: store)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    store.dispose();
  });

  testWidgets('la console ne dispose jamais un store injecté', (tester) async {
    // Un store fourni (même un mock) appartient à son créateur : le
    // démontage de la console ne doit pas le disposer (notifyListeners
    // leverait une erreur si c'était le cas).
    final injected = PlatformStore();
    await tester.pumpWidget(
      MaterialApp(home: SuperAdminConsole(store: injected)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();

    expect(() => injected.notifyListeners(), returnsNormally,
        reason: 'le store injecté doit rester utilisable après démontage');
  });
}
