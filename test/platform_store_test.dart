import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';

void main() {
  test('renaming a société cascades to its agences', () {
    final store = PlatformStore();

    store.updateSociete(
      store.societes.first.copyWith(raisonSociale: 'Propre237 Douala SAS'),
    );

    expect(
      store.agences.where((a) => a.societe == 'Propre237 Douala SARL'),
      isEmpty,
    );
    expect(
      store.agences.where((a) => a.societe == 'Propre237 Douala SAS').length,
      2,
    );
  });

  test('dashboard helpers count the design data correctly', () {
    final store = PlatformStore();

    // Seed: 3 sociétés (2 Actif), 4 agences, 4 utilisateurs.
    expect(store.societesActives, 2);
    expect(store.agencesCount, 4);
    expect(store.utilisateursCount, 4);
  });
}
