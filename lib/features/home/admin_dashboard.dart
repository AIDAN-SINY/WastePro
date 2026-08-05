import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/admin_heatmap.dart';
import '../../providers/user_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

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
        padding: const EdgeInsets.all(20.0),
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
}