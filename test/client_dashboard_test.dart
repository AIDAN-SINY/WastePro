import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/client_dashboard.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/navigation_provider.dart';
import 'package:waste_pro/providers/user_provider.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get user => _user;
}

void main() {
  testWidgets('client dashboard bottom nav does not overflow', (tester) async {
    // Taille téléphone + barre de navigation système simulée en bas.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(
            value: FakeUserProvider(
              UserModel(
                phoneNumber: '+237699999999',
                fullName: 'Test Client',
                role: 'client',
                password: 'pw',
              ),
            ),
          ),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ],
        child: const MaterialApp(home: ClientDashboard()),
      ),
    );
    // Laisse les animations (logo/progress) se jouer.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // Un « bottom overflow » déclencherait une FlutterError ici.
    expect(tester.takeException(), isNull);

    // La navbar est bien rendue avec ses 4 onglets.
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });
}
