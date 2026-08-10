import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/navigation_provider.dart';

// Screens
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pre_register_screen.dart';
import 'features/home/client_dashboard.dart';
import 'features/home/collector_dashboard.dart';
import 'features/backoffice/backoffice_screen.dart';
import 'features/backoffice/data/backoffice_store.dart';
import 'features/company/company_console.dart';
import 'features/superadmin/data/firestore_platform_store.dart';
import 'features/superadmin/data/platform_store.dart';
import 'features/superadmin/super_admin_console.dart';
import 'routing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Inside your main() or where you initialize Firebase
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Allows app to work while "unavailable"
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // Initialize Provider and Check for existing session
  final userProvider = UserProvider();
  await userProvider.tryAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const WasteProApp(),
    ),
  );
}

/// Donne accès au store Firestore de la console super admin (créé
/// paresseusement, partagé entre toutes les instances de la console afin de
/// ne pas dupliquer les abonnements Firestore).
class ConsoleStoreScope extends InheritedWidget {
  const ConsoleStoreScope({
    super.key,
    required this.ensureStore,
    required super.child,
  });

  final PlatformStore Function() ensureStore;

  static PlatformStore storeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ConsoleStoreScope>()!;
    return scope.ensureStore();
  }

  @override
  bool updateShouldNotify(ConsoleStoreScope oldWidget) => true;
}

class WasteProApp extends StatefulWidget {
  const WasteProApp({super.key, this.consoleStore, this.backofficeStore});

  /// Store de la console injecté par les tests (mock) — sinon un
  /// [FirestorePlatformStore] est créé paresseusement.
  final PlatformStore? consoleStore;

  /// Store du backoffice injecté par les tests (mock) — sinon un
  /// [FirestoreBackofficeStore] est créé par l'écran.
  final BackofficeStore? backofficeStore;

  @override
  State<WasteProApp> createState() => _WasteProAppState();
}

class _WasteProAppState extends State<WasteProApp> {
  FirestorePlatformStore? _consoleStore;
  GoRouter? _router;
  UserProvider? _userProvider;

  PlatformStore ensureConsoleStore() {
    final override = widget.consoleStore;
    if (override != null) return override;
    // Ne réutilise jamais un store disposé : après dispose, on en recrée un
    // (sinon « A FirestorePlatformStore was used after being disposed »).
    return _consoleStore ??= FirestorePlatformStore();
  }

  GoRouter _buildRouter(UserProvider userProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: userProvider,
      redirect: (context, state) => consoleRedirect(
        user: userProvider.user,
        path: state.uri.path,
        // En debug, la console reste consultable sans session (store mock)
        // pour prévisualiser/développer par URL.
        allowConsolePreview: kDebugMode,
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              AuthWrapper(backofficeStore: widget.backofficeStore),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          // Pré-inscription client (candidature) : le compte réel n'est créé
          // qu'après approbation par le chef d'agence.
          path: '/register',
          builder: (context, state) => const PreRegisterScreen(),
        ),
        GoRoute(
          path: '/console/:page',
          builder: (context, state) {
            final user = context.read<UserProvider>().user;
            final useMock = kDebugMode && user == null;
            return SuperAdminConsole(
              // Sans session (preview debug) → store mock ; sinon le store
              // Firestore partagé.
              store: useMock ? null : ConsoleStoreScope.storeOf(context),
              page: state.pathParameters['page'],
              autoCreate: state.uri.queryParameters['create'],
            );
          },
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    if (_userProvider != userProvider || _router == null) {
      _userProvider = userProvider;
      _router = _buildRouter(userProvider);
    }
  }

  @override
  void dispose() {
    // On ne dispose que le store créé ici (jamais celui injecté par les tests).
    if (widget.consoleStore == null) {
      _consoleStore?.dispose();
      // Réinitialise la référence : un store disposé ne doit plus jamais
      // être rendu par ensureConsoleStore() (sinon l'erreur « used after
      // being disposed » à la prochaine ouverture de la console).
      _consoleStore = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleStoreScope(
      ensureStore: ensureConsoleStore,
      child: MaterialApp.router(
        title: 'Waste Pro Cameroon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        routerConfig: _router!,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key, this.backofficeStore});

  /// Store du backoffice injecté par les tests (mock) — sinon l'écran crée
  /// son [FirestoreBackofficeStore].
  final BackofficeStore? backofficeStore;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

/// Écran affiché à un Agency Manager dont le compte n'a pas encore
/// d'agence assignée (Phase 3).
///
/// Sans agence, le backoffice n'aurait aucun périmètre : plutôt que de
/// laisser l'utilisateur voir les données de toutes les agences, on lui
/// demande de contacter son administrateur. L'entreprise (General
/// Administrator) ou le super admin doit assigner le chef d'agence à une
/// agence dans la console ; la prochaine connexion lui donnera accès.
class UnassignedManagerScreen extends StatelessWidget {
  const UnassignedManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 30,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No agency assigned yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account is not linked to any agency. Contact your '
                  'company administrator so they can assign you to an '
                  'agency — then log in again to access the backoffice.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    final provider = context.read<UserProvider>();
                    if (provider.user != null) provider.logout();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 1. If no user is logged in, show the Welcome/Preview Screen
    if (userProvider.user == null) {
      return const WelcomeScreen();
    }

    // 2. If user is logged in, direct to their specific Dashboard
    final user = userProvider.user!;
    final role = user.role.trim().toLowerCase();
    if (role == 'super_admin') {
      // Normalement redirigé vers /console/overview par le routeur ; ce
      // fallback garde la console accessible même si le routeur ne passe pas.
      return SuperAdminConsole(store: ConsoleStoreScope.storeOf(context));
    } else if (role == 'general_admin') {
      // General Administrator → console de SON entreprise.
      return CompanyConsole(societeId: user.societeId);
    } else if (role == 'collector') {
      return const CollectorDashboard();
    } else if (role == 'agency_manager') {
      // Phase 3 (défense en profondeur) : un chef d'agence sans agence
      // assignée ne doit JAMAIS tomber sur le backoffice non scopé (il
      // verrait les données de toutes les agences). Un écran dédié lui
      // demande de contacter son administrateur.
      if (user.agenceId.isEmpty) {
        return const UnassignedManagerScreen();
      }
      return BackofficeScreen(
        store: widget.backofficeStore,
        agenceId: user.agenceId,
        societeId: user.societeId,
      );
    } else if (role == 'admin') {
      // 'admin' : comptes créés avant la Phase 1 (legacy) → backoffice
      // global (comportement conservé).
      return BackofficeScreen(
        store: widget.backofficeStore,
        agenceId: user.agenceId,
        societeId: user.societeId,
      );
    } else {
      return const ClientDashboard();
    }
  }
}
