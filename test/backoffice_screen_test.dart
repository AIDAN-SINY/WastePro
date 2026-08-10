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
    // La carte affiche aussi le collecteur assigné au client.
    expect(find.text('Bonanjo · Standard · Paul Mbarga'), findsOneWidget);
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

  testWidgets('desktop : sidebar web-first + navigation sans drawer', (
    tester,
  ) async {
    // Large écran → layout desktop (web-first) : sidebar fixe à gauche,
    // pas de tab bar mobile ni de menu hamburger.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeScreen(store: BackofficeStore()),
      ),
    );
    await tester.pumpAndSettle();

    // Sidebar desktop (brand + entrées) visible ; pas de tab bar mobile.
    expect(find.text('AGENCY BACKOFFICE'), findsOneWidget);
    expect(find.byKey(const Key('bo_tab_dashboard')), findsNothing);
    expect(find.byKey(const Key('bo_menu')), findsNothing);

    // Navigation via la sidebar : cliquer Clients affiche la liste.
    await tester.tap(find.text('Clients').first);
    await tester.pumpAndSettle();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Bonanjo · Standard · Paul Mbarga'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Bouton d'action web-first visible (remplace le FAB mobile) et toggle
    // de recherche desktop présent (page listable).
    expect(find.text('New client'), findsOneWidget);
    expect(find.byKey(const Key('bo_fab')), findsNothing);
    expect(find.byKey(const Key('bo_bo_search_toggle')), findsOneWidget);
  });

  testWidgets('desktop : le dashboard affiche les KPIs en ligne', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeScreen(store: BackofficeStore()),
      ),
    );
    await tester.pumpAndSettle();

    // KPIs du dashboard présents (page d'accueil par défaut).
    expect(find.text('Active clients'), findsOneWidget);
    expect(find.text("Today's collections"), findsOneWidget);
    expect(find.text('Revenue (thousands)'), findsOneWidget);
    expect(find.text('Success rate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop : le review d\'application est un dialogue centré', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeScreen(store: BackofficeStore()),
      ),
    );
    await tester.pumpAndSettle();

    // Aller sur la page Applications via la sidebar.
    await tester.tap(find.text('Applications').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();

    // Web-first : dialogue centré (Dialog), pas de bottom sheet.
    expect(find.text('Review application'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);

    // Ferme le dialogue en tapant sur la barrière (hors de la boîte).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('desktop : la sidebar affiche le nom de l\'agence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _NamedBackofficeStore('Douala — Bonanjo');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // Nom de l'agence dans le footer de la sidebar (desktop).
    expect(find.text('Douala — Bonanjo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile : le review d\'application reste une bottom sheet', (
    tester,
  ) async {
    // Petit écran → bottom sheet (pas de dialogue centré).
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeScreen(store: BackofficeStore()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_menu_applications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();

    expect(find.text('Review application'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows the pending applications section', (
    tester,
  ) async {
    await pumpBackoffice(tester, BackofficeStore());

    // Titre de section + en-tête de la carte (le menu latéral porte un
    // libellé « Applications », distinct).
    expect(find.text('Pending applications'), findsWidgets);
    expect(find.text('2 to review'), findsOneWidget);
    expect(find.text('Carine Mbappe'), findsOneWidget);
    expect(find.text('Landry Fokou'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applications page lists the applications', (tester) async {
    await pumpBackoffice(tester, BackofficeStore());

    await tester.tap(find.byKey(const Key('bo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_menu_applications')));
    await tester.pumpAndSettle();

    // Les 3 candidatures (2 pending + 1 approved) sont listées.
    expect(find.text('Carine Mbappe'), findsOneWidget);
    expect(find.text('Landry Fokou'), findsOneWidget);
    expect(find.text('Yolande Essomba'), findsOneWidget);
    // Seules les candidatures en attente ont un bouton Review.
    expect(find.text('Review'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('review flow approves an application and assigns a collector', (
    tester,
  ) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_menu_applications')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Review application'), findsOneWidget);

    // Choisir un collecteur actif puis approuver.
    await tester.tap(find.byKey(const Key('bo_review_collector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paul Mbarga · ★ 4.8').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_review_approve')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3)); // toast timer

    // La candidature est approuvée avec le collecteur assigné…
    expect(store.pendingRegistrations.length, 1);
    final approved = store.registrations.firstWhere(
      (r) => r.fullName == 'Carine Mbappe',
    );
    expect(approved.status, 'approved');
    expect(approved.collecteurId, 'co1');
    // … et le client a été créé (un collecteur peut avoir plusieurs clients).
    final client = store.clients.firstWhere((c) => c.name == 'Carine Mbappe');
    expect(client.collecteurId, 'co1');
    expect(client.status, 'Active');
    expect(tester.takeException(), isNull);
  });

  testWidgets('review flow can reject an application', (tester) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_menu_applications')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_review_reject')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    final rejected = store.registrations.firstWhere(
      (r) => r.fullName == 'Carine Mbappe',
    );
    expect(rejected.status, 'rejected');
    expect(store.pendingRegistrations.length, 1);
    expect(store.clients.any((c) => c.name == 'Carine Mbappe'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reassign collector from the client card', (tester) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    // Kebab de Jean Dooh → action « Reassign collector ».
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
    await tester.tap(find.text('Reassign collector'));
    await tester.pumpAndSettle();
    expect(find.text('Reassign collector'), findsWidgets);

    // Choisir Vincent Onana puis confirmer.
    await tester.tap(find.byKey(const Key('bo_reassign_collector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincent Onana · ★ 4.5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo_reassign_confirm')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3)); // toast timer

    // La fiche client porte le nouveau collecteur.
    final client = store.clients.firstWhere((c) => c.name == 'Jean Dooh');
    expect(client.collecteurId, 'co2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reassign sheet refuses without a chosen collector', (
    tester,
  ) async {
    final store = BackofficeStore();
    await pumpBackoffice(tester, store);

    await tester.tap(find.byKey(const Key('bo_tab_clients')));
    await tester.pumpAndSettle();

    // Samuel Njoya (suspendu) n'a pas de collecteur assigné : le champ est
    // vide par défaut, confirmer sans choisir est refusé.
    final card = find.ancestor(
      of: find.text('Samuel Njoya'),
      matching: find.byType(BoItemCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.more_horiz_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reassign collector'));
    await tester.pumpAndSettle();
    expect(find.text('Reassign collector'), findsWidgets);

    await tester.tap(find.byKey(const Key('bo_reassign_confirm')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // La feuille reste ouverte, aucune réassignation.
    expect(find.text('Reassign collector'), findsWidgets);
    expect(
      store.clients.firstWhere((c) => c.name == 'Samuel Njoya').collecteurId,
      '',
    );
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

/// Store mock avec un nom d'agence pré-rempli (simule le store Firestore
/// scopé qui charge `agences/{agenceId}`).
class _NamedBackofficeStore extends BackofficeStore {
  _NamedBackofficeStore(String agenceName) {
    setAgenceName(agenceName);
  }
}
