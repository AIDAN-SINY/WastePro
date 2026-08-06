import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/navigation_provider.dart';

// Screens
import 'features/auth/screens/welcome_screen.dart'; // Ensure you created this file
import 'features/home/client_dashboard.dart';
import 'features/home/collector_dashboard.dart';
import 'features/backoffice/backoffice_screen.dart';
import 'features/superadmin/data/firestore_platform_store.dart';
import 'features/superadmin/super_admin_console.dart';

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

class WasteProApp extends StatelessWidget {
  const WasteProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waste Pro Cameroon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Created once (lazily) so AuthWrapper rebuilds don't leak Firestore
  // snapshot subscriptions; disposed with the wrapper.
  FirestorePlatformStore? _consoleStore;

  @override
  void dispose() {
    _consoleStore?.dispose();
    super.dispose();
  }

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
    final role = userProvider.user!.role.trim().toLowerCase();
    if (role == 'super_admin') {
      _consoleStore ??= FirestorePlatformStore();
      return SuperAdminConsole(store: _consoleStore);
    } else if (role == 'collector') {
      return const CollectorDashboard();
    } else if (role == 'admin') {
      return const BackofficeScreen();
    } else {
      return const ClientDashboard();
    }
  }
}
