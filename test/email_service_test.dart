import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/services/email_service.dart';

void main() {
  EmailService makeService() => EmailService(db: FakeFirebaseFirestore());

  group('EmailService.isConfigured', () {
    test('returns false when env vars are not set', () {
      final service = makeService();
      expect(service.isConfigured, isFalse);
    });
  });

  group('EmailService methods', () {
    test('sendPickupReminder returns false when not configured', () async {
      final service = makeService();
      final result = await service.sendPickupReminder(
        email: 'test@example.com',
        clientName: 'Jean Dooh',
        date: '2026-08-28',
        time: '07:00',
      );
      expect(result, isFalse);
    });

    test('sendPaymentConfirmation returns false when not configured', () async {
      final service = makeService();
      final result = await service.sendPaymentConfirmation(
        email: 'test@example.com',
        clientName: 'Jean Dooh',
        amount: 5500,
        plan: 'Weekly',
        txRef: 'TX-12345',
      );
      expect(result, isFalse);
    });

    test('sendSubscriptionExpiry returns false when not configured', () async {
      final service = makeService();
      final result = await service.sendSubscriptionExpiry(
        email: 'test@example.com',
        clientName: 'Jean Dooh',
        daysLeft: 3,
        expiryDate: '2026-09-01',
      );
      expect(result, isFalse);
    });

    test('sendGeneral returns false when not configured', () async {
      final service = makeService();
      final result = await service.sendGeneral(
        email: 'test@example.com',
        subject: 'Test',
        message: 'Hello from WastePro',
      );
      expect(result, isFalse);
    });

    test('sendReport returns false when not configured', () async {
      final service = makeService();
      final result = await service.sendReport(
        email: 'test@example.com',
        recipientName: 'Admin',
        reportTitle: 'Monthly Report',
        period: 'August 2026',
      );
      expect(result, isFalse);
    });
  });
}
