import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/registration_sreen.dart';
import 'features/home/client_dashboard.dart';
import 'features/home/collector_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/user_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// Minimal MyApp wrapper used by tests and app entrypoint
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: const WasteProApp(home: AuthWrapper()),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool>? _loadUserFuture;
  String? _currentUid;

  Future<bool> _ensureUserLoaded(String uid) async {
    if (_currentUid != uid) {
      _currentUid = uid;
      _loadUserFuture = Provider.of<UserProvider>(context, listen: false)
          .refreshUser(uid)
          .then(
            (_) =>
                Provider.of<UserProvider>(context, listen: false).user != null,
          );
    }
    return _loadUserFuture!;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen to Firebase Auth state
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If Firebase is still checking the login status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If user is NOT logged in, show Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          future: _ensureUserLoaded(snapshot.data!.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userProvider = Provider.of<UserProvider>(context);
            if (userProvider.user == null) {
              return RegistrationScreen(
                uid: snapshot.data!.uid,
                phone: snapshot.data!.phoneNumber ?? '',
              );
            }

            // 4. Redirect based on Role
            if (userProvider.user!.role == 'collector') {
              return const CollectorDashboard();
            } else {
              return const ClientDashboard();
            }
          },
        );
      },
    );
  }
}
