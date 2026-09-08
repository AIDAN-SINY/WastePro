import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waste_pro/services/campay_service.dart';

void main() {
  group('CampayService.initCollect', () {
    test('sends the request and parses the reference + USSD code', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/collect/');
        expect(request.headers['Authorization'], 'Token test-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], '3000');
        expect(body['currency'], 'XAF');
        expect(body['from'], '237690000000');
        expect(body['external_reference'], 'WP-123');
        return http.Response(
          jsonEncode({
            'reference': 'bcedde9b-62a7-4421-96ac-2e6179552a1a',
            'ussd_code': '*126#',
            'operator': 'MTN',
          }),
          200,
        );
      });

      final service = CampayService(token: 'test-token', client: client);
      final result = await service.initCollect(
        amount: 3000,
        currency: 'XAF',
        from: '237690000000',
        description: 'WastePro Monthly subscription',
        externalReference: 'WP-123',
      );

      expect(result.reference, 'bcedde9b-62a7-4421-96ac-2e6179552a1a');
      expect(result.ussdCode, '*126#');
      expect(result.operator, 'MTN');
    });

    test('throws CampayException when CamPay rejects (actionable message)',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'ER102 Unsupported Carrier phone number'}),
          400,
        );
      });

      final service = CampayService(token: 'test-token', client: client);
      await expectLater(
        service.initCollect(
          amount: 100,
          currency: 'XAF',
          from: '23712345678',
          description: 'test',
          externalReference: 'WP-1',
        ),
        throwsA(
          isA<CampayException>().having(
            (e) => e.message,
            'message',
            contains('ER102'),
          ),
        ),
      );
    });

    test('throws if no token is configured', () async {
      final service = CampayService(token: '', client: MockClient((_) async {
        return http.Response('{}', 200);
      }));
      expect(service.isConfigured, isFalse);
      await expectLater(
        service.initCollect(
          amount: 100,
          currency: 'XAF',
          from: '237690000000',
          description: 'test',
          externalReference: 'WP-1',
        ),
        throwsA(isA<CampayException>()),
      );
    });
  });

  group('CampayService.getTransactionStatus', () {
    test('parse un statut SUCCESSFUL', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/transaction/ref-1/');
        return http.Response(
          jsonEncode({
            'reference': 'ref-1',
            'status': 'SUCCESSFUL',
            'amount': 3000,
            'currency': 'XAF',
            'operator': 'MTN',
            'code': 'CP201027T00005',
            'operator_reference': '1880106956',
          }),
          200,
        );
      });

      final service = CampayService(token: 'test-token', client: client);
      final status = await service.getTransactionStatus('ref-1');

      expect(status.isSuccessful, isTrue);
      expect(status.isPending, isFalse);
      expect(status.amount, 3000);
      expect(status.operator, 'MTN');
      expect(status.code, 'CP201027T00005');
    });

    test('distinguishes PENDING / FAILED', () async {
      final pending = CampayService(
        token: 't',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'reference': 'r', 'status': 'PENDING'}),
            200,
          ),
        ),
      );
      final failed = CampayService(
        token: 't',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'reference': 'r', 'status': 'FAILED'}),
            200,
          ),
        ),
      );

      expect((await pending.getTransactionStatus('r')).isPending, isTrue);
      expect((await failed.getTransactionStatus('r')).isFailed, isTrue);
    });
  });

  group('CampayService helpers', () {
    test('normalizePhone strips + and spaces', () {
      expect(CampayService.normalizePhone('+237 690 000 000'), '237690000000');
      expect(CampayService.normalizePhone('+237-690-000-000'), '237690000000');
      expect(CampayService.normalizePhone('+237690000000'), '237690000000');
    });

    test('newExternalReference generates a unique reference with prefix', () {
      final a = CampayService.newExternalReference('WP');
      final b = CampayService.newExternalReference('WP');
      expect(a, startsWith('WP-'));
      expect(a, isNot(b));
    });

    test('isConfigured reflects the presence of the token', () {
      expect(CampayService(token: '').isConfigured, isFalse);
      expect(CampayService(token: 'abc').isConfigured, isTrue);
    });
  });
}
