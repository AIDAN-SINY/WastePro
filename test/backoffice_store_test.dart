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

  group('BackofficeStore.notifications', () {
    test('approuver une candidature crée une notification approved', () async {
      final store = BackofficeStore();
      final reg = store.pendingRegistrations.first;

      await store.approveRegistration(reg, collecteurId: 'co1');

      final notif = store.notifications.single;
      expect(notif.id, 'notif${reg.id}');
      expect(notif.type, 'approved');
      expect(notif.title, 'Application approved');
      expect(notif.read, isFalse);
    });

    test('rejeter une candidature crée une notification rejected', () async {
      final store = BackofficeStore();
      final reg = store.pendingRegistrations.first;

      await store.rejectRegistration(reg);

      final notif = store.notifications.single;
      expect(notif.type, 'rejected');
      expect(notif.title, 'Application rejected');
    });

    test('une nouvelle décision sur la même candidature remplace la notif',
        () async {
      final store = BackofficeStore();
      final reg = store.pendingRegistrations.first;

      await store.rejectRegistration(reg);
      await store.approveRegistration(reg, collecteurId: 'co1');

      expect(store.notifications.length, 1);
      expect(store.notifications.single.type, 'approved');
    });
  });
}
