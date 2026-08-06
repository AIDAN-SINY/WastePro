import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waste_pro/features/backoffice/backoffice_screen.dart';
import 'package:waste_pro/features/backoffice/data/backoffice_store.dart';
import 'package:waste_pro/features/backoffice/widgets/item_card.dart';
import 'package:waste_pro/features/backoffice/widgets/toast.dart';

void main() {
  setUp(BoToastService.resetForTesting);

  Future<void> pumpBackoffice(
    WidgetTester tester,
    BackofficeStore store,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard renders KPIs and charts without overflow', (
    tester,
  ) async {
    await pumpBackoffice(tester, BackofficeStore());

    // Also present in the (off-screen) side menu, hence findsWidgets.
    expect(find.text("Vue d'ensemble"), findsWidgets);
    expect(find.text('Clients actifs'), findsOneWidget);
    expect(find.text("Collectes aujourd'hui"), findsOneWidget);
    expect(find.text('Revenus (milliers)'), findsOneWidget);
    expect(find.text('Taux de réussite'), findsOneWidget);
    expect(find.text('Activité récente'), findsOneWidget);
    expect(find.textContaining('Ramassage effectué'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clients list renders seed data', (tester) async {
    await pumpBackoffice(tester, BackofficeStore());

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Marie Ekwalla'), findsOneWidget);
    expect(find.text('Bonanjo · Standard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create client via FAB persists in the store', (tester) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bo_fab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau client'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('bo_f_name')), 'Jean Test');
    // Le mot de passe est requis à la création (il permet au client de se
    // connecter à son application).
    await tester.enterText(find.byKey(const Key('bo_f_password')), 'secret123');
    await tester.tap(find.byKey(const Key('bo_sheet_save')));
    await tester.pumpAndSettle();

    // Toast timer must expire before the test ends.
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Jean Test'), findsOneWidget);
    expect(store.clients.any((c) => c.name == 'Jean Test'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a client without a password shows a warning', (
    tester,
  ) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bo_fab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau client'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('bo_f_name')), 'Jean Sans MDP');
    await tester.tap(find.byKey(const Key('bo_sheet_save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // La feuille reste ouverte et aucun client n'est créé.
    expect(find.text('Nouveau client'), findsOneWidget);
    expect(store.clients.any((c) => c.name == 'Jean Sans MDP'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete client through the action sheet', (tester) async {
    final store = BackofficeStore();
    final before = store.clients.length;
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    // Tap the kebab of Jean Dooh's card.
    final card = find.ancestor(
      of: find.text('Jean Dooh'),
      matching: find.byType(BoItemCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.more_horiz_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Jean Dooh'), findsNothing);
    expect(store.clients.length, before - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit client via kebab -> action sheet -> form sheet', (
    tester,
  ) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Jean Dooh'),
      matching: find.byType(BoItemCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.more_horiz_rounded),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier client'), findsOneWidget);

    // The form is prefilled with the client's name.
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('bo_f_name')),
    );
    expect(nameField.controller!.text, 'Jean Dooh');

    await tester.enterText(find.byKey(const Key('bo_f_name')), 'Jean Dooh Jr');
    await tester.tap(find.byKey(const Key('bo_sheet_save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Jean Dooh Jr'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsNothing);
    expect(store.clients.any((c) => c.name == 'Jean Dooh Jr'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('side menu navigates to facturation', (tester) async {
    await pumpBackoffice(tester, BackofficeStore());

    await tester.tap(find.byKey(const Key('bo_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Facturation'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bo_menu_facturation')));
    await tester.pumpAndSettle();

    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.textContaining('éch. '), findsWidgets);
    expect(find.text('Facturation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter chips narrow the client list', (tester) async {
    await pumpBackoffice(tester, BackofficeStore());

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    // Only suspended clients remain after filtering.
    await tester.tap(find.text('Suspendus'));
    await tester.pumpAndSettle();

    expect(find.text('Samuel Njoya'), findsOneWidget);
    expect(find.text('Éric Tchoua'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
