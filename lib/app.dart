import 'package:flutter/material.dart';
// TODO: Import your theme and routes

class WasteProApp extends StatelessWidget {
  const WasteProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WastePro',

      // TODO: Add your theme
      // theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      // themeMode: ThemeMode.light,

      // TODO: Set initial route and route definitions
      // home: const SplashScreen(),
      // routes: {
      //   '/login': (context) => const LoginScreen(),
      //   '/signup': (context) => const SignupScreen(),
      //   '/home': (context) => const HomeScreen(),
      //   '/profile': (context) => const ProfileScreen(),
      // },
      home: Scaffold(
        appBar: AppBar(title: const Text('WastePro')),
        body: const Center(child: Text('Welcome to WastePro')),
      ),
    );
  }
}
