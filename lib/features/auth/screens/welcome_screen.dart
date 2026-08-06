import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:flutter/material.dart';
import '../../superadmin/super_admin_console.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. THE BACKGROUND IMAGE
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/waste_bg.jpg'), // Your image here
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. THE BLUR EFFECT
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Adjust blur intensity
              child: Container(
                color: Colors.black.withValues(alpha: 0.3), // Dark overlay to make text readable
              ),
            ),
          ),

          // 3. THE CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.recycling_rounded, size: 100, color: Colors.white),
                  const SizedBox(height: 30),
                  const Text(
                    "Welcome to WastePro",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "The smart way to manage waste in Cameroon.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const Spacer(),
                  
                  // Action: Login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                      child: const Text("Get Started", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),

                  // Dev-only preview of the Super Admin console (debug builds)
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SuperAdminConsole(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 15,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        "Aperçu console super admin (dev)",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}