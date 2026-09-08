import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/services/whatsapp_service.dart';

void main() {
  WhatsAppService makeService() => WhatsAppService(db: FakeFirebaseFirestore());

  group('WhatsAppService.isConfigured', () {
    test('returns false when env vars are not set', () {
      final service = makeService();
      expect(service.isConfigured, isFalse);
    });
  });

  group('WhatsApp message formatting', () {
    test('pickup reminder is callable when not configured', () async {
      final service = makeService();
      final result = await service.sendPickupReminder(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        date: '2026-08-28',
        time: '07:00',
      );
      expect(result, isFalse);
    });

    test('payment confirmation is callable', () async {
      final service = makeService();
      final result = await service.sendPaymentConfirmation(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        amount: 5500,
        plan: 'Weekly',
        txRef: 'TX-12345',
      );
      expect(result, isFalse);
    });

    test('subscription expiry is callable', () async {
      final service = makeService();
      final result = await service.sendSubscriptionExpiry(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        daysLeft: 3,
        expiryDate: '2026-09-01',
      );
      expect(result, isFalse);
    });

    test('missed collection is callable', () async {
      final service = makeService();
      final result = await service.sendMissedCollection(
        phone: '+237677123456',
        clientName: 'Jean Dooh',
        reason: 'Client absent',
      );
      expect(result, isFalse);
    });

    test('general message is callable', () async {
      final service = makeService();
      final result = await service.sendGeneral(
        phone: '+237677123456',
        message: 'Test message',
      );
      expect(result, isFalse);
    });

    test('free-form message is callable', () async {
      final service = makeService();
      final result = await service.sendFreeFormMessage(
        phone: '+237677123456',
        message: 'Hello from WastePro',
        type: 'general',
      );
      expect(result, isFalse);
    });
  });

  group('WhatsApp template listing', () {
    test('listTemplates returns empty when not configured', () async {
      final service = makeService();
      final templates = await service.listTemplates();
      expect(templates, isEmpty);
    });
  });
}
