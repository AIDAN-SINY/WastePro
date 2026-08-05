import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user!;

    return Scaffold(
      appBar: AppBar(title: const Text("Payment History"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot>(
        // For a prototype, we check the user's active sub document
        stream: FirebaseFirestore.instance.collection('subscriptions').doc(user.phoneNumber).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No subscription history found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final startDate = (data['startDate'] as Timestamp).toDate();
          
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text("Latest Transaction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: Text("${data['planName']} Plan"),
                  subtitle: Text("Paid: ${data['price']} XAF\nDate: ${startDate.day}/${startDate.month}/${startDate.year}"),
                  trailing: const Text("SUCCESS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}