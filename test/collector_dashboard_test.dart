import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/collector_dashboard.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';

import 'helpers/setup_firebase.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get user => _user;
}

/// Seeds the fake Firestore with the test data expected by the collector
/// dashboard tests (8 clients, 2 completed, 1 missed, 5 to-do).
Future<FakeFirebaseFirestore> _seedFirestore() async {
  final db = FakeFirebaseFirestore();

  // Day names for collection_days matching.
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  final today = days[DateTime.now().weekday - 1];

  // 8 clients assigned to collector '+237678901122'.
  final clients = [
    ('c1', 'Jean Dooh', '+237699100001', true),
    ('c2', 'Brice Talla', '+237699100002', true),
    ('c3', 'Robert Essomba', '+237699100003', true),
    ('c4', 'Marie Ekwalla', '+237699100004', true),
    ('c5', 'Samuel Njoya', '+237699100005', true),
    ('c6', 'Carine Mbappe', '+237699100006', true),
    ('c7', 'Landry Fokou', '+237699100007', true),
    ('c8', 'Yolande Essomba', '+237699100008', true),
  ];
  const plan = 'Standard \u00b7 2x/week';

  for (final (id, name, phone, active) in clients) {
    await db.collection('clients').doc(id).set({
      'name': name,
      'phone': phone,
      'collecteurId': '+237678901122',
      'status': active ? 'Active' : 'Inactive',
      'plan': plan,
      'adresse': 'Bastos',
      'quartier': 'Nlongkak',
      'zone': 'Bastos',
    });
    // User doc with subscription + collection days.
    await db.collection('users').doc(phone).set({
      'phoneNumber': phone,
      'fullName': name,
      'role': 'client',
      'isSubscribed': true,
      'collection_days': [today],
      'pickup_time': '07:00 — 08:00',
      'zone_name': 'Bastos',
    });
  }

  // Jean Dooh: verified today (Done) — client has confirmed the pickup.
  final todayDate = DateTime.now().toIso8601String().substring(0, 10);
  final ts = DateTime.now();
  await db.collection('pickups').add({
    'client_id': '+237699100001',
    'collector_id': '+237678901122',
    'status': 'verified',
    'date': todayDate,
    'heure_arrivee': '07:15',
    'heure_depart': '07:30',
    'poids': 5.2,
    'commentaire': '',
    'timestamp': ts,
  });
  // Brice Talla: verified today (Done) — client has confirmed the pickup.
  await db.collection('pickups').add({
    'client_id': '+237699100002',
    'collector_id': '+237678901122',
    'status': 'verified',
    'date': todayDate,
    'heure_arrivee': '07:40',
    'heure_depart': '07:55',
    'poids': 3.1,
    'commentaire': '',
    'timestamp': ts,
  });

  // History: pickups from past days (verified).
  await db.collection('pickups').add({
    'client_id': '+237699100003',
    'collector_id': '+237678901122',
    'status': 'verified',
    'date': '2026-08-04',
    'heure_arrivee': '07:10',
    'heure_depart': '07:25',
    'poids': 4.0,
    'commentaire': '',
    'timestamp': ts.subtract(const Duration(days: 2)),
  });
  await db.collection('pickups').add({
    'client_id': '+237699100001',
    'collector_id': '+237678901122',
    'status': 'verified',
    'date': '2026-08-05',
    'heure_arrivee': '07:20',
    'heure_depart': '07:35',
    'poids': 6.0,
    'commentaire': '',
    'timestamp': ts.subtract(const Duration(days: 1)),
  });

  return db;
}

void main() {
  setUpAll(() => setupFirebaseMocks());

  late FakeFirebaseFirestore db;

  Future<void> pumpCollector(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    db = await _seedFirestore();

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
        child: MaterialApp(home: CollectorDashboard(db: db)),
      ),
    );
    // Let animations (scan line, ring) play without crashing.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('renders topbar, progress card and route list', (tester) async {
    await pumpCollector(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Paul Mbarga'), findsWidgets);
    expect(find.text("Today's Route"), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget); // 2 Done / 8 clients
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Brice Talla'), findsOneWidget);
    expect(find.text('Missed'), findsWidgets);
    // Filters
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Done'), findsWidgets);
    // Tab bar
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('filters the route by status', (tester) async {
    await pumpCollector(tester);

    // Filter chips scroll horizontally: use first matching widget.
    // (No pumpAndSettle: the QR scan line animates in a loop.)
    // 'Done' text appears on both filter chip and status badges,
    // so we tap the first occurrence (the filter chip).
    await tester.tap(find.text('Done').first);
    await tester.pump();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Brice Talla'), findsOneWidget);

    await tester.tap(find.text('To Do').first);
    await tester.pump();
    expect(find.text('Robert Essomba'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsNothing);

    await tester.tap(find.text('All').first);
    await tester.pump();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Brice Talla'), findsOneWidget);
  });

  testWidgets('opens client detail sheet from route', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Detail sheet: actions + primary button.
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Start Route'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Start Collection'), findsOneWidget);
    expect(find.text('Standard · 2x/week'), findsOneWidget);
  });

  testWidgets('completes the 3-step collection flow and shows toast',
      (tester) async {
    await pumpCollector(tester);

    // Open client "Robert Essomba" (To Do).
    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Step 1: QR.
    await tester.tap(find.text('Start Collection'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Verify Your Presence'), findsOneWidget);
    // Next button is disabled until QR is validated: tapping it won't advance.
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Verify Your Presence'), findsOneWidget);
    expect(find.text('Take a Photo'), findsNothing);

    await tester.tap(find.text('Simulate QR Scan'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('QR code validated.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));

    // Step 2: photo.
    expect(find.text('Take a Photo'), findsOneWidget);
    await tester.tap(find.text('Tap to take photo'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));

    // Step 3: weight + comment.
    expect(find.text('Collection Details'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '4.5');
    await tester.tap(find.text('Validate &\nConfirm').first);
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet closed + toast + progress updated (but status stays In Progress
    // until client confirms).
    expect(find.text('Collection sent for client confirmation — Robert Essomba'), findsOneWidget);
  });

  testWidgets('QR step offers the real camera scanner next to the simulate '
      'fallback', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Start Collection'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Verify Your Presence'), findsOneWidget);

    // Real scan entry point + demo fallback are both present.
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('Simulate QR Scan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks a client as missed with a reason', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Report'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Report a Problem'), findsOneWidget);

    // Confirm is disabled until a reason is selected.
    await tester.tap(find.text('Client absent'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Collection marked as missed.'),
      findsOneWidget,
    );
    // Counter stays 2/8, Robert Essomba is now Missed.
    expect(find.text('2/8'), findsOneWidget);
  });

  testWidgets('switches to history and profile tabs', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('History'));
    await tester.pump();
    expect(find.textContaining('August'), findsWidgets);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(find.text('Collector · Bastos / Nlongkak Zone'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('+237678901122'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
  });
}
