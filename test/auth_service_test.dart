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

  group('AuthService.canonicalKeys', () {
    test('ajoute la clé brute sans +237 (docs créés à la main)', () {
      // Un compte créé à la main peut utiliser la clé brute '653645807'
      // au lieu de '+237653645807' : le login doit essayer les deux.
      expect(AuthService.canonicalKeys('653645807'), {
        '+237653645807',
        '653645807',
      });
      expect(AuthService.canonicalKeys('+237653645807'), {
        '+237653645807',
        '653645807',
      });
    });

    test('ignore les clés vides', () {
      expect(AuthService.canonicalKeys(''), {''});
    });
  });
}
