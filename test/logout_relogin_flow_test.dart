import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_pro/features/backoffice/backoffice_screen.dart';
import 'package:waste_pro/features/backoffice/data/backoffice_store.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';
import 'package:waste_pro/main.dart';
import 'package:waste_pro/providers/user_provider.dart';
import 'package:waste_pro/services/auth_service.dart';

import 'fakes/fake_auth_backend.dart';

/// Backend dont le signOut ne termine JAMAIS (simule un signOut Firebase
/// bloqué — plugin web/desktop, réseau…) : le logout doit quand même vider
/// la session côté app, sinon l'utilisateur reste prisonnier du backoffice
/// et ne peut pas se reconnecter avec un autre compte.
class _HangingSignOutBackend extends FakeAuthBackend {
  @override
  Future<void> signOut() => Completer<void>().future; // ne se résout jamais
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(FakeFirebaseFirestore, FakeAuthBackend, UserProvider)> pumpApp(
    WidgetTester tester,
    FakeAuthBackend backend,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('+237656778990').set({
      'phoneNumber': '+237656778990',
      'fullName': 'Chef A',
      'role': 'agency_manager',
      'agenceId': 'ag1',
    });
    await db.collection('users').doc('+237674738258').set({
      'phoneNumber': '+237674738258',
      'fullName': 'Chef B',
      'role': 'agency_manager',
      'agenceId': 'ag2',
    });

    final userProvider = UserProvider(backend: backend);
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: userProvider,
        child: WasteProApp(
          consoleStore: PlatformStore(),
          backofficeStore: BackofficeStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (db, backend, userProvider);
  }

  Future<void> loginAs(
    WidgetTester tester,
    FakeFirebaseFirestore db,
    FakeAuthBackend backend,
    UserProvider userProvider,
    String phone,
    String password,
  ) async {
    final auth = AuthService(db: db, backend: backend);
    final user = await auth.login(phone, password);
    expect(user, isNotNull);
    await userProvider.setUser(user!);
    await tester.pumpAndSettle();
  }

  testWidgets('login A → logout → login B (parcours réel)', (tester) async {
    final backend = FakeAuthBackend()
      ..seedAccount('237656778990@wastepro.cm', 'mdpA')
      ..seedAccount('237674738258@wastepro.cm', 'mdpB');
    final (db, _, userProvider) = await pumpApp(tester, backend);

    // Login A → backoffice.
    await loginAs(tester, db, backend, userProvider, '+237656778990', 'mdpA');
    expect(find.byType(BackofficeScreen), findsOneWidget);

    // Logout (signOut backend normal) → retour à l'accueil.
    await userProvider.logout();
    await tester.pumpAndSettle();
    expect(find.byType(BackofficeScreen), findsNothing);
    expect(find.text('Log In'), findsOneWidget);
    expect(userProvider.user, isNull);

    // Login B → backoffice de B.
    await loginAs(tester, db, backend, userProvider, '+237674738258', 'mdpB');
    expect(find.byType(BackofficeScreen), findsOneWidget);
    expect(userProvider.user!.fullName, 'Chef B');
  });

  testWidgets(
    'le logout vide la session même si le signOut backend ne se termine pas',
    (tester) async {
      final backend = _HangingSignOutBackend()
        ..seedAccount('237656778990@wastepro.cm', 'mdpA')
        ..seedAccount('237674738258@wastepro.cm', 'mdpB');
      final (db, _, userProvider) = await pumpApp(tester, backend);

      // Login A (via AuthService, comme l'écran de login).
      await loginAs(tester, db, backend, userProvider, '+237656778990', 'mdpA');
      expect(find.byType(BackofficeScreen), findsOneWidget);

      // Logout : le signOut backend est bloqué, mais la session app DOIT
      // être vidée (retour à l'accueil + possibilité de se reconnecter).
      unawaited(userProvider.logout());
      await tester.pumpAndSettle();

      expect(find.byType(BackofficeScreen), findsNothing);
      expect(find.text('Log In'), findsOneWidget);
      expect(userProvider.user, isNull);

      // Login B : possible malgré le signOut bloqué (le signIn remplace
      // la session).
      await loginAs(tester, db, backend, userProvider, '+237674738258', 'mdpB');
      expect(find.byType(BackofficeScreen), findsOneWidget);
      expect(userProvider.user!.fullName, 'Chef B');
    },
  );
}
