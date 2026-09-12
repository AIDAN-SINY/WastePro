import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // No composite index required: filter client-side by createdAt.
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.phoneNumber)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = [...(snapshot.data?.docs ?? [])];
          docs.sort((a, b) {
            final aTs = (a.data() as Map)['createdAt'];
            final bTs = (b.data() as Map)['createdAt'];
            final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
            final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No payment history found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = (data['status'] ?? 'pending').toString();
              final amount = data['amount'] ?? 0;
              final description =
                  (data['description'] ?? 'CamPay payment').toString();
              final operator = data['operator']?.toString();
              final createdAt = data['createdAt'];
              DateTime? date;
              if (createdAt is Timestamp) date = createdAt.toDate();

              final statusColor = status == 'completed'
                  ? Colors.green
                  : status == 'failed'
                      ? Colors.red
                      : Colors.orange;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: Text(description),
                  subtitle: Text(
                    [
                      'Paid: $amount XAF',
                      if (operator != null) 'Operator: $operator',
                      if (date != null)
                        'Date: ${date.day}/${date.month}/${date.year}',
                      'Ref: ${docs[index].id}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
