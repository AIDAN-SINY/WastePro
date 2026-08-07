import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/services/auth_service.dart';

void main() {
  group('AuthService.canonicalPhone', () {
    test('normalise les numéros saisis librement', () {
      expect(AuthService.canonicalPhone('677123456'), '+237677123456');
      expect(AuthService.canonicalPhone('237677123456'), '+237677123456');
      expect(AuthService.canonicalPhone('+237 677 12 34 56'), '+237677123456');
      expect(AuthService.canonicalPhone(' +2376-77-12-34-56 '), '+237677123456');
      expect(AuthService.canonicalPhone('+237677123456'), '+237677123456');
    });

    test('retourne une chaîne vide pour un numéro vide', () {
      expect(AuthService.canonicalPhone(''), '');
      expect(AuthService.canonicalPhone('   '), '');
    });
  });
}
