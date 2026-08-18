import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/client_dashboard.dart';
import 'package:waste_pro/features/home/notifications_screen.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/navigation_provider.dart';
import 'package:waste_pro/providers/user_provider.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get user => _user;
}

void main() {
  Widget wrap(UserProvider provider, FakeFirebaseFirestore db) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(home: ClientDashboard(db: db)),
    );
  }

  FakeUserProvider clientProvider() => FakeUserProvider(
    UserModel(
      phoneNumber: '+237699999999',
      fullName: 'Test Client',
      role: 'client',
      password: 'pw',
    ),
  );

  Future<void> pumpDashboard(
    WidgetTester tester,
    FakeFirebaseFirestore db,
  ) async {
    await tester.pumpWidget(wrap(clientProvider(), db));
    // Laisse les animations (logo/progress) se jouer.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('client dashboard bottom nav does not overflow', (tester) async {
    // Taille téléphone + barre de navigation système simulée en bas.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);

    await pumpDashboard(tester, FakeFirebaseFirestore());

    // Un « bottom overflow » déclencherait une FlutterError ici.
    expect(tester.takeException(), isNull);

    // La navbar est bien rendue avec ses 4 onglets.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('la cloche affiche un badge quand il y a des non-lues', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('notifications').doc('notif1').set({
      'id': 'notif1',
      'phone': '+237699999999',
      'type': 'approved',
      'title': 'Application approved',
      'message': 'Welcome!',
      'read': false,
      'createdAt': '2026-08-11',
    });
    await db.collection('notifications').doc('notif2').set({
      'id': 'notif2',
      'phone': '+237699999999',
      'type': 'approved',
      'title': 'Another',
      'message': 'Hello again!',
      'read': true,
      'createdAt': '2026-08-10',
    });

    await pumpDashboard(tester, db);

    // Seule la notification non lue compte → badge « 1 ».
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('pas de notifications → pas de badge', (tester) async {
    await pumpDashboard(tester, FakeFirebaseFirestore());

    expect(find.text('1'), findsNothing);
    expect(find.text('9+'), findsNothing);
  });

  testWidgets('le collecteur assigné est affiché sur le dashboard client', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('collecteurs').doc('co1').set({
      'id': 'co1',
      'name': 'Vincent Onana',
      'phone': '+237 693 55 44 33',
      'zone': 'etoudi',
      'rating': 4.5,
      'status': 'Actif',
    });
    final provider = FakeUserProvider(
      UserModel(
        phoneNumber: '+237699999999',
        fullName: 'Test Client',
        role: 'client',
        password: 'pw',
        collecteurId: 'co1',
      ),
    );

    await tester.pumpWidget(wrap(provider, db));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // Le nom du collecteur assigné (et sa note) remplacent le mock.
    expect(find.text('Vincent Onana'), findsOneWidget);
    expect(find.textContaining('4.5'), findsOneWidget);
  });

  testWidgets('pas de collecteur assigné → message dédié', (tester) async {
    await pumpDashboard(tester, FakeFirebaseFirestore());

    expect(find.text('No collector assigned yet'), findsOneWidget);
  });

  testWidgets('le tap sur la cloche ouvre l écran Notifications', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('notifications').doc('notif1').set({
      'id': 'notif1',
      'phone': '+237699999999',
      'type': 'rejected',
      'title': 'Application rejected',
      'message': 'You can re-apply.',
      'read': false,
      'createdAt': '2026-08-11',
    });

    await pumpDashboard(tester, db);

    await tester.tap(find.byIcon(Icons.notifications_none_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Application rejected'), findsOneWidget);
  });
}
