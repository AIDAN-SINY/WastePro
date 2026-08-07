import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';

void main() {
  test('renaming a société cascades to its agences', () {
    final store = PlatformStore();

    store.updateSociete(
      store.societes.first.copyWith(raisonSociale: 'WastePro Douala SAS'),
    );

    expect(
      store.agences.where((a) => a.societe == 'WastePro Douala Ltd'),
      isEmpty,
    );
    expect(
      store.agences.where((a) => a.societe == 'WastePro Douala SAS').length,
      2,
    );
  });

  test('dashboard helpers count the design data correctly', () {
    final store = PlatformStore();

    // Seed: 3 companies (2 Active), 4 agencies, 4 users.
    expect(store.societesActives, 2);
    expect(store.agencesCount, 4);
    expect(store.utilisateursCount, 4);
  });
}
