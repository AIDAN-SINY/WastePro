import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/collector_dashboard.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get user => _user;
}

void main() {
  Future<void> pumpCollector(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: FakeUserProvider(
          UserModel(
            phoneNumber: '+237678901122',
            fullName: 'Paul Mbarga',
            role: 'collector',
            password: 'pw',
          ),
        ),
        child: const MaterialApp(home: CollectorDashboard()),
      ),
    );
    // Laisse les animations (scan line, ring) se jouer sans crasher.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('renders topbar, progress card and tournée list', (tester) async {
    await pumpCollector(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Paul Mbarga'), findsWidgets);
    expect(find.text('Tournée du jour'), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget); // 2 Terminés / 8 clients
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Brice Talla'), findsOneWidget);
    expect(find.text('Manqué'), findsWidgets);
    // Filtres
    expect(find.text('Tous'), findsOneWidget);
    expect(find.text('Terminés'), findsOneWidget);
    // Tab bar
    expect(find.text('Tournée'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('filters the tournée by status', (tester) async {
    await pumpCollector(tester);

    // Les chips filtres défilent horizontalement : on s'assure qu'ils
    // sont visibles avant de taper. (Pas de pumpAndSettle : la ligne de
    // scan QR anime en boucle.)
    await tester.ensureVisible(find.text('Terminés'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Terminés'));
    await tester.pump();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Brice Talla'), findsNothing);

    await tester.ensureVisible(find.text('Manqués'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Manqués'));
    await tester.pump();
    expect(find.text('Brice Talla'), findsOneWidget);
    expect(find.text('Jean Dooh'), findsNothing);

    await tester.ensureVisible(find.text('Tous'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tous'));
    await tester.pump();
    expect(find.text('Jean Dooh'), findsOneWidget);
    expect(find.text('Brice Talla'), findsOneWidget);
  });

  testWidgets('opens client detail sheet from tournée', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet détail : actions + bouton primaire.
    expect(find.text('Appeler'), findsOneWidget);
    expect(find.text('Itinéraire'), findsOneWidget);
    expect(find.text('Signaler'), findsOneWidget);
    expect(find.text('Démarrer la collecte'), findsOneWidget);
    expect(find.text('Standard · 2x/semaine'), findsOneWidget);
  });

  testWidgets('completes the 3-step collection flow and shows toast',
      (tester) async {
    await pumpCollector(tester);

    // Ouvrir le client « Robert Essomba » (À faire).
    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Étape 1 : QR.
    await tester.tap(find.text('Démarrer la collecte'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Valider votre présence'), findsOneWidget);
    // Le bouton Suivant est désactivé tant que le QR n'est pas validé :
    // taper dessus ne change pas d'étape.
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Valider votre présence'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsNothing);

    await tester.tap(find.text('Simuler la lecture du QR'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('QR code validé.'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 300));

    // Étape 2 : photo.
    expect(find.text('Prendre une photo'), findsOneWidget);
    await tester.tap(find.text('Touchez pour prendre la photo'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 300));

    // Étape 3 : poids + commentaire.
    expect(find.text('Détails de la collecte'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '4.5');
    await tester.tap(find.text('Valider la collecte'));
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet fermé + toast + progression mise à jour (3/8).
    expect(find.text('Collecte enregistrée — Robert Essomba'), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget);
  });

  testWidgets('marks a client as missed with a reason', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Robert Essomba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Signaler'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signaler un problème'), findsOneWidget);

    // Confirmer est désactivé tant qu'aucun motif n'est choisi.
    await tester.tap(find.text('Client absent'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmer'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Ramassage marqué comme manqué.'),
      findsOneWidget,
    );
    // Le compteur reste 2/8, Robert Essomba est maintenant Manqué.
    expect(find.text('2/8'), findsOneWidget);
  });

  testWidgets('switches to historique and profil tabs', (tester) async {
    await pumpCollector(tester);

    await tester.tap(find.text('Historique'));
    await tester.pump();
    expect(find.text('Mardi 04 août'), findsOneWidget);
    expect(find.text('Mercredi 05 août'), findsOneWidget);
    expect(find.text('Robert Essomba'), findsWidgets);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.text('Collecteur · Zone Bonanjo / Akwa'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('+237678901122'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}

