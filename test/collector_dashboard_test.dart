import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:waste_pro/features/backoffice/models.dart';
import 'package:waste_pro/features/home/collector_dashboard.dart';
import 'package:waste_pro/features/home/data/collector_store.dart';
import 'package:waste_pro/features/backoffice/widgets/toast.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get user => _user;
}

/// Store mock : profil du collecteur + collectes (aujourd'hui + passé) +
/// clients assignés — simule le chargement Firestore.
class _MockCollectorStore extends CollectorStore {
  _MockCollectorStore() {
    setCollecteur(
      const CollecteurModel(
        id: 'co1',
        name: 'Paul Mbarga',
        phone: '+237678901122',
        zone: 'Bonanjo / Akwa',
        rating: 4.8,
        status: 'Active',
      ),
    );
    final today = CollectorStore.todayIso();
    final yesterday = _key(DateTime.now().subtract(const Duration(days: 1)));
    collectes.addAll([
      CollecteModel(
        id: 'c1',
        client: 'Jean Dooh',
        collecteur: 'Paul Mbarga',
        date: today,
        poids: 4.2,
        status: 'Completed',
        commentaire: 'Bac plein',
      ),
      CollecteModel(
        id: 'c2',
        client: 'Sarah Mbida',
        collecteur: 'Paul Mbarga',
        date: today,
        poids: 0,
        status: 'Scheduled',
      ),
      CollecteModel(
        id: 'c3',
        client: 'Marie Ekwalla',
        collecteur: 'Paul Mbarga',
        date: today,
        poids: 0,
        status: 'Scheduled',
      ),
      CollecteModel(
        id: 'c4',
        client: 'Robert Essomba',
        collecteur: 'Paul Mbarga',
        date: yesterday,
        poids: 3.8,
        status: 'Completed',
      ),
      CollecteModel(
        id: 'c5',
        client: 'Brice Talla',
        collecteur: 'Paul Mbarga',
        date: yesterday,
        poids: 0,
        status: 'Missed',
        motif: 'Client absent',
      ),
    ]);
    clients.addAll([
      const ClientModel(
        id: 'cl1',
        name: 'Jean Dooh',
        phone: '+237 677 12 34 56',
        zone: 'Bonanjo',
        plan: 'Standard',
        status: 'Active',
        collecteurId: 'co1',
      ),
      const ClientModel(
        id: 'cl2',
        name: 'Sarah Mbida',
        phone: '+237 691 77 04 22',
        zone: 'Bonanjo',
        plan: 'Essential',
        status: 'Active',
        collecteurId: 'co1',
      ),
      const ClientModel(
        id: 'cl3',
        name: 'Marie Ekwalla',
        phone: '+237 690 45 12 78',
        zone: 'Akwa',
        plan: 'Premium',
        status: 'Active',
        collecteurId: 'co1',
      ),
    ]);
  }

  static String _key(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

void main() {
  setUp(BoToastService.resetForTesting);

  Future<void> pumpCollector(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: FakeUserProvider(
          UserModel(
            phoneNumber: '+237678901122',
            fullName: 'Paul Mbarga',
            role: 'collector',
            password: 'pw',
          ),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CollectorDashboard(store: _MockCollectorStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mobile : topbar, progression réelle et tournée du jour', (
    tester,
  ) async {
    await pumpCollector(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Paul Mbarga'), findsWidgets);
    expect(find.text("Today's route"), findsOneWidget);
    // 1 terminée / 3 collectes aujourd'hui.
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Sarah Mbida'), findsOneWidget);
    // Zone du client issue de la fiche client réelle.
    expect(find.textContaining('Bonanjo'), findsWidgets);
    // Statuts réels : badge Done pour la collecte terminée (le chip filtre
    // porte aussi ce libellé → findsWidgets).
    expect(find.text('Done'), findsWidgets);
    // Filtres + tabs (anglais). « To do » porte le chip ET les badges des
    // 2 collectes Scheduled → findsWidgets.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('To do'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // Pas de cadre téléphone ni de simulation.
    expect(find.text('Simuler la lecture du QR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters the route by status', (tester) async {
    await pumpCollector(tester);

    // Le chip « To do » est le PREMIER texte « To do » dans l'arbre (les
    // badges des cartes viennent après) — et le seul dans la zone chips.
    await tester.tap(find.text('To do').first);
    await tester.pumpAndSettle();
    // Seules les collectes Scheduled restent (Sarah, Marie).
    expect(find.text('Sarah Mbida'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsNothing);

    await tester.tap(find.text('Done').first);
    await tester.pumpAndSettle();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Sarah Mbida'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Sarah Mbida'), findsOneWidget);
  });

  testWidgets('completes a scheduled collection with weight and note', (
    tester,
  ) async {
    final store = _MockCollectorStore();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: FakeUserProvider(
          UserModel(
            phoneNumber: '+237678901122',
            fullName: 'Paul Mbarga',
            role: 'collector',
            password: 'pw',
          ),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CollectorDashboard(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ouvrir Sarah Mbida (Scheduled).
    await tester.tap(find.text('Sarah Mbida'));
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Mark as missed'), findsOneWidget);

    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.text('Complete collection'), findsOneWidget);

    // Sans poids valide, on ne peut pas confirmer.
    await tester.tap(find.text('Confirm collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter a valid weight (kg)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cd_poids')), '3.5');
    await tester.enterText(find.byKey(const Key('cd_comment')), 'Bac à moitié plein');
    await tester.tap(find.text('Confirm collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Toast de succès visible (avant l'expiration du timer).
    expect(find.text('Collection completed — Sarah Mbida'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // expire le toast

    // La collecte est marquée Completed dans le store + UI mise à jour.
    final updated = store.collectes.firstWhere((c) => c.id == 'c2');
    expect(updated.status, 'Completed');
    expect(updated.poids, 3.5);
    expect(updated.commentaire, 'Bac à moitié plein');
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('marks a collection as missed with a reason', (tester) async {
    final store = _MockCollectorStore();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: FakeUserProvider(
          UserModel(
            phoneNumber: '+237678901122',
            fullName: 'Paul Mbarga',
            role: 'collector',
            password: 'pw',
          ),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CollectorDashboard(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marie Ekwalla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as missed').last);
    await tester.pumpAndSettle();
    expect(find.text('Mark as missed'), findsWidgets);

    // Sans motif, on ne peut pas confirmer.
    await tester.tap(find.text('Confirm').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Choose a reason'), findsOneWidget);

    await tester.tap(find.text('Client absent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Toast de confirmation visible (avant expiration du timer).
    expect(find.text('Collection marked as missed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    final updated = store.collectes.firstWhere((c) => c.id == 'c3');
    expect(updated.status, 'Missed');
    expect(updated.motif, 'Client absent');
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('history tab shows past collections grouped by day', (
    tester,
  ) async {
    await pumpCollector(tester);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // 2 jours dans l'historique (hier + aujourd'hui), avec les collectes.
    expect(find.text('Jean Dooh'), findsWidgets);
    expect(find.text('Robert Essomba'), findsOneWidget);
    expect(find.text('Brice Talla'), findsOneWidget);
    expect(find.text('Missed'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile tab shows real collector data', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Collector · Bonanjo / Akwa'), findsOneWidget);
    // Stats réelles : 2 collectes terminées au total (aujourd'hui + hier),
    // poids total 8.0 kg (4.2 + 3.8).
    expect(find.text('2'), findsOneWidget);
    expect(find.text('8.0 kg'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('+237678901122'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop : sidebar web-first + KPIs en ligne', (tester) async {
    await pumpCollector(tester, width: 1440, height: 900);

    // Sidebar desktop (marque + COLLECTOR APP + nav), pas de bottom tabs.
    expect(find.text('COLLECTOR APP'), findsOneWidget);
    expect(find.byKey(const Key('cd_tab_0')), findsNothing);
    // KPIs du dashboard en ligne (desktop).
    expect(find.text('Collections today'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Collected today'), findsOneWidget);
    expect(find.text('Success rate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop : compléter une collecte passe par un dialogue centré', (
    tester,
  ) async {
    await pumpCollector(tester, width: 1440, height: 900);

    await tester.tap(find.text('Sarah Mbida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    // Web-first : dialogue centré, pas de bottom sheet.
    expect(find.text('Complete collection'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
