import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/admin_heatmap.dart';
import '../../providers/user_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final admin = userProvider.user!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("WastePro Admin System", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900], // Professional Bank Blue
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => userProvider.logout(),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Control Tower: ${admin.fullName}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const Text("System Overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- FINANCIAL & LOGISTICAL KPIS ---
            Row(
              children: [
                _statCard("Total Revenue", "450,000 XAF", Colors.green, Icons.account_balance_wallet),
                const SizedBox(width: 10),
                _statCard("Active Subs", "124", Colors.orange, Icons. people),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCard("Collectors", "12", Colors.blue, Icons.local_shipping),
                const SizedBox(width: 10),
                _statCard("Pending KYC", "3", Colors.red, Icons.verified_user),
              ],
            ),

            const SizedBox(height: 30),
            const Text("Research & Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // --- ADMIN MODULES ---
            _adminTile(
              Icons.map,
              "Financial Heatmap",
              "Visualize payment adoption",
              Colors.indigo,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminHeatmapScreen()),
                );
              },
            ),
            _adminTile(Icons.verified, "Collector Management", "Whitelist and CNI Verification", Colors.green, () {}),
            _adminTile(Icons.assessment, "Financial Reports", "Download monthly audit trail", Colors.purple, () {}),
            _adminTile(Icons.settings, "System Configuration", "Adjust pricing and zones", Colors.blueGrey, () {}),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Helper for Stats Cards
  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Helper for Admin Actions
  Widget _adminTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  Widget _buildBottomNav() {
    // Pas de hauteur fixe : la barre s'adapte à son contenu (évite le
    // « bottom overflow » quand le contenu est plus haut que 65 px).
    return Container(
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
                icon: Icons.dashboard_rounded,
                label: "Dashboard",
                index: 0,
                onTap: () {
                  setState(() => _currentIndex = 0);
                },
              ),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: "Heatmap",
                index: 1,
                onTap: () {
                  setState(() => _currentIndex = 1);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminHeatmapScreen()),
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.people_rounded,
                label: "Users",
                index: 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                },
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: "Settings",
                index: 3,
                onTap: () {
                  setState(() => _currentIndex = 3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _currentIndex == index;
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