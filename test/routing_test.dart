import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/main.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';
import 'package:waste_pro/features/backoffice/backoffice_screen.dart';
import 'package:waste_pro/features/backoffice/data/backoffice_store.dart';
import 'package:waste_pro/features/backoffice/widgets/toast.dart';
import 'package:waste_pro/features/company/company_console.dart';
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

/// Provider whose session can actually be cleared by [logout] — used to test
/// that the console leaves the `/console/*` route after signing out (even in
/// debug builds where the session-less console preview is allowed).
class _MutableUserProvider extends UserProvider {
  _MutableUserProvider(this._current);

  UserModel? _current;

  @override
  UserModel? get user => _current;

  @override
  bool get isLoading => false;

  @override
  Future<void> logout() async {
    _current = null;
    notifyListeners();
  }
}

UserModel _user(String role, {String agenceId = '', String societeId = ''}) =>
    UserModel(
      phoneNumber: '+237677123456',
      fullName: 'Test',
      role: role,
      password: 'x',
      agenceId: agenceId,
      societeId: societeId,
    );

void main() {
  setUp(BoToastService.resetForTesting);

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
      // Phase 1 : le General Administrator (console entreprise) n a pas
      // accès à la console plateforme, et l'Agency Manager non plus.
      expect(
        consoleRedirect(user: _user('general_admin'), path: '/console/agences'),
        '/',
      );
      expect(
        consoleRedirect(user: _user('agency_manager'), path: '/console/users'),
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
      // Les autres rôles restent sur l accueil (AuthWrapper choisit leur
      // écran) : ni le General Administrator ni l'Agency Manager ne sont
      // redirigés vers la console plateforme.
      expect(consoleRedirect(user: _user('general_admin'), path: '/'), isNull);
      expect(consoleRedirect(user: _user('agency_manager'), path: '/'), isNull);
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

    testWidgets('general admin loggé → console entreprise', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: _user('general_admin')),
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CompanyConsole), findsOneWidget);
      expect(find.byType(SuperAdminConsole), findsNothing);
    });

    testWidgets('agency manager loggé → backoffice de son agence', (
      tester,
    ) async {
      // Phase 3 : le chef d'agence avec une agence assignée arrive au
      // backoffice scopé à son agence (agenceId transmis à l'écran).
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(
            fakeUser: _user('agency_manager', agenceId: 'ag1'),
          ),
          child: WasteProApp(
            consoleStore: PlatformStore(),
            backofficeStore: BackofficeStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackofficeScreen), findsOneWidget);
      expect(find.byType(SuperAdminConsole), findsNothing);
      expect(find.byType(CompanyConsole), findsNothing);
    });

    testWidgets('agency manager SANS agence → écran « No agency assigned »', (
      tester,
    ) async {
      // Phase 3 (défense) : jamais de backoffice non scopé pour un chef
      // d'agence — il verrait les données de toutes les agences.
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: _user('agency_manager')),
          child: WasteProApp(
            consoleStore: PlatformStore(),
            backofficeStore: BackofficeStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackofficeScreen), findsNothing);
      expect(find.text('No agency assigned yet'), findsOneWidget);
    });

    testWidgets('legacy rôle admin loggé → backoffice (pré-Phase 1)', (
      tester,
    ) async {
      // Comptes créés avant la Phase 1 : leur doc users porte encore le
      // rôle générique 'admin' — ils doivent continuer d'arriver au
      // backoffice (régression guard).
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(fakeUser: _user('admin')),
          child: WasteProApp(
            consoleStore: PlatformStore(),
            backofficeStore: BackofficeStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackofficeScreen), findsOneWidget);
      expect(find.byType(CompanyConsole), findsNothing);
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

    testWidgets('logout depuis la console revient à l écran d accueil', (
      tester,
    ) async {
      // Desktop viewport so the console renders the sidebar with the logout
      // button (tests run in debug mode: the session-less console preview is
      // allowed — the exact condition that used to make logout do nothing).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = _MutableUserProvider(_user('super_admin'));
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: provider,
          child: WasteProApp(consoleStore: PlatformStore()),
        ),
      );
      await tester.pumpAndSettle();

      // The super admin is on the console.
      expect(find.byType(SuperAdminConsole), findsOneWidget);

      // Click the logout button in the sidebar footer.
      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      // The console unmounts and the welcome screen is shown.
      expect(find.byType(SuperAdminConsole), findsNothing);
      expect(find.text('Log In'), findsOneWidget);
    });
  });
}
