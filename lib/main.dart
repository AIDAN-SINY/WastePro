import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/client_dashboard.dart';
import 'features/home/collector_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers/user_provider.dart';

// Minimal MyApp wrapper used by tests and app entrypoint
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: const WasteProApp(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

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

        // 3. If user IS logged in, check if we have their profile data
        if (userProvider.user == null) {
          // Trigger a fetch of user data from Firestore
          userProvider.refreshUser(snapshot.data!.uid);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
  }
}
