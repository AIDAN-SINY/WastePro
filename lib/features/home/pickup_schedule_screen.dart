import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PickupScheduleScreen extends StatelessWidget {
  const PickupScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Pickups"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch clients who have a schedule
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'client')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection:
                Axis.horizontal, // Allows the table to slide left/right
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Client Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Day',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(
                    cells: [
                      DataCell(Text(data['fullName'] ?? 'N/A')),
                      DataCell(Text(data['pickupDay'] ?? 'Not set')),
                      DataCell(Text(data['pickupTime'] ?? 'Not set')),
                      DataCell(
                        // THE AUTOMATIC CHECKBOX
                        Icon(
                          // If needsPickup is false, it means we scanned the QR and it is "Done"
                          data['needsPickup'] == false
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: data['needsPickup'] == false
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
