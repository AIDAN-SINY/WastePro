import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'registration_sreen.dart';

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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  
                  // Action: Register
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen())),
                      child: const Text("Get Started", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action: Login
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                    child: const Text(
                      "Already have an account? login", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}