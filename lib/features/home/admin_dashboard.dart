import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/features/home/admin_heatmap.dart';
import 'package:waste_pro/features/home/admin_payments_screen.dart';
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
        title: const Text(
          'WastePro Admin System',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => userProvider.logout(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
        builder: (context, txSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnap) {
              final txs = txSnap.data?.docs ?? [];
              final users = usersSnap.data?.docs ?? [];

              final completed =
                  txs.where((d) => d.data()['status'] == 'completed');
              final revenue = completed.fold<double>(
                0,
                (sum, d) =>
                    sum + ((d.data()['amount'] as num?)?.toDouble() ?? 0),
              );
              final activeSubs = users
                  .where((d) => d.data()['isSubscribed'] == true)
                  .length;
              final collectors = users
                  .where(
                    (d) =>
                        (d.data()['role'] as String?)?.toLowerCase() ==
                        'collector',
                  )
                  .length;
              final pendingKyc = users.where((d) {
                final role =
                    (d.data()['role'] as String?)?.toLowerCase() ?? '';
                final verified = d.data()['isVerified'] == true;
                return role == 'collector' && !verified;
              }).length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control Tower: ${admin.fullName}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const Text(
                      'System Overview',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _statCard(
                          'Total Revenue',
                          '${revenue.toInt()} XAF',
                          Colors.green,
                          Icons.account_balance_wallet,
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          'Active Subs',
                          '$activeSubs',
                          Colors.orange,
                          Icons.people,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statCard(
                          'Collectors',
                          '$collectors',
                          Colors.blue,
                          Icons.local_shipping,
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          'Pending KYC',
                          '$pendingKyc',
                          Colors.red,
                          Icons.verified_user,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Research & Management',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    _adminTile(
                      Icons.map,
                      'Financial Heatmap',
                      'Visualize payment adoption',
                      Colors.indigo,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminHeatmapScreen(),
                          ),
                        );
                      },
                    ),
                    _adminTile(
                      Icons.payments,
                      'CamPay Backoffice',
                      'All MoMo payments, sync & audit trail',
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPaymentsScreen(),
                          ),
                        );
                      },
                    ),
                    _adminTile(
                      Icons.verified,
                      'Collector Management',
                      'Whitelist and CNI Verification',
                      Colors.green,
                      () {},
                    ),
                    _adminTile(
                      Icons.settings,
                      'System Configuration',
                      'Adjust pricing and zones',
                      Colors.blueGrey,
                      () {},
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

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
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminTile(
    IconData icon,
    String title,
    String sub,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
