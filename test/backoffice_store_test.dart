import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/backoffice/data/backoffice_store.dart';

void main() {
  group('BackofficeStore.reassignCollecteur', () {
    test('met à jour le client et ses collectes à venir uniquement', () async {
      final store = BackofficeStore();

      // Aïcha Bello (cl4) est assignée à Paul Mbarga (co1) ; sa collecte
      // cc3 (Scheduled) est portée par Paul Mbarga.
      final cl4 = store.clients.firstWhere((c) => c.id == 'cl4');
      expect(cl4.collecteurId, 'co1');
      expect(store.collectes.firstWhere((c) => c.id == 'cc3').collecteur,
          'Paul Mbarga');

      await store.reassignCollecteur(clientId: 'cl4', collecteurId: 'co2');

      // La fiche client porte le nouveau collecteur.
      expect(store.clients.firstWhere((c) => c.id == 'cl4').collecteurId, 'co2');

      // La collecte à venir bascule vers Vincent Onana.
      expect(store.collectes.firstWhere((c) => c.id == 'cc3').collecteur,
          'Vincent Onana');

      // L'historique (collecte effectuée) ne change pas.
      expect(store.collectes.firstWhere((c) => c.id == 'cc1').collecteur,
          'Paul Mbarga');
    });

    test('ne touche pas aux collectes des autres clients', () async {
      final store = BackofficeStore();

      await store.reassignCollecteur(clientId: 'cl4', collecteurId: 'co2');

      // Marie Ekwalla (cl2, co2) et sa collecte cc2 (Completed, Vincent Onana)
      // restent intactes.
      expect(store.clients.firstWhere((c) => c.id == 'cl2').collecteurId, 'co2');
      expect(store.collectes.firstWhere((c) => c.id == 'cc2').collecteur,
          'Vincent Onana');
    });

    test('ne fait rien quand le collecteur est identique', () async {
      final store = BackofficeStore();

      await store.reassignCollecteur(clientId: 'cl1', collecteurId: 'co1');

      expect(store.clients.firstWhere((c) => c.id == 'cl1').collecteurId, 'co1');
      expect(store.collectes.firstWhere((c) => c.id == 'cc1').collecteur,
          'Paul Mbarga');
    });

    test('un client inconnu est un no-op', () async {
      final store = BackofficeStore();
      final count = store.clients.length;

      await store.reassignCollecteur(clientId: 'nope', collecteurId: 'co2');

      expect(store.clients.length, count);
    });
  });
}
