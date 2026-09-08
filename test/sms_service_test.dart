import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/services/sms_service.dart';

void main() {
  SmsService makeService() => SmsService(db: FakeFirebaseFirestore());

  group('SmsService.isConfigured', () {
    test('returns false when env vars are not set', () {
      final service = makeService();
      expect(service.isConfigured, isFalse);
    });
  });

  group('SmsService methods', () {
    test('sendSms returns false when not configured', () async {
      final service = makeService();
      final result = await service.sendSms(
        phone: '+237677123456',
        message: 'Test message',
        type: 'test',
      );
      expect(result, isFalse);
    });

    test('all notification methods are callable when not configured', () async {
      final service = makeService();

      final pickup = await service.sendPickupReminder(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        date: '2026-08-28',
        time: '07:00',
      );
      expect(pickup, isFalse);

      final payment = await service.sendPaymentConfirmation(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        amount: 5500,
        plan: 'Weekly',
      );
      expect(payment, isFalse);

      final expiry = await service.sendSubscriptionExpiry(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        daysLeft: 3,
      );
      expect(expiry, isFalse);

      final missed = await service.sendMissedCollection(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        reason: 'Client absent',
      );
      expect(missed, isFalse);

      final general = await service.sendGeneral(
        phone: '+237677123456',
        message: 'Test',
      );
      expect(general, isFalse);
    });
  });
}
