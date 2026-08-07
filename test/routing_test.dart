import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/main.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';
import 'package:waste_pro/features/superadmin/super_admin_console.dart';
import 'package:waste_pro/routing.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider({this.fakeUser, this.fakeIsLoading = false});

  final UserModel? fakeUser;
  final bool fakeIsLoading;

  @override
  UserModel? get user => fakeUser;

  @override
  bool get isLoading => fakeIsLoading;
}

UserModel _user(String role) => UserModel(
      phoneNumber: '+237677123456',
      fullName: 'Test',
      role: role,
      password: 'x',
    );

void main() {
  group('consolePageIndex', () {
    test('mappe les noms d URL vers les pages de la console', () {
      expect(consolePageIndex(null), 0);
      expect(consolePageIndex('overview'), 0);
      expect(consolePageIndex('societes'), 1);
      expect(consolePageIndex('agences'), 2);
      expect(consolePageIndex('utilisateurs'), 3);
      expect(consolePageIndex('rapports'), 4);
      expect(consolePageIndex('parametres'), 5);
      expect(consolePageIndex('inconnu'), 0);
    });
  });

  group('consoleRedirect', () {
    test('bloque la console sans session', () {
      expect(consoleRedirect(user: null, path: '/console/overview'), '/');
      expect(consoleRedirect(user: null, path: '/console/societes'), '/');
    });

    test('autorise la prévisualisation debug sans session', () {
      expect(
        consoleRedirect(
          user: null,
          path: '/console/overview',
          allowConsolePreview: true,
        ),
        isNull,
      );
    });

    test('laisse le super admin naviguer librement dans la console', () {
      expect(
        consoleRedirect(user: _user('super_admin'), path: '/console/societes'),
        isNull,
      );
      expect(
        consoleRedirect(
          user: _user('super_admin'),
          path: '/console/parametres',
        ),
        isNull,
      );
    });

    test('renvoie les non-super-admins vers l accueil', () {
      expect(
        consoleRedirect(user: _user('client'), path: '/console/societes'),
        '/',
      );
      expect(
        consoleRedirect(user: _user('admin'), path: '/console/overview'),
        '/',
      );
      expect(
        consoleRedirect(user: _user('collector'), path: '/console/rapports'),
        '/',
      );
    });

    test('envoie le super admin vers la console depuis l accueil', () {
      expect(
        consoleRedirect(user: _user('super_admin'), path: '/'),
        '/console/overview',
      );
      expect(consoleRedirect(user: _user('client'), path: '/'), isNull);
      expect(consoleRedirect(user: null, path: '/'), isNull);
    });

    test('interdit les écrans d auth une fois connecté', () {
      expect(consoleRedirect(user: _user('client'), path: '/login'), '/');
      expect(consoleRedirect(user: _user('client'), path: '/register'), '/');
      expect(consoleRedirect(user: null, path: '/login'), isNull);
      expect(consoleRedirect(user: null, path: '/register'), isNull);
    });

    test('renvoie les chemins inconnus vers l accueil', () {
      expect(consoleRedirect(user: null, path: '/xyz'), '/');
      expect(consoleRedirect(user: _user('client'), path: '/xyz'), '/');
    });
  });

  group('WasteProApp router', () {
    testWidgets('super admin loggé → redirigé vers la console', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: _user('super_admin')),
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperAdminConsole), findsOneWidget);
      // The "Overview" page is shown (index 0).
      expect(find.text('Overview'), findsWidgets);
    });

    testWidgets('non connecté → écran d accueil', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: null),
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperAdminConsole), findsNothing);
      // The welcome screen shows the CTA card with its primary button.
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('la navigation par la barre latérale change de page sans rechargement', (
      tester,
    ) async {
      // Viewport desktop (la console passe en layout bureau → table).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: _user('super_admin')),
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      // We start on the overview: the Companies page is not there.
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('New company'), findsNothing);

      // Click "Companies" in the sidebar → URL + page change immediately
      // (no page reload needed).
      await tester.tap(find.text('Companies'));
      await tester.pumpAndSettle();

      expect(find.text('New company'), findsOneWidget);
      expect(find.text('WastePro Douala Ltd'), findsWidgets);
    });

    testWidgets('deep link /console/societes restaure la page Sociétés', (
      tester,
    ) async {
      // Viewport desktop (la console passe en layout bureau → table).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Simule le chargement direct de l'URL profonde (rechargement de page
      // web) : defaultRouteName devient le chemin de l'URL du navigateur.
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/console/societes';
      addTearDown(() {
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: null),
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperAdminConsole), findsOneWidget);
      // The Companies page (toolbar "New company") must be shown, not the
      // overview.
      expect(find.text('New company'), findsOneWidget);
      expect(find.text('WastePro Douala Ltd'), findsWidgets);
    });
  });
}
