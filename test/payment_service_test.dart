import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/services/campay_service.dart';
import 'package:waste_pro/services/payment_service.dart';

void main() {
  group('PaymentService', () {
    test('recordTransaction écrit la transaction dans Firestore', () async {
      final db = FakeFirebaseFirestore();
      final service = PaymentService(db: db);

      await service.recordTransaction(
        phone: '+237690000000',
        amount: 3000,
        currency: 'XAF',
        type: 'subscription',
        title: 'Monthly plan',
        result: const PaymentResult(
          success: true,
          status: 'successful',
          txRef: 'WP-123',
          transactionId: 'bcedde9b-62a7-4421-96ac-2e6179552a1a',
        ),
      );

      final doc = await db.collection('transactions').doc('WP-123').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['phone'], '+237690000000');
      expect(data['amount'], 3000);
      expect(data['currency'], 'XAF');
      expect(data['type'], 'subscription');
      expect(data['description'], 'Monthly plan');
      expect(data['status'], 'successful');
      expect(data['transactionId'], 'bcedde9b-62a7-4421-96ac-2e6179552a1a');
      expect(data['paymentMethod'], 'campay');
    });

    test('recordTransaction accepte un paiement échoué', () async {
      final db = FakeFirebaseFirestore();
      final service = PaymentService(db: db);

      await service.recordTransaction(
        phone: '+237690000000',
        amount: 1000,
        currency: 'XAF',
        type: 'pickup',
        title: 'Extra pickup',
        result: const PaymentResult(
          success: false,
          status: 'cancelled',
          txRef: 'PICKUP-1',
        ),
      );

      final doc = await db.collection('transactions').doc('PICKUP-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['status'], 'cancelled');
    });

    test('en mode démo, le montant est plafonné à 25 XAF', () async {
      final db = FakeFirebaseFirestore();
      // Jeton configuré → charge() va jusqu'à l'initiation CamPay.
      final service = PaymentService(
        db: db,
        campay: CampayService(token: 'demo'),
      );

      // Le plafond démo (25 XAF) s'applique au montant facturé.
      expect(service.demoChargeableAmount(3000), 25);
      expect(service.demoChargeableAmount(25), 25);
      expect(service.demoChargeableAmount(10), 10);
    });

    test('isConfigured reflète le jeton CamPay', () {
      final db = FakeFirebaseFirestore();
      expect(
        PaymentService(db: db, campay: CampayService(token: '')).isConfigured,
        isFalse,
      );
      expect(
        PaymentService(db: db, campay: CampayService(token: 'abc')).isConfigured,
        isTrue,
      );
    });

    testWidgets('charge lève si CamPay n est pas configuré', (tester) async {
      final service = PaymentService(
        db: FakeFirebaseFirestore(),
        campay: CampayService(token: ''),
      );
      expect(service.isConfigured, isFalse);

      // Contexte réel : la garde lève AVANT toute navigation, donc le
      // contexte n'est jamais utilisé.
      BuildContext? ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      await expectLater(
        service.charge(
          context: ctx!,
          amount: 3000,
          currency: 'XAF',
          email: 'a@b.cm',
          phone: '+237690000000',
          name: 'Test',
          title: 'Monthly plan',
          type: 'subscription',
        ),
        throwsA(isA<String>()),
      );
    });
  });
}
