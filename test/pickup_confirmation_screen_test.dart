import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waste_pro/features/home/pickup_confirmation_screen.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';

import 'helpers/setup_firebase.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get user => _user;
}

void main() {
  setUpAll(() => setupFirebaseMocks());

  const clientPhone = '+237699000001';
  const collectorId = '+237600000001';
  const pickupId = 'PKP-TEST-1';
  const collectorName = 'Paul Mbarga';

  Future<FakeFirebaseFirestore> seedPendingPickup() async {
    final db = FakeFirebaseFirestore();
    await db.collection('pickups').doc(pickupId).set({
      'pickup_id': pickupId,
      'client_id': clientPhone,
      'collector_id': collectorId,
      'collector_name': collectorName,
      'date': '2026-08-18',
      'heure_arrivee': '07:15',
      'heure_depart': '07:30',
      'poids': 4.5,
      'commentaire': 'Bin was at the gate',
      'status': 'pending_client_confirmation',
      'timestamp': DateTime(2026, 8, 18, 7, 30),
    });
    return db;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeFirebaseFirestore db, {
    String? overridePickupId,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = FakeUserProvider(
      UserModel(
        phoneNumber: clientPhone,
        fullName: 'Alice Njoya',
        role: 'client',
        password: 'pw',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: provider,
        child: MaterialApp(
          home: PickupConfirmationScreen(
            db: db,
            pickupId: overridePickupId ?? pickupId,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the pickup info, the QR code and the two actions',
      (tester) async {
    final db = await seedPendingPickup();
    await pumpScreen(tester, db);

    expect(tester.takeException(), isNull);
    // AppBar + panel headings.
    expect(find.text('Validate Pickup'), findsOneWidget);
    expect(find.text(collectorName), findsOneWidget);
    expect(find.text('4.5 kg'), findsOneWidget);
    expect(find.text('Did this pickup really happen?'), findsOneWidget);
    // The QR code containing the pickup info is rendered.
    expect(find.byType(QrImageView), findsOneWidget);
    // The two actions requested: scan OR the pickup didn't occur.
    expect(find.text('Scan code'), findsOneWidget);
    expect(find.text("The pickup didn't occur"), findsOneWidget);
  });

  Future<void> tapVisible(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  testWidgets(
      'tapping “Scan code” animates a scan line then validates with a tick '
      'and notifies the collector', (tester) async {
    final db = await seedPendingPickup();
    await pumpScreen(tester, db);

    await tapVisible(tester, 'Scan code');
    await tester.pump();
    // Scanning state: animated green line + status text.
    expect(find.text('Scanning the QR code…'), findsOneWidget);
    expect(find.text('Scan code'), findsNothing);

    // Let the scan animation run to completion (2600 ms) + async work.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Scanning the QR code…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 100));

    // Tick displayed + Done action.
    expect(find.text('Pickup validated'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Scan code'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The collector received the “Pickup validated from client …” push.
    final pushes = await db.collection('push_notifications').get();
    final collectorPush = pushes.docs.where((d) {
      final data = d.data();
      final payload = data['data'] as Map<String, dynamic>? ?? const {};
      return data['to'] == collectorId &&
          payload['type'] == 'pickup_validated';
    });
    expect(collectorPush.length, 1);
    expect(
      collectorPush.first.data()['title'],
      'Pickup validated from client Alice Njoya ',
    );
    final collectorPayload =
        collectorPush.first.data()['data'] as Map<String, dynamic>;
    expect(collectorPayload['pickupId'], pickupId);

    // The client also received a confirmation push.
    final clientPush = pushes.docs.where((d) {
      final data = d.data();
      final payload = data['data'] as Map<String, dynamic>? ?? const {};
      return data['to'] == clientPhone &&
          payload['type'] == 'pickup_confirmed';
    });
    expect(clientPush.length, 1);

    // The pickup itself is now verified (source of truth for the agency
    // backoffice + the collector tour).
    final pickup = await db.collection('pickups').doc(pickupId).get();
    expect(pickup.data()?['status'], 'verified');
  });

  testWidgets("the pickup can be disputed with “The pickup didn't occur”",
      (tester) async {
    final db = await seedPendingPickup();
    await pumpScreen(tester, db);

    await tapVisible(tester, "The pickup didn't occur");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dispute reason selector appears.
    expect(find.text('Why are you disputing this pickup?'), findsOneWidget);
    await tester.tap(find.text('Did not happen'));
    await tester.pump();
    await tester.tap(find.text('Report issue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Submission confirmed in a dialog.
    expect(
      find.text('Your report has been submitted. The agency will review it.'),
      findsOneWidget,
    );

    // The client gets a dispute confirmation push.
    final pushes = await db.collection('push_notifications').get();
    final disputePush = pushes.docs.where((d) {
      final data = d.data();
      final payload = data['data'] as Map<String, dynamic>? ?? const {};
      return data['to'] == clientPhone &&
          payload['type'] == 'pickup_disputed';
    });
    expect(disputePush.length, 1);
  });
}
