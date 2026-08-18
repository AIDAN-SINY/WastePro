import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';
import 'package:waste_pro/features/superadmin/super_admin_console.dart';
import 'package:waste_pro/main.dart';
import 'package:waste_pro/providers/user_provider.dart';
import 'package:waste_pro/services/auth_service.dart';

import 'fakes/fake_auth_backend.dart';

/// Logout depuis la console super admin avec le VRAI `UserProvider.logout()`
/// (session vidée avant le signOut backend) — pas le provider fake mutable
/// des tests de routage. C'est le parcours réel de l'utilisateur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'super admin : logout depuis la console → écran d accueil (provider réel)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = FakeFirebaseFirestore();
      final backend = FakeAuthBackend()
        ..seedAccount('237640996787@wastepro.cm', 'admin123');
      await db.collection('users').doc('+237640996787').set({
        'phoneNumber': '+237640996787',
        'fullName': 'Super Admin',
        'role': 'super_admin',
      });

      final userProvider = UserProvider(backend: backend);
      final auth = AuthService(db: db, backend: backend);
      final user = await auth.login('+237640996787', 'admin123');
      expect(user, isNotNull);
      await userProvider.setUser(user!);

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      // Le super admin est redirigé vers la console.
      expect(find.byType(SuperAdminConsole), findsOneWidget);

      // Logout via l'icône de la sidebar (footer).
      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      // Retour à l'écran d'accueil (bouton Log In de la CTA).
      expect(find.byType(SuperAdminConsole), findsNothing);
      expect(find.text('Log In'), findsOneWidget);
      expect(userProvider.user, isNull);
    },
  );
}
