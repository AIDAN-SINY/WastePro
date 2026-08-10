import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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

  group('AuthService.submitPreRegistration', () {
    Future<void> submit(AuthService auth, {String phone = '698 22 44 66'}) {
      return auth.submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: phone,
        zone: 'Bonanjo',
        agenceId: 'ag1',
        agenceName: 'Douala — Bonanjo',
        societeId: 'so1',
        password: 'secret123',
      );
    }

    test('écrit une candidature pending avec le numéro canonique', () async {
      final db = FakeFirebaseFirestore();
      final auth = AuthService(db: db);
      await submit(auth);

      final docs = await db.collection('registrations').get();
      expect(docs.docs.single.data()['phone'], '+237698224466');
      expect(docs.docs.single.data()['fullName'], 'Carine Mbappe');
      expect(docs.docs.single.data()['agenceId'], 'ag1');
      expect(docs.docs.single.data()['status'], 'pending');
      expect(docs.docs.single.data()['collecteurId'], '');
    });

    test('refuse un numéro qui a déjà un compte', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('+237698224466').set({
        'phoneNumber': '+237698224466',
        'fullName': 'Déjà client',
        'role': 'client',
        'password': 'x',
      });
      final auth = AuthService(db: db);
      expect(
        () => submit(auth),
        throwsA(contains('already has an account')),
      );
      expect((await db.collection('registrations').get()).docs, isEmpty);
    });

    test('refuse une candidature déjà en attente pour le même numéro', () async {
      final db = FakeFirebaseFirestore();
      final auth = AuthService(db: db);
      await submit(auth);
      expect(
        () => submit(auth),
        throwsA(contains('already have a pending application')),
      );
      expect((await db.collection('registrations').get()).docs, hasLength(1));
    });

    test('refuse sans numéro valide', () async {
      final db = FakeFirebaseFirestore();
      final auth = AuthService(db: db);
      expect(
        () => submit(auth, phone: '  '),
        throwsA(contains('Invalid phone number')),
      );
    });


    test('résout un nom d agence tapé vers son agenceId (insensible à la casse)',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('agences').doc('ag1').set({
        'id': 'ag1',
        'societe': 'WastePro Douala Ltd',
        'societeId': 'so1',
        'ville': 'Douala — Bonanjo',
        'responsable': 'Jean Dooh',
        'telephone': '+237 677 12 34 56',
        'status': 'Active',
      });

      final auth = AuthService(db: db);
      await auth.submitPreRegistration(
        fullName: 'Carine Mbappe',
        phone: '698 22 44 66',
        zone: 'Bonanjo',
        agenceId: '', // nom tapé, pas de sélection
        agenceName: 'DOUALA — BONANJO',
        societeId: '',
        password: 'secret123',
      );

      // La candidature est rattachée à l'agence (sinon invisible au chef).
      final docs = await db.collection('registrations').get();
      expect(docs.docs.single.data()['agenceId'], 'ag1');
      expect(docs.docs.single.data()['societeId'], 'so1');
    });

    test('refuse un nom d agence qui ne correspond à aucune agence', () async {
      final db = FakeFirebaseFirestore();
      final auth = AuthService(db: db);
      // Aucune agence en base : taper un nom inconnu ne doit PAS créer une
      // candidature « orpheline » (agenceId vide) qu'aucun chef d'agence ne
      // pourrait voir ni traiter — le client choisit une agence existante.
      await expectLater(
        auth.submitPreRegistration(
          fullName: 'Carine Mbappe',
          phone: '698 22 44 66',
          zone: 'Kribi',
          agenceId: '',
          agenceName: 'Nouvelle Agence Kribi',
          societeId: '',
          password: 'secret123',
        ),
        throwsA(contains('Agency not found')),
      );
      expect((await db.collection('registrations').get()).docs, isEmpty);
    });
  });
}
