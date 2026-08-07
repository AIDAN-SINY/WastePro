import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waste_pro/features/backoffice/backoffice_screen.dart';
import 'package:waste_pro/features/backoffice/data/backoffice_store.dart';
import 'package:waste_pro/features/backoffice/widgets/chips.dart';
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
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Active clients'), findsOneWidget);
    expect(find.text("Today's collections"), findsOneWidget);
    expect(find.text('Revenue (thousands)'), findsOneWidget);
    expect(find.text('Success rate'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.textContaining('Pickup completed'), findsOneWidget);
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
    expect(find.text('New client'), findsOneWidget);

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
    expect(find.text('New client'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('bo_f_name')), 'Jean Sans MDP');
    await tester.tap(find.byKey(const Key('bo_sheet_save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // The sheet stays open and no client is created.
    expect(find.text('New client'), findsOneWidget);
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

    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Delete'));
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

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit client'), findsOneWidget);

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
    expect(find.text('Billing'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bo_menu_facturation')));
    await tester.pumpAndSettle();

    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.textContaining('due '), findsWidgets);
    expect(find.text('Billing'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter chips narrow the client list', (tester) async {
    await pumpBackoffice(tester, BackofficeStore());

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    // Only suspended clients remain after filtering. The chip label is
    // 'Suspended' — the same text as the badges on the cards, so target the
    // chip row explicitly.
    await tester.tap(
      find.descendant(
        of: find.byType(BoChipRow),
        matching: find.text('Suspended'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Samuel Njoya'), findsOneWidget);
    expect(find.text('Éric Tchoua'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
