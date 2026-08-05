import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Getting the user data from our Global State (Provider)
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Account"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
}