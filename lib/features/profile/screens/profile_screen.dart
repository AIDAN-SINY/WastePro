import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../auth/screens/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    // Getting the user data from our Global State (Provider)
    final userProvider = Provider.of<UserProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context);
    final user = userProvider.user;

    // Redirect to login if user is null (after logout)
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Account"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 1. TOP HEADER: ICON & NAME
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, size: 55, color: Colors.white),
            ),
            const SizedBox(height: 15),
            Text(
              user.fullName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Account Type: ${user.role.toUpperCase()}",
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),

            // 2. INFORMATION SECTION
            _buildSectionTitle("Personal Information"),
            _buildInfoTile(Icons.phone, "Phone Number", "+237 ${user.phoneNumber}"),
            
            // Place of Residence (Based on our Map Geolocation)
            _buildInfoTile(
              Icons.home, 
              "Place of Residence", 
              user.latitude != null 
                ? "Pinned at: ${user.latitude!.toStringAsFixed(4)}, ${user.longitude!.toStringAsFixed(4)}" 
                : "No location set yet"
            ),

            const SizedBox(height: 20),

            // 3. SECURITY & SETTINGS SECTION
            _buildSectionTitle("Security & Services"),
            _buildActionTile(Icons.lock_outline, "Security PIN", "Change your 4-digit code", () {}),
            _buildActionTile(Icons.map_outlined, "Collection Point", "Update your GPS location", () {}),
            _buildActionTile(Icons.support_agent, "Contact Support", "Talk to WastePro agents", () {}),

            const SizedBox(height: 40),

            // 4. LOGOUT / DELETE
            TextButton(
              onPressed: () => userProvider.logout(),
              child: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(navProvider),
    );
  }

  // --- UI HELPERS FOR CLEANER CODE ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(backgroundColor: Colors.green.withValues(alpha: 0.1), child: Icon(icon, color: Colors.green, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
    );
  }

  Widget _buildBottomNav(NavigationProvider navProvider) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.home_rounded,
                label: "Accueil",
                index: 0,
                onTap: () {
                  navProvider.setIndex(0);
                  Navigator.pop(context);
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.history_rounded,
                label: "Historique",
                index: 1,
                onTap: () {
                  navProvider.setIndex(1);
                  Navigator.pushReplacementNamed(context, '/history');
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.description_rounded,
                label: "Facture",
                index: 2,
                onTap: () {
                  navProvider.setIndex(2);
                  Navigator.pushReplacementNamed(context, '/subscription');
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.person_rounded,
                label: "Profil",
                index: 3,
                onTap: () {
                  navProvider.setIndex(3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required NavigationProvider navProvider,
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = navProvider.currentIndex == index;
    final Color dGreen = const Color(0xFF0F3D2E);
    final Color dMuted = const Color(0xFF7C8A80);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: dGreen.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? dGreen.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected 
                    ? Border.all(color: dGreen.withOpacity(0.3), width: 1.5)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? dGreen : dMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? dGreen : dMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}